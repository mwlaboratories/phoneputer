{ config, lib, ... }:

let
  c = config.lib.stylix.colors;

  # Wallpaper-agnostic: the scheme comes from whatever wallpaper is set, so
  # don't hard-code which base is dark. Luma (Rec. 709 weights, 0-1000) of a
  # base, from stylix's per-channel decimals.
  luma = b:
    let ch = x: lib.toInt c."${b}-rgb-${x}";
    in (2126 * ch "r" + 7152 * ch "g" + 722 * ch "b") / 2550;

  # base16: base00 is the background end. In a dark scheme that's the dark
  # one, in a light scheme base07 is. Mirror the roles accordingly.
  darkScheme = luma "base00" < luma "base07";
  role = if darkScheme
    then { bg = "base00"; fg = "base05"; palest = "base07"; dim = "base03"; }
    else { bg = "base07"; fg = "base02"; palest = "base00"; dim = "base04"; };

  # The vivid accents below need a genuinely dark background and pale text.
  # A washed-out scheme (darkest colour mid-grey, palest not pale) falls back
  # to fixed values instead of losing contrast.
  pick = b: limitOk: fallback: if limitOk (luma b) then c.${b} else fallback;
  bg = pick role.bg (l: l <= 200) "0b1e25";
  fg = pick role.fg (l: l >= 650) "cee7ee";
  palest = pick role.palest (l: l >= 750) "ecf2f2";
  dim = c.${role.dim};
in
{
  # Ghostty via the home-manager module so stylix can theme it.
  #
  # Stylix delivers colors as a ghostty theme file (programs.ghostty.themes.stylix)
  # and sets settings.theme = "stylix". The terminal is always dark (a light
  # background looks milky under the transparency + blur), whatever the
  # wallpaper: the darkest end of the scheme becomes the background and its
  # pale end the text (see `role`/`pick` above), with fixed fallbacks when the
  # scheme isn't contrasty enough. Editing the generated theme directly avoids
  # any config-vs-theme precedence ambiguity.
  #
  # The scheme's accent colours are all muted blue-greys (the wallpaper is
  # nearly monochrome), so ANSI 1-6 barely stood apart on the dark background
  # (asciiquarium's fish, ls colours, diffs). They get vivid fixed colours;
  # 0, 7, 8 and 15 come from the scheme (0 is the background itself).
  programs.ghostty = {
    enable = true;
    # Bold text in ANSI 0-7 uses the bright colour (8-15), as in xterm.
    # asciiquarium draws its castle in bold black on a black background
    # (Term::Animation paints every cell's background ANSI 0); bold-is-bright
    # terminals show that as grey, Ghostty's default left it invisible.
    # Making 0 itself lighter is no fix: it greys every cell's background too.
    settings.bold-color = "bright";
    # (Phone: the title bar stays, unlike on the desktop. Its menu button is
    # the way to Ghostty's menus on a touch screen.)
    # The window is rarely an exact number of rows tall; by default all the
    # leftover pixels pile up as a strip at the bottom. Spread them around.
    settings.window-padding-balance = true;
    # background-opacity comes from stylix.opacity.terminal (see stylix.nix).
    # By default it skips cells with an explicit background colour, which then
    # render opaque: TUIs like asciiquarium showed solid stripes across the
    # translucent window. Apply the opacity to those cells too.
    settings.background-opacity-cells = true;
    # Padding keeps the theme background, so a TUI that paints every cell
    # (asciiquarium) sat inside a lighter frame between its cells and the
    # window edge. Extend the edge cells' background into the padding instead.
    settings.window-padding-color = "extend";
    themes.stylix = {
      background = lib.mkForce bg;
      foreground = lib.mkForce fg;
      cursor-color = lib.mkForce fg; # cursor stays visible on dark bg
      selection-foreground = lib.mkForce palest;
      palette = lib.mkForce [
        "0=#${bg}"
        "1=#ff7b72" # red
        "2=#7ee787" # green
        "3=#f2cc60" # yellow
        "4=#79c0ff" # blue
        "5=#d2a8ff" # magenta
        "6=#56d4dd" # cyan
        "7=#${fg}"
        "8=#${dim}"
        "9=#ffa198"
        "10=#aff5b4"
        "11=#f8e3a1"
        "12=#a5d6ff"
        "13=#e2c5ff"
        "14=#8ae9ee"
        "15=#${palest}"
      ];
    };
  };

  # Phone only, below this line; everything above mirrors nixos-config's
  # home/programs/ghostty.nix, keep the two in step.
  #
  # The wallpaper blurred behind the see-through terminal (the Blur my Shell
  # extension). Blur my Shell's own opacity and "make the focused window
  # solid" stay off: the terminal is always the focused window on a phone.
  dconf.settings."org/gnome/shell/extensions/blur-my-shell/applications" = {
    blur = true;
    whitelist = [ "com.mitchellh.ghostty" ];
    opacity = lib.hm.gvariant.mkInt32 255;
    dynamic-opacity = false;
  };
}
