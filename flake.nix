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
    deploy-rs,
    firefox-addons,
    hyprland,
    home-manager,
    home-manager-darwin,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-darwin,
    nix-darwin,
    nixvim,
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
  in rec {
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

    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    # These are for system-wide configuration
    nixosModules = import ./modules/nixos;

    # User defintions for the system (careful these create/overwrite users)
    systemUsers = import ./users;

    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    # These are for users level configuration
    homeManagerModules = import ./modules/home-manager;

    nixosConfiguration =
      if build_target.isLinux
      then {
        "${build_target.host}" = nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./hosts/${build_target.host}/configuration.nix
          ];
        };
      }
      else {
        darwinConfiguration."${build_target.host}" = nix-darwin.lib.darwinSystem {
          specialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./hosts/macbook/nix-core.nix
            ./hosts/macbook/system.nix
            ./hosts/macbook/apps.nix
            ./users/darwin-pete.nix
          ];
        };
      };
    homeManagerConfiguration =
      if build_target.isLinux
      then {
        "${build_target.user}@${build_target.host}" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
          lib = nixpkgs.lib;
          extraSpecialArgs = {inherit inputs outputs build_target;};
          modules = [
            ./home-manager/home.nix
            homeManagerModules.pete-modules.alacritty-config
            homeManagerModules.pete-modules.awesome-config
            homeManagerModules.pete-modules.user-config
            homeManagerModules.pete-modules.crypto
            homeManagerModules.pete-modules.firefox-config
            homeManagerModules.pete-modules.games
            homeManagerModules.pete-modules.hyprland-config
            homeManagerModules.pete-modules.media-tools
            homeManagerModules.pete-modules.messengers
            homeManagerModules.pete-modules.misc-tools
            homeManagerModules.pete-modules.pen-tools
            homeManagerModules.pete-modules.neovim-env
            homeManagerModules.pete-modules.office-cloud
            homeManagerModules.pete-modules.tmux-config
          ];
        };
      }
      else {
        "${build_target.user}@${build_target.host}" = home-manager-darwin.lib.homeManagerConfiguration {
          homeConfigurations = {
            pkgs = nixpkgs-darwin.legacyPackages.x86_64-darwin;
            extraSpecialArgs = {inherit inputs outputs build_target;};
            modules = [
              ./home-manager/darwin-home.nix
            ];
          };
        };
      };
  };
}
