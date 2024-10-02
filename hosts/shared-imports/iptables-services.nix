{
  pkgs,
  lib,
  ...
}: {
  # Use iptables instead of nftables, this is required for Docker
  networking.nftables.enable = false;

  # We will manually configure all rules for iptables
  # Overwrite the NixOS iptables configuration
  networking.firewall.enable = false;

  environment.systemPackages = lib.mkAfter (with pkgs; [
    iptables
  ]);

  # Manually configure iptables rules
  systemd.services.iptables-rules = {
    description = "Custom iptables rules";
    wantedBy = ["multi-user.target"];
    script = let
      iptables = "${pkgs.iptables}/bin/iptables";
    in ''
        # Flush existing rules
        ${iptables} -F

        # Delete nixos-fw chains
        for chain in $({iptables} -L -n | grep 'Chain nixos-fw' awk '{print $2}'); do
          ${iptables} -F $chain
          ${iptables} -X $chain
        done

        # Set default policies
        ${iptables} -P INPUT DROP
        ${iptables} -P FORWARD ACCEPT
        ${iptables} -P OUTPUT ACCEPT

        # Rules
        ${iptables} -I INPUT -i lo -j ACCEPT
        ${iptables} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ${iptables} -A INPUT -p udp --dport 53 -j ACCEPT
        ${iptables} -A INPUT -j DROP
    '';
  };
}
