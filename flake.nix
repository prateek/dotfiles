{
  description = "Prateek's macOS dotfiles (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      mkHost =
        {
          hostname,
          system ? "aarch64-darwin",
          username ? "prateek",
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs hostname username; };
          modules = [
            ./nix/modules/common.nix
            ./nix/modules/darwin
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs hostname username; };
              home-manager.users.${username} = import ./nix/modules/home;
            }
            ./nix/hosts/${hostname}.nix
          ] ++ extraModules;
        };
    in
    {
      darwinConfigurations = {
        prateek-mac = mkHost { hostname = "prateek-mac"; };
      };

      # Convenience for `nix build .#system`
      packages.aarch64-darwin.default =
        self.darwinConfigurations.prateek-mac.system;

      # `nix flake check` evaluation gate
      checks.aarch64-darwin.build =
        self.darwinConfigurations.prateek-mac.system;

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt-rfc-style;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-rfc-style;
    };
}
