{ config, ... }:
{
  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "framework-dt";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "remotebuild";
        sshKey = config.age.secrets.p22-build-key.path;
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];
    extraOptions = ''
      builders-use-substitutes = true
      fallback = true
    '';
  };

  programs.ssh.knownHosts = {
    "framework-dt" = {
      hostNames = [ "framework-dt" "192.168.1.8" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO70Au6FegohwKFygshDnN9TGll69m4cc1WXMqa8tXl/";
    };
  };
}
