# Patches and workarounds for packages and system settings
{
  config,
  pkgs,
  ...
}: {
  # Signal desktop fix for GPU render bug
  home.file.".local/state/nix/profile/bin/signal-desktop".text = ''
    #!/bin/sh
    export LIBGL_ALWAYS_SOFTWARE=1
    export ELECTRON_DISABLE_GPU=true
    exec ${pkgs.signal-desktop}/bin/signal-desktop "$@"
  '';

  home.file.".local/state/nix/profile/bin/86box".text = ''
    #!/bin/sh
    export QT_QPA_PLATFORM=xcb
    exec ${pkgs._86Box-with-roms}/bin/86box "$@"
  '';

  home.sessionVariables.PATH = "${config.home.homeDirectory}/.local/bin:${config.home.sessionVariables.PATH}";
}
