{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    mpc # Media player daemon CLI interface
    playerctl
		picard # Fix metadata
  ];

  services.mpd = {
    enable = true;
    extraConfig = ''
      audio_output {
      	type            "pipewire"
      	name            "PipeWire Sound Server"
      }

      audio_output {
      	type						"fifo"
      	name						"ncmpcpp visualizer"
      	path						"${config.xdg.dataHome}/mpd/mpd.fifo"
      	format					"44100:16:1"
      }
    '';
  };

  services.mpdris2 = {
    enable = true;

    mpd = {
      # host = "127.0.0.1";
      # port = 6600;
    };
  };

  services.easyeffects = {
    enable = true;
  };

  programs.cava = {
    enable = true;
    settings = {
      general.framerate = 60;
      output = {
        channels = "mono";
      };
      color = {
        gradient = 1;

        gradient_color_1 = "'#1c2f5f'";
        gradient_color_2 = "'#253a73'";
        gradient_color_3 = "'#2e4587'";
        gradient_color_4 = "'#38509b'";
        gradient_color_5 = "'#415cad'";
        gradient_color_6 = "'#4a67be'";
        gradient_color_7 = "'#5071c6'";
        gradient_color_8 = "'#5277c3'";
        gradient_color_9 = "'#5c83cf'";
        gradient_color_10 = "'#668fd9'";
        gradient_color_11 = "'#709be3'";
        gradient_color_12 = "'#7aa7ec'";
        gradient_color_13 = "'#84b3f5'";
        gradient_color_14 = "'#8ebffd'";
        gradient_color_15 = "'#98caff'";
        gradient_color_16 = "'#a3d4ff'";
        gradient_color_17 = "'#afdfff'";
        gradient_color_18 = "'#bbe9ff'";
        gradient_color_19 = "'#c7f2ff'";
        gradient_color_20 = "'#d3fbff'";
      };
    };
  };

  programs.ncmpcpp = {
    enable = true;
    settings = {
      execute_on_song_change = ''notify-send "Now Playing" "$(mpc --format '%title% \n%artist%' current)"'';
      song_list_format = "{%g - }{%a - }{%t}|{$8%f$9}$R$3(%l)$9";
      song_library_format = "{%g - }{%a - }{%t}|{$8%f$9}$R$3(%l)$9";
      visualizer_data_source = "${config.xdg.dataHome}/mpd/mpd.fifo";
      visualizer_output_name = "mpd_fifo";
      visualizer_type = "ellipse";
      visualizer_in_stereo = "yes";
      visualizer_look = "+|";
      visualizer_color = "41, 83, 119, 155, 185, 215, 209, 203, 197, 161";
    };
    bindings = [
      {
        key = "j";
        command = "scroll_down";
      }
      {
        key = "k";
        command = "scroll_up";
      }
      {
        key = "h";
        command = "previous_column";
      }
      {
        key = "l";
        command = "next_column";
      }
      {
        key = "ctrl-d";
        command = "page_down";
      }
      {
        key = "ctrl-u";
        command = "page_up";
      }
      {
        key = "d";
        command = [
          "delete_playlist_items"
          "delete_browser_items"
          "delete_stored_playlist"
        ];
      }
      {
        key = "/";
        command = [
          "find"
          "find_item_forward"
        ];
      }
      {
        key = "n";
        command = "next_found_item";
      }
      {
        key = "N";
        command = "previous_found_item";
      }
      {
        key = "J";
        command = "move_sort_order_down";
      }
      {
        key = "K";
        command = "move_sort_order_up";
      }
      {
        key = "g";
        command = "move_home";
      }
      {
        key = "G";
        command = "move_end";
      }
    ];
  };

  programs.bash.initExtra = ''
        alias music_player=ncmpcpp
    		alias music_visualizer=cava
  '';
}
