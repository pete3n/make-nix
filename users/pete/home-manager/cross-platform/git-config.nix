{
  config,
  lib,
  pkgs,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  hasGitUser = makeNixLib.hasTag "git-user" makeNixAttrs.tags;
  needsHomeActivation = hasGitUser && makeNixAttrs.isHomeAlone;
in
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim";
      init = {
        defaultBranch = "main";
        templateDir = "${config.home.homeDirectory}/.git-templates";
      };
      user = {
        name = "pete3n";
        email = "pete3n@protonmail.com";
      };
    };
  };

  home.file.".git-templates/gitlint".text = ''
    [general]
    ignore=title-trailing-punctuation, T3
    contrib=contrib-title-conventional-commits,CC1
    #extra-path=./gitlint_rules/my_rules.py

    ### Configuring rules ###
    [title-max-length]
    line-length=80

    [title-min-length]
    min-length=5
  '';

  home.activation = lib.mkIf needsHomeActivation {
    decryptGitSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.age-plugin-yubikey}/bin:${pkgs.age}/bin:${pkgs.pcsclite}/bin:$PATH"

      _ssh_dir="${config.home.homeDirectory}/.ssh"
      _key_path="$_ssh_dir/pete3n"
      _age_file="${../../secrets/pete3n.age}"
      _identity="${../../secrets/age-plugin-yubikeys}"

      mkdir -p "$_ssh_dir"
      chmod 700 "$_ssh_dir"

      if [ ! -f "$_key_path" ]; then
        # Start pcscd transiently if not running
        if ! pgrep -x pcscd > /dev/null; then
          ${pkgs.pcsclite}/sbin/pcscd --foreground &
          _pcscd_pid=$!
          sleep 1
        fi

        $DRY_RUN_CMD ${pkgs.age}/bin/age \
          --decrypt \
          --identity "$_identity" \
          --output "$_key_path" \
          "$_age_file" \
          </dev/tty >/dev/tty 2>/dev/tty

        $DRY_RUN_CMD chmod 600 "$_key_path"

        # Stop pcscd if we started it
        [ -n "''${_pcscd_pid:-}" ] && kill "$_pcscd_pid" 2>/dev/null || true
      fi
    '';
  };
}
