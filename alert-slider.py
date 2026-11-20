# The alert slider on the side of the phone (run by gnome-phone.nix in
# your session):
#   top:    silent  - no ringtone, no vibration, Do Not Disturb on
#   middle: vibrate - vibration only
#   bottom: ring    - ringtone and vibration
# Rings and vibrations come from feedbackd, so the slider switches its
# profile. Music, videos and the call itself keep their volume.

import subprocess

import evdev
from evdev import ecodes

ABS_SND_PROFILE = 0x22  # the slider's position: 0 top, 1 middle, 2 bottom
POSITIONS = {
    0: ("silent", False),  # feedbackd profile, notification banners
    1: ("quiet", True),
    2: ("full", True),
}


def find_slider():
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if ABS_SND_PROFILE in dict(dev.capabilities().get(ecodes.EV_ABS, [])):
            return dev
    raise SystemExit("no alert slider found")


def apply(position):
    profile, banners = POSITIONS.get(position, POSITIONS[2])
    subprocess.run(["gsettings", "set", "org.sigxcpu.feedbackd", "profile", profile])
    subprocess.run(["gsettings", "set", "org.gnome.desktop.notifications",
                    "show-banners", "true" if banners else "false"])


dev = find_slider()
apply(dev.absinfo(ABS_SND_PROFILE).value)  # where it stands at login
for event in dev.read_loop():
    if event.type == ecodes.EV_ABS and event.code == ABS_SND_PROFILE:
        apply(event.value)
