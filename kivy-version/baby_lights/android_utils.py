"""
Android system integration utilities.
Handles immersive mode and screen pinning functionality.
"""

from kivy.clock import Clock
from kivy.event import EventDispatcher
from kivy.properties import NumericProperty
from kivy.utils import platform

try:
    from android.runnable import run_on_ui_thread
except ImportError:
    # Fallback decorator if not available
    def run_on_ui_thread(func):
        return func


# Conditional import for Android-specific modules
if platform == 'android':
    try:
        from jnius import PythonJavaClass, autoclass, cast, java_method
    except ImportError:
        pass

from baby_lights.logger import logger


class SystemInsets(EventDispatcher):
    """Shared Android safe-area values for every Kivy component."""

    top = NumericProperty(0)
    bottom = NumericProperty(0)

    # ``None`` means that the Android window has not been measured yet.
    bars_visible = None
    request_pending = False
    request_generation = 0
    initialized = False
    last_nonzero_top = 0
    last_nonzero_bottom = 0


system_insets = SystemInsets()

# Showing system bars and receiving their final WindowInsets are separate
# Android operations.  During a resume/unlock transition Android can briefly
# return an empty inset, so give the window a few frames to settle before
# accepting ``0, 0`` as the new value.
_INSETS_RETRY_DELAYS = (0.05, 0.1, 0.2, 0.4, 0.8)


def set_system_bars_visible(visible):
    """Update the shared inset state when system bars change visibility."""
    previous_visibility = system_insets.bars_visible
    if previous_visibility != visible:
        system_insets.bars_visible = visible
        system_insets.request_generation += 1
        system_insets.initialized = False
        logger.info(
            'System-bar visibility changed: %s -> %s '
            '(generation=%s, cached top=%spx, bottom=%spx)',
            previous_visibility,
            visible,
            system_insets.request_generation,
            system_insets.top,
            system_insets.bottom,
        )

    if not visible:
        # Keep the last measured visible-bar insets.  The shader does not use
        # them, and retaining them prevents the main screen from jumping into
        # the navigation bar while Android is restoring the window after an
        # immersive-mode exit or device unlock.
        system_insets.request_pending = False
        logger.debug(
            'System bars hidden; retaining cached insets '
            '(top=%spx, bottom=%spx)',
            system_insets.top,
            system_insets.bottom,
        )


