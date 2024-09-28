{...}: {
  services.skhd = {
    enable = true;
    skhdConfig = ''
      alt - return : alacritty
      alt - c : yabai -m window --close
      alt - f : yabai -m window --toggle zoom-fullscreen
      alt - p : yabai -m window --toggle float
      alt - d : yabai -m window --focus title="NUC"

      alt - h : yabai -m window --focus west
      alt - j : yabai -m window --focus south
      alt - k : yabai -m window --focus north
      alt - l : yabai -m window --focus east

      shift + alt - h : yabai -m window --swap west
      shift + alt - j : yabai -m window --swap south
      shift + alt - k : yabai -m window --swap north
      shift + alt - l : yabai -m window --swap east

      # Only work with SIP disabled
      #alt - 1 : yabai -m space --focus 1
      #alt - 2 : yabai -m space --focus 2
      #alt - 3 : yabai -m space --focus 3
      #alt - 4 : yabai -m space --focus 4
      #alt - 5 : yabai -m space --focus 5

      #alt + shift - 1 : yabai -m window --space 1
      #alt + shift - 2 : yabai -m window --space 2
      #alt + shift - 3 : yabai -m window --space 3
      #alt + shift - 4 : yabai -m window --space 4
      #alt + shift - 5 : yabai -m window --space 5
    '';
  };
}
