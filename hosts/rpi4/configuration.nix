# Pi 4 host configuration. The board base module (raspberry-pi-4.base) is
# imported here rather than in the builder so each host can choose exactly
# which nixos-raspberrypi modules it needs (display, bluetooth, camera, etc.)
#
# Available board modules (import from nixos-raspberrypi.nixosModules):
#   raspberry-pi-4.base         — required: kernel, firmware, bootloader defaults
#   raspberry-pi-4.display-vc4  — VC4 GPU / display output
#
# makeNixLib.piBaseModAttr ctx.piBoard returns "raspberry-pi-4" for this host,
# which you can use if you want to drive imports programmatically. However,
# importing explicitly by name is clearer and is the recommended pattern.
{
  lib,
  makeNixLib,
  makeNixAttrs,
  nixos-raspberrypi,
  ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-4.base
    raspberry-pi-4.display-vc4
  ];

  users.users.${makeNixAttrs.user}.initialPassword = "changeme";
  users.users.root.initialPassword = "changeme";

  networking.hostName = makeNixAttrs.host;
  system.stateVersion = "25.11";

  # SSH is required for 'nixos-rebuild --target-host' after first boot.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Authorised keys are injected by users/linux-user.nix via makeNixAttrs.sshPubKeys.

  # Enable the GPIO kernel module if the pi-gpio tag is set.
  boot.kernelModules = lib.optionals (makeNixLib.hasTag "pi-gpio" makeNixAttrs.tags) [ "gpio-keys" ];
}
