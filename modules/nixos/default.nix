# Host specific module imports
{
  console = import ./console.nix;
  gaming = import ./gaming.nix;
  getac-modules = import ./getac;
  iptables-default = import ./iptables-default-rules.nix;
  nvidia-scripts = import ./nvidia-scripts.nix;
  system-tools = import ./system-tools.nix;
  X11-tools = import ./X11-tools.nix;
  xps-modules = import ./xps;
  yubi-smartcard = import ./yubikey-sc.nix;
}
