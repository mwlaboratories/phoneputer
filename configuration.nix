# Your phone's configuration: GNOME, a user, and your packages.
#
# All OnePlus 6 hardware support (kernel, firmware, modem, Bluetooth, sensors,
# SSH over the USB-C cable) comes from the Mobile NixOS fork, so this file is
# only about what you want on the phone. Change anything here.

{ config, lib, pkgs, ... }:

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
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "dialout" ];
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
  hardware.bluetooth.enable = true;

  # GNOME, logging in automatically: typing a password on the login screen
  # of a phone is no fun. The screen lock still asks for it.
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "phone";
  };
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

  # Your packages
  environment.systemPackages = with pkgs; [
    brave
    git
    vim
    neovim
    wget
    curl
    lazygit
    kitty
    asciiquarium
    gnomeExtensions.screen-rotate
  ];

  system.stateVersion = "25.11";
}
