# The power key, like on a phone (run by gnome-phone.nix in your session):
#   short press: screen off, or back on
#   hold 1 s:    log out (shut down from the login screen or the system menu)
# Also turns the screen on when a call comes in.
# GNOME's own power-key action is off, so only this script acts on it.

import subprocess
import threading
import time

import evdev
from evdev import ecodes

HOLD = 1.0  # seconds for "hold"


def find_power_key():
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        keys = dev.capabilities().get(ecodes.EV_KEY, [])
        if "pwrkey" in dev.name and ecodes.KEY_POWER in keys:
            return dev
    raise SystemExit("no power key found")


def screensaver(method, *args):
    return subprocess.run(
        ["gdbus", "call", "--session", "--dest", "org.gnome.ScreenSaver",
         "--object-path", "/org/gnome/ScreenSaver",
         "--method", f"org.gnome.ScreenSaver.{method}", *args],
        capture_output=True, text=True).stdout


def toggle_screen():
    # The screensaver without a lock screen is just a dark screen.
    on = "true" in screensaver("GetActive")
    screensaver("SetActive", "false" if on else "true")


def wake_on_calls():
    # ModemManager announces every new call with a CallAdded signal.
    monitor = subprocess.Popen(
        ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.ModemManager1"],
        stdout=subprocess.PIPE, text=True)
    for line in monitor.stdout:
        if "CallAdded" in line:
            screensaver("SetActive", "false")


threading.Thread(target=wake_on_calls, daemon=True).start()

dev = find_power_key()
pressed = None
for event in dev.read_loop():
    if event.type != ecodes.EV_KEY or event.code != ecodes.KEY_POWER:
        continue
    if event.value == 1:  # down
        pressed = time.monotonic()
    elif event.value == 0 and pressed is not None:  # up
        held = time.monotonic() - pressed
        pressed = None
        if held >= HOLD:
            subprocess.run(["gnome-session-quit", "--logout", "--no-prompt"])
        else:
            toggle_screen()
