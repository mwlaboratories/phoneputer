# Looks: wallpaper, colours and fonts, applied everywhere by Stylix.
#
# Stylix picks a colour scheme from the wallpaper and applies it to GNOME,
# GTK apps, the terminal and more. Docs: https://nix-community.github.io/stylix/
#
# The wallpaper itself is chosen in hosts/phoneputer/configuration.nix
# (stylix.image); wallpaper and colours change together.

{ config, pkgs, lib, ... }:

let
  inherit (config.stylix) fonts image polarity;
  size = toString fonts.sizes.applications;
  colors = config.lib.stylix.colors.withHashtag;

  # Two fixes for the phone on top of Stylix's GNOME Shell theme: the
  # clock's menu (notifications and calendar) is wider than the screen, so
  # a narrower notification list makes it fit; and the on-screen keyboard's
  # keys are nearly black, so a pressed key (a little darker) didn't show:
  # it lights up in the accent colour instead.
  phoneShellCss = pkgs.writeText "phone-shell.css" ''
    .message-list { width: 22em; }
    .keyboard-key:active, .keyboard-key:checked,
    .keyboard-key.default-key:active, .keyboard-key.default-key:checked {
      background-color: ${colors.base0D};
      color: ${colors.base00};
    }
  '';
in
{
  # Added to the theme Stylix builds into GNOME Shell (after Stylix's own
  # overlay, see overlays.enable below).
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          gr=$out/share/gnome-shell/gnome-shell-theme.gresource
          gresource=${pkgs.buildPackages.glib.dev}/bin/gresource
          mkdir phone-theme && cd phone-theme
          for r in $($gresource list $gr); do
            mkdir -p ".$(dirname $r)"
            $gresource extract $gr $r > ".$r"
          done
          for css in org/gnome/shell/theme/gnome-shell-{dark,light}.css; do
            if [ -e $css ]; then cat ${phoneShellCss} >> $css; fi
          done
          {
            echo '<?xml version="1.0" encoding="UTF-8"?><gresources><gresource prefix="/">'
            for r in $($gresource list $gr); do echo "<file>''${r#/}</file>"; done
            echo '</gresource></gresources>'
          } > theme.xml
          ${pkgs.buildPackages.glib.dev}/bin/glib-compile-resources --target=$gr theme.xml
          cd ..
        '';
      });
    })
  ];

  stylix = {
    enable = true;

    # Without a wallpaper of your own: NixOS artwork (CC-BY-SA 4.0); see
    # the others with `nix search nixpkgs nixos-artwork.wallpapers`.
    image = lib.mkDefault pkgs.nixos-artwork.wallpapers.waterfall.gnomeFilePath;

    # Dark or light theme.
    polarity = "dark";

    # The terminal lets the wallpaper show through (1 = solid). 0.6 suits
    # the terminal's dark background (home.nix) with the blur behind it.
    opacity.terminal = 0.6;

    # Stylix themes GNOME Shell (top bar, menus, login screen) by building
    # the colours into it, so a new wallpaper rebuilds GNOME Shell: about a
    # minute and a half when you rebuild on the phone. GNOME Shell loads its
    # theme when it starts: new colours in its menus show after you log out
    # and back in.
    overlays.enable = true;
    # Stylix's other two overlays rebuild far more than they change: a
    # colour scheme built into GtkSourceView recompiles every app that uses
    # it (Files, Text Editor, Papers, ...), and the recoloured NixOS logo
    # what shows it. The text editor gets the colours from Home Manager
    # instead, without rebuilding anything.
    targets.gtksourceview.enable = false;
    targets.nixos-icons.enable = false;
    # Qt apps keep GNOME's own Qt theme: Stylix only themes Qt through qtct,
    # and warns about GNOME's.
    targets.qt.enable = false;

    # GNOME's own fonts: clear on a small, sharp screen.
    fonts = {
      sansSerif = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      serif = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      monospace = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  # Stylix sets the GNOME wallpaper, dark mode and fonts for the user nix
  # through Home Manager (home.nix). These are the same as defaults for any
  # other user you add.
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/desktop/background" = {
        picture-uri = "file://${image}";
        picture-uri-dark = "file://${image}";
        picture-options = "zoom";
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri = "file://${image}";
        picture-options = "zoom";
      };
      "org/gnome/desktop/interface" = {
        color-scheme = if polarity == "dark" then "prefer-dark" else "default";
        font-name = "${fonts.sansSerif.name} ${size}";
        document-font-name = "${fonts.serif.name} ${size}";
        monospace-font-name = "${fonts.monospace.name} ${size}";
      };
    };
  }];

  # Boot screen: silentBoot sends the kernel's messages to a hidden console
  # (tty2), so no scrolling text on screen. Plymouth (splash) stays off for
  # now: its one test boot died, but so do some boots without it (under
  # investigation in the Mobile NixOS fork).
  mobile.beautification = {
    silentBoot = true;
    splash = false;
  };
}