def refresh_system_bar_insets(force=False, _attempt=0):
    """Measure Android insets for the current system-bar state.

    The measurement is shared by the whole application. ``force=True`` is
    used after lifecycle/window transitions, when a previous measurement may
    still be valid syntactically but stale in practice.
    """
    if platform != 'android':
        system_insets.top = 0
        system_insets.bottom = 0
        system_insets.initialized = True
        return False

    if system_insets.bars_visible is not True:
        logger.debug('Skipping inset refresh while system bars are hidden')
        return False
    if system_insets.request_pending:
        logger.debug('Inset refresh already pending')
        return False
    if system_insets.initialized and not force:
        logger.debug('Skipping inset refresh; cached values are initialized')
        return False

    system_insets.request_pending = True
    generation = system_insets.request_generation
    logger.info(
        'Requesting system-bar insets (generation=%s, attempt=%s, force=%s)',
        generation,
        _attempt,
        force,
    )

    def apply_insets(top, bottom, navigation_visible):
        # A request from before entering immersive mode (or before the bars
        # were shown again) must not modify the state of the newer request.
        if system_insets.request_generation != generation:
            logger.debug(
                'Ignoring stale system-bar inset callback '
                '(generation=%s, current=%s)',
                generation,
                system_insets.request_generation,
            )
            return

        system_insets.request_pending = False
        if system_insets.bars_visible is not True:
            logger.debug('Ignoring inset callback while system bars are hidden')
            return

        # Right after resume/unlock the decor can report only one of the two
        # bars while the other one is still being animated in. Do not turn
        # that transient partial value into the shared layout state.
        navigation_pending = navigation_visible is not True
        missing_cached_bar = (
            top == 0 and system_insets.last_nonzero_top > 0
        ) or (bottom == 0 and system_insets.last_nonzero_bottom > 0)
        if (
            (top == 0 and bottom == 0)
            or navigation_pending
            or missing_cached_bar
        ) and _attempt < len(_INSETS_RETRY_DELAYS):
            delay = _INSETS_RETRY_DELAYS[_attempt]
            logger.info(
                'System-bar insets are not settled yet '
                '(top=%spx, bottom=%spx, navigation_visible=%s); '
                'retrying in %.2fs',
                top,
                bottom,
                navigation_visible,
                delay,
            )
            Clock.schedule_once(
                lambda _dt: refresh_system_bar_insets(
                    force=True, _attempt=_attempt + 1
                ),
                delay,
            )
            return

        # If Android still reports a transient zero after all retries, keep
        # the last known non-zero safe area. Extra padding is safer than
        # allowing content to be drawn underneath a visible navigation bar.
        if bottom == 0 and system_insets.last_nonzero_bottom > 0:
            logger.warning(
                'Navigation-bar inset did not settle; retaining last known '
                'bottom inset of %spx',
                system_insets.last_nonzero_bottom,
            )
            bottom = system_insets.last_nonzero_bottom
        if top == 0 and system_insets.last_nonzero_top > 0:
            logger.warning(
                'Status-bar inset did not settle; retaining last known '
                'top inset of %spx',
                system_insets.last_nonzero_top,
            )
            top = system_insets.last_nonzero_top

        system_insets.top = top
        system_insets.bottom = bottom
        if top > 0:
            system_insets.last_nonzero_top = top
        if bottom > 0:
            system_insets.last_nonzero_bottom = bottom
        system_insets.initialized = True
        logger.info(
            'Shared system-bar insets: top=%spx, bottom=%spx '
            '(generation=%s, attempt=%s)',
            top,
            bottom,
            generation,
            _attempt,
        )

    request_system_bar_insets(apply_insets)
    return True


