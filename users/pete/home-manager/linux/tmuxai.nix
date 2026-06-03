{
  config,
  lib,
  makeNixAttrs,
  makeNixLib,
  pkgs,
  ...
}:
let
  hasTmuxAi = makeNixLib.hasTag "local-ai" (makeNixAttrs.tags or [ ]);

  # Sandboxed wrapper passed as programs.tmuxai.package so it is the binary
  # installed into PATH. Raw pkgs.tmuxai is only referenced by store path here
  # and never exposed directly. sandboxed is provided by sandbox-wrapper.nix.
  tmuxaiSandboxed =
    pkgs.writeShellScriptBin "tmuxai" # sh
      ''
        set -u

        NIX_TMUXAI="${pkgs.tmuxai}/bin/tmuxai"
        TMUX="''${TMUX:-}"
        TMUX_PANE="''${TMUX_PANE:-}"

        exec sandboxed "''${NIX_TMUXAI}" "$@"
      '';
in
lib.mkIf hasTmuxAi {
  programs.tmuxai = {
    enable = true;
    package = tmuxaiSandboxed;

    defaultModel = "local";

    # Adjust model to match what is currently loaded in Ollama.
    models.local = {
      provider = "openrouter";
      model = "qwen3-coder:latest";
      api_key = "ollama";
      base_url = "http://localhost:11434/v1";
    };

    debug = false;
    yolo = false;
    maxContextSize = 100000;
    maxCaptureLines = 200;
    waitInterval = 5;

    execConfirm = true;
    sendKeysConfirm = true;
    pasteMultilineConfirm = true;

    statusLine = "{app} ({context}) [{model}] » ";
    execSplitArgs = [ "-d" "-h" ];

    whitelistPatterns = [
      ''^ls(\s+.*)?$''
      ''^pwd\s*$''
      ''^cat(\s+.*)?$''
      ''^find(\s+.*)?$''
      ''^stat(\s+.*)?$''
      ''^file(\s+.*)?$''
      ''^tree(\s+.*)?$''
      ''^echo(\s+.*)?$''
      ''^cd(\s+[\w\.\~\/-]+)?\s*$''
    ];

    blacklistPatterns = [
      ''rm\s+''
      ''mv\s+''
      ''dd\s+''
      ''chmod\s+''
      ''chown\s+''
      ''sudo\s+''
      ''pkexec\s+''
    ];
  };

  # Create runtime directories that tmuxai manages imperatively.
  # kb/ and skills/ are populated by the user at runtime, not Nix-managed.
  home.activation.tmuxaiDirs =
    lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
      ''
        for _dir in \
          "${config.home.homeDirectory}/.config/tmuxai/kb" \
          "${config.home.homeDirectory}/.config/tmuxai/skills"; do
          if [ ! -d "''${_dir}" ]; then
            printf "tmuxai: creating directory %s\n" "''${_dir}"
            $DRY_RUN_CMD mkdir -p "''${_dir}"
          fi
        done
      '';

  programs.bash.shellAliases = {
    ta = "tmuxai";
  };
}
