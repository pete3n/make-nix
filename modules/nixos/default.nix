# Host specific module imports
{
  console = import ./console.nix;
  getac-modules = import ./getac;
  iptables-default = import ./iptables-default-rules.nix;
  nvidia-scripts = import ./nvidia-scripts.nix;
  pete-mounts = import ./pete-mounts.nix;
  pete-printer = import ./pete-printer.nix;
  pete-services = import ./pete-services.nix;
  system-tools = import ./system-tools.nix;
  usrp-sdr = import ./usrp-sdr.nix;
  X11-tools = import ./X11-tools.nix;
  xps-modules = import ./xps;
  yubi-smartcard = import ./yubikey-sc.nix;
}
