# Your own settings, as the user nix, through Home Manager.
#
# Stylix (stylix.nix) themes your session from here: wallpaper, colours,
# fonts, GTK apps. Because these are your own settings, a new wallpaper
# shows as soon as `nixos-rebuild switch` finishes, without logging out.
# Add more of your own settings below; options:
# https://nix-community.github.io/home-manager/options.xhtml

{ ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # A file Home Manager wants to manage that's already there is kept as
    # <name>.hm-backup instead of stopping the switch.
    backupFileExtension = "hm-backup";

    users.nix = {
      home.stateVersion = "25.11";

      # GNOME Shell keeps the phone's own theme from gnome-phone.nix (the
      # Stylix colours, plus a notification list that fits the screen)
      # instead of Stylix's, which would also need you logged in to switch.
      stylix.targets.gnome.colors.enable = false;

      # Ghostty, the terminal, in the Stylix colours and see-through
      # (stylix.opacity.terminal in stylix.nix).
      programs.ghostty.enable = true;
    };
  };
}
