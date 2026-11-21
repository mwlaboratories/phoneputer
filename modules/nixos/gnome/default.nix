# GNOME on a phone screen.
#
# GNOME runs on the phone mostly as it comes, at 150% scale (set below).
# This adds what a phone needs on top: the clock moved out from behind the
# notch, the on-screen keyboard by hand and with haptic
# feedback, and the defaults below. The power key and alert slider are in
# ./buttons.nix.

{ pkgs, ... }:

let
  # Our own small extensions, in ./extensions.
  extension = name: pkgs.runCommand "gnome-shell-extension-${name}" {
    passthru.extensionUuid = "${name}@phoneputer";
  } ''
    dir=$out/share/gnome-shell/extensions/${name}@phoneputer
    mkdir -p $dir
    cp ${./extensions + "/${name}/metadata.json"} $dir/metadata.json
    cp ${./extensions + "/${name}/extension.js"} $dir/extension.js
  '';

  # Developer access (dev-access): lets tools over SSH take screenshots and
  # run GNOME Shell JavaScript, so a coding agent can see and drive the
  # phone like adb on Android. Any program in your session can then take
  # screenshots too; set to false to turn it off.
  devAccess = true;

  extensions = (with pkgs.gnomeExtensions; [
    just-perfection  # moves the clock, hides icons
    blur-my-shell    # blur behind see-through windows (Ghostty: see home.nix) and the top bar
  ]) ++ [
    (extension "osk-haptics") # a short vibration on every key of the on-screen keyboard
    (extension "osk-manual")  # the on-screen keyboard only opens with a swipe up from the bottom edge
    (extension "osk-voice")   # dictation: a microphone button above the keys (./dictation.nix)
  ] ++ pkgs.lib.optional devAccess (extension "dev-access");
in
{
  imports = [
    ./buttons.nix
    ./dictation.nix
  ];

  environment.systemPackages = extensions;

  # The phone's internal storage holds dozens of Android partitions
  # (system, vendor, modem, ...); without this Files lists a dozen of them
  # in its sidebar ("/", "odm", "34 MB Volume", ...). Your files are in your
  # home folder, and the whole disk is under Other Locations → Computer.
  # A USB stick isn't on this storage chip, so it still shows up.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_PATH}=="platform-1d84000.ufshc-*", ENV{UDISKS_IGNORE}="1"
  '';

  # Display scale 150%. GNOME picks 250% by itself, which leaves a screen
  # only 432 pixels wide in GNOME's terms: menus run off the edge and
  # dragging windows doesn't work well. At 150% it's 720 wide. This is the
  # default for every user and the login screen; change it per user in
  # GNOME Settings → Displays.
  environment.etc."xdg/monitors.xml".text = ''
    <monitors version="2">
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>0</x>
          <y>0</y>
          <scale>1.5</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>DSI-1</connector>
              <vendor>unknown</vendor>
              <product>unknown</product>
              <serial>unknown</serial>
            </monitorspec>
            <mode>
              <width>1080</width>
              <height>2280</height>
              <rate>60.000</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';

  # feedbackd plays vibrations (and sounds) for events; it knows the
  # OnePlus 6's vibration motor from its device theme. Users need to be in
  # the `feedbackd` group (see configuration.nix).
  programs.feedbackd.enable = true;

  # Defaults for every user; most stay changeable in GNOME Settings.
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell" = {
        enabled-extensions = map (e: e.extensionUuid) extensions;
        # The dock: files, browser, phone and Signal. The browser is Firefox:
        # Chromium-based browsers (Brave, Chrome) handle touch poorly. The
        # on-screen keyboard comes up with a swipe up from the bottom edge.
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "firefox.desktop"
          "org.gnome.Calls.desktop"
          "signal.desktop"
        ];
      };
      "org/gnome/shell/extensions/just-perfection" = {
        # The clock sits behind the notch in the middle; move it to the
        # left, next to the workspace dots. Tap it for your notifications
        # (missed calls, SMS, ...) and the calendar.
        clock-menu-position = pkgs.lib.gvariant.mkInt32 2; # left
        clock-menu-position-offset = pkgs.lib.gvariant.mkInt32 1; # after the dots
        support-notifier-type = pkgs.lib.gvariant.mkInt32 0; # no pop-ups
        # The accessibility icon shows in the top bar because the on-screen
        # keyboard counts as an accessibility feature; it only takes room
        # next to the notch. Settings → Accessibility still has it all.
        accessibility-menu = false;
      };
      # The battery level in numbers in the top bar, like on a phone.
      "org/gnome/desktop/interface".show-battery-percentage = true;
      # Dragging a window to the top edge maximizes it (off by default in
      # GNOME 51).
      "org/gnome/mutter".edge-tiling = true;
      # feedbackd: vibrations only, no click sounds. The alert slider sets
      # this at login and whenever you move it (alert-slider.py).
      "org/sigxcpu/feedbackd".profile = "quiet";
      # The on-screen keyboard is always available, so the swipe up from the
      # bottom edge always opens it (otherwise only in GNOME's "touch mode",
      # which the phone's buttons, keyboards to Linux, keep breaking). It
      # never pops up by itself: see osk-manual.
      "org/gnome/desktop/a11y/applications".screen-keyboard-enabled = true;
      # Like your monitor: after idle-delay (5 min, GNOME Settings → Power)
      # the screen only goes off; the phone never sleeps, so it stays
      # online (calls, SSH, downloads). Costs more battery than sleeping.
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-battery-type = "nothing";
        sleep-inactive-ac-type = "nothing";
        # The power key turns the screen off and on (powerKeyScreen
        # below), not GNOME's suspend.
        power-button-action = "nothing";
      };
      # No lock screen: when the screen comes back on you're straight back
      # in your session, apps as you left them, without typing your
      # password. Anyone holding the phone can use it then; turn
      # "Automatic Screen Lock" on in GNOME Settings → Privacy if you want
      # the password back.
      "org/gnome/desktop/screensaver".lock-enabled = false;
    };
    # The extensions come from this file, not from the Extensions app: the
    # list is locked, so every user gets exactly these (also users who had
    # their own list). Add or remove extensions above, in `extensions`.
    locks = [ "/org/gnome/shell/enabled-extensions" ];
  }];
}
