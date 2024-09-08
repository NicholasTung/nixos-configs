{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    impermanence.url = "github:nix-community/impermanence";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    # optionally choose not to download darwin deps (saves some resources on Linux)
    agenix.inputs.darwin.follows = "";

    golink.url = "github:tailscale/golink";

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, impermanence, agenix, deploy-rs, golink, ... }: {
    nixosConfigurations.agrotera = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit agenix; };
      modules = [
        impermanence.nixosModules.impermanence
        agenix.nixosModules.default
        golink.nixosModules.default
        ./configuration.nix
      ];
    };

    # FIXME (2024-09-08): prototyping definition
    # dev shell specifically for my mbp
    devShells."aarch64-darwin".default =
      let
        system = "aarch64-darwin";
        pkgs = import nixpkgs { inherit system; };
      in
      pkgs.mkShell {
        packages = with pkgs; [
          nil
          nixpkgs-fmt
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

    # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
