# The phone's buttons, like on a phone.
#
# The power key: short press turns the screen off or on, holding it for a
# second logs out (./power-key.py); shut down from the login screen or the
# system menu. The phone never sleeps.
#
# The alert slider on the side: silent, vibrate or ring (./alert-slider.py).

{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
in
{
  systemd.user.services.power-key = {
    description = "Power key: screen off/on, hold to log out; screen on for calls";
    unitConfig.ConditionGroup = "users"; # not in the login screen
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.glib pkgs.gnome-session ];
    serviceConfig = {
      ExecStart = "${python}/bin/python3 ${./power-key.py}";
      Restart = "on-failure";
    };
  };

  systemd.user.services.alert-slider = {
    description = "Alert slider: silent, vibrate or ring";
    unitConfig.ConditionGroup = "users"; # not in the login screen
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.glib ];
    # Where gsettings finds the settings it changes (feedbackd's, GNOME's).
    environment.XDG_DATA_DIRS = pkgs.lib.concatMapStringsSep ":"
      (p: "${p}/share/gsettings-schemas/${p.name}")
      [ pkgs.feedbackd pkgs.gsettings-desktop-schemas ];
    serviceConfig = {
      ExecStart = "${python}/bin/python3 ${./alert-slider.py}";
      Restart = "on-failure";
    };
  };

  # The phone never sleeps. GNOME still tries to when the power key is
  # pressed with the screen off (whatever power-button-action says), so
  # sleeping is refused outright; GNOME then also drops "Suspend" from its
  # menu. Shutting down and restarting are unaffected.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id.indexOf("org.freedesktop.login1.suspend") == 0 ||
          action.id.indexOf("org.freedesktop.login1.hibernate") == 0 ||
          action.id.indexOf("org.freedesktop.login1.hybrid-sleep") == 0) {
        return polkit.Result.NO;
      }
    });
  '';

  # The system itself ignores the power key (its default is to shut down).
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
  };

  # Let the logged-in user read the power key and the alert slider. The
  # rule has to run before udev's seat rules (73-*), which turn "uaccess"
  # into access.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-power-key.rules" ''
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*pwrkey*", TAG+="uaccess"
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Alert slider", TAG+="uaccess"
    '')
  ];
}
