{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/a0f72048-c503-4002-a69e-05cba47bf75b";
    fsType = "ext4";
  };
  fileSystems."/mnt/nfs" = {
    device = "192.168.1.16:/mnt/user/share";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto"];
  };
}
