# overlays/default.nix
# Expose named overlays AND an ordered list 'all'.
# Optionally accept makeNixAttrs (user/system context); if not provided, fall back to final.system.
{
  inputs,
  makeNix,
  makeNixAttrs ? null,
}:
let
  # Helper: determine platform using either makeNixAttrs.system (provided from userAttrs)
  # or the current final.system from nixpkgs.
  isLinuxFor =
    final:
    let
      sys = if makeNixAttrs == null then final.system else makeNixAttrs.system;
    in
    makeNix.isLinux sys;

  isDarwinFor =
    final:
    let
      sys = if makeNixAttrs == null then final.system else makeNixAttrs.system;
    in
    makeNix.isDarwin sys;

  # Import local pkgs from ./packages as overlays.local-packages and prepend
  # them with local to differentiate between nixpkgs version. Call with pkgs.local
  local-packages = final: prev: {
    local =
      let
        pkgs = final;

        # Import cross-platform packages
        crossPlatformPackages = import ../packages/cross-platform { inherit pkgs; };

        # Import linux-only packages if our target is linux
        linuxPackages = if isLinuxFor final then import ../packages/linux { inherit pkgs; } else { };

        # Import darwin-only packages if our target is darwin
        darwinPackages = if isDarwinFor final then import ../packages/darwin { inherit pkgs; } else { };
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
          # Wrapper to transparently launch Hyprland with nixGLIntel on non-NixOS
          # systems which require it to function correctly.
          hyprland-nixgli-wrapped = prev.hyprland.overrideAttrs (oldAttrs: {
            postInstall =
              (oldAttrs.postInstall or "")
              +
              # sh
              ''
                mv $out/bin/Hyprland $out/bin/Hyprland.unwrapped
                makeWrapper ${final.nixgl.nixGLIntel}/bin/nixGLIntel $out/bin/Hyprland \
                --add-flags "$out/bin/Hyprland.unwrapped"
              '';
          });

          # Workaround for: https://github.com/signalapp/Signal-Desktop/issues/6855
          # Cannot find target for triple amdgcn--
          no-gpu-signal-desktop = prev.unstable.signal-desktop.overrideAttrs (oldAttrs: {
            installPhase = oldAttrs.installPhase + ''
              wrapProgram $out/bin/signal-desktop \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --set ELECTRON_DISABLE_GPU true
            '';
          });

          _86Box = prev._86Box-with-roms.overrideAttrs (oldAttrs: {
            preFixup = oldAttrs.preFixup + ''
              makeWrapperArgs+=(--set QT_QPA_PLATFORM "xcb")
            '';
          });
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
      localSystem = final.stdenv.hostPlatform;
      config.allowUnfree = true;
    };
  };

  linux-compatibility-packages =
    final: prev: if isLinuxFor final then inputs.nixgl.overlay final prev else { };

in
{
  # Name overlays (for flake outputs.overlays.<name>)
  inherit
    local-packages
    mod-packages
    unstable-packages
    linux-compatibility-packages
    ;
}
