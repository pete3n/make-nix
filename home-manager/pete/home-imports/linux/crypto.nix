{
  build_target,
  inputs,
  ...
}: {
  home.packages = with inputs.nixpkgs-unstable.legacyPackages.${build_target.system}; [
    bisq-desktop
    monero-gui
    monero-cli
  ];
}
