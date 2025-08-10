{
  description = "Multi-platform Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.05";
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

    nixgl.url = "github:nix-community/nixGL";
    hyprcursor.url = "github:hyprwm/hyprcursor";
    nixvim.url = "github:pete3n/nixvim-flake?ref=nixos-25.05";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      home-manager,
      home-manager-darwin,
      nixpkgs,
      nix-darwin,
      self,
      ...
    }@inputs:
    # @inputs because we need to pass both inputs and outputs to our
    # configurations
    let

      lib = nixpkgs.lib.extend (
        final: prev: {
          mknix = import ./lib {
            inherit inputs; # pass flake inputs if needed
            lib = prev; # base nixpkgs.lib
          };
        }
      );

      outputs = self.outputs; # Could be writting as 'inherit (self) outputs' but
      # this is more clear. We need to include outputs because we reference our
      # own outputs in our outputs

      # This is a workaround to allow passing a specified user, host, and
      # target system options to the flake, which will be accessible to
      # system and home configurations through outputs.
      make_opts = import ./make_opts.nix { };

      hmAloneUsers = lib.mknix.getHomeAloneAttrs;

      hmAloneConfigs = builtins.mapAttrs (
        _key: userCfg:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${userCfg.system};
          extraSpecialArgs = {
            inherit inputs lib outputs;
            make_opts = userCfg;
          };
          modules = [
            (lib.mknix.getHomeAlonePath {
              system = userCfg.system;
              user = userCfg.user;
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
            if lib.mknix.isLinux system then
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
            if lib.mknix.isDarwin system then
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
          if lib.mknix.isLinux system then localLinuxPackages else localDarwinPackages
        )
      );

      # Formatter for nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Flake wide overlays accessible though ouputs.overlays
      overlays = import ./overlays { inherit inputs lib make_opts; };

      # Provide an easy import for all home-manager modules to each configuration
      homeModules = import ./modules/home-manager;

      # Provide an import for all nixos system modules to each configuration
      nixosModules = import ./modules/nixos;

      # System configuration for Linux based systems
      nixosConfigurations =
        if lib.mknix.isLinux make_opts.system then
          {
            "${make_opts.host}" = nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit inputs lib outputs make_opts;
              };
              modules = [
                ./hosts/${make_opts.host}/configuration.nix
                ./users/linux_user.nix
              ];
            };
          }
        else
          { };

      # System configuration for Darwin based systems
      darwinConfigurations =
        if lib.mknix.isDarwin make_opts.system then
          {
            "${make_opts.host}" = nix-darwin.lib.darwinSystem {
              specialArgs = {
                inherit inputs lib outputs make_opts;
              };
              modules = [
                ./hosts/${make_opts.host}/nix-core.nix
                ./hosts/${make_opts.host}/system.nix
                ./hosts/${make_opts.host}/apps.nix
                ./users/darwin_user.nix
              ];
            };
          }
        else
          { };

      homeConfigurations =
        (
          if lib.mknix.isLinux make_opts.system then
            {
              # Home-manager configuration for Linux based systems
              "${make_opts.user}@${make_opts.host}" = home-manager.lib.homeManagerConfiguration {
                # Home-manager requires 'pkgs' instance to be manually specified
                pkgs = nixpkgs.legacyPackages.${make_opts.system};
                extraSpecialArgs = {
                  inherit inputs lib outputs make_opts;
                };
                modules = [ ./users/homes/${make_opts.user}/linux/home.nix ];
              };
            }
          else
            {
              # Home-manager configuration for Darwin based systems
              "${make_opts.user}@${make_opts.host}" = home-manager-darwin.lib.homeManagerConfiguration {
                pkgs = nixpkgs.legacyPackages.${make_opts.system};
                extraSpecialArgs = {
                  inherit inputs lib outputs make_opts;
                };
                modules = [ ./users/homes/${make_opts.user}/darwin/home.nix ];
              };
            }
        )
        // hmAloneConfigs;
    };
}
