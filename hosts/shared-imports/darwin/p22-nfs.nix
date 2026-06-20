{ lib, ... }:
let
  nfsMount = remote: local: {
    serviceConfig = {
      ProgramArguments = [
        "/bin/bash"
        "-c"
        "/bin/mkdir -p ${local} && /sbin/mount_nfs -o rw,resvport,vers=4 ${remote} ${local}"
      ];
      RunAtLoad = true;
      StartInterval = 300;
      StandardErrorPath = "/var/log/nfs-mount.log";
      KeepAlive.NetworkState = true;
    };
  };
in
{
  system.activationScripts.extraActivation.text =
    lib.mkAfter # sh
      ''
        /bin/mkdir -p /private/var/mnt
        if ! grep -q '^mnt' /etc/synthetic.conf 2>/dev/null; then
        	printf 'mnt\tprivate/var/mnt\n' >> /etc/synthetic.conf
        	/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
        fi      
      '';

  launchd.daemons.nfs-share = nfsMount "backupsvr.p22:/mnt/user/share" "/mnt/nfs/share";
  launchd.daemons.nfs-open = nfsMount "backupsvr.p22:/mnt/user/open" "/mnt/nfs/open";
}
