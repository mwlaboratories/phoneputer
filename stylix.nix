# Looks: wallpaper, colours and fonts, applied everywhere by Stylix.
#
# Stylix picks a colour scheme from the wallpaper and applies it to GNOME,
# GTK apps, the terminal and more. To restyle the phone, change the
# wallpaper below and rebuild. Docs: https://nix-community.github.io/stylix/

{ config, pkgs, ... }:

let
  inherit (config.stylix) fonts image polarity;
  size = toString fonts.sizes.applications;
in
{
  stylix = {
    enable = true;

    # The wallpaper; the colours are taken from it. Any image works:
    #   image = ./my-wallpaper.jpg;
    # This one is NixOS artwork (CC-BY-SA 4.0); see the others with
    # `nix search nixpkgs nixos-artwork.wallpapers`.
    image = pkgs.nixos-artwork.wallpapers.waterfall.gnomeFilePath;

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

  # Boot screen: no scrolling kernel text, but a spinning NixOS logo in the
  # wallpaper's colours (Plymouth, themed by Stylix) until GNOME starts.
  # Changes the kernel command line, so flash the boot image once after
  # turning this on or off.
  mobile.beautification = {
    silentBoot = true;
    splash = true;
  };
}
