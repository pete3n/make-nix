{ pkgs, lib, ... }:
let
  # Custom Nix snowflake info tooltip script
  nixVersions = pkgs.writeShellScript "get-nix-versions" ''
    #!/bin/sh
	nixosVer=$(nixos-version)
	kernelVer=$(uname -r)
	nixVer=$(nix --version)
	echo "{\"tooltip\": \"NixOS: $nixosVer\nLinux Kernel: $kernelVer\n$nixVer\"}"
  '';
in
{
  programs.waybar = {
    enable = true;
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
	
	modules-center = [
	  "clock"
	];

	modules-right = [ 
	  "custom/wdisplays"
	  "backlight"
	  "pulseaudio"
	  "battery" 
	];    
	"custom/snowflake" = {
	  format = "{icon}";
	  tooltip-format = "{tooltip}";
    	  exec = "${nixVersions}";
	  return-type = "json";
	  format-icons = { default = "❄️"; };
	  tooltip = true;
	};
	  
	"hyprland/workspaces" = {
	  format = "{name} {icon}";
	  tooltip = false;
	  all-outputs = true;
	  format-icons = {
	    "active" = "";
	    "default" = "";
	  };
	};

	"custom/wdisplays" = {
	  format = "{icon}";
	  tooltip = false;
	  format-icons = {
	    default = [ "🖥️"];
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

    style = ''  
      * {    
          border: none;    
	  border-radius: 0;    
	  font-size: 14px;
	  min-height: 25px;
      }  

      window#waybar {    
	background: transparent;    
      }  

      #snowflake {
	background: transparent;
     	color: #5277c3;
	border-radius: 5px;
	padding-left: 10px;
      }

      #workspaces {
        border-radius: 10px;
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
	border-radius: 10px;
	background-color: transparent;
	color: #7ebae4;
      }

      #backlight, #wdisplays {
	border-radius: 10px;
	background-color: transparent;
	color: #5277c3;
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
