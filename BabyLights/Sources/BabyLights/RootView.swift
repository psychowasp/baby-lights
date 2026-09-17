//
//  RootView.swift
//  BabyLights
//
//  Baby Lights on NucleantSwiftUI: a black screen that answers a touch
//  with a soft glow, behind a start screen for the parent. All the glows
//  are one `VertexShader`, an instance each — see LightsScreen.swift.
//
//  This is the library: everything but `@main`, which the package's
//  `BabyLightsApp` target and the Xcode app each supply in one file, so
//  both build the same code from here.
//

import NucleantSwiftUI
import Observation

/// Which screen is up and which dialog, if any, is over it. One per app:
/// the menu command that leaves the lights screen has no view to write
/// through, so it reaches this the way the examples' Appearance menu does.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen { case main, lights }

    enum Modal {
        case startConfirmation, about, exitConfirmation

        var title: String {
            switch self {
            case .startConfirmation: return "Start Baby Lights"
            case .about:             return "About Baby Lights"
            case .exitConfirmation:  return "Exit Baby Lights"
            }
        }

        var message: String {
            switch self {
            case .startConfirmation:
                return """
                    This will start immersive mode.

                    To exit later, press and hold both corners
                    (top-left and bottom-right) for 0.5 seconds.
                    """
            case .about:
                return """
                    Baby Lights is designed to
                    provide a distraction-free,
                    non-addictive visual for
                    babies who briefly handle
                    a parent's phone, preventing
                    accidental actions.

                    No data is collected.
                    No sounds, ads, or tracking.
                    """
            case .exitConfirmation:
                return "Are you sure you want to exit the app?"
            }
        }
    }

    var screen = Screen.main
    var modal: Modal?
}

@View
public struct RootView {
    @State private var touchManager = TouchManager()

    public init() {}

    public var body: some View {
        ZStack {
            switch AppModel.shared.screen {
            case .main:
                // The parent's screens live in a stack — settings is pushed
                // over the start screen and popped with Back. The lights
                // screen stays outside it: no bar, nothing for a baby to tap.
                NavigationStack("Baby Lights") {
                    MainScreen()
                }
            case .lights:
                LightsScreen()
            }
            if let modal = AppModel.shared.modal {
                Dialog(modal)
            }
        }
        .environment(\.touchManager, touchManager)
        .colorScheme(.light)
    }
}

/// The exit gesture needs two fingers, which a mouse does not have — so on
/// the desktop the lights screen is also left from the menu bar.
public struct BabyLightsCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandMenu("Lights") {
            Button("Exit Baby Lights") {
                AppModel.shared.modal = nil
                AppModel.shared.screen = .main
            }
        }
    }
}
