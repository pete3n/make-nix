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
    raspberry-pi-3.display-vc4
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
    linkConfig.MACAddress = "10:A8:29:86:15:E4";
  };

  # Static IP on eth0. useDHCP is disabled globally and only enabled
  networking.useDHCP = false;
  networking.interfaces.eth0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "10.138.95.1";
      prefixLength = 24;
    }];
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      # Only listen on eth0, not loopback or any future interfaces.
      interface = "eth0";
      bind-interfaces = true;

      # DHCP range and lease time.
      dhcp-range = "10.138.95.6,10.138.95.6,24h";

      # Advertise the Pi itself as the gateway and DNS server.
      dhcp-option = [
        "option:router,10.138.95.1"
        "option:dns-server,10.138.95.1"
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
