{pkgs, ...}: {
  services.udev.extraRules = ''
    # Udev rule for SDR device (B200)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2500", ATTRS{idProduct}=="0020", MODE="0666"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2500", ATTRS{idProduct}=="0021", MODE="0666"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2500", ATTRS{idProduct}=="0022", MODE="0666"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3923", ATTRS{idProduct}=="7813", MODE="0666"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3923", ATTRS{idProduct}=="7814", MODE="0666"
  '';

  environment.systemPackages = with pkgs; [
    uhd # USRP SDR
  ];
}
