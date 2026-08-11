"""Apply the Baby Lights Android bootstrap compatibility workaround.

On the current ksproject/ksp-bootstraps development branches, Android's Java
environment updates are visible to ``System.getenv`` but not to the native
bootstrap's ``getenv`` call. Supply the two values from the generated project
configuration when native code cannot see them.
"""

from pathlib import Path
import os


def main() -> None:
    app_main = Path(os.environ["APP_MAIN"])
    main_c = app_main / "cpp" / "main.c"
    source = main_c.read_text(encoding="utf-8")

    old = '''    const char *app_path = getenv("ANDROID_APP_PATH");
    const char *entrypoint = getenv("ANDROID_ENTRYPOINT");
    if (!app_path || !entrypoint) {
        LOGE("missing ANDROID_APP_PATH / ANDROID_ENTRYPOINT");
        return 1;
    }
'''
    new = '''    const char *app_path = getenv("ANDROID_APP_PATH");
    const char *entrypoint = getenv("ANDROID_ENTRYPOINT");
    if (!app_path) {
        app_path = "/data/user/0/com.kivyschool.baby_lights/files/app";
    }
    if (!entrypoint) {
        entrypoint = "baby_lights";
    }
'''

    if old not in source:
        if new in source:
            return
        raise RuntimeError(f"Unexpected ksproject bootstrap source: {main_c}")

    main_c.write_text(source.replace(old, new, 1), encoding="utf-8")


if __name__ == "__main__":
    main()
