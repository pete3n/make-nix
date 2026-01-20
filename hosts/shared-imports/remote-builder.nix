{ ... }:
{
  users = {
    groups.remotebuild = { };
    users = {
      remotebuild = {
        isSystemUser = true;
        group = "builders";
        useDefaultShell = true;

        openssh.authorizedKeys.keys = [
          # Primary Yubikey
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEFU2BKDdywiMqeD7LY8lgKeBo0mjHEyP7ej+Y2JNuJDAAAABHNzaDo= pete@framework16"
          # Backup Yubikey
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHwNQ411TYRwGAGINX4i4FI7Ek7lfTQv0s8vbXmnqVh/AAAABHNzaDo= pete@framework16"
        ];
      };
    };
  };

  nix.settings.allowed-users = [ 
		"@builders" 
		"root" 
	];
  nix.settings.trusted-users = [ 
		"@builders"
		"root"
	];
}
