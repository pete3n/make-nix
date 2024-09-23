# Patches and workarounds for packages and system settings
{
  config,
  pkgs,
  ...
}: {
  # Signal desktop fix for GPU render bug
  home.file.".local/bin/signal-desktop".text = ''
    #!/bin/sh
    export LIBGL_ALWAYS_SOFTWARE=1
    export ELECTRON_DISABLE_GPU=true
    exec ${pkgs.signal-desktop}/bin/signal-desktop "$@"
  '';

  home.file.".local/bin/86box".test = ''
    #!/bin/sh
    export QT_QPA_PLATFORM=xcb
    exec ${pkgs._86Box-with-roms}/bin/86box "$@"
  '';

  home.sessionVariables.PATH = "${config.home.homeDirectory}/.local/bin:${config.home.sessionVariables.PATH}";
}
