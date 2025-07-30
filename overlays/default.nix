# This file defined flake-wide overlays
{ inputs, make_opts, ... }:
{
  # Import local pkgs from ./packages as overlays.local-packages and prepend
  # them with local to differentiate between nixpkgs version. Call with pkgs.local
  local-packages = final: prev: {
    local =
      let
        pkgs = final;

        # Import cross-platform packages
        crossPlatformPackages = import ../packages/cross-platform { inherit pkgs; };

        # Import linux-only packages if our target is linux
        linuxPackages = if make_opts.isLinux then import ../packages/linux { inherit pkgs; } else { };

        # Import darwin-only packages if our target is darwin
        darwinPackages = if !make_opts.isLinux then import ../packages/darwin { inherit pkgs; } else { };
      in
      # Merge all packages into `local`
      crossPlatformPackages // linuxPackages // darwinPackages;
  };

  # Individual package modifications, can be accessed by applying the
  # outputs.overlays.mod-packages overlay to nixpkgs. Call with pkgs.mod
  mod-packages = final: prev: {
    mod =
      if prev ? unstable && prev ? local then
        {
          # Workaround for: https://github.com/signalapp/Signal-Desktop/issues/6855
          # Cannot find target for triple amdgcn--
          no-gpu-signal-desktop = prev.unstable.signal-desktop.overrideAttrs (oldAttrs: {
            installPhase =
              oldAttrs.installPhase
              + ''
                wrapProgram $out/bin/signal-desktop \
                --set LIBGL_ALWAYS_SOFTWARE 1 \
                --set ELECTRON_DISABLE_GPU true
              '';
          });

          _86Box = prev._86Box-with-roms.overrideAttrs (oldAttrs: {
            preFixup =
              oldAttrs.preFixup
              + ''
                makeWrapperArgs+=(--set QT_QPA_PLATFORM "xcb")
              '';
          });

          rofi-calc-wayland = prev.rofi-calc.override { rofi-unwrapped = prev.rofi-wayland-unwrapped; };
        }
      else
        throw "The 'unstable' or 'local' overlay is missing. The mod overlay \
				may modify unstable or local packages, so it is necessary to apply them \
				before attempting to apply the mod overlay.";
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  nixgl = if make_opts.isLinux then inputs.nixgl.overlay else (_: _: { });

  compatability = final: prev:
    if make_opts.tags == "debian" then {
      hyprland = final.writeShellScriptBin "Hyprland" ''
        exec ${final.nixgl.nixGLIntel}/bin/nixGLIntel ${prev.hyprland}/bin/Hyprland "$@"
      '';
    } else
      { };
}
