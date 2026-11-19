# GNOME on a phone screen.
#
# GNOME is made for laptops. On a phone its app grid shows tiny icons with
# cut-off names, and its clock sits in the middle of the top bar, behind
# the notch. This file fixes the app grid with a few lines of style (CSS)
# and hides the clock. The numbers are in GNOME's logical pixels.

{ config, pkgs, stylix, ... }:

let
  # GNOME Shell's own theme in the Stylix colours. Stylix would normally
  # patch and recompile all of GNOME Shell for this (stylix.nix turns that
  # off); building just the stylesheet keeps GNOME Shell from the binary
  # cache.
  stylixShellTheme = pkgs.callPackage "${stylix}/modules/gnome/theme.nix" {
    inherit (config.lib.stylix) colors;
    inherit (config.stylix) inputs;
  };

  # A GNOME Shell theme: the Stylix-coloured theme, plus the phone tweaks
  # below.
  phoneTheme = pkgs.writeTextDir "share/themes/Phoneputer/gnome-shell/gnome-shell.css" ''
    @import url("file://${stylixShellTheme}/share/gnome-shell/gnome-shell.css");

    /* App grid: four columns of large icons with short, small names,
       like a phone home screen. */
    .icon-grid {
      column-spacing: 4px;
      row-spacing: 8px;
      page-padding-top: 12px;
      page-padding-bottom: 12px;
      page-padding-left: 8px;
      page-padding-right: 8px;
    }
    .overview-tile {
      padding: 6px;
    }
    .overview-icon.overview-icon-with-label StLabel {
      width: 76px;
      font-size: 0.85em;
    }
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

  # Brave on a phone: always full screen, and tell GNOME when a text field
  # is tapped so the on-screen keyboard comes up (Chromium only does that
  # with these flags). A wrapper, so Brave itself still comes from the
  # binary cache.
  nixpkgs.overlays = [
    (final: prev: {
      brave = prev.symlinkJoin {
        name = "brave-phone-${prev.brave.version}";
        paths = [ prev.brave ];
        nativeBuildInputs = [ prev.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/brave --add-flags \
            "--start-maximized --enable-wayland-ime --wayland-text-input-version=3"
          desktop=$out/share/applications/brave-browser.desktop
          sed "s#${prev.brave}/bin/brave#$out/bin/brave#g" \
            ${prev.brave}/share/applications/brave-browser.desktop > $desktop.new
          rm $desktop && mv $desktop.new $desktop
        '';
        inherit (prev.brave) meta;
      };
    })
  ];

  # feedbackd plays vibrations (and sounds) for events; it knows the
  # OnePlus 6's vibration motor from its device theme. Users need to be in
  # the `feedbackd` group (see configuration.nix).
  programs.feedbackd.enable = true;

  # Defaults for every user; still changeable in the Extensions app.
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell" = {
        enabled-extensions = map (e: e.extensionUuid) extensions;
        # The dock: just a browser and the file manager.
        favorite-apps = [ "brave-browser.desktop" "org.gnome.Nautilus.desktop" ];
      };
      "org/gnome/shell/extensions/user-theme".name = "Phoneputer";
      "org/gnome/shell/extensions/just-perfection" = {
        # The clock (and with it the notification list) sits behind the
        # notch; hide it. Notifications still pop up as banners.
        clock-menu = false;
        support-notifier-type = pkgs.lib.gvariant.mkInt32 0; # no pop-ups
        # Every window opens full screen, like apps on a phone.
        window-maximized-on-create = true;
      };
      # Dragging a window to the top edge maximizes it (off by default in
      # GNOME 51).
      "org/gnome/mutter".edge-tiling = true;
      # feedbackd: vibrations only, no click sounds ("full" adds sounds).
      "org/sigxcpu/feedbackd".profile = "quiet";
    };
  }];
}
