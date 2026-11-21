# Your own apps and settings, as the user nix, through Home Manager.
#
# Stylix (../../modules/nixos/stylix.nix) themes your session from here:
# wallpaper, colours, fonts, GTK apps. Because these are your own settings,
# a new wallpaper shows as soon as the rebuild finishes, without logging
# out. Apps you add or remove here show in the app grid after you log out
# and back in. Options: https://nix-community.github.io/home-manager/options.xhtml

{ lib, pkgs, ... }:

let
  # A website as an app: its own icon in the app grid and dock, opening in
  # its own Brave window. The icon is copied out of the Papirus icon theme,
  # so the phone gets just that file.
  webApp = { name, url, icon }: pkgs.makeDesktopItem {
    name = lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name);
    desktopName = name;
    exec = "brave --app=${url}";
    icon = pkgs.runCommand "${icon}.svg" { } ''
      cp ${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${icon}.svg $out
    '';
    categories = [ "Network" ];
  };
in
{
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    claude-code # coding agents in the terminal: `claude`
    codex       #   and `codex`
    luanti      # voxel game
    signal-desktop # Signal (a linked device: Signal on another phone stays the main one)
    lazygit
    asciiquarium
    (webApp { name = "YouTube"; url = "https://m.youtube.com"; icon = "youtube"; })
    (webApp { name = "Fluid"; url = "https://paveldogreat.github.io/WebGL-Fluid-Simulation/"; icon = "fluid"; })
  ];

  # Brave, a second browser: it blocks ads (YouTube too) by itself. It runs
  # as a Wayland app, which handles touch better than through XWayland.
  # Firefox stays the default browser.
  programs.brave = {
    enable = true;
    commandLineArgs = [ "--ozone-platform=wayland" ];
  };

  # Ghostty, the terminal: always dark whatever the wallpaper, with bright
  # accent colours, see-through (stylix.opacity.terminal in
  # ../../modules/nixos/stylix.nix) and the wallpaper blurred behind it.
  # In ghostty.nix. A firmer buzz for the on-screen keyboard's keys is in
  # feedbackd.nix.
  imports = [ ./ghostty.nix ./feedbackd.nix ];

  # GNOME Shell already has the Stylix colours built in (stylix.nix). The
  # extra copy Stylix would load per user, through the User Themes
  # extension, isn't needed, and its reload stops a rebuild done while
  # you're logged out.
  stylix.targets.gnome.colors.enable = false;
}
