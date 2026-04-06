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

    nixos-raspberrypi = {
      url = "github:pete3n/nixos-raspberrypi/main";
      # Do not force nixpkgs.follows here. The repo pins its own
      # nixpkgs deliberately because the Pi kernel and firmware packages
      # are built against specific nixpkgs revisions.
    };
  };

  outputs =
    {
      agenix,
      home-manager,
      nixpkgs,
      nix-darwin,
      nixos-raspberrypi,
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

      # All system-attached home-manager users, loaded from make-attrs/system/.
      # This includes Pi hosts — they are identified by piBoard being non-null.
      allSystemUsers = makeNixLib.getHomeAttrs { dir = ./make-attrs/system; };

      # Top-level split: embedded vs standard hosts.
      embeddedUsers = nixpkgs.lib.filterAttrs (_: sa: (sa.embeddedTarget or null) != null) allSystemUsers;
      standardUsers = nixpkgs.lib.filterAttrs (_: sa: (sa.embeddedTarget or null) == null) allSystemUsers;

      # Per-platform embedded subsets. Each new embedded platform adds one line here.
      piUsers = nixpkgs.lib.filterAttrs (
        _: sa: (sa.embeddedTarget or null) == "raspberry-pi"
      ) embeddedUsers;
      # riscvUsers = nixpkgs.lib.filterAttrs
      #   (_: sa: (sa.embeddedTarget or null) == "riscv") embeddedUsers;
      # Home-manager users that have a NixOS/Nix-Darwin system config

      linuxUsers = nixpkgs.lib.filterAttrs (_: sa: makeNixLib.isLinux sa.system) standardUsers;
      darwinUsers = nixpkgs.lib.filterAttrs (_: sa: makeNixLib.isDarwin sa.system) standardUsers;

      # Standard system-attached HM configs (non-embedded Linux and Darwin).
      hmConfigs = builtins.mapAttrs (
        _key: hmAttrs:
        let
          ctx = makeNixLib.makeAttrsCtx hmAttrs;
          userOverlays = import ./overlays {
            inherit inputs makeNixLib;
            makeNixAttrs = ctx;
          };
          pkgsForUser = import nixpkgs {
            localSystem.system = ctx.system;
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
      ) standardUsers;

      # Pi users share the same linux home.nix path as standard Linux hosts.
      # Packages are built natively for aarch64-linux, which requires binfmt
      # emulation on the build host: boot.binfmt.emulatedSystems = [ "aarch64-linux" ]
      # crossSystem is intentionally NOT used here because cross-compiling
      # the full package set causes build-time host tools to be compiled for
      # aarch64 and then fail when the build system tries to execute them.
      piHmConfigs = builtins.mapAttrs (
        _key: piAttrs:
        let
          ctx = makeNixLib.makeAttrsCtx piAttrs;
          userOverlays = import ./overlays {
            inherit inputs makeNixLib;
            makeNixAttrs = ctx;
          };
          pkgsForPi = import nixpkgs {
            localSystem.system = ctx.system;
            overlays = [
              userOverlays.unstable-packages
              userOverlays.local-packages
              userOverlays.mod-packages
            ];
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsForPi;
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
      ) piUsers;

      # Standalone HM configs for non-NixOS Linux users.
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
            localSystem.system = ctx.system;
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

      # Build a single Pi nixosConfiguration from its attrs.
      # nixos-raspberrypi.lib.nixosSystem is a drop-in for nixpkgs.lib.nixosSystem
      # that automatically injects nixos-raspberrypi into specialArgs (required for
      # board modules to resolve their flake-relative paths) and pins a compatible
      # nixpkgs. Nixpkgs is passed explicitly so that version is used instead.
      makePiSystem =
        sa:
        let
          ctx = makeNixLib.makeAttrsCtx sa;
          buildSys = if ctx.buildSystem != null then ctx.buildSystem else "x86_64-linux";

          # The nixpkgs SD image module provides the partition layout, fileSystems
          # definitions, and the config.system.build.sdImage derivation. It must be
          # included when building an image but should NOT be included for a running
          # system (it would conflict with real hardware-generated fileSystems).
          #
          # The aarch64 module is used for rpi02/3/4/5 — all are 64-bit targets.
          # rpi02 in 32-bit mode would need sd-image-armv7l-installer.nix instead,
          # but NixOS on the Zero 2W is always run in 64-bit mode with the nvmd flake.
          sdImageModule =
            if ctx.deployMethod == "sd-image" then
              [ "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix" ]
            else
              [ ];
        in
        nixos-raspberrypi.lib.nixosSystem {
          nixpkgs = nixpkgs;
          specialArgs = {
            inherit
              inputs
              outputs
              makeNixLib
              nixos-raspberrypi
              ;
            makeNixAttrs = ctx;
          };
          modules = sdImageModule ++ [
            (
              assert
                builtins.pathExists ./hosts/${sa.host}/configuration.nix
                || throw "piConfigurations: missing ./hosts/${sa.host}/configuration.nix";
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
                # Set the build platform so Nix knows we are cross-building.
                # This is what enables aarch64 packages to be fetched from
                # cache.nixos.org without needing binfmt on the build host
                # (though binfmt is still required for any packages that must
                # be built locally rather than fetched from cache).
                nixpkgs.buildPlatform.system = buildSys;
              }
            )
          ];
        };

      # The Pi system closures, keyed by user@host.
      # These are full NixOS configurations suitable for 'nixos-rebuild --target-host'.
      piSystemConfigs = builtins.mapAttrs (_key: sa: makePiSystem sa) piUsers;

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
            config.allowUnfree = true;
          };
          # These packages only support Linux so they are excluded
          # for non-Linux build targets, this prevents errors when evaluating
          # the flake
          localLinuxPackages =
            if makeNixLib.isLinux system then
              import ./packages/linux {
                inherit system pkgs;
                config.allowUnfree = true;
              }
            else
              { };

          # These packages only support Darwin so they are excluded
          # for non-Darwin build targets
          localDarwinPackages =
            if makeNixLib.isDarwin system then
              import ./packages/darwin {
                inherit system pkgs;
                config.allowUnfree = true;
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
      nixosConfigurations =
        (builtins.mapAttrs (
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
        ) linuxUsers)
        // (builtins.mapAttrs (_key: _sa: piSystemConfigs.${_key}) piUsers);

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
                builtins.pathExists ./hosts/${sa.host}/configuration.nix
                || throw "darwinConfigurations: missing ./hosts/${sa.host}/configuration.nix";
              ./hosts/${sa.host}/configuration.nix
            )
            agenix.nixosModules.default
            ./users/darwin-user.nix
          ];

        }
      ) darwinUsers;

      # homeConfigurations covers all three user categories.
      homeConfigurations = hmAloneConfigs // hmConfigs // piHmConfigs;

      # piConfigurations: the full NixOS system closures, identical to what
      # is merged into nixosConfigurations. Exposed separately to reference
      # Pi-specific build attributes without scanning the full nixosConfigurations set.

      # nix build .#piConfigurations."pete@rpi4-home".config.system.build.toplevel
      piConfigurations = piSystemConfigs;

      # piImages: SD card images for hosts where deployMethod = "sd-image".
      # Build a specific image:
      #   nix build .#piImages."pete@rpi4-home"
      # Flash it:
      #   zstd -d result/sd-image/*.img.zst -o rpi4.img
      #   sudo dd if=rpi4.img of=/dev/sdX bs=8M status=progress
      piImages = builtins.mapAttrs (key: _sa: piSystemConfigs.${key}.config.system.build.sdImage) (
        nixpkgs.lib.filterAttrs (_: sa: (makeNixLib.makeAttrsCtx sa).deployMethod == "sd-image") piUsers
      );

      # piNetboot: PXE/network boot artifacts for rpi5 hosts where deployMethod = "pxe".
      # Build:
      #   nix build .#piNetboot."pete@rpi5-pxe"
      piNetboot = builtins.mapAttrs (
        key: _sa: piSystemConfigs.${key}.config.system.build.netbootRamdisk
      ) (nixpkgs.lib.filterAttrs (_: sa: (makeNixLib.makeAttrsCtx sa).deployMethod == "pxe") piUsers);
    };
}
