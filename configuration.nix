# Configuration for OnePlus 6 (enchilada) on Mobile NixOS
# GNOME, SSH, WiFi, modem, and SSH/serial over USB-C.

{ config, lib, pkgs, ... }:

{
  imports = [
    ./usb-gadget.nix # SSH and a serial console over the USB-C cable
  ];

  networking.hostName = "phoneputer";

  # Allow unfree packages (needed for OnePlus firmware)
  nixpkgs.config.allowUnfree = true;

  # Enable SSH server (essential for mobile device access)
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes"; # For initial setup
  services.openssh.settings.PasswordAuthentication = true; # For initial setup

  # WiFi and mobile data
  networking.networkmanager.enable = true;
  # Mainline gets no factory WiFi MAC, so it is random per boot and the router
  # hands out a new IP after every reboot. "stable" derives it from machine-id.
  networking.networkmanager.wifi.macAddress = "stable";
  systemd.services.ModemManager.enable = true;

  # Never suspend: the modem's QMI port dies on resume, killing 4G.
  # Screen blanking still works for power saving.
  systemd.sleep.settings.Sleep.AllowSuspend = false;

  # The kernel device tree looks for firmware in qcom/sdm845/OnePlus/enchilada/,
  # but the firmware package installs it in qcom/sdm845/oneplus6/.
  hardware.firmware = let
    fw = config.mobile.device.firmware;
  in [
    ((pkgs.runCommand "oneplus6-firmware-symlink" {} ''
      mkdir -p $out/lib/firmware/qcom/sdm845/OnePlus
      ln -s ${fw}/lib/firmware/qcom/sdm845/oneplus6 $out/lib/firmware/qcom/sdm845/OnePlus/enchilada
    '') // { compressFirmware = false; })
  ];

  # Enable audio
  # PipeWire is enabled by default, but the audio is very quiet with it
  services.pipewire.enable = lib.mkForce false;
  # Make sure to select "Speakers Output" as the output device in the settings
  services.pulseaudio.enable = true;

  # Set root password for SSH access. Change it, or better: add your SSH key
  # to users.users.root.openssh.authorizedKeys.keys and disable passwords.
  users.users.root.password = "nixtheplanet";

  # Enable GNOME Desktop Environment
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # Enable GNOME Keyring for password management
  services.gnome.gnome-keyring.enable = true;

  # Enable dconf for GNOME settings
  programs.dconf.enable = true;

  # Remove unwanted GNOME applications
  environment.gnome.excludePackages = with pkgs; [
    baobab      # disk usage analyzer
    cheese      # photo booth
    eog         # image viewer
    epiphany    # web browser
    simple-scan # document scanner
    totem       # video player
    yelp        # help viewer
    evince      # document viewer
    file-roller # archive manager
    geary       # email client
    seahorse    # password manager
    gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-contacts
    gnome-font-viewer gnome-logs gnome-maps gnome-music gnome-screenshot
    gnome-system-monitor gnome-weather gnome-disk-utility pkgs.gnome-connections
  ];

  # Minimal essential packages
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    lazygit
    asciiquarium
    neovim
    kitty
    gnomeExtensions.screen-rotate
  ];

  system.stateVersion = "25.11";
}
