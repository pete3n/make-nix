{
  description = "Build angryoxide for MIPS MUSLSF";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    angryoxide = {
      url = "path:./angryoxide";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, angryoxide }:
    {
      defaultPackage.x86_64-linux =
        (import nixpkgs {
          system = "x86_64-linux";
          crossSystem = {
            config = "mips-unknown-linux-musl";
            gcc = {
              float = "soft";
            };
          };
          overlays = [
            (self: super: {
              angryoxide = import angryoxide {
                inherit (super) lib;
                fetchFromGitHub = super.fetchFromGitHub;
                rustPlatform = super.rustPlatform;
              };
            })
          ];
        }).pkgsStatic.file;
    };
}
