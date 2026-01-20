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
			mkdir -p "$ssh_dir"
			chmod 700 "$ssh_dir"
			cd "$ssh_dir"

			# Import resident keys
			if ! find "$ssh_dir" -maxdepth 1 -type f -name '*_sk*' ! -name '*.pub' | grep -q .; then
				printf "\nImporting resident SSH keys from security key...\n"
				${pkgs.openssh}/bin/ssh-keygen -K
			fi

			# Pick the first imported SK stub and symlink it to the standard name
			first_sk="$(
				find "$ssh_dir" -maxdepth 1 -type f -name '*_sk*' ! -name '*.pub' | head -n 1 || true
			)"

			if [ -n "$first_sk" ] && [ ! -e "$ssh_dir/id_ed25519_sk" ]; then
				ln -s "$first_sk" "$ssh_dir/id_ed25519_sk"
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
