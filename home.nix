# Your own settings and apps, as the user nix, through Home Manager.
#
# Stylix (stylix.nix) themes your session from here: wallpaper, colours,
# fonts, GTK apps. Because these are your own settings, a new wallpaper
# shows as soon as the rebuild finishes, without logging out. Apps you add
# or remove here show in the app grid after you log out and back in.
# Options: https://nix-community.github.io/home-manager/options.xhtml

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
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # A file Home Manager wants to manage that's already there is kept as
    # <name>.hm-backup instead of stopping the switch.
    backupFileExtension = "hm-backup";

    users.nix = {
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

      # Brave, a second browser: it blocks ads (YouTube too) by itself.
      # It runs as a Wayland app, which handles touch better than through
      # XWayland. Firefox stays the default browser.
      programs.brave = {
        enable = true;
        commandLineArgs = [ "--ozone-platform=wayland" ];
      };

      # Ghostty, the terminal, in the Stylix colours and see-through
      # (stylix.opacity.terminal in stylix.nix).
      programs.ghostty.enable = true;

      # GNOME Shell's theme comes from gnome-phone.nix (the Stylix colours,
      # plus a notification list that fits the screen), not from Stylix's
      # User Themes setup, which needs you logged in to switch.
      stylix.targets.gnome.colors.enable = false;
    };
  };
}
