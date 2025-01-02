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
    {
      self,
      nixpkgs,
      angryoxide,
    }:
    {
      packages.x86_64-linux.default =
        let
          crossPkgs = import nixpkgs {
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
          };
        in
        crossPkgs.angryoxide;
    };
}
