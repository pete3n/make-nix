{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.quickNotes;
	DLR = "$";

  quickNotes =
    pkgs.writeShellScriptBin "qn"
      #sh
        ''
          	# Usage: qn.sh "Any quoted text string.\n Newline \t tab."
          	notes_file=quick_notes.md
          	notes_path="${DLR}{XDG_DOCUMENTS_DIR:-$HOME/Documents}/$notes_file"
          	
          	[ -d "$(dirname "$notes_path")" ] || exit 1
          	input="$*"
          	printf "%b\n" "$input" >> "$notes_path"
        '';
in
{
  options.programs.quickNotes = {
    enable = lib.mkEnableOption "Install the quickNotes scripts";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ quickNotes ];
  };
}
