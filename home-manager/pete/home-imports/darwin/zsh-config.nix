{ ... }:
{
  programs.bash.enable = false;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = false;
    syntaxHighlighting.enable = true;
    defaultKeymap = "viins";
    profileExtra =
      # bash
      ''
        export EDITOR=nvim

        # Show fastfetch at login
        if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
        	export FASTFETCH_EXECUTED=1
        	command -v fastfetch &> /dev/null && fastfetch
        fi
      '';
    initExtra =
      # bash
      ''
        alias ls=lsd
        alias lsc='lsd --classic'
        alias wl-copy='pbcopy'
        alias wl-paste='pbpaste'
      '';
  };
}
