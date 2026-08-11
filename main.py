import os
import trio

# The package/Android entry point does not set this variable and therefore
# uses plain Kivy. This launcher is intentionally the development entry point.
os.environ.setdefault('BABY_LIGHTS_MODE', 'development')

from baby_lights import BabyLightsApp

app = BabyLightsApp()

trio.run(app.async_run, 'trio')
