# Your phone's configuration: GNOME, a user, and your packages.
#
# All OnePlus 6 hardware support (kernel, firmware, modem, Bluetooth, sensors,
# SSH over the USB-C cable) comes from the Mobile NixOS fork, so this file is
# only about what you want on the phone. Change anything here.

{ config, lib, pkgs, ... }:

let
  # A website as an app: its own icon in the app grid and dock, opening in
  # Firefox. The icon is copied out of the Papirus icon theme, so the phone
  # gets just that file.
  webApp = { name, url, icon }: pkgs.makeDesktopItem {
    name = lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name);
    desktopName = name;
    exec = "firefox --new-window ${url}";
    icon = pkgs.runCommand "${icon}.svg" { } ''
      cp ${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${icon}.svg $out
    '';
    categories = [ "Network" ];
  };
in
{
  networking.hostName = "phoneputer";

  # Allow unfree packages (needed for OnePlus firmware)
  nixpkgs.config.allowUnfree = true;

  # The user you are logged in as. Log in over SSH with this password too.
  # Change it after the first boot with `passwd`.
  users.users.phone = {
    isNormalUser = true;
    description = "Phone";
    initialPassword = "nixtheplanet";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "dialout" "feedbackd" ];
  };

  # Root, for SSH. Same password; change it with `passwd` as root.
  users.users.root.initialPassword = "nixtheplanet";

  # SSH over WiFi and over the USB-C cable (ssh phone@172.16.42.1).
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.settings.PasswordAuthentication = true;

  # WiFi and mobile data (set up WiFi in GNOME Settings → Wi-Fi)
  networking.networkmanager.enable = true;
  networking.modemmanager.enable = true;
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
  hardware.bluetooth.enable = true;

  # GNOME. You log in with your password; that same password unlocks the
  # keyring where apps like Firefox keep their saved passwords, so they never
  # ask for it separately.
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  # Audio: PipeWire + WirePlumber, the NixOS default with GNOME. The camera
  # in GNOME (Snapshot) also needs it, through PipeWire's libcamera support.
  # If the speaker is too quiet, that is a hardware fix (ALSA/UCM) that
  # belongs in the Mobile NixOS fork; don't disable PipeWire here.

  # Remove GNOME applications that make little sense on a phone
  environment.gnome.excludePackages = with pkgs; [
    baobab      # disk usage analyzer
    cheese      # photo booth
    epiphany    # web browser
    simple-scan # document scanner
    totem       # video player
    yelp        # help viewer
    evince      # document viewer
    papers      # document viewer (replaced evince in GNOME 49)
    file-roller # archive manager
    geary       # email client
    seahorse    # password manager
    gnome-calendar gnome-characters gnome-contacts gnome-font-viewer
    gnome-logs gnome-maps gnome-music gnome-system-monitor gnome-weather
    gnome-disk-utility gnome-connections
  ];

  # Phone calls (GNOME Calls, with callaudiod for the call audio) and SMS
  # (Chatty). They use the modem through ModemManager; insert a SIM.
  programs.calls.enable = true;
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

  # Your packages
  # (nvim comes from nvim.nix)
  environment.systemPackages = with pkgs; [
    firefox
    ghostty     # terminal
    claude-code # coding agents in the terminal: `claude`
    codex       #   and `codex`
    luanti      # voxel game
    chatty      # SMS
    signal-desktop # Signal (a linked device: Signal on another phone stays the main one)
    git
    vim
    wget
    curl
    lazygit
    asciiquarium
    (webApp { name = "YouTube"; url = "https://m.youtube.com"; icon = "youtube"; })
    (webApp { name = "Fluid"; url = "https://paveldogreat.github.io/WebGL-Fluid-Simulation/"; icon = "fluid"; })
  ];

  system.stateVersion = "25.11";
}
