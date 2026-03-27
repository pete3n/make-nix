{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.yubi-age-decrypt;

  yubi-age-decrypt = pkgs.writeShellScriptBin "yubi-age-decrypt" # sh
    ''
      set -eu

      export PATH="${pkgs.age-plugin-yubikey}/bin:${pkgs.age}/bin:$PATH"

      if ! [ -S /run/pcscd/pcscd.comm ]; then
        printf "\n\033[0;35mwarning: \033[0myubi-age-decrypt: pcscd socket not found at /run/pcscd/pcscd.comm. Install and start pcscd, then re-run home-manager switch to decrypt git SSH key."  >&2
        exit 0
      fi

      if [ ! -t 0 ]; then
        printf "\n\033[0;35mwarning: \033[0myubi-age-decrypt: not a TTY; skipping Yubikey age decryption. Re-run home-manager switch with a TTY to decrypt.\n" >&2
        exit 0
      fi

      # Args: output_file age_file identity_file
      _output_file="$1"
      _age_file="$2"
      _identity_file="$3"

      if [ ! -f "$_output_file" ]; then
        _output_dir="$(dirname "$_output_file")"
        mkdir -p "$_output_dir"
        chmod 700 "$_output_dir"

        printf "\nyubi-age-decrypt: decrypting %s...\n" "$_output_file" >&2
        ${pkgs.age}/bin/age \
          --decrypt \
          --identity "$_identity_file" \
          --output "$_output_file" \
          "$_age_file"
        chmod 600 "$_output_file"
      fi
    '';
in
{
  options.programs.yubi-age-decrypt = {
    enable = lib.mkEnableOption "Decrypt age secrets using a Yubikey identity.";
    secrets = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          outputFile = lib.mkOption {
            type = lib.types.path;
            description = "Destination path for the decrypted file.";
            example = "/home/pete/.ssh/pete3n";
          };
          ageFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to the encrypted .age file.";
            example = "secrets/pete3n.age";
          };
          identityFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to the age plugin identity file.";
            example = "secrets/age-plugin-yubikeys";
          };
        };
      });
      default = [];
      description = "List of age secrets to decrypt using a Yubikey identity.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ yubi-age-decrypt ];

    home.activation.yubiAgeDecrypt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.concatMapStrings (secret: ''
        $DRY_RUN_CMD ${yubi-age-decrypt}/bin/yubi-age-decrypt \
          ${lib.escapeShellArg secret.outputFile} \
          ${lib.escapeShellArg secret.ageFile} \
          ${lib.escapeShellArg secret.identityFile}
      '') cfg.secrets}
    '';
  };
}
