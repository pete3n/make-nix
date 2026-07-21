{ pkgs, lib, ... }:
let
  fpr = "081B780E59C37C11F59EFA2BC89CFF43D68AD2CB";
  authKeygrip = "1B73CE32F24F63ADCCC49061D9D95B414B057B7F";
in
{
  programs.gpg = {
    enable = true;

    publicKeys = [{
      source = ./keys/pubkey.asc;
      trust = "ultimate";
    }];

    settings = {
      default-key = fpr;
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      cert-digest-algo = "SHA512";
      keyid-format = "0xlong";
      with-fingerprint = true;
      require-cross-certification = true;
      no-symkey-cache = true;
    };

    # pcscd owns the USB interface; keep scdaemon's internal CCID driver out of it.
    scdaemonSettings.disable-ccid = true;
  };

  services.gpg-agent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    enableSshSupport = true;
    sshKeys = [ authKeygrip ];
    pinentry.package = pkgs.pinentry-gnome3;
    defaultCacheTtl = 60;
    maxCacheTtl = 120;
  };
}
