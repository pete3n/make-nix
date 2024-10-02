{
  lib,
  inputs,
  build_target,
  ...
}: {
  home.packages = lib.mkAfter (with import inputs.nixpkgs-unstable {
      system = build_target.system;
      config.allowUnfree = true;
      config.allowUnfreePredicate = _: true; # Optional: Allow specific unfree packages
      overlays = [
        (final: prev: {
          signal-desktop = prev.signal-desktop.overrideAttrs (oldAttrs: {
            installPhase =
              oldAttrs.installPhase
              + ''
                wrapProgram $out/bin/signal-desktop \
                --set LIBGL_ALWAYS_SOFTWARE 1 \
                --set ELECTRON_DISABLE_GPU true
              '';
          });
        })
      ];
    }; [
      element-desktop
      signal-desktop
      skypeforlinux
      teams-for-linux
    ]);
}
