# GNOME on a phone screen.
#
# GNOME is made for laptops: its top bar runs into the rounded screen
# corners and puts the clock under the notch, and its app grid uses tiny
# icons with cut-off names on a narrow screen. This file fixes both with
# two GNOME extensions and a few lines of style (CSS). The numbers are in
# GNOME's logical pixels; the OnePlus 6 runs at 2.5× scale, so its screen
# is 432 logical pixels wide.

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

    /* Quick settings: GNOME's toggles are 12em wide, so two of them
       don't fit next to each other; narrower ones do. */
    .quick-toggle {
      min-width: 10.5em;
      max-width: 10.5em;
    }

    /* Clock menu: notifications and the date only (the month calendar is
       hidden below); GNOME's 29em notification list is wider than the
       whole screen. */
    .message-list {
      width: 13em;
    }
    .datemenu-today-button .date-label {
      font-size: 1em;
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
        # The Activities button would sit under the notch. Swipe up from
        # the bottom edge to open the overview instead.
        activities-button = false;
        # Clock menu: notifications and the date, like a phone's pull-down.
        # The month calendar is in the Calendar app.
        calendar = false;
        events-button = false;
        world-clock = false;
        weather = false;
      };
      # Just the time in the top bar, like a phone.
      "org/gnome/desktop/interface".clock-show-date = false;
    };
  }];
}
