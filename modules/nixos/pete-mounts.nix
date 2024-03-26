{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];

  fileSystems."/mnt/nfs" = {
    device = "192.168.1.16:/mnt/user/share";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto"];
  };
}
