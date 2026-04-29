{
  lib,
  makeNixLib,
  makeNixAttrs,
  nixos-raspberrypi,
  ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-3.base
  ];

  users.users.${makeNixAttrs.user}.initialPassword = "changeme";
  users.users.root.initialPassword = "changeme";
  networking.hostName = makeNixAttrs.host;
  system.stateVersion = "25.11";

  # Assign a deterministic locally-administered MAC to eth0.
  # The 02: prefix marks it as locally administered (not hardware-assigned).
  # systemd-networkd link files are the correct NixOS mechanism for this —
  # they apply before the interface is brought up, so the MAC is stable.
  systemd.network.links."10-eth0" = {
    matchConfig.OriginalName = "eth0";
    linkConfig.MACAddress = "10:A8:29:18:26:4b";
  };

  # Static IP on eth0. useDHCP is disabled globally and only enabled
  networking.useDHCP = false;
  networking.interfaces.eth0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "169.254.0.1";
      prefixLength = 16;
    }];
  };

  services.dnsmasq = {
    enable = false;
    settings = {
      # Only listen on eth0, not loopback or any future interfaces.
      interface = "eth0";
      bind-interfaces = true;

      # DHCP range and lease time.
      dhcp-range = "169.254.0.100,169.254.0.200,24h";

      # Advertise the Pi itself as the gateway and DNS server.
      dhcp-option = [
        "option:router,169.254.0.1"
        "option:dns-server,169.254.0.1"
      ];

      # Don't forward plain (non-dotted) hostnames upstream.
      domain-needed = true;
      # Don't forward addresses in the private ranges upstream.
      bogus-priv = true;
    };
  };

  # dnsmasq listens on port 53 — open it on the interface.
  networking.firewall.interfaces.eth0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 ];  # 53 = DNS, 67 = DHCP server
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  boot.kernelModules = lib.optionals
    (makeNixLib.hasTag "pi-gpio" makeNixAttrs.tags) [ "gpio-keys" ];
}
