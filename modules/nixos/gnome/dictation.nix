# Voice dictation: speak, and the words appear above the on-screen
# keyboard, ready to send to the app (extensions/osk-voice).
#
# The service (./dictation.js) records the microphone and streams it to
# Soniox, which turns speech into text. It runs only once you tap the
# microphone: D-Bus starts it on the first call. It's kept apart from the
# keyboard so other things can use it too, like a dictation input method
# for the G2 glasses later.
#
# It needs a Soniox API key, read from ~/.config/soniox/api-key (see
# ./dictation.js); it never goes into the Nix store or this repository.

{ pkgs, ... }:

let
  busName = "org.phoneputer.Dictation";
in
{
  systemd.user.services.dictation = {
    description = "Voice dictation for the on-screen keyboard (Soniox)";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.pipewire ]; # pw-record
    environment = {
      # gjs finds the websocket library (libsoup) here. GNOME Shell uses the
      # same gjs and libsoup, so they're on the phone already.
      GI_TYPELIB_PATH = "${pkgs.libsoup_3}/lib/girepository-1.0";
      # The languages you speak, comma-separated: a hint for Soniox, which
      # still recognises others, e.g. "en,nl". Empty: Soniox works it out
      # by itself.
      SONIOX_LANGUAGE_HINTS = "";
    };
    serviceConfig = {
      Type = "dbus";
      BusName = busName;
      ExecStart = "${pkgs.gjs}/bin/gjs -m ${./dictation.js}";
      Restart = "on-failure";
    };
  };

  # Lets D-Bus start the service above when the keyboard first calls it.
  services.dbus.packages = [
    (pkgs.writeTextDir "share/dbus-1/services/${busName}.service" ''
      [D-BUS Service]
      Name=${busName}
      Exec=${pkgs.coreutils}/bin/false
      SystemdService=dictation.service
    '')
  ];
}
