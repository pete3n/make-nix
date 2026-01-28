# TODO:

## Shell

sedall - replaced all matches in all files (default with back)
show changed files and # changes
rg -l "test" | xargs -I {} sed -i.bak "s/test/replaced/g" {}

## Nix

Home-manager rollback
home-manager cleanup
NixOS boot cleanup

### Set default boot entry

For systemd boot only

- Get current build / specialisation derivation
- Match to /boot/entries file with RG (can you have duplicate matches?)
- Get /boot/entry filename
- Set /boot/loader/loader.conf default option to filename

hash script for correct hashing

- Easy way to set a prompt
  nix shell nixpkgs#lazygit -c bash --rcfile <(echo 'PS1="lazygit> "')

- Build local package for cross platform
  nix build --impure --expr 'with import <nixpkgs> { crossSystem = "aarch64-linux"; }; pkgsCross.aarch64-multiplatform.callPackage ./angryoxide {}'
- Build local package
  nix build --impure --expr 'with import <nixpkgs> { system = "x86_64-linux"; }; pkgs.callPackage ./angryoxide {}'