def hide_status_bar_and_extend_content():
    if platform != 'android':
        return False
    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        VERSION = autoclass('android.os.Build$VERSION')
        View = autoclass('android.view.View')
        Color = autoclass('android.graphics.Color')
        LayoutParams = autoclass('android.view.WindowManager$LayoutParams')

        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def setup_ui():
            window = activity.getWindow()
            decor = window.getDecorView()

            # 1) Remove legacy/fullscreen flags that block edge-to-edge
            window.clearFlags(
                LayoutParams.FLAG_FULLSCREEN
                | LayoutParams.FLAG_LAYOUT_NO_LIMITS
                | LayoutParams.FLAG_TRANSLUCENT_STATUS
                | LayoutParams.FLAG_TRANSLUCENT_NAVIGATION
            )

            # 2) Allow the app to draw behind system bars
            if VERSION.SDK_INT >= 30:
                window.setDecorFitsSystemWindows(False)

                # Make bars transparent so content actually occupies that area
                window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
                window.setStatusBarColor(Color.TRANSPARENT)
                window.setNavigationBarColor(Color.TRANSPARENT)

                # Opt into display cutout area (notches)
                if VERSION.SDK_INT >= 28:
                    window.getAttributes().layoutInDisplayCutoutMode = (
                        LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    )
                    window.setAttributes(window.getAttributes())

                # Hide bars using WindowInsetsController
                WindowInsets = autoclass('android.view.WindowInsets$Type')
                WindowInsetsController = autoclass(
                    'android.view.WindowInsetsController'
                )
                controller = window.getInsetsController()
                if controller:
                    controller.hide(
                        WindowInsets.statusBars() | WindowInsets.navigationBars()
                    )
                    controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    )
            else:
                # Legacy best-effort for < API 30
                window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
                window.setStatusBarColor(Color.TRANSPARENT)
                window.setNavigationBarColor(Color.TRANSPARENT)

                flags = (
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
                decor.setSystemUiVisibility(flags)

            logger.info('Edge-to-edge enabled; status bar area now usable.')

        setup_ui()
        set_system_bars_visible(False)
        return True
    except Exception as e:
        logger.error(f'Failed to enable edge-to-edge: {e}')
        return False


def show_status_bar_and_constrain_content():
    """
    Show the status bar and navigation bar.

    This does the opposite of hide_status_bar_and_extend_content():
    - Shows status bar and navigation bar
    - Keeps the window edge-to-edge on modern Android
    - Lets the app apply the actual WindowInsets to its content
    - Restores standard Android app behavior
    """
    if platform != 'android':
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        VERSION = autoclass('android.os.Build$VERSION')
        View = autoclass('android.view.View')
        LayoutParams = autoclass('android.view.WindowManager$LayoutParams')

        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def setup_ui():
            window = activity.getWindow()
            decor = window.getDecorView()

            # Get current flags
            current_flags = decor.getSystemUiVisibility()

            # Remove the layout flags that extend content behind system bars
            new_flags = current_flags & ~(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )

            # Apply the new flags
            decor.setSystemUiVisibility(new_flags)

            # 1) Clear any fullscreen/edge-to-edge flags
            window.clearFlags(
                LayoutParams.FLAG_FULLSCREEN
                | LayoutParams.FLAG_LAYOUT_NO_LIMITS
                | LayoutParams.FLAG_TRANSLUCENT_STATUS
                | LayoutParams.FLAG_TRANSLUCENT_NAVIGATION
            )

            # 2) Restore normal windowed behavior
            if VERSION.SDK_INT >= 30:
                # Android 15/API 35 enforces edge-to-edge for apps targeting
                # API 35+. Keep the window edge-to-edge and apply the actual
                # system-bar insets to the Kivy layout ourselves.
                window.setDecorFitsSystemWindows(False)

                # Restore system bar backgrounds (not transparent)
                window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

                # Force non-transparent bars to create proper boundaries
                Color = autoclass('android.graphics.Color')
                # Use a solid color instead of leaving it default
                window.setStatusBarColor(Color.parseColor('#000000'))
                window.setNavigationBarColor(Color.parseColor('#000000'))

                # Show bars using WindowInsetsController
                WindowInsets = autoclass('android.view.WindowInsets$Type')
                WindowInsetsController = autoclass(
                    'android.view.WindowInsetsController'
                )
                controller = window.getInsetsController()
                if controller:
                    controller.show(
                        WindowInsets.statusBars() | WindowInsets.navigationBars()
                    )
                    # Reset behavior to default
                    controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_DEFAULT
                    )

            else:
                # Legacy approach: clear all immersive/fullscreen flags
                window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

                # Clear all system UI flags (back to normal windowed mode)
                decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE)

            logger.info('Status bar shown and content constrained to safe area.')

        setup_ui()
        set_system_bars_visible(True)
        # Showing the bars after immersive mode or resume requires a fresh
        # read even when the provider already has initialized values.
        refresh_system_bar_insets(force=True)
        return True
    except Exception as e:
        logger.error(f'Failed to show status bar and constrain content: {e}')
        return False


def request_system_bar_insets(callback):
    """Read the visible system-bar insets and return them to Kivy.

    ``WindowInsets`` are reported by Android in physical pixels, which is also
    the unit used internally by Kivy layouts. The callback is scheduled on the
    Kivy thread and receives ``(top, bottom, navigation_visible)``. On desktop,
    or if Android does not expose the insets, the values are zero/``None``.

    The request is asynchronous because Android requires window operations to
    happen on its UI thread and the insets can change after system bars are
    shown or hidden.
    """

    def deliver(top, bottom, navigation_visible=None):
        Clock.schedule_once(
            lambda _dt: callback(top, bottom, navigation_visible), 0
        )

    if platform != 'android':
        deliver(0, 0, None)
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        VERSION = autoclass('android.os.Build$VERSION')
        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def read_insets():
            try:
                decor = activity.getWindow().getDecorView()
                window_insets = decor.getRootWindowInsets()

                if window_insets is None:
                    logger.warning('Android WindowInsets are not available yet')
                    deliver(0, 0, None)
                    return

                if VERSION.SDK_INT >= 30:
                    WindowInsetsType = autoclass('android.view.WindowInsets$Type')
                    navigation_bar_type = WindowInsetsType.navigationBars()
                    inset_types = (
                        WindowInsetsType.statusBars()
                        | navigation_bar_type
                        | WindowInsetsType.displayCutout()
                    )
                    insets = window_insets.getInsets(inset_types)
                    top, bottom = insets.top, insets.bottom
                    navigation_visible = window_insets.isVisible(
                        navigation_bar_type
                    )
                else:
                    # On older Android versions the normal windowed mode above
                    # already applies system-bar insets to the content view.
                    # Do not add them a second time in the Kivy layout.
                    top, bottom = 0, 0
                    navigation_visible = None

                logger.info(
                    'System-bar insets: top=%spx, bottom=%spx, '
                    'navigation_visible=%s',
                    top,
                    bottom,
                    navigation_visible,
                )
                deliver(top, bottom, navigation_visible)
            except Exception as e:
                logger.error(f'Failed to read Android WindowInsets: {e}')
                deliver(0, 0, None)

        read_insets()
        return True
    except Exception as e:
        logger.error(f'Failed to request Android WindowInsets: {e}')
        deliver(0, 0, None)
        return False


