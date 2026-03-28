{ pkgs, ... }:
let
  brother = "Brother_HL-L3280CDW_NixOS";
  samsung = "Samsung_ML-2510_NixOS";
in
{
  hardware.printers = {
    ensureDefaultPrinter = brother;
    ensurePrinters = [
      {
        name = brother;
        deviceUri = "usb://Brother/HL-L3280CDW%20series?serial=U67025M3N212473";
        model = "gutenprint.5.3://brother-hl-3400cn";
        description = "Brother HL-L3280CDW USB";
        location = "Bedroom";
        ppdOptions = {
          ColorModel = "RGB";
          PageSize = "Letter";
          Duplex = "DuplexNoTumble";
        };
      }
      {
        name = samsung;
        model = "samsung/ml2510.ppd";
        deviceUri = "usb://Samsung/ML-2510%20Series?serial=3V61BKEP229785D.";
        description = "Samsung ML-2510 USB";
        location = "Office";
        ppdOptions = {
          ColorModel = "Grayscale";
          PageSize = "Letter";
        };
      }
    ];
  };
  services.printing = {
    enable = true;
    drivers = [
      pkgs.gutenprint
      pkgs.splix
    ];
  };

  environment.systemPackages = with pkgs; [
    cups
    system-config-printer
  ];
}
