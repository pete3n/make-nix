{ pkgs, ... }:
let
  # Custom Nix snowflake info tooltip script
  jq = pkgs.jq;
  nixVersions = pkgs.writeShellScriptBin "get-nix-versions" ''
        nixosVer=$(nixos-version)
        kernelVer=$(uname -r)
        nixVer=$(nix --version)
        ${jq}/bin/jq -c -n --arg nixos "NixOS: $nixosVer" \
    			--arg kernel "Linux Kernel: $kernelVer" \
    			--arg nix "$nixVer" \
    			'{"tooltip": "\($nixos)\r\($kernel)\r\($nix)"}'
  '';
in
{
  home.packages = [ pkgs.pavucontrol ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        start_hidden = true;
        height = 25;
        margin-left = 15;
        margin-right = 15;

        modules-left = [
          "custom/snowflake"
          "hyprland/workspaces"
        ];

        modules-center = [ "clock" ];

        modules-right = [
          "custom/wdisplays"
          "backlight"
          "pulseaudio"
          "battery"
        ];

        "custom/snowflake" = {
          exec = "${nixVersions}/bin/get-nix-versions";
          format = "❄️";
          return-type = "json";
          tooltip = false; # Disable tooltip
          on-click = "${pkgs.libnotify}/bin/notify-send 'Nix Info' \"$(${nixVersions}/bin/get-nix-versions | jq -r '.tooltip')\"";
        };

        "hyprland/workspaces" = {
          format = "{name} {icon}";
          tooltip = false;
          all-outputs = true;
          format-icons = {
            "active" = " ";
            "default" = " ";
          };
        };

        "custom/wdisplays" = {
          format = "{icon}";
          tooltip = false;
          format-icons = {
            default = [ "🖵 " ];
          };
          on-click = "wdisplays";
        };

        "backlight" = {
          device = "intel_backlight";
          format = "<span color='#5277c3'>{icon}</span> {percent}%";
          tooltip = false;
          format-icons = [
            ""
            ""
            ""
            ""
            ""
            ""
            ""
            ""
            ""
          ];
          scroll-step = 1;
        };

        "pulseaudio" = {
          format = "<span color='#5277c3'>{icon} </span> {volume}%";
          format-muted = "";
          tooltip = false;
          format-icons = {
            headphone = "";
            default = [
              ""
              ""
              "󰕾"
              "󰕾"
              "󰕾"
              ""
              ""
              ""
            ];
          };
          scroll-step = 1;
          on-click = "pavucontrol";
        };

        "battery" = {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon}  {capacity}%";
          format-charging = " ⚡{capacity}%";
          format-alt = "{time} {icon}";
          format-icons = [
            " "
            " "
            " "
            " "
            " "
          ];
        };
        "clock" = {
          format = "<span color='#7ebae4'>   </span>{:%H:%M}";
          format-alt = "{:%a, %d- %b %H:%M}";
        };
      };
    };

    style = # css
      ''
                * {    
                border: none;    
                border-radius: 0;    
                font-size: 14px;
                min-height: 25px;  
                }  
                window#waybar {    
                background: transparent;    
                }  
                #custom-snowflake {
                font-size: 20px;
                background: transparent;
                color: #5277c3;
                border-radius: 5px;
                padding-left: 10px;
                }
                #hyprland-workspaces {
                background-color: transparent;
                color: #5277c3;
                padding-right: 10px;
                }
                #workspaces button {    
                background: transparent;
                color: #5277c3;
                padding: 0 5px;  
                }
                #clock {
                background-color: transparent;
                color: #7ebae4;
                }
                #custom-wdisplays {
                background-color: transparent;
                color: #5277c3;
        				padding-top: 3px;
                padding-left: 15px;
                padding-right: 10px;
                }
                #backlight {
                background-color: transparent;
                color: #5277c3;
                padding-top: 2px;
                padding-bottom: 2px;
                padding-left: 10px;
                padding-right: 10px;
                }
                #pulseaudio {
                border-radius: 0px;
                background-color: transparent;
                color: #5277c3;
                padding-right: 10px;
                }
                #battery {
                border-radius: 0px;
                background-color: transparent;
                color: #5277c3;
                padding-right: 0px;
                }
      '';
  };
}
