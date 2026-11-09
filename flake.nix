{
  description = "A purpose-built operating system for keeping secrets";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      runTest = file: pkgs.testers.runNixOSTest (import file { inherit self; });
    in
    {
      nixosModules.default = ./modules;

      nixosConfigurations.boxcrypt = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.default
          ./modules/presets/appliance.nix
        ];
      };

      packages.${system}.image = self.nixosConfigurations.boxcrypt.config.system.build.image;

      checks.${system} = {
        install = runTest ./tests/install.nix;
        network = runTest ./tests/network.nix;
        security = runTest ./tests/security.nix;
        verified-boot = runTest ./tests/verified-boot.nix;
        wifi = runTest ./tests/wifi.nix;
      };
    };
}
