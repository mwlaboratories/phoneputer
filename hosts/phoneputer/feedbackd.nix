# A firmer buzz for the on-screen keyboard (the osk-haptics extension).
#
# The extension asks feedbackd for its "button-pressed" event. feedbackd
# looks that up in its theme. The stock theme gives it a tiny buzz
# (strength 0.2 for 7 ms) that you can barely feel on the OnePlus 6.
#
# So this adds a small theme of your own that changes just that event.
# feedbackd looks for a theme in ~/.config/feedbackd/themes/<name>.json,
# with <name> from the dconf key org/sigxcpu/feedbackd/theme. Our theme
# names "default" as its parent, so everything else stays as it was: the
# OnePlus 6 device theme first, then feedbackd's default theme.
#
# Profiles stack: "full" plays its own feedback and that of "quiet" and
# "silent"; "quiet" plays "quiet" and "silent". The vibration lives in
# "quiet", so it covers both the quiet profile (yours, see
# ../../modules/nixos/gnome/default.nix) and the full one, where the click
# sound from "full" plays on top.
#
# Check a change on the phone with:
#   fbd-theme-validate --compatible=oneplus,enchilada ~/.config/feedbackd/themes/phoneputer.json

{ pkgs, ... }:

let
  theme = {
    name = "phoneputer";
    parent-name = "default";
    profiles = [{
      name = "quiet";
      feedbacks = [{
        event-name = "button-pressed";
        type = "VibraPattern";
        # Strength from 0 to 1, time in ms. On the OnePlus 6 strength only
        # sets the motor's voltage, and from about 0.52 up it is already
        # the maximum (so 0.7 is full strength); waveform and frequency
        # can't be chosen. Feel candidates, or your own values, with
        # tests/haptics-sweep.sh before changing these.
        magnitudes = [ 0.7 ];
        durations = [ 12 ];
      }];
    }];
  };
in
{
  xdg.configFile."feedbackd/themes/phoneputer.json" = {
    text = builtins.toJSON theme;
    # feedbackd reads the theme once. A SIGHUP makes it read it again, so
    # a new value is felt right after the rebuild.
    onChange = "${pkgs.procps}/bin/pkill -HUP -x feedbackd || true";
  };

  # Tell feedbackd to use the theme above. Changing this key also makes it
  # reload.
  dconf.settings."org/sigxcpu/feedbackd".theme = "phoneputer";
}
