{ config, lib, pkgs, ... }:

let
  cfg = config.programs.tmuxai;
  yamlFormat = pkgs.formats.yaml { };

  # Model submodule covering all supported providers.
  # Provider-specific fields (api_base, region, etc.) default to null
  # and are omitted from the generated config when unset.
  modelSubmodule = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.enum [
          "openrouter"
          "openai"
          "azure"
          "gemini"
          "github-copilot"
          "bedrock"
        ];
        description = ''
          AI provider. Use "openrouter" for local Ollama (set base_url to
          http://localhost:11434/v1). Supports environment variable expansion
          in string values, e.g. api_key = "''${TMUXAI_API_KEY}".
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        description = "Model identifier string for the provider.";
        example = "qwen2.5-coder:7b";
      };

      api_key = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          API key. Not required for github-copilot or bedrock.
          For local Ollama any non-empty placeholder is sufficient.
          Use environment variable expansion for secrets:
          api_key = "''${TMUXAI_KEY}".
        '';
        example = "\${OPENROUTER_API_KEY}";
      };

      base_url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Custom API base URL. Required for local Ollama.";
        example = "http://localhost:11434/v1";
      };

      # Azure-specific
      api_base = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Azure OpenAI resource base URL.";
        example = "https://your-resource.openai.azure.com/";
      };

      api_version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Azure API version string.";
        example = "2025-04-01-preview";
      };

      deployment_name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Azure deployment name.";
      };

      region = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "AWS region for Bedrock. Falls back to AWS_REGION env var.";
        example = "us-east-1";
      };

      aws_profile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Named AWS credentials profile for Bedrock.";
        example = "default";
      };
    };
  };

  # Serialise a model attrset, dropping unset (null) optional fields.
  modelToAttrs = model: lib.filterAttrs (_: val: val != null) {
    inherit (model)
      provider model api_key
      base_url
      api_base api_version deployment_name
      region aws_profile;
  };

in
{
  options.programs.tmuxai = {
    enable = lib.mkEnableOption "tmuxai AI terminal assistant";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The tmuxai package to install.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Name of the model configuration to use by default.
        If null, tmuxai selects the first model alphabetically.
      '';
      example = "local";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf modelSubmodule;
      default = { };
      description = "Named model configurations. At least one must be defined.";
      example = lib.literalExpression ''
        {
          local = {
            provider = "openrouter";
            model    = "qwen2.5-coder:7b";
            api_key  = "ollama";
            base_url = "http://localhost:11434/v1";
          };
        }
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Log full AI messages sent and received to ~/.config/tmuxai/debug/.";
    };

    yolo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Skip all confirmation prompts. Use with caution.";
    };

    maxContextSize = lib.mkOption {
      type = lib.types.int;
      default = 100000;
      description = "Maximum context size in tokens. Reaching 80% triggers automatic squashing.";
    };

    maxCaptureLines = lib.mkOption {
      type = lib.types.int;
      default = 200;
      description = "Maximum lines captured from each pane per AI request.";
    };

    waitInterval = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds to wait after command execution before re-capturing pane output.";
    };

    execConfirm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require confirmation before executing AI-suggested commands.";
    };

    sendKeysConfirm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require confirmation before AI sends keypresses.";
    };

    pasteMultilineConfirm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require confirmation before AI pastes multiline content.";
    };

    whitelistPatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns matching commands that skip the confirmation prompt.";
      example = [ "^ls(\\s+.*)?$" "^pwd\\s*$" "^cat(\\s+.*)?$" ];
    };

    blacklistPatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns matching commands that always show the confirmation prompt.";
      example = [ "rm\\s+" "mv\\s+" "dd\\s+" ];
    };

    statusLine = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Custom status line format string. Available placeholders:
        {app}, {context}, {context_used}, {context_max},
        {model}, {state}, {state_badge}, {model_changed}.
        If null, uses the tmuxai default ("TmuxAI » ").
      '';
      example = "{app} ({context}) - {model} >> ";
    };

    execSplitArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "-d" "-h" ];
      description = ''
        Raw arguments passed to `tmux split-window` when creating the exec pane.
        Flags -t, -P, and -F are managed internally and must not be included.
      '';
      example = [ "-d" "-v" "-p" "70" ];
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Arbitrary settings merged into ~/.config/tmuxai/config.yaml after the
        module's explicit options. Values here override any explicitly configured
        option of the same name. Use for features not covered by the module's
        options: knowledge_base, web_search, web_fetch, prompts, etc.
      '';
      example = lib.literalExpression ''
        {
          knowledge_base = {
            auto_load = [ "nix-workflows" ];
            skills = {
              enabled        = true;
              auto_match     = true;
            };
          };
          web_search = {
            enabled          = true;
            default_provider = "searxng";
            providers.searxng.base_url = "http://localhost:8888";
          };
        }
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.nullOr yamlFormat.type;
      default = null;
      description = ''
        MCP server configurations written to ~/.config/tmuxai/mcp.json.
        Keys are server names; values follow the tmuxai mcp.json schema.
      '';
      example = lib.literalExpression ''
        {
          context7 = {
            command = "npx";
            args    = [ "-y" "@upstash/context7-mcp@latest" ];
          };
          local-tools = {
            type = "streamable-http";
            url  = "http://localhost:3050/mcp";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.models != { };
        message   = "programs.tmuxai: at least one model must be defined in programs.tmuxai.models.";
      }
    ];

    home.packages = [ cfg.package ];

    xdg.configFile."tmuxai/config.yaml".source =
      let
        explicitSettings =
          {
            debug             = cfg.debug;
            yolo              = cfg.yolo;
            max_context_size  = cfg.maxContextSize;
            max_capture_lines = cfg.maxCaptureLines;
            wait_interval     = cfg.waitInterval;
            exec_confirm      = cfg.execConfirm;
            send_keys_confirm = cfg.sendKeysConfirm;
            paste_multiline_confirm = cfg.pasteMultilineConfirm;
            tmux.exec_split_args = cfg.execSplitArgs;
            models = lib.mapAttrs (_: modelToAttrs) cfg.models;
          }
          // lib.optionalAttrs (cfg.defaultModel != null) {
            default_model = cfg.defaultModel;
          }
          // lib.optionalAttrs (cfg.statusLine != null) {
            status_line = cfg.statusLine;
          }
          // lib.optionalAttrs (cfg.whitelistPatterns != [ ]) {
            whitelist_patterns = cfg.whitelistPatterns;
          }
          // lib.optionalAttrs (cfg.blacklistPatterns != [ ]) {
            blacklist_patterns = cfg.blacklistPatterns;
          };
      in
      yamlFormat.generate "tmuxai-config.yaml"
        (lib.recursiveUpdate explicitSettings cfg.settings);

    xdg.configFile."tmuxai/mcp.json" = lib.mkIf (cfg.mcpServers != null) {
      text = builtins.toJSON { mcpServers = cfg.mcpServers; };
    };
  };
}
