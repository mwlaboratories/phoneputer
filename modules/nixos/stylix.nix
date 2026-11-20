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
in
{
  stylix = {
    enable = true;

    # Without a wallpaper of your own: NixOS artwork (CC-BY-SA 4.0); see
    # the others with `nix search nixpkgs nixos-artwork.wallpapers`.
    image = lib.mkDefault pkgs.nixos-artwork.wallpapers.waterfall.gnomeFilePath;

    # Dark or light theme.
    polarity = "dark";

    # The terminal lets the wallpaper show through a little (1 = solid).
    opacity.terminal = 0.75;

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
