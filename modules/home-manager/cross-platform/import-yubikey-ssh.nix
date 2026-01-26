{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.import-yubikey-ssh;

  import-yubikey-ssh = pkgs.writeShellScriptBin "import-yubikey-ssh" # sh
		''
			set -eu

			ssh_dir="$HOME/.ssh"
			basename="id_ed25519_sk"
			ssh_keygen="${pkgs.openssh}/bin/ssh-keygen"
			mkdir -p "$ssh_dir"
			chmod 700 "$ssh_dir"
			cd "$ssh_dir"

			# Import resident keys if no SK stubs exist (exclude .pub).
			if ! find "$ssh_dir" -maxdepth 1 -type f -name "*$${basename}*" ! -name '*.pub' -print -quit | read -r _; then
				printf "\nImporting resident SSH keys from security key...\n" >&2
				"$ssh_keygen" -K
				printf "import-yubikey-ssh: ssh-keygen -K rc=%s\n" "$?" >&2
			fi
		'';
in
{
  options.programs.import-yubikey-ssh = {
    enable = lib.mkEnableOption "Import SSH keys and set config.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ import-yubikey-ssh ];
    home.activation.bootstrapSsh = lib.hm.dag.entryAfter [ "writeBoundary" ] #sh 
		''
			$DRY_RUN_CMD ${import-yubikey-ssh}/bin/import-yubikey-ssh || true
    '';
  };
}
