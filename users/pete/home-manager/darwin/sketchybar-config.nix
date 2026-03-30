{ pkgs, ... }:
{
  programs.sketchybar = {
    enable = true;
    extraPackages = [ pkgs.aerospace ];
    service.enable = true;

    config = # bash
      ''
        BAR_COLOR=0xff1f2335
        ITEM_COLOR=0xff7ebae4
        FONT="JetBrainsMono Nerd Font"

        sketchybar --bar \
        	drawing=on \
        	topmost=on \
        	height=25 \
        	position=top \
        	color=$BAR_COLOR \
        	padding_left=15 \
        	padding_right=15

        sketchybar --default \
        	icon.font="$FONT:Regular:14.0" \
        	label.font="$FONT:Regular:14.0" \
        	icon.color=$ITEM_COLOR \
        	label.color=$ITEM_COLOR \
        	padding_left=5 \
        	padding_right=5

        sketchybar --add event aerospace_workspace_change

        for sid in 1 2 3 4 5; do
        	sketchybar --add item "space.$sid" left \
        		--subscribe "space.$sid" aerospace_workspace_change \
        		--set "space.$sid" \
        			icon="$sid" \
        			click_script="aerospace workspace $sid" \
        			script="sketchybar --set \$NAME icon.color=\$([ \"\$AEROSPACE_FOCUSED_WORKSPACE\" = \"\$sid\" ] && echo 0xff5277c3 || echo 0xff7ebae4)"
        done

        sketchybar --add item clock center \
        	--set clock \
        		update_freq=1 \
        		script="sketchybar --set clock label=\"\$(date '+%H:%M')\""

        sketchybar --add item battery right \
        	--set battery \
        		update_freq=60 \
        		script="sketchybar --set battery label=\"\$(pmset -g batt | grep -o '[0-9]*%')\""

        sketchybar --update
      '';
  };
}
