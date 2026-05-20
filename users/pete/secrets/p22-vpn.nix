{ makeNixAttrs, ... }:
{
  age.secrets = {
    "openvpn/p22-client1" = {
      file = ./openvpn/p22-client1.age;
      path = "/var/run/openvpn/${makeNixAttrs.user}/p22-client1.ovpn";
      mode = "0600";
      owner = "root";
      group = "root";
    };
    "openvpn/p22-client1-tcp" = {
      file = ./openvpn/p22-client1-tcp.age;
      path = "/var/run/openvpn/${makeNixAttrs.user}/p22-client1-tcp.ovpn";
      mode = "0600";
      owner = "root";
      group = "root";
    };
  };

  environment.shellAliases = {
    p22-vpn = "sudo openvpn --config /var/run/openvpn/${makeNixAttrs.user}/p22-client1.ovpn";
    p22-vpn-tcp = "sudo openvpn --config /var/run/openvpn/${makeNixAttrs.user}/p22-client1-tcp.ovpn";
  };
}
