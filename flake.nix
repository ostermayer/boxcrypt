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

      nixosConfigurations.cryptbox = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.default
          ./modules/presets/appliance.nix
        ];
      };

      checks.${system} = {
        appliance = self.nixosConfigurations.cryptbox.config.system.build.toplevel;
        network = runTest ./tests/network.nix;
        security = runTest ./tests/security.nix;
        wifi = runTest ./tests/wifi.nix;
      };
    };
}
