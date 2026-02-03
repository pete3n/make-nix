{
  description = "Pete3n's make-nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Provide firefox overlay to workaround broken Darwin package
    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

		pete3n-mods = {
			url = "github:pete3n/nix-modules?ref=nixos-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};

    nixvim = {
			url = "github:pete3n/nixvim-flake?ref=nixos-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};

    hyprcursor.url = "github:hyprwm/hyprcursor";
    deploy-rs.url = "github:serokell/deploy-rs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs =
    {
      agenix,
      home-manager,
      nixpkgs,
      nix-darwin,
      self,
      ...
    }@inputs:
    # @inputs because we need to pass both inputs and outputs to our
    # configurations
    let

      # make-nix library
      makeNixLib = import ./lib {
        lib = nixpkgs.lib;
        inherit inputs;
      };

      homeModules' = import ./modules/home-manager;

      outputs = self.outputs; # Could be writting as 'inherit (self) outputs' but
      # this is more clear. We need to include outputs because we reference our
      # own outputs in our outputs

      # Home-manager users that have a NixOS/Nix-Darwin system config
      linuxUsers = nixpkgs.lib.filterAttrs (_: sa: makeNixLib.isLinux sa.system) hmUsers;
      darwinUsers = nixpkgs.lib.filterAttrs (_: sa: makeNixLib.isDarwin sa.system) hmUsers;

      hmUsers = makeNixLib.getHomeAttrs { dir = ./make-attrs/system; };
      hmConfigs = builtins.mapAttrs (
        _key: hmAttrs:
        let
          ctx = makeNixLib.makeAttrsCtx hmAttrs;

          userOverlays = import ./overlays {
            inherit inputs makeNixLib;
            makeNixAttrs = ctx;
          };

          pkgsForUser = import nixpkgs {
            localSystem = {
              system = ctx.system;
            };
            overlays = [
              userOverlays.unstable-packages
              userOverlays.local-packages
              userOverlays.mod-packages
            ];
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsForUser;
          extraSpecialArgs = {
            inherit inputs makeNixLib;
            homeModules = homeModules';
            makeNixAttrs = ctx;
          };
          modules = [
            (makeNixLib.getHomePath {
              system = ctx.system;
              user = ctx.user;
              basePath = ./users;
            })
          ];
        }
      ) hmUsers;

      hmAloneUsers = makeNixLib.getHomeAttrs { dir = ./make-attrs/home-alone; };
      hmAloneConfigs = builtins.mapAttrs (
        _key: haAttrs:
        let
          ctx = makeNixLib.makeAttrsCtx haAttrs;

          userOverlays = import ./overlays {
            inherit inputs makeNixLib;
            makeNixAttrs = ctx;
          };
          pkgsForUser = import nixpkgs {
            localSystem = {
              system = ctx.system;
            };
            overlays = [
              userOverlays.unstable-packages
              userOverlays.local-packages
              userOverlays.mod-packages
            ];
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsForUser;
          extraSpecialArgs = {
            inherit inputs makeNixLib;
            homeModules = homeModules';
            makeNixAttrs = ctx;
          };
          modules = [
            (makeNixLib.getHomePath {
              system = ctx.system;
              user = ctx.user;
              basePath = ./users;
            })
          ];
        }
      ) hmAloneUsers;

      # Supported systems for flake packages, shells, etc.
      supportedSystems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # This is a function to generate an attribute set for each of the
      # systems in the supportedSystems list
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Custom locally defined packages from the ./packages directory
      # Accessible through 'nix build', 'nix shell', etc
      # The forAllSystems function will create a packages output for each
      # system in supportedSystems, so you can run:
      # 'nix build .#packages.aarch64-darwin.yubioath-darwin' etc.
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          localPackages = import ./packages/cross-platform {
            inherit system pkgs;
            config = {
              allowUnfree = true;
            };
          };
          # These packages only support Linux so they are excluded
          # for non-Linux build targets, this prevents errors when evaluating
          # the flake
          localLinuxPackages =
            if makeNixLib.isLinux system then
              import ./packages/linux {
                inherit system pkgs;
                config = {
                  allowUnfree = true;
                };
              }
            else
              { };

          # These packages only support Darwin so they are excluded
          # for non-Darwin build targets
          localDarwinPackages =
            if makeNixLib.isDarwin system then
              import ./packages/darwin {
                inherit system pkgs;
                config = {
                  allowUnfree = true;
                };
              }
            else
              { };
        in
        # Combine our local cross-platform packages with the appropriate
        # Linux-only or Darwin-only local packages depending on the build target
        pkgs.lib.recursiveUpdate localPackages (
          if makeNixLib.isLinux system then localLinuxPackages else localDarwinPackages
        )
      );

      # Formatter for nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Flake wide overlays accessible though ouputs.overlays
      overlays = import ./overlays { inherit inputs makeNixLib; };

      # Provide an easy import for all home-manager modules to each configuration
      homeModules = import ./modules/home-manager;

      # Provide an import for all nixos system modules to each configuration
      nixosModules = import ./modules/nixos;

      # System configuration for Linux based systems
      nixosConfigurations = builtins.mapAttrs (
        _key: sa:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs makeNixLib;
            makeNixAttrs = makeNixLib.makeAttrsCtx sa;
          };
          modules = [
            (
              assert
                builtins.pathExists ./hosts/${sa.host}/configuration.nix
                || throw "nixosConfigurations: missing ./hosts/${sa.host}/configuration.nix";
              ./hosts/${sa.host}/configuration.nix
            )
            ./users/linux-user.nix
            agenix.nixosModules.default
            (
              { lib, pkgs, ... }:
              {
                # Ensure age can find age-plugin-yubikey during activation
                system.activationScripts.agenixInstall.text = lib.mkBefore ''
                  export PATH=${pkgs.age-plugin-yubikey}/bin:${pkgs.age}/bin:$PATH
                '';
              }
            )
          ];
        }
      ) linuxUsers;

      # System configuration for Darwin based systems
      darwinConfigurations = builtins.mapAttrs (
        _key: sa:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit inputs outputs makeNixLib;
            makeNixAttrs = makeNixLib.makeAttrsCtx sa;
          };
          modules = [
            (
              assert
                builtins.pathExists ./hosts/${sa.host}/nix-core.nix
                || throw "darwinConfigurations: missing ./hosts/${sa.host}/nix-core.nix";
              ./hosts/${sa.host}/nix-core.nix
            )
            (
              assert
                builtins.pathExists ./hosts/${sa.host}/system.nix
                || throw "darwinConfigurations: missing ./hosts/${sa.host}/system.nix";
              ./hosts/${sa.host}/system.nix
            )
            (
              assert
                builtins.pathExists ./hosts/${sa.host}/apps.nix
                || throw "darwinConfigurations: missing ./hosts/${sa.host}/apps.nix";
              ./hosts/${sa.host}/apps.nix
            )
            agenix.nixosModules.default
            ./users/darwin-user.nix
          ];

        }
      ) darwinUsers;

      homeConfigurations = hmAloneConfigs // hmConfigs;
    };
}
