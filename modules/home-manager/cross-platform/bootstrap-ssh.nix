{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.bootstrap-ssh;

  bootstrap-ssh = pkgs.writeShellScriptBin "bootstrap-ssh" # sh
		''
			set -eu

			ssh_dir="$HOME/.ssh"
			link="$ssh_dir/id_ed25519_sk"
			ssh_keygen="${pkgs.openssh}/bin/ssh-keygen"
			mkdir -p "$ssh_dir"
			chmod 700 "$ssh_dir"
			cd "$ssh_dir"

			# Remove broken symlinks
			if [ -L "$link" ] && [ ! -e "$link" ]; then
				printf "bootstrap-ssh: removing broken symlink %s\n" "$link" >&2
				rm -f "$link"
			fi

			# Import resident keys if no SK stubs exist (exclude .pub).
			if ! find "$ssh_dir" -maxdepth 1 -type f -name '*_sk*' ! -name '*.pub' -print -quit | read -r _; then
				printf "\nImporting resident SSH keys from security key...\n" >&2
				printf "bootstrap-ssh: running: %s -K\n" "$ssh_keygen" >&2
				"$ssh_keygen" -K
				printf "bootstrap-ssh: ssh-keygen -K rc=%s\n" "$?" >&2
			fi

			# Link ID to first available stub
			if [ ! -e "$link" ]; then
				target="$(find "$ssh_dir" -maxdepth 1 -type f -name '*_sk*' ! -name '*.pub' -print | head -n 1 || true)"

				if [ -n "$target" ]; then
					tmp="$link.tmp.$$"
					ln -s "$target" "$tmp"
					mv -f "$tmp" "$link"
					printf "bootstrap-ssh: linked %s -> %s\n" "$link" "$target" >&2
				else
					printf "bootstrap-ssh: no SK stub found after import (nothing to link)\n" >&2
				fi
			fi
		'';
in
{
  options.programs.bootstrap-ssh = {
    enable = lib.mkEnableOption "Import SSH keys and set config.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ bootstrap-ssh ];
    home.activation.bootstrapSsh = lib.hm.dag.entryAfter [ "writeBoundary" ] #sh 
		''
      if [ ! -e "$HOME/.ssh/id_ed25519_sk" ]; then
        printf "\nbootstrap-ssh: missing id_ed25519_sk; attempting import...\n"
        $DRY_RUN_CMD ${bootstrap-ssh}/bin/bootstrap-ssh || true
      fi
    '';

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

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
  };
}
