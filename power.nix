# Power modes: Balanced, Performance and Power Saver in GNOME's quick
# settings (the battery menu at the top).
#
# GNOME's own power-profiles-daemon has no driver for this phone: its modes
# change nothing, and Performance is missing. TuneD takes its place and
# speaks the same language to GNOME, with profiles that set the CPU clock
# policy (the "governor").
#
# Balanced lets the kernel pick the CPU clock from the load (schedutil).
# That is fine for most things, but it keeps the big cores around 1.8 GHz
# where Firefox needs their full 2.65 GHz to finish each frame in time:
# with the WebGL fluid demo, Performance measured about 70 % more frames
# than Balanced. Performance holds every core at its top clock, which
# costs battery, so it is a mode you pick, not the default.

{ ... }:

{
  services.power-profiles-daemon.enable = false;

  services.tuned = {
    enable = true;
    profiles = {
      phone-balanced = {
        main.summary = "CPU clock follows the load";
        cpu.governor = "schedutil";
      };
      phone-performance = {
        main.summary = "CPU at its top clock";
        cpu.governor = "performance";
      };
    };
    ppdSettings = {
      profiles = {
        balanced = "phone-balanced";
        performance = "phone-performance";
        power-saver = "powersave"; # TuneD's own
      };
      # TuneD's stock battery variant of Balanced slows the CPU right down;
      # keep Balanced the same on battery.
      battery.balanced = "phone-balanced";
    };
  };
}
