# Looks: wallpaper, colours and fonts, applied everywhere by Stylix.
#
# Stylix picks a colour scheme from the wallpaper and applies it to GNOME,
# GTK apps, the terminal and more. To restyle the phone, change the
# wallpaper below and rebuild. Docs: https://nix-community.github.io/stylix/

{ pkgs, ... }:

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
}
