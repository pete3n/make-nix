# TODO:

## Shell

sedall - replaced all matches in all files (default with back)
show changed files and # changes
rg -l "test" | xargs -I {} sed -i.bak "s/test/replaced/g" {}

## Nix

Home-manager rollback
home-manager cleanup
NixOS boot cleanup / set default

hash script for correct hashing

- Easy way to set a prompt
  nix shell nixpkgs#lazygit -c bash --rcfile <(echo 'PS1="lazygit> "')
