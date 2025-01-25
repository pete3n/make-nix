{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.lazydocker;
  configFile = pkgs.writeText "lazydocker-config.yml" (
    builtins.toJSON {
      customCommands = {
        containers = map (cmd: {
          name = cmd.name;
          attach = cmd.attach or false;
          command = cmd.command;
          serviceNames = cmd.serviceNames or [ ];
          stream = cmd.stream or false;
          description = cmd.description or "";
        }) cfg.customCommands.containers;

        images = map (cmd: {
          name = cmd.name;
          attach = cmd.attach or false;
          command = cmd.command;
          serviceNames = cmd.serviceNames or [ ];
          stream = cmd.stream or false;
          description = cmd.description or "";
        }) cfg.customCommands.images;
      };
    }
  );
in
{
  options.programs.lazydocker = {
    enable = lib.mkEnableOption "lazydocker HM module";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lazydocker;
      description = "The lazydocker package to install.";
    };

    customCommands = {
      containers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "The name of the custom command.";
              };

              attach = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the command should attach to the container.";
              };

              command = lib.mkOption {
                type = lib.types.str;
                description = "The actual docker command to execute.";
              };

              serviceNames = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "List of service names this command applies to.";
              };

              stream = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the command should stream the output.";
              };

              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "A short description of the command.";
              };
            };
          }
        );
        default = [ ];
        description = "List of custom commands for containers.";
      };
      images = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "The name of the image command.";
              };

              attach = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the command should attach to the container.";
              };

              command = lib.mkOption {
                type = lib.types.str;
                description = "The actual docker command to execute.";
              };

              serviceNames = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "List of service names this command applies to.";
              };

              stream = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the command should stream the output.";
              };

              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "A short description of the command.";
              };
            };
          }
        );
        default = [ ];
        description = "List of custom commands for images.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".config/lazydocker/config.yml".source = configFile;
  };
}
