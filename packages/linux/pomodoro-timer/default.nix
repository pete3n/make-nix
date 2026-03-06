{ pkgs }:
let
  runtimeDeps = with pkgs; [
    jq
    mpc
    gnused
    coreutils
    findutils
    imagemagick
    hyprland
    alacritty
    swayimg
    python3
  ];

  pomodoroMain = pkgs.writeShellScriptBin "pomodoro" # sh
    (builtins.readFile ./pomodoro.sh);

  pomodoroConfig = pkgs.writeShellScriptBin "pomodoro-config" # sh
    ''
      exec ${pkgs.alacritty}/bin/alacritty \
        --option "window.dimensions.columns=120" \
        --option "window.dimensions.lines=40" \
        --option "window.decorations='none'" \
        --title "Pomodoro" \
        -e ${pkgs.python3}/bin/python3 \
        ${./config-tui.py}
    '';

in
pkgs.symlinkJoin {
  name = "pomodoro-timer";
  version = "1.0.0";
  paths = [ pomodoroMain pomodoroConfig ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    for bin in pomodoro pomodoro-config; do
      wrapProgram $out/bin/$bin \
        --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
    done
  '';
}