def enable_immersive_mode():
    """
    Enable immersive sticky mode and screen pinning on Android.

    This will:
    - Hide navigation and status bars
    - Enable sticky immersive mode
    - Pin the app (prevent task switching)
    """
    logger.info('Enabling immersive sticky mode on Android')

    if platform != 'android':
        logger.info('Not on Android platform, skipping immersive mode')
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        View = autoclass('android.view.View')

        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def setup_ui():
            """Setup immersive UI on the main thread."""
            try:
                decor = activity.getWindow().getDecorView()
                flags = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
                decor.setSystemUiVisibility(flags)
                logger.info('Immersive mode enabled successfully')

                # Try to enable screen pinning
                activity.startLockTask()
                logger.info('Screen pinning enabled successfully')

            except Exception as e:
                logger.warning(f'Could not start lock task: {e}')

        # Run on UI thread using decorator
        setup_ui()

        return True

    except ImportError as e:
        logger.error(f'Failed to import Android modules: {e}')
        return False
    except Exception as e:
        logger.error(f'Failed to enable immersive mode: {e}')
        return False


def disable_immersive_mode():
    """
    Disable immersive mode and restore normal navigation.

    This will:
    - Restore navigation and status bars
    - Stop screen pinning
    """
    logger.info('Disabling immersive mode on Android')

    if platform != 'android':
        logger.info('Not on Android platform, skipping')
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        View = autoclass('android.view.View')

        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def restore_ui():
            """Restore normal UI on the main thread."""
            try:
                decor = activity.getWindow().getDecorView()
                decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE)
                logger.info('Normal UI mode restored')

                activity.stopLockTask()
                logger.info('Screen pinning disabled')

            except Exception as e:
                logger.warning(f'Could not stop lock task: {e}')

        # Run on UI thread using decorator
        restore_ui()

        return True

    except ImportError as e:
        logger.error(f'Failed to import Android modules: {e}')
        return False
    except Exception as e:
        logger.error(f'Failed to disable immersive mode: {e}')
        return False


def set_status_bar_color(color_hex='#F5F7FF'):
    """
    Set Android status bar color.

    Args:
        color_hex (str): Hex color code (e.g., '#F5F7FF' for soft blue-white)
    """
    if platform == 'android':
        try:
            # Get the Android activity
            PythonActivity = autoclass('org.kivy.android.PythonActivity')
            activity = cast('android.app.Activity', PythonActivity.mActivity)

            @run_on_ui_thread
            def setup_status_bar():
                """Setup status bar color on the main thread."""
                try:
                    # Get window and set status bar color
                    window = activity.getWindow()

                    # Get Android constants - access nested class properly
                    LayoutParams = autoclass('android.view.WindowManager$LayoutParams')

                    # Clear the translucent status bar flag and add
                    # system bar backgrounds
                    window.clearFlags(LayoutParams.FLAG_TRANSLUCENT_STATUS)
                    window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

                    # Convert hex to Android color int
                    Color = autoclass('android.graphics.Color')
                    color_int = Color.parseColor(color_hex)

                    # Set the status bar color
                    window.setStatusBarColor(color_int)

                    logger.info(f'Status bar color set to {color_hex}')

                except Exception as e:
                    logger.error(f'Failed to set status bar color: {e}')

            # Run on UI thread using decorator
            setup_status_bar()

            # Set icons to dark for light background (call separately)
            set_status_bar_icons_dark(True)

        except Exception as e:
            logger.error(f'Failed to set status bar color: {e}')


