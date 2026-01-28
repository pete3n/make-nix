{ lib, makeNixAttrs, ... }:
let
  user = makeNixAttrs.user;
in
{
  environment.etc."age/${user}/age-plugin-yubikeys".source = ./age-plugin-yubikeys;

  age.identityPaths = lib.mkAfter [
    "/etc/static/age/${user}/age-plugin-yubikeys"
  ];

  age.secrets."wifi-${user}-p22-lan-2g" = {
    file = ./wpa_supplicant/p22-lan-2g.conf.age;
    owner = "root";
    group = "root";
    mode = "0400";
    path = "/run/wpa_supplicant/${user}/p22-lan-2g.conf";
  };

  age.secrets."wifi-${user}-p22-lan-5g" = {
    file = ./wpa_supplicant/p22-lan-5g.conf.age;
    owner = "root";
    group = "root";
    mode = "0400";
    path = "/run/wpa_supplicant/${user}/p22-lan-5g.conf";
  };
}
