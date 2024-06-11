# Host specific module imports
{
  console = import ./console.nix;
  framework16-modules = import ./framework16;
  gaming = import ./gaming.nix;
  getac-modules = import ./getac;
  iptables-default = import ./iptables-default-rules.nix;
  nvidia-scripts = import ./nvidia-scripts.nix;
  pete-mounts = import ./pete-mounts.nix;
  pete-printer = import ./pete-printer.nix;
  system-tools = import ./system-tools.nix;
  X11-tools = import ./X11-tools.nix;
  xps-modules = import ./xps;
  yubi-smartcard = import ./yubikey-sc.nix;
}
