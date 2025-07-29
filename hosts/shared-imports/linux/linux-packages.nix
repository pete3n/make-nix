{ pkgs, ... }:
{
  programs.steam.enable = true;
  environment.systemPackages =
    (with pkgs; [
      acpi
      auto-cpufreq
      cryptsetup
      dhcpcd
      dig
      docker-compose
      gnumake
      gparted
      gptfdisk
      home-manager
      iw
      killall
      knot-dns
      libnotify
      nixos-rebuild-ng
      openvpn
      parted
      pavucontrol
      pciutils
      pipewire
      qemu
      qemu-utils
      tcpdump
      thermald
      traceroute
      usbutils
      wpa_supplicant
    ])
    ++ [
      (pkgs.unstable.lutris.override {
        extraPkgs = p: [
          p.wineWowPackages.waylandFull
          p.winetricks
        ];
      })
    ];
}
