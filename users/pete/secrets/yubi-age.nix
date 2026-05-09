{ lib, makeNixAttrs, ... }:
let
  user = makeNixAttrs.user;
in
{
  environment.etc."age/${user}/age-plugin-yubikeys".source = ./age-plugin-yubikeys;

	# Place ssh keys before yubikey to prevent non-interactive failures
  age.identityPaths = lib.mkAfter [
		"/etc/ssh/ssh_host_ed25519_key"
    "/etc/static/age/${user}/age-plugin-yubikeys"
  ];

  age.secrets."anthropic-api-key" = {
    file = ./api_keys/anthropic-aichat-api.age;
		owner = user;
		mode = "0400";
  };

  age.secrets."wifi-${user}-wifi-lan" = {
    file = ./wpa_supplicant/wifi-lan.conf.age;
    owner = "root";
    group = "root";
    mode = "0400";
    path = "/run/wpa_supplicant/${user}/wifi-lan.conf";
  };
}
