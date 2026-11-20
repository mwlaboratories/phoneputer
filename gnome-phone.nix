# GNOME on a phone screen.
#
# GNOME runs on the phone mostly as it comes, at 150% scale (set below).
# This file adds what a phone needs on top: the Stylix colours in GNOME
# Shell, the clock hidden from behind the notch, the on-screen keyboard
# with haptic feedback, and sleeping when the screen goes dark.

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

  extensions = (with pkgs.gnomeExtensions; [
    user-themes      # loads the theme above
    just-perfection  # hides the clock
  ]) ++ [ oskHaptics ];
in
{
  environment.systemPackages = extensions ++ [ phoneTheme ];

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
        # The dock. The browser is Firefox: Chromium-based browsers (Brave,
        # Chrome) handle touch poorly and don't bring up GNOME's on-screen
        # keyboard yet. YouTube and Fluid are websites (webApp in
        # configuration.nix).
        favorite-apps = [
          "com.mitchellh.ghostty.desktop"
          "firefox.desktop"
          "youtube.desktop"
          "org.luanti.luanti.desktop"
          "fluid.desktop"
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
      # Like a phone: when the screen goes dark it sleeps, so one press of
      # the power key always wakes it. GNOME blanks the screen after
      # idle-delay (5 min by default, GNOME Settings → Power) and only
      # suspends after 15 min; a press in between woke the screen and then
      # suspended at once. If you change the blank delay, match it here.
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-battery-timeout = pkgs.lib.gvariant.mkInt32 300;
        sleep-inactive-ac-timeout = pkgs.lib.gvariant.mkInt32 300;
      };
    };
    # The extensions come from this file, not from the Extensions app: the
    # list is locked, so every user gets exactly these (also users who had
    # their own list). Add or remove extensions above, in `extensions`.
    locks = [ "/org/gnome/shell/enabled-extensions" ];
  }];
}
