{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    impermanence.url = "github:nix-community/impermanence";
    
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    # optionally choose not to download darwin deps (saves some resources on Linux)
    agenix.inputs.darwin.follows = "";

    golink.url = "github:tailscale/golink";
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
  };
}