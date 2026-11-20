# GNOME on a phone screen.
#
# GNOME runs on the phone mostly as it comes, at 150% scale (set below).
# This file adds what a phone needs on top: the Stylix colours in GNOME
# Shell, the clock hidden from behind the notch, the on-screen keyboard
# with haptic feedback, and the power key turning the screen off and on.

{ config, pkgs, stylix, ... }:

let
  # GNOME Shell's own theme in the Stylix colours. Stylix would normally
  # patch and recompile all of GNOME Shell for this (stylix.nix turns that
  # off); building just the stylesheet keeps GNOME Shell from the binary
  # cache. It's loaded as the "Phoneputer" shell theme.
  stylixShellTheme = pkgs.callPackage "${stylix}/modules/gnome/theme.nix" {
    inherit (config.lib.stylix) colors;
    inherit (config.stylix) inputs;
  };

  phoneTheme = pkgs.writeTextDir "share/themes/Phoneputer/gnome-shell/gnome-shell.css" ''
    @import url("file://${stylixShellTheme}/share/gnome-shell/gnome-shell.css");
  '';

  # Our own small extension (./osk-haptics): a short vibration on every
  # touch of the on-screen keyboard, which GNOME doesn't do by itself.
  oskHaptics = pkgs.runCommand "gnome-shell-extension-osk-haptics" {
    passthru.extensionUuid = "osk-haptics@phoneputer";
  } ''
    dir=$out/share/gnome-shell/extensions/osk-haptics@phoneputer
    mkdir -p $dir
    cp ${./osk-haptics/metadata.json} $dir/metadata.json
    cp ${./osk-haptics/extension.js} $dir/extension.js
  '';

  # Developer access (./dev-access): lets tools over SSH take screenshots
  # and run GNOME Shell JavaScript, so a coding agent can see and drive
  # the phone like adb on Android. Any program in your session can then
  # take screenshots too; set to false to turn it off.
  devAccess = true;
  devAccessExtension = pkgs.runCommand "gnome-shell-extension-dev-access" {
    passthru.extensionUuid = "dev-access@phoneputer";
  } ''
    dir=$out/share/gnome-shell/extensions/dev-access@phoneputer
    mkdir -p $dir
    cp ${./dev-access/metadata.json} $dir/metadata.json
    cp ${./dev-access/extension.js} $dir/extension.js
  '';

  extensions = (with pkgs.gnomeExtensions; [
    user-themes      # loads the theme above
    just-perfection  # hides the clock
  ]) ++ [ oskHaptics ] ++ pkgs.lib.optional devAccess devAccessExtension;
in
{
  environment.systemPackages = extensions ++ [ phoneTheme ];

  # The power key: short press turns the screen off or on, holding it for
  # a second logs out (./power-key.py). Shut down from the login screen or
  # the system menu.
  systemd.user.services.power-key = {
    description = "Power key: screen off/on, hold to log out; screen on for calls";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.glib pkgs.gnome-session ];
    serviceConfig = {
      ExecStart = "${pkgs.python3.withPackages (ps: [ ps.evdev ])}/bin/python3 ${./power-key.py}";
      Restart = "on-failure";
    };
  };
  # The phone never sleeps. GNOME still tries to when the power key is
  # pressed with the screen off (whatever power-button-action says), so
  # sleeping is refused outright; GNOME then also drops "Suspend" from its
  # menu. Shutting down and restarting are unaffected.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id.indexOf("org.freedesktop.login1.suspend") == 0 ||
          action.id.indexOf("org.freedesktop.login1.hibernate") == 0 ||
          action.id.indexOf("org.freedesktop.login1.hybrid-sleep") == 0) {
        return polkit.Result.NO;
      }
    });
  '';
  # The system itself ignores the key (its default is to shut down).
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
  };
  # Let the logged-in user read the power key. The rule has to run before
  # udev's seat rules (73-*), which turn "uaccess" into access.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-power-key.rules" ''
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*pwrkey*", TAG+="uaccess"
    '')
  ];

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
        # Chromium-based browsers (Brave, Chrome) handle touch poorly and
        # don't bring up GNOME's on-screen keyboard yet.
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "firefox.desktop"
          "org.gnome.Calls.desktop"
          "signal.desktop"
        ];
      };
      "org/gnome/shell/extensions/user-theme".name = "Phoneputer";
      "org/gnome/shell/extensions/just-perfection" = {
        # The clock (and with it the notification list) sits behind the
        # notch; hide it. Notifications still pop up as banners.
        clock-menu = false;
        support-notifier-type = pkgs.lib.gvariant.mkInt32 0; # no pop-ups
      };
      # Dragging a window to the top edge maximizes it (off by default in
      # GNOME 51).
      "org/gnome/mutter".edge-tiling = true;
      # feedbackd: vibrations only, no click sounds ("full" adds sounds).
      "org/sigxcpu/feedbackd".profile = "quiet";
      # On-screen keyboard always on: it comes up whenever a text field is
      # tapped. GNOME's automatic mode only works in "touch mode", which the
      # phone's buttons (volume, alert slider, power: keyboards to Linux)
      # get in the way of.
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
