{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ nfs-utils ];

  services.rpcbind.enable = true; # needed for NFS
  systemd.mounts =
    let
      commonMountOptions = {
        type = "nfs";
        mountConfig = {
          Options = "rw,noatime,sec=sys,vers=4,user=pete";
        };
      };
    in
    [
      (
        commonMountOptions
        // {
          what = "192.168.1.16:/mnt/user/share";
          where = "/mnt/nfs/share";
        }
      )

      (
        commonMountOptions
        // {
          what = "192.168.1.16:/mnt/user/open";
          where = "/mnt/nfs/open";
        }
      )
    ];

  systemd.automounts =
    let
      commonAutoMountOptions = {
        wantedBy = [ "multi-user.target" ];
        requires = [ "network-online.target" ];
        automountConfig = {
          TimeoutIdleSec = "600";
        };
      };
    in
    [
      (commonAutoMountOptions // { where = "/mnt/nfs/share"; })
      (commonAutoMountOptions // { where = "/mnt/nfs/open"; })
    ];
}
