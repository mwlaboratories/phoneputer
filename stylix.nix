# Looks: wallpaper, colours and fonts, applied everywhere by Stylix.
#
# Stylix picks a colour scheme from the wallpaper and applies it to GNOME,
# GTK apps, the terminal and more. Docs: https://nix-community.github.io/stylix/
#
# Your own wallpaper: put an image named wallpaper.png or wallpaper.jpg next
# to flake.nix, `git add` it (a flake only sees files git knows about), and
# rebuild. Wallpaper and colours change together. Without one, the phone
# uses the NixOS "waterfall" wallpaper.

{ config, pkgs, lib, ... }:

let
  inherit (config.stylix) fonts image polarity;
  size = toString fonts.sizes.applications;

  ownWallpaper = lib.findFirst builtins.pathExists null [
    ./wallpaper.png
    ./wallpaper.jpg
  ];
in
{
  stylix = {
    enable = true;

    # The wallpaper; the colours are taken from it. The default is NixOS
    # artwork (CC-BY-SA 4.0); see the others with
    # `nix search nixpkgs nixos-artwork.wallpapers`.
    image =
      if ownWallpaper != null then ownWallpaper
      else pkgs.nixos-artwork.wallpapers.waterfall.gnomeFilePath;

    # Dark or light theme.
    polarity = "dark";

    # Stylix themes GNOME Shell by patching and recompiling it, which on a
    # PC means hours of aarch64 emulation. gnome-phone.nix applies the same
    # colours as a shell theme instead, so GNOME Shell comes from the cache.
    overlays.enable = false;

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

  # Stylix sets the GNOME wallpaper, dark mode and fonts through Home
  # Manager, which this config doesn't use. So they are set here as
  # system-wide defaults; you can still change them in GNOME Settings.
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

  # Boot screen: off for now. With Plymouth (mobile.beautification.splash)
  # the phone hung at "Started Show Plymouth Boot Screen" on 2026-11-19;
  # under investigation.
  mobile.beautification = {
    silentBoot = false;
    splash = false;
  };
}
