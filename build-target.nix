{ ... }:
{
  user = "joe";
  host = "nuc";
  system = "x86_64-linux";
  isLinux = true;
  specialisations   = [ x11 wayland_egpu ];
}
