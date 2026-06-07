# Project jail for ninjection.nvim — Neovim plugin development
#
# Provides lua tooling for linting, formatting, and headless testing
# with PlenaryBusted via the kickstart-nix test harness.
#
# TODO: Wire up nvim-dev and its env vars. Options:
#   1. Add the kickstart-nix flake as a make-nix input and pass its
#      outputs here (nvimDev, nvimPackPath, nvimRtp)
#   2. Have the kickstart-nix flake export a `tooling` attrset
#   3. Import the neovim-overlay directly
{
  makeJailedClaude,
  makeJailedShell,
  pkgs,
  # Uncomment when kickstart-nix flake is wired up:
  # nvimDev,
  # nvimPackPath,
  # nvimRtp,
}:
let
  extraPkgs = with pkgs; [
    lua-language-server
    nixd
    stylua
    luajitPackages.luacheck
    luajitPackages.busted
    # nvimDev
  ];

  # Uncomment when nvim-dev is available:
  # extraEnv = {
  #   VIMRUNTIME = "${nvimDev}/share/nvim/runtime";
  #   NVIM_PACKPATH = nvimPackPath;
  #   NVIM_RTP = nvimRtp;
  # };

  jailArgs = {
    name = "ninjection";
    inherit extraPkgs;
    # inherit extraEnv;
  };
in
{
  packages = [
    (makeJailedClaude jailArgs)
    (makeJailedShell jailArgs)
  ];

  shellAliases = {
    "claude-nj" = "sandboxed -q --allow api.anthropic.com --allow 2607:6bc0::/32 setpriv --ambient-caps=-sys_nice -- jailed-claude-ninjection";
    "jail-test-nj" = "setpriv --ambient-caps=-sys_nice -- jailed-shell-ninjection";
  };
}
