# The phone part: mobile data, calls and SMS. They use the modem through
# ModemManager; insert a SIM.

{ pkgs, ... }:

{
  # Mobile data with whatever SIM is in the phone: NetworkManager picks the
  # APN from the SIM's operator. The SIM PIN isn't stored here (the config
  # is readable by every program on the phone); GNOME asks for it after
  # boot, like any phone.
  networking.networkmanager.ensureProfiles.profiles.mobile-data = {
    connection = {
      id = "Mobile data";
      type = "gsm";
      autoconnect = true;
      # Keep retrying: after the modem restarts or comes back from a call
      # it can refuse a few attempts before it's ready.
      autoconnect-retries = 0;
    };
    gsm.auto-config = true;
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

  # Phone calls (GNOME Calls, with callaudiod for the call audio) and SMS
  # (Chatty).
  programs.calls.enable = true;
  environment.systemPackages = [ pkgs.chatty ];
  # Calls and Chatty run in the background from login, so incoming calls
  # ring and SMS arrive. Their autostart entries are skipped in GNOME's
  # systemd session, which wants the units they ship instead; enable those.
  systemd.packages = [ pkgs.calls pkgs.chatty ];
  # Only in real users' sessions, not in the login screen's (which is a
  # GNOME session too, and would ask for permission to use the modem).
  systemd.user.services.calls-daemon = {
    wantedBy = [ "gnome-session.target" ];
    unitConfig.ConditionGroup = "users";
  };
  systemd.user.services."sm.puri.Chatty-daemon" = {
    wantedBy = [ "gnome-session.target" ];
    unitConfig.ConditionGroup = "users";
  };
  # Chatty links olm (Matrix encryption), which nixpkgs marks insecure.
  # SMS doesn't use it.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];
}
