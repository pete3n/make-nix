{ pkgs }:
let
  runtimeDeps = with pkgs; [
    coreutils
		ffmpeg
		gawk
		mpc
    python3
  ];

  ipod-shuffle-4g = pkgs.writeShellScriptBin "ipod-shuffle-4g" ''
    exec ${pkgs.python3}/bin/python3 ${./ipod-shuffle-4g.py} "$@"
  '';

  ipod-mpd-copy =
    pkgs.writeShellScriptBin "ipod-mpd-copy" # sh
      (builtins.readFile ./ipod-mpd-copy.sh);
in
pkgs.symlinkJoin {
  name = "ipod-shuffle-4g";
  version = "1.5.0";
  paths = [
    ipod-shuffle-4g
    ipod-mpd-copy
  ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    for bin in ipod-shuffle-4g ipod-mpd-copy; do
      wrapProgram $out/bin/$bin \
				--prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
    done
  '';
}
