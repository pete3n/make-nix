{pkgs, ...}: {
  home.packages = with pkgs; [
    cryptomator
    drawio
    nb
    nextcloud-client
    onlyoffice-bin
    pika-backup
    protonmail-bridge
    remmina
    standardnotes
    thunderbird
  ];
}
