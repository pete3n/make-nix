{ config, lib, ... }:

let
  cfg = config.programs.lazydocker;
in
{
  options.programs.lazydocker.customCommands = {
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
              description = "Attach to container.";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Docker command to run.";
            };
            serviceNames = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Applies to these services.";
            };
            stream = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Stream output.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Command description.";
            };
          };
        }
      );
      default = [ ];
      description = "Container commands.";
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
              description = "Attach to container.";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Docker command to run.";
            };
            serviceNames = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Applies to these services.";
            };
            stream = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Stream output.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Command description.";
            };
          };
        }
      );
      default = [ ];
      description = "Image commands.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lazydocker.settings = {
      customCommands = {
        containers = map (cmd: {
          inherit (cmd) name command;
          attach = cmd.attach or false;
          serviceNames = cmd.serviceNames or [ ];
          stream = cmd.stream or false;
          description = cmd.description or "";
        }) cfg.customCommands.containers;

        images = map (cmd: {
          inherit (cmd) name command;
          attach = cmd.attach or false;
          serviceNames = cmd.serviceNames or [ ];
          stream = cmd.stream or false;
          description = cmd.description or "";
        }) cfg.customCommands.images;
      };
    };
  };
}
