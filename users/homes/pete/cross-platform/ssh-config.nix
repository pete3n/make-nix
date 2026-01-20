{ config, pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "bootstrap-ssh" ''
      set -eu

      ssh_dir="$HOME/.ssh"
      mkdir -p "$ssh_dir"
      chmod 700 "$ssh_dir"

      # Import resident keys
      if ! ls "$ssh_dir"/*_sk* 2>/dev/null | grep -vq '\.pub$'; then
        printf "\nImporting resident SSH keys from security key...\n"
        ${pkgs.openssh}/bin/ssh-keygen -K
      fi

      # Pick the first imported SK stub and symlink it to the standard name
      first_sk="$(
        ls -1 "$ssh_dir"/*_sk* 2>/dev/null | grep -v '\.pub$' | head -n 1 || true
      )"

      if [ -n "$first_sk" ] && [ ! -e "$ssh_dir/id_ed25519_sk" ]; then
        ln -s "$(basename "$first_sk")" "$ssh_dir/id_ed25519_sk"
      fi
    '')
  ];

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "framework-dt framework-dt.p22" = {
        user = "remotebuild";
        identitiesOnly = true;
        identityFile = [
          "${config.home.homeDirectory}/.ssh/id_ed25519_sk"
        ];
      };
    };
  };
}
