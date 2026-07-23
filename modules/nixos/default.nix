{
  local-ai = import ./local-ai.nix;
  nvidia-scripts = import ./nvidia-scripts.nix;
  yubikeyUsbipServer = import ./yk-usbip-server.nix;
  yubikeyUsbipRemote = import ./yk-usbip-remote.nix;
}
