{
  description = "NixOS Mobile for OnePlus 6 (enchilada)";

  inputs = {
    # Main NixOS package collection (unstable for the latest mobile support)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Mobile NixOS fork: newer sdm845 kernel and all OnePlus 6 hardware support
    mobile-nixos = {
      url = "github:mwlaboratories/mobile-nixos/main";
      flake = false; # We import it directly, not as a flake
    };

    # Stylix: one wallpaper themes the whole phone (see stylix.nix)
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager: your own settings as the user nix (see home.nix)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixvim: Neovim set up in Nix (see nvim.nix)
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mobile-nixos, stylix, home-manager, nixvim, ... }:
    let
      phone = { buildKernelOn ? null }: nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit stylix; };
        modules = [
          (import "${mobile-nixos}/lib/configuration.nix" { device = "oneplus-enchilada"; })
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          nixvim.nixosModules.nixvim
          ./configuration.nix
          ./home.nix
          ./stylix.nix
          ./gnome-phone.nix
          ./nvim.nix
          ./power.nix
          {
            # Compile the kernel natively on the PC instead of through aarch64
            # emulation: minutes instead of hours. Everything else comes from
            # the binary cache. null (the default) builds it on the phone.
            mobile.boot.stage-1.kernel.buildOn = buildKernelOn;
          }
        ];
      };
    in {
      nixosConfigurations = {
        # Build on an x86_64 PC (fast), deploy with --target-host.
        phoneputer = phone { buildKernelOn = "x86_64-linux"; };
        # Build on the phone itself (slow: the phone compiles its own kernel).
        phoneputer-native = phone { };
      };

      # Everything to flash, built on the PC: `nix build .#images`
      packages.x86_64-linux = {
        images = self.nixosConfigurations.phoneputer.config.mobile.outputs.android.android-fastboot-images;
        boot-image = self.nixosConfigurations.phoneputer.config.mobile.outputs.android.android-bootimg;
      };
    };
}
