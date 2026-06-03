{ pkgs, makeNixAttrs, ... }:
{
  # Enable auditd — sandbox-wrapper.nix manages per-run rules dynamically
  # via auditctl; no static rules needed here.
  security.audit.enable = true;
  security.auditd.enable = true;

  # Delegate bpf-firewall to user sessions; retained for when the --user
  # IPAddressDeny regression is fixed upstream.
  systemd.services."user@".serviceConfig.Delegate = "cpu memory pids bpf-firewall";

  # NOPASSWD rules for sandbox-wrapper tooling.
  # stdbuf: forces line-buffered stdout on ausearch so the real-time watcher
  #         receives events immediately rather than when the 4KB pipe buffer fills.
  # auditctl: adds/removes per-run audit rules.
  # ausearch: queries the audit log (used by ausandbox-log).
  security.sudo.extraRules = [
    {
      users = [ makeNixAttrs.user ];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemd-run";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.coreutils}/bin/tail";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.audit}/bin/auditctl";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.audit}/bin/ausearch";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
