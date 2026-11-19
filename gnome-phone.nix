# GNOME on a phone screen.
#
# GNOME is made for laptops: its top bar runs into the rounded screen
# corners and puts the clock under the notch, and its app grid uses tiny
# icons with cut-off names on a narrow screen. This file fixes both with
# two GNOME extensions and a few lines of style (CSS). The numbers are in
# GNOME's logical pixels; the OnePlus 6 runs at 2.5× scale, so its screen
# is 432 logical pixels wide.

{ pkgs, ... }:

let
  # A GNOME Shell theme: the normal theme (with the Stylix colours), plus
  # the phone tweaks below.
  phoneTheme = pkgs.writeTextDir "share/themes/Phoneputer/gnome-shell/gnome-shell.css" ''
    @import url("resource:///org/gnome/shell/theme/gnome-shell-dark.css");

    /* Top bar: keep clear of the rounded screen corners. */
    #panel {
      padding: 0 22px;
    }

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

  extensions = with pkgs.gnomeExtensions; [
    user-themes      # loads the theme above
    just-perfection  # moves the clock out from under the notch
  ];
in
{
  environment.systemPackages = extensions ++ [ phoneTheme ];

  # Defaults for every user; still changeable in the Extensions app.
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell".enabled-extensions =
        map (e: e.extensionUuid) extensions;
      "org/gnome/shell/extensions/user-theme".name = "Phoneputer";
      "org/gnome/shell/extensions/just-perfection" = {
        clock-menu-position = pkgs.lib.gvariant.mkInt32 2;        # left
        clock-menu-position-offset = pkgs.lib.gvariant.mkInt32 0; # first
        support-notifier-type = pkgs.lib.gvariant.mkInt32 0;      # no pop-ups
      };
    };
  }];
}
