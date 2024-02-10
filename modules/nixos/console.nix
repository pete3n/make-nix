{
  pkgs,
  lib,
  ...
}: {
  #KMS console causes issues with window managers on the XPS
  services.kmscon = {
    enable = lib.mkDefault true;
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

  console = {
    earlySetup = true;
    packages = with pkgs; [
      terminus_font
      powerline-fonts
      powerline-symbols
    ];
    keyMap = "us";
  };
}
