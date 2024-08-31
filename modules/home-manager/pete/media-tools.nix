{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    #(blender.override {
    #  cudaSupport = true;
    #}) # 3D modelling
    ffmpeg # Video encoding/transcoding
    gimp # Image editing
    handbrake # DVD wripping
    helvum # Audio patch panel for pipewire
    mpc-cli # MPD CLI
    pavucontrol # Pulse audio volume control
    rhythmbox
    shotcut # Video editing
    vlc # Videolan client
    yt-dlp # Youtube download Python
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

  programs.cava = {
    enable = true;
    settings = {
      general.framerate = 60;
      output = {
        channels = "mono";
      };
      color = {
        gradient = 1;
        gradient_color_1 = "'#102698'";
        gradient_color_2 = "'#1b2e9e'";
        gradient_color_3 = "'#2536a4'";
        gradient_color_4 = "'#2d3faa'";
        gradient_color_5 = "'#3547b0'";
        gradient_color_6 = "'#3d4fb6'";
        gradient_color_7 = "'#4457bb'";
        gradient_color_8 = "'#4c60c1'";
        gradient_color_9 = "'#5368c6'";
        gradient_color_10 = "'#5b70cc'";
        gradient_color_11 = "'#6279d1'";
        gradient_color_12 = "'#6a81d6'";
        gradient_color_13 = "'#728adc'";
        gradient_color_14 = "'#7a92e1'";
        gradient_color_15 = "'#829be6'";
        gradeint_color_16 = "'#8aa3eb'";
        gradeint_color_17 = "'#93acf0'";
        gradeint_color_18 = "'#9bb5f5'";
        gradeint_color_19 = "'#a4bdfa'";
        gradeint_color_20 = "'#adc6ff'";
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
        command = ["find" "find_item_forward"];
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

  programs.bash.profileExtra = ''
       alias music_player=ncmpcpp
    alias music_visualizer=cava
  '';
}
