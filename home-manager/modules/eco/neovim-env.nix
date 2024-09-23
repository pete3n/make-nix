{
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    inputs.nixvim.packages.x86_64-linux.default # Customized Neovim dev package
  ]);
}
