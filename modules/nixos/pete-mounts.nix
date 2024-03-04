{pkgs, ...}: {
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/764d6cb6-e59e-4e4f-b97e-fc70673ec4d1";
    fstype = "ext4";
  };
}
