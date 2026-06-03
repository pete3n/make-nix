{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.pi-agent;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.pi-agent = {
    enable = lib.mkEnableOption "pi-agent coding assistant";

    package = lib.mkPackageOption pkgs "pi" {
      nullable = true;
      extraDescription = ''
        Set to a jailed wrapper derivation to run pi inside a bubblewrap sandbox.
      '';
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          defaultProvider = "anthropic";
          defaultModel = "claude-sonnet-4-20250514";
          defaultThinkingLevel = "medium";
          enableInstallTelemetry = false;
          quietStartup = true;
        }
      '';
      description = ''
        Global settings written to {file}`~/.pi/agent/settings.json`.
        See <https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/settings.md>
        for the full schema.
      '';
    };

    models = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          providers = {
            ollama = {
              baseUrl = "http://localhost:11434/v1";
              api = "openai-completions";
              apiKey = "ollama";
              models = [
                { id = "llama3.1:8b"; }
              ];
            };
          };
        }
      '';
      description = ''
        Custom model/provider definitions written to {file}`~/.pi/agent/models.json`.
        See <https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md>
        for the full schema.
      '';
    };

    context = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Global context instructions written to {file}`~/.pi/agent/AGENTS.md`.
        Pi loads this file at startup for all projects. Per-project instructions
        go in an {file}`AGENTS.md` in the project directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file = {
      ".pi/agent/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = jsonFormat.generate "pi-agent-settings" cfg.settings;
      };

      ".pi/agent/models.json" = lib.mkIf (cfg.models != { }) {
        source = jsonFormat.generate "pi-agent-models" cfg.models;
      };

      ".pi/agent/AGENTS.md" = lib.mkIf (cfg.context != "") {
        text = cfg.context;
      };
    };
  };
}
