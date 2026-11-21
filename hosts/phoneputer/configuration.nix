# Your phone: a user, its wallpaper and the system around it. Your own
# apps and settings are in ./home.nix.
#
# All OnePlus 6 hardware support (kernel, firmware, modem, Bluetooth,
# sensors) comes from the Mobile NixOS fork; the rest of
# what makes it a phone is in ../../modules/nixos. Change anything here.

{ pkgs, ... }:

{
  imports = [
    ../../modules/nixos/phone.nix
    ../../modules/nixos/stylix.nix
    ../../modules/nixos/gnome
    ../../modules/nixos/nvim.nix
    ../../modules/nixos/power.nix
  ];

  networking.hostName = "phoneputer";

  # Your time zone, for the clock (otherwise UTC: an hour behind in
  # winter). The same as the PC (nixos-config). 12- or 24-hour display is
  # in ../../modules/nixos/gnome (clock-format).
  time.timeZone = "Europe/Amsterdam";

  # The wallpaper; the colours of the whole phone are taken from it. Put
  # your own image here (`git add` it: a flake only sees files git knows
  # about) and rebuild. This one: a hammerhead shark over the sea floor.
  stylix.image = ./wallpaper.jpg;

  # Allow unfree packages (needed for OnePlus firmware)
  nixpkgs.config.allowUnfree = true;

  # The user you are logged in as. Log in over SSH with this password too.
  # Change it after the first boot with `passwd`.
  users.users.nix = {
    isNormalUser = true;
    description = "Nix";
    uid = 1001; # the same as the earlier user "phone", so its files stay yours
    initialPassword = "nixtheplanet";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "dialout" "feedbackd" ];
  };

  # The user's own apps and settings, through Home Manager.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # A file Home Manager wants to manage that's already there is kept as
    # <name>.hm-backup instead of stopping the switch.
    backupFileExtension = "hm-backup";
    users.nix = import ./home.nix;
  };

  # Root, for SSH. Same password; change it with `passwd` as root.
  users.users.root.initialPassword = "nixtheplanet";

  # SSH over WiFi: `ssh nix@<the phone's address>` (GNOME Settings → Wi-Fi,
  # the gear next to your network).
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.settings.PasswordAuthentication = true;

  # Rebuild on the phone itself: `nh os switch` in a terminal, from the
  # checkout in ~/phoneputer (git clone https://github.com/mwlaboratories/phoneputer).
  # The phone builds faster than a PC can through aarch64 emulation. Only
  # the kernel is built on a PC (see flake.nix); when it changes, build
  # there and copy it over first.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.nh = {
    enable = true;
    flake = "/home/nix/phoneputer"; # with another user name, change it here too
  };

  # WiFi and mobile data (set up WiFi in GNOME Settings → Wi-Fi; mobile
  # data is in ../../modules/nixos/phone.nix)
  networking.networkmanager.enable = true;
  networking.modemmanager.enable = true;
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

  # Firefox, the browser. On a small screen every line counts: no
  # bookmarks toolbar ("Import bookmarks..."), and no sponsored shortcuts
  # or stories on the new tab page. Everything else stays changeable in
  # Firefox's settings. More: https://mozilla.github.io/policy-templates/
  programs.firefox = {
    enable = true;
    policies = {
      DisplayBookmarksToolbar = "never";
      FirefoxHome = {
        SponsoredTopSites = false;
        SponsoredPocket = false;
        SponsoredStories = false;
      };
    };
  };

  # Programs for everyone on the phone. Your own apps are in ./home.nix;
  # nvim comes from ../../modules/nixos/nvim.nix.
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
  ];

  system.stateVersion = "25.11";
}
