{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.import-yubikey-ssh;
  userKeysArgv = lib.escapeShellArgs cfg.userKeys;

  import-yubikey-ssh = pkgs.writeShellScriptBin "import-yubikey-ssh" # sh
		''
      set -eu
			set -- ${userKeysArgv}

      ssh_dir="$HOME/.ssh"
      ssh_keygen="${pkgs.openssh}/bin/ssh-keygen"

      mkdir -p "$ssh_dir"
      chmod 700 "$ssh_dir"
      cd "$ssh_dir"

      need_import=0

      # If no list provided, trigger import of no *_sk* private keyfiles exist.
			if [ "$#" -eq 0 ]; then
        if ! find "$ssh_dir" -maxdepth 1 -type f -name 'id_ed25519_sk_rk_*' ! -name '*.pub' -print -quit | grep -q .; then
          need_import=1
        fi
      else
				for key in "$@"; do
          if [ ! -f "$ssh_dir/$key" ] || [ ! -f "$ssh_dir/$key.pub" ]; then
            need_import=1
            break
          fi
        done
      fi

      if [ "$need_import" -eq 1 ]; then
				# Avoid hanging non-interactive activation runs
				if [ ! -t 0 ]; then
					printf "\nimport-yubikey-ssh: not a TTY; skipping Yubikey ssh import\n" >&2
					exit 0
				fi

        printf "\nImporting resident SSH keys from security key...\n" >&2
        "$ssh_keygen" -K

        rc=$?
				if [ $rc -eq 0 ]; then
					printf "import-yubikey-ssh: success\n\n"
				else 
					printf "import-yubikey-ssh: failed\n\n"
				fi
        exit "$rc"
      fi
    '';
in
{
  options.programs.import-yubikey-ssh = {
    enable = lib.mkEnableOption "Import SSH keys and set config.";
		userKeys = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			default = [  ];
			example = [
				"id_ed25519_sk_rk_aws"
				"id_ed25519_sk_rk_github"
			];
			description = "List of SSH key stub filenames to check for in ~/.ssh. \
			Missing keys trigger an ssh-keygen -K import. Default will trigger if no matches for 'id_ed25519_sk_rk_*' exist.";
		};
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ import-yubikey-ssh ];
    home.activation.bootstrapSsh = lib.hm.dag.entryAfter [ "writeBoundary" ] #sh 
		''
			$DRY_RUN_CMD ${import-yubikey-ssh}/bin/import-yubikey-ssh || true
    '';
  };
}
