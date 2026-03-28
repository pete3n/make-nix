{ ... }:
{
  environment.etc."auto_master".text = ''
    +auto_master            # Use directory service
    /home                   auto_home       -nobrowse,hidefromfinder
    /Network/Servers        -fstab
    /                       -               -static
    /Volumes/nfs            auto_nfs        -nobrowse,nosuid,noowners
  '';

  environment.etc."auto_nfs".text = ''
    share  -fstype=nfs,rw,resvport,vers=4  backupsvr.p22:/mnt/user/share
    open   -fstype=nfs,rw,resvport,vers=4  backupsvr.p22:/mnt/user/open
  '';

  system.activationScripts.nfsMountPoints.text = ''
    mkdir -p /Volumes/nfs
  '';
}
