{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "sandboxed" ''
      if [ $# -eq 0 ]; then
        echo "Usage: sandboxed <command> [args...]" >&2
        echo "Runs a command with outbound network blocked except localhost." >&2
        exit 1
      fi

      exec ${pkgs.systemd}/bin/systemd-run \
        --user \
        --pty \
        --same-dir \
        --wait \
        --collect \
        --unit="sandboxed-$(basename "$1")-$$" \
        --property="IPAddressDeny=any" \
        --property="IPAddressAllow=127.0.0.0/8" \
        --property="IPAddressAllow=::1/128" \
        --property="NetClass=0x53" \
        --property="Environment=HOME=$HOME" \
        --property="Environment=XDG_CONFIG_HOME=$XDG_CONFIG_HOME" \
        -- "$@"
    '')
  ];
}
