{ pkgs, makeNixAttrs, ... }:
{
	imports = [ ../infrax.nix ];
  system.primaryUser = makeNixAttrs.user;
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Disable auto-optimise-store because of this issue:
    #   https://github.com/NixOS/nix/issues/7273
    # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
    auto-optimise-store = false;
  };

  nixpkgs.hostPlatform = "x86_64-darwin";

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;
}
