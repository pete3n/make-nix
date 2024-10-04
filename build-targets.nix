{ ... }:
{
  /*
     These variables must be set before using the flake to build configurations:

     user is the username used to configure home-manager and other user level
     settings.

     host is the system host that will be configured. This is a unique
     name that controls system level configuration, services, and also hardware
     specific settings

    system is the system doublet describing CPU architecture and OS

     linux is the host OS linux or darwin. Ensures that OS specific
     configurations are applied correctly - this is easier than parsing this value
    from the system
  */
  user = "pete";
  host = "framework16";
  system = "x86_64-linux";
  isLinux = true;
}
