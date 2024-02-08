# Host specific module imports
{
  getac-modules = import ./getac;
  xps-modules = import ./xps;
  nvidia-scripts = import ./nvidia-scripts.nix;
  iptables-default = import ./iptables-default-rules.nix;
}
