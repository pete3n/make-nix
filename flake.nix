{
  description = "Multi-platform Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hyprcursor.url = "github:hyprwm/hyprcursor";
    nixvim.url = "github:pete3n/nixvim-flake";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = {
    home-manager,
    home-manager-darwin,
    nixpkgs,
    nixpkgs-darwin,
    nix-darwin,
    self,
    ...
  } @ inputs: let
    inherit (self) outputs;

    build_target = import ./build-targets.nix {};

    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (
      system:
        import ./pkgs {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
          config = {
            allowUnfree = true;
          };
        }
    );

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};

    # User defintions for the system (careful these create/overwrite users)
    systemUsers = import ./users;

    nixosConfigurations =
      if build_target.isLinux
      then {
        "${build_target.host}" = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./hosts/${build_target.host}/configuration.nix
            ./users/linux/linux-${build_target.user}.nix
          ];
        };
      }
      else {};

    darwinConfigurations =
      if !build_target.isLinux
      then {
        "${build_target.host}" = nix-darwin.lib.darwinSystem {
          specialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./hosts/${build_target.host}/nix-core.nix
            ./hosts/${build_target.host}/system.nix
            ./hosts/${build_target.host}/apps.nix
            ./users/darwin/darwin-${build_target.user}.nix
          ];
        };
      }
      else {};

    homeConfigurations =
      if build_target.isLinux
      then {
        "${build_target.user}@${build_target.host}" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${build_target.system}; # Home-manager requires 'pkgs' instance
          lib = nixpkgs.lib;
          extraSpecialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./home-manager/${build_target.user}/linux-home.nix
          ];
        };
      }
      else {
        "${build_target.user}@${build_target.host}" = home-manager-darwin.lib.homeManagerConfiguration {
          pkgs = nixpkgs-darwin.legacyPackages.${build_target.system};
          extraSpecialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./home-manager/${build_target.user}/darwin-home.nix
          ];
        };
      };
  };
}
