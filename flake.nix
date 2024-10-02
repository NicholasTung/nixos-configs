{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    impermanence.url = "github:nix-community/impermanence";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # optionally choose not to download darwin deps (saves some resources on Linux)
      inputs.darwin.follows = "";
    };
    golink.url = "github:tailscale/golink";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , impermanence
    , agenix
    , deploy-rs
    , golink
    , ...
    }: {
      nixosConfigurations.agrotera = nixpkgs.lib.nixosSystem {
        system = flake-utils.lib.system.x86_64-linux;
        specialArgs = { inherit agenix; };
        modules = [
          impermanence.nixosModules.impermanence
          agenix.nixosModules.default
          golink.nixosModules.default
          ./configuration.nix
        ];
      };

      # deploy-rs
      deploy.nodes.agrotera = {
        hostname = "agrotera";
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.agrotera;
          remoteBuild = true;
        };
      };

      # FYI: checks don't work when running deploy on a different architecture than the target
      # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    }
    # slightly funny, merge devShell attrset with outputs
    // flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system}; in
    {
      devShell =
        pkgs.mkShell {
          packages = with pkgs; [
            nil # linter
            nixpkgs-fmt
          ];
        };
    });
}
