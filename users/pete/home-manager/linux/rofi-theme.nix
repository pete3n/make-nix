{ config, lib, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  options.rofi.theme = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Rofi theme configuration.";
  };
  config = {
    rofi.theme = {
      "*" = {
        selected-normal-foreground = mkLiteral "#ffffff";
        foreground = mkLiteral "#ffffff";
        normal-foreground = mkLiteral "@foreground";
        alternate-normal-background = mkLiteral "transparent";
        red = mkLiteral "#ff322f";
        selected-urgent-foreground = mkLiteral "#ffc39c";
        blue = mkLiteral "#278bd2";
        urgent-foreground = mkLiteral "#f3843d";
        alternate-urgent-background = mkLiteral "transparent";
        active-foreground = mkLiteral "#268bd2";
        lightbg = mkLiteral "#eee8d5";
        selected-active-foreground = mkLiteral "#205171";
        alternate-active-background = mkLiteral "transparent";
        background = mkLiteral "transparent";
        bordercolor = mkLiteral "#393939";
        alternate-normal-foreground = mkLiteral "@foreground";
        normal-background = mkLiteral "transparent";
        lightfg = mkLiteral "#586875";
        selected-normal-background = mkLiteral "#268bd2";
        border-color = mkLiteral "@foreground";
        spacing = mkLiteral "2";
        separatorcolor = mkLiteral "#268bdb";
        urgent-background = mkLiteral "transparent";
        selected-urgent-background = mkLiteral "#268bd2";
        alternate-urgent-foreground = mkLiteral "@urgent-foreground";
        background-color = mkLiteral "#00000000";
        alternate-active-foreground = mkLiteral "@active-foreground";
        active-background = mkLiteral "#0a0047";
        selected-active-background = mkLiteral "#268bd2";
      };

      # Holds the entire window
      "window" = {
        background-color = mkLiteral "#393939cc";
        border = mkLiteral "1";
        padding = mkLiteral "5";
      };

      # Wrapper around bar and results
      "mainbox" = {
        border = mkLiteral "0";
        padding = mkLiteral "0";
      };

      "textbox" = {
        text-color = mkLiteral "@foreground";
      };

      # Command prompt left of the input
      "#prompt" = {
        enabled = false;
      };

      # Actual text box
      "#entry" = {
        placeholder-color = mkLiteral "#00ff00";
        expand = true;
        horizontal-align = "0";
        placeholder = "";
        padding = mkLiteral "0px 0px 0px 5px";
        blink = true;
      };

      # Top bar
      "#inputbar" = {
        children = map mkLiteral [
          "prompt"
          "entry"
        ];
        border = mkLiteral "1px";
        border-radius = mkLiteral "4px";
        padding = mkLiteral "6px";
      };

      # Results
      "listview" = {
        fixed-height = mkLiteral "0";
        border = mkLiteral "2px dash 0px 0px";
        border-color = mkLiteral "@separatorcolor";
        spacing = mkLiteral "2px";
        scrollbar = mkLiteral "true";
        padding = mkLiteral "2px 0px 0px";
      };

      # Each result
      "element" = {
        border = mkLiteral "0";
        padding = mkLiteral "1px";
      };

      "element.normal.normal" = {
        background-color = mkLiteral "@normal-background";
        text-color = mkLiteral "@normal-foreground";
      };

      "element.normal.urgent" = {
        background-color = mkLiteral "@urgent-background";
        text-color = mkLiteral "@urgent-foreground";
      };

      "element.normal.active" = {
        background-color = mkLiteral "@active-background";
        text-color = mkLiteral "@active-foreground";
      };

      "element.selected.normal" = {
        background-color = mkLiteral "@selected-normal-background";
        text-color = mkLiteral "@selected-normal-foreground";
      };

      "element.selected.urgent" = {
        background-color = mkLiteral "@selected-urgent-background";
        text-color = mkLiteral "@selected-urgent-foreground";
      };

      "element.selected.active" = {
        background-color = mkLiteral "@selected-active-background";
        text-color = mkLiteral "@selected-active-foreground";
      };

      "element.alternate.normal" = {
        background-color = mkLiteral "@alternate-normal-background";
        text-color = mkLiteral "@alternate-normal-foreground";
      };

      "element.alternate.urgent" = {
        background-color = mkLiteral "@alternate-urgent-background";
        text-color = mkLiteral "@alternate-urgent-foreground";
      };

      "element.alternate.active" = {
        background-color = mkLiteral "@alternate-active-background";
        text-color = mkLiteral "@alternate-active-foreground";
      };

      "scrollbar" = {
        witdh = mkLiteral "4px";
        border = mkLiteral "0";
        handle-width = mkLiteral "8px";
        padding = mkLiteral "0";
      };

      "mode-switcher" = {
        border = mkLiteral "2px dash 0px 0px";
        border-color = mkLiteral "@separatorcolor";
      };

      "button.selected" = {
        background-color = mkLiteral "@selected-normal-background";
        text-color = mkLiteral "@selected-normal-foreground";
      };

      "button" = {
        background-color = mkLiteral "@selected-normal-background";
        text-color = mkLiteral "@selected-normal-foreground";
      };

      "inputbar" = {
        spacing = mkLiteral "0";
        text-color = mkLiteral "@normal-foreground";
        padding = mkLiteral "1px";
        children = mkLiteral "[ prompt,textbox-prompt-colon,entry,case-indicator ]";
      };

      "case-indicator" = {
        spacing = mkLiteral "0";
        text-color = mkLiteral "@normal-foreground";
      };

      "entry" = {
        spacing = mkLiteral "0";
        text-color = mkLiteral "@normal-foreground";
      };

      "prompt" = {
        spacing = mkLiteral "0";
        text-color = mkLiteral "@normal-foreground";
      };

      "textbox-prompt-colon" = {
        expand = mkLiteral "false";
        str = ":";
        margin = mkLiteral "0px 0.3em 0em 0em";
        text-color = mkLiteral "@normal-foreground";
      };

      "element-text" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };
    };
  };
}