def set_status_bar_icons_dark(dark=True):
    """
    Set status bar icons to dark or light.

    Args:
        dark (bool): True for dark icons (light status bar),
                    False for light icons (dark status bar)
    """
    if platform == 'android':
        try:
            PythonActivity = autoclass('org.kivy.android.PythonActivity')
            activity = cast('android.app.Activity', PythonActivity.mActivity)

            @run_on_ui_thread
            def setup_status_bar_icons():
                """Setup status bar icons on the main thread."""
                try:
                    # Get Android View class for constants
                    View = autoclass('android.view.View')

                    window = activity.getWindow()
                    view = window.getDecorView()

                    # Get current system UI flags
                    current_flags = view.getSystemUiVisibility()
                    logger.info(f'Current UI flags: {current_flags}')

                    if dark:
                        # Add light status bar flag (dark icons)
                        new_flags = current_flags | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                        logger.info(
                            f'Setting LIGHT_STATUS_BAR flag: {View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR}'
                        )
                    else:
                        # Remove light status bar flag (light icons)
                        new_flags = (
                            current_flags & ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                        )
                        logger.info('Removing LIGHT_STATUS_BAR flag')

                    view.setSystemUiVisibility(new_flags)
                    logger.info(f'New UI flags set to: {new_flags}')

                    icon_type = 'dark' if dark else 'light'
                    logger.info(f'Status bar icons set to {icon_type}')

                except Exception as e:
                    logger.error(f'Failed to set status bar icons: {e}')

            # Run on UI thread using decorator
            setup_status_bar_icons()

        except Exception as e:
            logger.error(f'Failed to set status bar icons: {e}')


def set_navigation_bar_black():
    """
    Set the navigation bar (bottom bar) color to black.

    This function specifically changes the bottom navigation bar color
    to black, which can be useful for creating a consistent dark theme
    or matching specific design requirements.
    """
    if platform != 'android':
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        activity = cast('android.app.Activity', PythonActivity.mActivity)

        @run_on_ui_thread
        def setup_navigation_bar():
            """Set navigation bar color to black on the main thread."""
            try:
                window = activity.getWindow()

                # Get Android constants and Color class
                LayoutParams = autoclass('android.view.WindowManager$LayoutParams')
                Color = autoclass('android.graphics.Color')

                # Enable system bar backgrounds to allow color changes
                window.addFlags(LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

                # Set navigation bar color to black
                window.setNavigationBarColor(Color.BLACK)

                logger.info('Navigation bar color set to black')

            except Exception as e:
                logger.error(f'Failed to set navigation bar color: {e}')

        # Run on UI thread using decorator
        setup_navigation_bar()
        return True

    except Exception as e:
        logger.error(f'Failed to set navigation bar black: {e}')
        return False


def is_lock_task_active():
    """
    Simple check if screen pinning (lock task) is active.

    Returns:
        bool: True if lock task is active
    """
    if platform != 'android':
        return False

    try:
        PythonActivity = autoclass('org.kivy.android.PythonActivity')
        ActivityManager = autoclass('android.app.ActivityManager')

        activity = cast('android.app.Activity', PythonActivity.mActivity)
        activity_manager = activity.getSystemService('activity')
        lock_task_state = activity_manager.getLockTaskModeState()
        lock_task_active = lock_task_state != ActivityManager.LOCK_TASK_MODE_NONE

        logger.debug(
            f'Lock task check: state={lock_task_state}, active={lock_task_active}'
        )

        return lock_task_active

    except Exception as e:
        logger.error(f'Failed to check lock task state: {e}')
        return False
