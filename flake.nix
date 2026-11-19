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
  };

  outputs = { self, nixpkgs, mobile-nixos, ... }:
    let
      phone = { buildKernelOn ? null }: nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          (import "${mobile-nixos}/lib/configuration.nix" { device = "oneplus-enchilada"; })
          ./configuration.nix
        ] ++ nixpkgs.lib.optional (buildKernelOn != null) ({ config, lib, ... }: {
          # Compile the kernel natively on the PC instead of through aarch64
          # emulation: minutes instead of hours. Everything else comes from
          # the binary cache.
          mobile.boot.stage-1.kernel.package = lib.mkForce
            ((import nixpkgs {
              localSystem = buildKernelOn;
              crossSystem = "aarch64-linux";
              overlays = config.nixpkgs.overlays;
            }).callPackage "${mobile-nixos}/devices/families/sdm845-mainline/kernel" { });
        });
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
