{
  description = "NixOS Mobile for OnePlus 6 (enchilada)";

  ############################################
  # Input Dependencies
  ############################################
  inputs = {
    # Main NixOS package collection (unstable for latest mobile support)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Mobile-NixOS repository - provides mobile-specific modules and device support
    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos";
      flake = false; # We import it directly, not as a flake
    };
  };

  ############################################
  # Flake Outputs
  ############################################
  outputs = { self, nixpkgs, mobile-nixos, ... }:
    let
      system = "aarch64-linux";
    in {
      nixosConfigurations = {
        phoneputer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (import "${mobile-nixos}/lib/configuration.nix" { device = "oneplus-enchilada"; })
            ./configuration.nix
          ];
        };
      };
    };
} 