# GNOME Shell in the Stylix colours: the top bar, menus, notifications and
# the login screen.
#
# Stylix builds GNOME Shell's theme from the colours, with one change for
# the phone: the clock's menu (notifications and calendar) is wider than
# the screen; a narrower notification list makes it fit.
#
# The theme replaces GNOME Shell's built-in one, as Stylix's own GNOME
# support does. But it is read from /etc instead of being built into GNOME
# Shell: GNOME Shell is compiled once (rebuilding on the phone: about a
# minute and a half), and a new wallpaper only changes the file in /etc.
# GNOME Shell loads its theme when it starts: new colours in its menus show
# after you log out and back in.

{ config, pkgs, stylix, ... }:

let
  shellTheme = (pkgs.callPackage "${stylix}/modules/gnome/theme.nix" {
    inherit (config.lib.stylix) colors;
    inherit (config.stylix) inputs;
  }).overrideAttrs (old: {
    postPatch = old.postPatch + ''
      echo '.message-list { width: 22em; }' >> data/theme/gnome-shell-light.scss
    '';
  });
in
{
  nixpkgs.overlays = [
    (final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          "${stylix}/modules/gnome/shell_remove_dark_mode.patch"
        ];
        postFixup = (old.postFixup or "") + ''
          ln -sf /etc/gnome-shell/gnome-shell-theme.gresource \
            $out/share/gnome-shell/gnome-shell-theme.gresource
        '';
      });
    })
  ];
  environment.etc."gnome-shell/gnome-shell-theme.gresource".source =
    "${shellTheme}/share/gnome-shell/gnome-shell-theme.gresource";
}
