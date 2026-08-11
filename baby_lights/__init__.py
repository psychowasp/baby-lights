from baby_lights.app import BabyLightsApp
from baby_lights.logger import logger

__all__ = ['BabyLightsApp']
__version__ = '0.1.1'


def main():
    """Run Baby Lights through the same entry point on desktop and Android."""
    import trio

    app = BabyLightsApp()
    trio.run(app.async_run, 'trio')


logger.info(f'Baby Lights App version {__version__} initialized.')
