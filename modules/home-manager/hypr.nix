{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
{
  options.hypr-config = {
    enable = lib.mkEnableOption "enable hypr config";
    hyprland = {
      enable = lib.mkEnableOption "enable hyprland config";
      extraConfig = lib.mkOption {
        type = lib.types.str;
        default = '''';
        description = "additional config for hyprland, passed to wayland.windowManager.hyprland.extraConfig";
      };
      plugins = {
        hyprgrass.enable = lib.mkEnableOption "enable hyprgrass plugin for touch gestures";
      };
    };
    hypridle.enable = lib.mkEnableOption "enable hypridle config";
    hyprlock.enable = lib.mkEnableOption "enable hyprlock config";
  };

  config = lib.mkIf config.hypr-config.enable {

    home.packages = with pkgs; [
      slurp
      grim
      cliphist

      (rustPlatform.buildRustPackage rec {
        pname = "config-store";
        version = "1.0.0";

        src = pkgs.fetchFromGitHub {
          owner = "DOD-101";
          repo = pname;
          rev = "refs/tags/v${version}";
          sha256 = "sha256-dmFIB9tVI5/hnI+VKeawFzKi6UJrRis0tpeQE5a5dGU=";
        };

        cargoHash = "sha256-tEhk6vDan5uaP1vvKanB+juKsGJndrJPP67kudds24s=";

        meta = {
          description = "A simple key-value store designed to be used from shell scripts written in rust";
          homepage = "https://github.com/DOD-101/config-store";
          mainProgram = "config-store";
          license = with lib.licenses; [
            mit
            asl20
          ];
          maintainers = with lib.maintainers; [ dod-101 ];

          platforms = lib.platforms.linux;
        };
      })
    ];

    # hyprland
    wayland.windowManager.hyprland = lib.mkIf config.hypr-config.hyprland.enable {
      enable = true;
      systemd.enable = true;
      plugins =
        [ ]
        ++ lib.optionals config.hypr-config.hyprland.plugins.hyprgrass.enable [
          pkgs.hyprlandPlugins.hyprgrass
        ];

      # Some additional style related config is done through the selected theme
      settings = {
        source = [
          "${../../resources/hypr/hyprenv.conf}"
          "${../../resources/hypr/hyprgeneral.conf}"
          "${../../resources/hypr/hyprbinds.conf}"
        ];

        workspace = [
          "special:minimized"
        ];

        "$terminal" = config.term;
        # TODO: This asumes that wofi is installed and is the preferred "launch menu"
        "$menu" = "wofi --show drun -O alphabetical -a -i -I";
        "$mainMod" = "Super";
        # TODO: This doesn't work, nor does the rest of the disabling of the Touchpad
        "$touchpadEnabled" = "true";

        windowrulev2 = [
          "opacity 0.95 override 0.7 override,class:(${config.term})"
        ];

        exec-once =
          [ ]
          ++ lib.optionals osConfig.sound-config.enable [
            "pipewire"
            "pipewire-pulse"
          ]
          ++ lib.optionals osConfig.razer-config.enable [ "openrazer-daemon" ]
          ++ lib.optionals config.hypr-config.hypridle.enable [ "systemctl --user start hypridle.service" ];

        plugin = {
          touch_gestures = lib.mkIf config.hypr-config.hyprland.plugins.hyprgrass.enable {
            hyprgrass-bind = [
              # swipe left from right edge
              ", edge:r:l, workspace, +1"
              # swipe right from left edge
              ", edge:l:r, workspace, -1"
              # swipe up from bottom edge
              ", edge:d:u, killactive"
              # swipe down from left edge
              ", edge:l:d, exec, pactl set-sink-volume @DEFAULT_SINK@ -4%"
              # tap with 3 fingers
              ", tap:3, exec, ${config.term}"
              # tap with 4 fingers
              ", tap:4, exec, xournalpp"
            ];

            # longpress can trigger mouse binds:
            hyprgrass-bindm = [
              ", longpress:3, resizewindow"
              ", longpress:2, movewindow"
            ];
          };
        };
      };

      extraConfig = config.hypr-config.hyprland.extraConfig;
    };

    home.file.".config/hypr/scripts" = lib.mkIf config.hypr-config.hyprland.enable {
      source = ../../resources/hypr/scripts;
      recursive = true;
    };

    # hypridle
    services.hypridle = lib.mkIf config.hypr-config.hypridle.enable {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock"; # avoid starting multiple hyprlock instances.
          before_sleep_cmd = "loginctl lock-session"; # lock before suspend.
          after_sleep_cmd = "hyprctl dispatch dpms on"; # to avoid having to press a key twice to turn on the display.
        };

        listener = [
          {
            timeout = 600; # 10min
            on-timeout = "loginctl lock-session"; # lock screen when timeout has passed
          }
          {
            timeout = 330; # 5.5min
            on-timeout = "hyprctl dispatch dpms off"; # screen off when timeout has passed
            on-resume = "hyprctl dispatch dpms on"; # screen on when activity is detected after timeout has fired.
          }
          {
            timeout = 21600; # 6h
            on-timeout = "systemctl suspend"; # suspend pc
          }
        ];
      };
    };

    # hyprlock
    programs.hyprlock = lib.mkIf config.hypr-config.hyprlock.enable {
      enable = true;
      settings = {
        general = {
          ignore_empty_input = true;
        };

        background = [
          {
            blur_passes = 1;
            blur_size = 7;
            noise = 1.17e-2;
            contrast = 0.8916;
            brightness = 0.8172;
            vibrancy = 0.1696;
            vibrancy_darkness = 0.0;
            color = "rgba(${config.theme.hashlessColor.background}fe)";
          }
        ];

        image = [
          {
            path = builtins.toString ../../resources/hypr/hyprlock.png;
            size = "150";
            rounding = -1;
            border_size = 0;
            position = "0, 200";
            halign = "center";
            valign = "center";
          }
        ];

        input-field = [
          {
            size = "300, 40";
            position = "0, -20";
            monitor = "";
            outline_thickness = 1;
            dots_size = 0.33;
            dots_spacing = 0.15;
            dots_center = true;
            dots_rounding = -1;
            outer_color = "rgb(${config.theme.hashlessColor.yellow})";
            inner_color = "rgb(${config.theme.hashlessColor.background})";
            font_color = "rgb(${config.theme.hashlessColor.foreground})";
            fade_on_empty = false;
            fade_timeout = 1000;
            placeholder_text = ''<span foreground="##fef2d0">Input Password...</span>'';
            hide_input = false;
            rounding = -1;
            check_color = "rgb(${config.theme.hashlessColor.yellow})";
            fail_color = "rgb(${config.theme.hashlessColor.red})";
            fail_text = "$FAIL <b>($ATTEMPTS)</b>";
            fail_transition = 300;
            capslock_color = "rgb(${config.theme.hashlessColor.magenta})";
            numlock_color = "rgb(${config.theme.hashlessColor.cyan})";
            bothlock_color = -1;
          }
        ];

        label = [
          {
            text = "Hello There, $USER";
            color = "rgba(${config.theme.hashlessColor.white}ff)";
            font_size = 25;
            font_family = "FiraCode Nerd Font Mono";
            rotate = 0;
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
          {
            text = "$TIME";
            color = "rgba(${config.theme.hashlessColor.white}ff)";
            font_size = 20;
            font_family = "FiraCode Nerd Font Mono";
            position = "0, 50";
            halign = "center";
            valign = "bottom";
          }
        ];
      };
    };
  };
}
