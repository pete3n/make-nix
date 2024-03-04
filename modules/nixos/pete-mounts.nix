{pkgs, ...}: {
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/a0f72048-c503-4002-a69e-05cba47bf75b";
    fsType = "ext4";
  };
}
