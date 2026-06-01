{ pkgs, ... }:
let
  iptables = "${pkgs.iptables}/bin/iptables";
  ip6tables = "${pkgs.iptables}/bin/ip6tables";

  # Script that adds LOG+DROP rules for a given cgroup path, then removes
  # them when the unit stops. Called by the systemd path watcher.
  sandboxCtl = pkgs.writeShellScript "sandbox-ctl" ''
    set -euo pipefail
    ACTION="$1"   # "add" or "remove"
    CGPATH="$2"   # relative cgroup path, e.g. user.slice/user-1000.slice/...

    case "$ACTION" in
      add)
        for ipt in "${iptables}" "${ip6tables}"; do
          # Check not already present (idempotent)
          $ipt -C SANDBOX_OUT -m cgroup --path "$CGPATH" \
            -j LOG --log-prefix "SANDBOX-BLOCKED: " --log-level 4 2>/dev/null && continue
          $ipt -A SANDBOX_OUT -m cgroup --path "$CGPATH" \
            -j LOG --log-prefix "SANDBOX-BLOCKED: " --log-level 4
          $ipt -A SANDBOX_OUT -m cgroup --path "$CGPATH" -j DROP
        done
        ;;
      remove)
        for ipt in "${iptables}" "${ip6tables}"; do
          $ipt -D SANDBOX_OUT -m cgroup --path "$CGPATH" \
            -j LOG --log-prefix "SANDBOX-BLOCKED: " --log-level 4 2>/dev/null || true
          $ipt -D SANDBOX_OUT -m cgroup --path "$CGPATH" -j DROP 2>/dev/null || true
        done
        ;;
    esac
  '';

  # Watches for cgroup directories appearing/disappearing under any user slice
  # matching the sandboxed-* naming convention
  sandboxWatcher = pkgs.writeShellScript "sandbox-watcher" ''
    set -euo pipefail
    CGROOT="/sys/fs/cgroup"

    ${pkgs.inotify-tools}/bin/inotifywait \
      --monitor \
      --recursive \
      --event create,delete \
      --format '%e %w%f' \
      --include 'sandboxed-.*\.service$' \
      "$CGROOT/user.slice" \
    | while read -r EVENT PATH; do
        # Strip cgroup root prefix to get relative path for iptables
        CGPATH="''${PATH#$CGROOT/}"
        case "$EVENT" in
          CREATE,ISDIR)
            logger -t sandbox-monitor "Adding rules for $CGPATH"
            ${sandboxCtl} add "$CGPATH"
            ;;
          DELETE,ISDIR)
            logger -t sandbox-monitor "Removing rules for $CGPATH"
            ${sandboxCtl} remove "$CGPATH"
            ;;
        esac
      done
  '';
in
{
  environment.systemPackages = [ pkgs.inotify-tools ];

  systemd.services.sandbox-monitor = {
    description = "Dynamic iptables rules for sandboxed processes";
    wantedBy = [ "multi-user.target" ];
    after = [ "iptables-rules.service" ];
    requires = [ "iptables-rules.service" ];

    serviceConfig = {
      ExecStart = sandboxWatcher;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
