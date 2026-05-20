{ lib, makeTags, ... }:
let
  hasP22 = lib.hasTag "p22" makeTags;
in
{
  age.secrets = lib.optionalAttrs hasP22 {
    "openvpn/p22-client1" = {
      file = ../secrets/openvpn/p22-client1.age;
      path = "/var/run/openvpn/p22-client1.ovpn";
      mode = "0600";
      owner = "root";
      group = "root";
    };
    "openvpn/p22-client1-tcp" = {
      file = ../secrets/openvpn/p22-client1-tcp.age;
      path = "/var/run/openvpn/p22-client1-tcp.ovpn";
      mode = "0600";
      owner = "root";
      group = "root";
    };
  };

  environment.shellAliases = lib.optionalAttrs hasP22 {
    p22-vpn     = "sudo openvpn --config /var/run/openvpn/p22-client1.ovpn";
    p22-vpn-tcp = "sudo openvpn --config /var/run/openvpn/p22-client1-tcp.ovpn";
  };
}
