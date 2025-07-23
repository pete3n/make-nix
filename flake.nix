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
      outputs = self.outputs; # Could be writting as 'inherit (self) outputs' but
      # this is more clear. We need to include outputs because we reference our
      # own outputs in our outputs

      # This is a workaround to allow passing a specified user, host, and
      # target system to the flake, which will pass this to the output
      # configurations to build them appropriately
      build_target = import ./build-target.nix { };

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
            if build_target.isLinux then
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
            if !build_target.isLinux then
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
          if build_target.isLinux then localLinuxPackages else localDarwinPackages
        )
      );

      # Formatter for nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Flake wide overlays accessible though ouputs.overlays
      overlays = import ./overlays { inherit inputs build_target; };

      # Provide an easy import for all home-manager modules to each configuration
      homeModules = import ./modules/home-manager;

      # Provide an import for all nixos system modules to each configuration
      nixosModules = import ./modules;

      # System configuration for Linux based systems
      nixosConfigurations =
        if build_target.isLinux then
          {
            "${build_target.host}" = nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit inputs outputs build_target;
              };
              modules = [
                ./hosts/${build_target.host}/configuration.nix
                ./users/linux/linux-${build_target.user}.nix
              ];
            };
          }
        else
          { };

      # System configuration for Darwin based systems
      darwinConfigurations =
        if !build_target.isLinux then
          {
            "${build_target.host}" = nix-darwin.lib.darwinSystem {
              specialArgs = {
                inherit inputs outputs build_target;
              };
              modules = [
                ./hosts/${build_target.host}/nix-core.nix
                ./hosts/${build_target.host}/system.nix
                ./hosts/${build_target.host}/apps.nix
                ./users/darwin/darwin-${build_target.user}.nix
              ];
            };
          }
        else
          { };

      homeConfigurations =
        if build_target.isLinux then
          {
            # Home-manager configuration for Linux based systems
            "${build_target.user}@${build_target.host}" = home-manager.lib.homeManagerConfiguration {
              # Home-manager requires 'pkgs' instance to be manually specified
              pkgs = nixpkgs.legacyPackages.${build_target.system};
              extraSpecialArgs = {
                inherit inputs outputs build_target;
              };
              modules = [ ./home-manager/${build_target.user}/linux-home.nix ];
            };
          }
        else
          {
            # Home-manager configuration for Darwin based systems
            "${build_target.user}@${build_target.host}" = home-manager-darwin.lib.homeManagerConfiguration {
              pkgs = nixpkgs.legacyPackages.${build_target.system};
              extraSpecialArgs = {
                inherit inputs outputs build_target;
              };
              modules = [ ./home-manager/${build_target.user}/darwin-home.nix ];
            };
          };

    };

}
