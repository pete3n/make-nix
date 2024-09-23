{...}: {
  /*
  These variables must be set before using the flake to build configurations:

  target_user is username used to configure home-manager and other user level
  settings.

  target_host is the system host that will be configured. This is a unique
  name that controls system level configuration, services, and also hardware
  specific settings

  target_is_linux is the host OS linux or darwin. Ensures that OS specific
  configurations are applied correctly
  */
  user = "pete";
  host = "macbook";
  isLinux = false;
}
