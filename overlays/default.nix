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
      sys = if makeNixAttrs == null then final.stdenv.hostPlatform.system else makeNixAttrs.system;
    in
    makeNix.isLinux sys;

  isDarwinFor =
    final:
    let
      sys = if makeNixAttrs == null then final.stdenv.hostPlatform.system else makeNixAttrs.system;
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

in
{
  # Name overlays (for flake outputs.overlays.<name>)
  inherit
    local-packages
    mod-packages
    unstable-packages
    ;
}
