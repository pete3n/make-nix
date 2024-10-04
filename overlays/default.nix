# This file defined flake-wide overlays
{ inputs, ... }:
{
  # Import local pkgs from ./ as overlays.local-packages and prepend them with
  # local to differentiate between nixpkgs version. Call with pkgs.local
  local-packages = final: _prev: { local = import ../packages { pkgs = final; }; };

  # Individual package modifications, can be accessed by applying the
  # outputs.overlays.mod-packages overlay to nixpkgs. Call with pkgs.mod
  mod-packages = final: prev: {
    mod = {
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
    };
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
