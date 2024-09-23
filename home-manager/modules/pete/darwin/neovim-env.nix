{
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    inputs.nixvim.packages.x86_64-darwin.default # Customized Neovim dev package
  ]);
}
