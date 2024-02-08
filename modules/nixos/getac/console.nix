{
  pkgs,
  lib,
  ...
}: {
  # Linux Kernel mode setting console
  services.kmscon = {
    enable = true;
    fonts = [
      {
        name = "JetBrains Mono";
        package = pkgs.jetbrains-mono;
      }
      {
        name = "Source Code Pro";
        package = pkgs.source-code-pro;
      }
    ];
    extraConfig = ''
      font-size=14
    '';
  };
}
