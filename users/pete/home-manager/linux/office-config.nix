{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Workaround for OnlyOffice font issue:
  # https://github.com/NixOS/nixpkgs/issues/373521
  hmFonts = "${config.home.profileDirectory}/share/fonts";
  ooFonts = "${config.xdg.dataHome}/fonts/onlyoffice"; # ~/.local/share/fonts/onlyoffice
in
{
  home.packages = with pkgs; [
    hunspell # Dictionary
    hunspellDicts.en_US
    libreoffice
		protonmail-bridge
    thunderbird
  ];

  programs.onlyoffice = {
    enable = true;
    settings = {
      UITheme = "theme-night"; # the internal ID for Modern Dark
      UserName = "makeNixAttrs.user";
    };
  };

  # Populate ~/.local/share/fonts with ttf files (not symlinks)
  home.activation.onlyofficeUserFonts =
    lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
      ''
        set -eu

        rm -rf "${ooFonts}"
        mkdir -p "${ooFonts}"

        # Copy actual files (dereference symlinks with -L)
        if [ -d "${hmFonts}" ]; then
        	${pkgs.rsync}/bin/rsync -aL \
        	--include='*/' --include='*.ttf' --include='*.otf' --exclude='*' \
        	"${hmFonts}/" "${ooFonts}/"
        fi
        chmod -R 744 "${ooFonts}"

        ${pkgs.findutils}/bin/find "${ooFonts}" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec chmod 0644 {} \;
        ${pkgs.fontconfig}/bin/fc-cache -f "${ooFonts}" >/dev/null 2>&1 || true
      '';
}
