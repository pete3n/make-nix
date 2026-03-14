{
  config,
  lib,
  hasCuda,
  makeNixAttrs,
  makeNixLib,
  pkgs,
  ...
}:
let
  hasLocalAi = makeNixLib.hasTag "local-ai" (makeNixAttrs.tags or [ ]);
  piperModel = "${config.home.homeDirectory}/.local/share/piper/en_US-amy-medium.onnx";
  whisperModel = "${config.home.homeDirectory}/.local/share/whisper/ggml-medium.en.bin";
  whisperPackage =
    if hasCuda then
      pkgs.whisper-cpp.override {
        cudaSupport = true;
        cudaPackages = pkgs.cudaPackages;
      }
    else
      pkgs.whisper-cpp;

  aichatWrapper =
    pkgs.writeShellScriptBin "aichat-ctx" # sh
      ''
        set -u

        NIX_GREP="${pkgs.gnugrep}/bin/grep"
        NIX_AICHAT="${pkgs.aichat}/bin/aichat"

        AICHAT_SESSIONS_DIR="''${AICHAT_SESSIONS_DIR:-''${HOME}/.config/aichat/sessions}"
        WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}"
        DISPLAY="''${DISPLAY:-}"
        TMUX="''${TMUX:-}"
        TERM_PROGRAM="''${TERM_PROGRAM:-}"

        if [ ! -d "''${AICHAT_SESSIONS_DIR}" ]; then
        	mkdir -p "''${AICHAT_SESSIONS_DIR}" >&2
        fi

        _session_prefix="''${1:-nix_env}"
        shift

        _session_date="$(date +%Y-%m-%d)"
        _session_name="''${_session_prefix}-''${_session_date}"
        _session_file="''${AICHAT_SESSIONS_DIR}/''${_session_name}.yaml"

        # --session-ctx <file> is only passed once as --file to aichat when a 
        # new session is created. Regular --file args always pass through.
        _ctx_files=""
        _pass_args=""
        _skip_next=0

        for _arg in "$@"; do
        	if [ "''${_skip_next}" = "1" ]; then
        		_ctx_files="''${_ctx_files:+''${_ctx_files}\n}''${_arg}"
        		_skip_next=0
        		continue
        	fi
        	case "''${_arg}" in
        		--session-ctx)
        		_skip_next=1
        		;;
        		--session-ctx=*)
        		_ctx_files="''${_ctx_files:+''${_ctx_files}\n}''${_arg#--session-ctx=}"
        		;;
        		*)
        		_pass_args="''${_pass_args:+''${_pass_args}\n}''${_arg}"
        		;;
        	esac
        done

        _is_new_session=0
        [ ! -f "''${_session_file}" ] && _is_new_session=1

        if [ "''${_is_new_session}" = "1" ]; then
        	os_info=""
        	hyprland_info=""

        	if [ "$(uname -s)" = "Darwin" ]; then
        		os_info="$(sw_vers | tr '\n' ' ')"
        	else
        		os_info="$("$NIX_GREP" ^PRETTY_NAME /etc/os-release | cut -d= -f2)"
        	fi

        	if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        		hyprland_info="$(hyprctl version)"
        	else
        		hyprland_info="not running"
        	fi

        	_context="$(printf "Kernel: %s\nOS: %s\nShell: %s\nTerminal: %s\nCompositor: %s / %s\nTmux: %s\nHyprland: %s\nNix: %s\n" \
        	"$(uname -a)" \
        	"''${os_info}" \
        	"''${SHELL}" \
        	"''${TERM_PROGRAM:-unknown}" \
        	"''${WAYLAND_DISPLAY:-none}" \
        	"''${DISPLAY:-none}" \
        	"''${TMUX:+yes}" \
        	"''${hyprland_info}" \
        	"$(nix --version)")"
        fi

        _cmd=("$NIX_AICHAT" --session "''${_session_name}")

        if [ "''${_is_new_session}" = "1" ]; then
        	_cmd+=(--prompt "System context: \n''${_context}")

        	# Expand --session-ctx files as --file only for new sessions
        	if [ -n "''${_ctx_files:-}" ]; then
        		while IFS= read -r _ctx_file; do
        			[ -n "''${_ctx_file}" ] && _cmd+=(--file "''${_ctx_file}")
        		done < <(printf '%b\n' "''${_ctx_files}")
        	fi
        fi

        # Pass remaining args through always
        if [ -n "''${_pass_args:-}" ]; then
        while IFS= read -r _pass_arg; do
        [ -n "''${_pass_arg}" ] && _cmd+=("''${_pass_arg}")
        done < <(printf '%b\n' "''${_pass_args}")
        fi

        exec "''${_cmd[@]}"
      '';

  aichatPreview =
    pkgs.writeShellScriptBin "aichat-preview" # sh
      ''
        set -u

        NIX_BAT="${pkgs.bat}/bin/bat"
        NIX_GLOW="${pkgs.glow}/bin/glow"
        NIX_SED="${pkgs.gnused}/bin/sed"

        _file="''${1:-}"
        _line="''${2:-1}"

        if [ -z "''${_file}" ]; then
          printf "Usage: aichat-preview <file> <line>\n" >&2
          exit 1
        fi

        _start=$(( _line > 10 ? _line - 10 : 1 ))
        _end=$(( _line + 20 ))

        # Extract line range, unescape YAML literal \n and \t sequences,
        # then render as Markdown with glow
        "$NIX_BAT" \
          --style=plain \
          --color=never \
          --line-range "''${_start}:''${_end}" \
          "''${_file}" \
          | "$NIX_SED" 's/\\n/\n/g; s/\\t/\t/g' \
          | "$NIX_GLOW" --style=dark -
      '';

  aichatSearch =
    pkgs.writeShellScriptBin "aichat-search" # sh
      ''
        set -u

        NIX_RG="${pkgs.ripgrep}/bin/rg"
        NIX_FZF="${pkgs.fzf}/bin/fzf"
        NIX_BAT="${pkgs.bat}/bin/bat"
        NIX_PREVIEW="${aichatPreview}/bin/aichat-preview"
        NIX_GLOW="${pkgs.glow}/bin/glow"
        NIX_SED="${pkgs.gnused}/bin/sed"

        AICHAT_SESSIONS_DIR="''${AICHAT_SESSIONS_DIR:-''${HOME}/.config/aichat/sessions}"

        use_tmux=0
        query=""

        for _arg in "$@"; do
        	case "''${_arg}" in
        		-t) use_tmux=1 ;;
        		*)  query="''${query}''${query:+ }''${_arg}" ;;
        	esac
        done

        if [ ! -d "''${AICHAT_SESSIONS_DIR}" ]; then
        	printf "Sessions directory not found: %s\n" "''${AICHAT_SESSIONS_DIR}" >&2
        	exit 1
        fi

        _result="$(
        "$NIX_RG" \
        --glob '*.yaml' \
        --line-number \
        --no-heading \
        --color=never \
        --smart-case \
        "''${query:-}" \
        | "$NIX_FZF" \
        --delimiter ':' \
        --nth '3..' \
        --with-nth '1,3..' \
        --query "''${query:-}" \
        --preview "''${NIX_PREVIEW} {1} {2}" \
        --preview-window 'right:60%:wrap' \
        --bind 'ctrl-/:toggle-preview' \
        --prompt 'aichat> ' \
        --header 'ENTER: open  CTRL-/: toggle preview'
        )"

        [ -z "''${_result:-}" ] && exit 0

        _file="$(printf '%s' "''${_result}" | cut -d':' -f1)"
        _line="$(printf '%s' "''${_result}" | cut -d':' -f2)"

        if [ -z "''${_file:-}" ] || [ -z "''${_line:-}" ]; then
        	printf "Could not parse selection: %s\n" "''${_result}" >&2
        	exit 1
        fi

        if [ "''${use_tmux}" = "1" ] && [ -n "''${TMUX:-}" ]; then
        	tmux split-window -h \
        	"$NIX_BAT --style=plain --color=never --paging=never "''${_file}" \
        	| "$NIX_SED" 's/\\\\n/\\n/g; s/\\\\t/\\t/g' \
        	| "$NIX_GLOW" --style=dark --pager -"
        else
        	"$NIX_BAT" --style=plain --color=never --paging=never "''${_file}" \
        	| "$NIX_SED" 's/\\n/\n/g; s/\\t/\t/g' \
        	| "$NIX_GLOW" --style=dark --pager -
        fi
      '';

  aiSpeak =
    pkgs.writeShellScriptBin "ai-speak" # sh
      ''
        set -u

        NIX_PIPER="${pkgs.piper-tts}/bin/piper"
        NIX_PAPLAY="${pkgs.pulseaudio}/bin/paplay"

        PIPER_MODEL="''${PIPER_MODEL:-${piperModel}}"

        if [ "$#" -gt 0 ]; then
          printf '%s' "$*"
        else
          cat
        fi \
          | "$NIX_PIPER" --model "''${PIPER_MODEL}" --output-raw \
          | "$NIX_PAPLAY" --raw --rate=22050 --format=s16le --channels=1
      '';

  aiRead =
    pkgs.writeShellScriptBin "ai-read" # sh
      ''
        set -u

        NIX_PIPER="${pkgs.piper-tts}/bin/piper"
        NIX_PAPLAY="${pkgs.pulseaudio}/bin/paplay"
        NIX_FILE="${pkgs.file}/bin/file"
        NIX_AWK="${pkgs.gawk}/bin/awk"

        PIPER_MODEL="''${PIPER_MODEL:-${piperModel}}"

        _file="''${1:-}"
        _offset="''${2:-0}"
        _text_tmp=$(mktemp /tmp/piper-text-XXXXXX.txt)

        cleanup() {
        	if [ -f "$_text_tmp" ]; then
        		rm "$_text_tmp"
        	fi
        }
        trap cleanup EXIT INT TERM

        if [ -z "''${_file}" ]; then
        	printf "Usage: ai-read <file> [offset%%]\n" >&2
        	rm -f "''${_text_tmp}"
        	exit 1
        fi

        if [ ! -f "''${_file}" ]; then
        	printf "ai-read: file not found: %s\n" "''${_file}" >&2
        	rm -f "''${_text_tmp}"
        	exit 1
        fi

        if [ "''${_offset}" -lt 0 ] || [ "''${_offset}" -gt 99 ]; then
        	printf "ai-read: offset must be between 0 and 99\n" >&2
        	rm -f "''${_text_tmp}"
        	exit 1
        fi

        _mime="$("$NIX_FILE" --mime-type -b "''${_file}")"

        case "''${_mime}" in
        	application/pdf)
        		${pkgs.poppler-utils}/bin/pdftotext "''${_file}" - > "''${_text_tmp}"
        		;;
        	application/vnd.openxmlformats-officedocument.wordprocessingml.document|\
        	application/msword)
        		${pkgs.pandoc}/bin/pandoc --to plain "''${_file}" > "''${_text_tmp}"
        		;;
        	text/*)
        		cat "''${_file}" > "''${_text_tmp}"
        		;;
        	*)
        		printf "ai-read: unsupported mime type: %s\n" "''${_mime}" >&2
        		rm -f "''${_text_tmp}"
        		exit 1
        		;;
        esac

        _total=$(wc -c < "''${_text_tmp}")
        _skip_bytes=$(( _total * _offset / 100 ))

        # Advance to next word boundary to avoid reading mid-word
        _start=$(
        	"$NIX_AWK" \
        		-v skip="''${_skip_bytes}" \
        		'BEGIN { bytes=0 }
        		{
        			line_len = length($0) + 1
        			if (bytes + line_len > skip) {
        				# Find next space after offset within this line
        				char_pos = skip - bytes
        				space_pos = index(substr($0, char_pos), " ")
        				if (space_pos > 0) {
        					print substr($0, char_pos + space_pos)
        				} else {
        					print $0
        				}
        				found = 1
        			} else {
        				bytes += line_len
        			}
        			if (found) { print; next }
        		}' \
        		"''${_text_tmp}"
        )

        rm -f "''${_text_tmp}"

        printf '%s' "''${_start}" \
        	| "$NIX_PIPER" --model "''${PIPER_MODEL}" --output-raw \
        	| "$NIX_PAPLAY" --raw --rate=22050 --format=s16le --channels=1
      '';

  aiTranscribe =
    pkgs.writeShellScriptBin "ai-transcribe" # sh
      ''
        	set -u

        	NIX_WHISPER="$(command -v whisper-cli)"
        	WHISPER_MODEL="''${WHISPER_MODEL:-${whisperModel}}"

        	_file=""
        	_output=""
        	_language="en"
        	_translate=0
        	_passthrough_args=""

        	cleanup() {
        		rm -f "''${_text_tmp:-}"
        	}
        	trap cleanup EXIT INT TERM

        	_parse_args() {
        		while [ "$#" -gt 0 ]; do
        			case "''${1}" in
        				-o)
        					shift
        					_output="''${1:-}"
        					;;
        				-o*)
        					_output="''${1#-o}"
        					;;
        				-l)
        					shift
        					_language="''${1:-en}"
        					;;
        				-l*)
        					_language="''${1#-l}"
        					;;
        				-t)
        					_translate=1
        					;;
        				-*)
        					_passthrough_args="''${_passthrough_args:+''${_passthrough_args}\n}''${1}"
        					;;
        				*)
        					if [ -z "''${_file}" ]; then
        						_file="''${1}"
        					else
        						printf "ai-transcribe: unexpected argument: %s\n" "''${1}" >&2
        						exit 1
        					fi
        					;;
        			esac
        			shift
        		done
        	}

        	_parse_args "$@"

        	if [ -z "''${_file}" ]; then
        		printf "Usage: ai-transcribe [options] <file>\n" >&2
        		printf "  -o <path>   output file path (without extension)\n" >&2
        		printf "  -oj         output JSON\n" >&2
        		printf "  -otxt       output text file\n" >&2
        		printf "  -l <lang>   language code (default: en, 'auto' to detect)\n" >&2
        		printf "  -t          translate to english\n" >&2
        		exit 1
        	fi

        	if [ ! -f "''${_file}" ]; then
        		printf "ai-transcribe: file not found: %s\n" "''${_file}" >&2
        		exit 1
        	fi

        	_cmd=("$NIX_WHISPER"
        		--model "''${WHISPER_MODEL}"
        		--language "''${_language}"
        		--no-prints
        		--no-timestamps
        	)

        	if [ "''${_translate}" = "1" ]; then
        		_cmd+=(--translate)
        	fi

        	if [ -n "''${_output}" ]; then
        		_cmd+=(--output-file "''${_output}")
        	fi

        	if [ -n "''${_passthrough_args:-}" ]; then
        		while IFS= read -r _arg; do
        			[ -n "''${_arg}" ] && _cmd+=("''${_arg}")
        		done < <(printf '%b\n' "''${_passthrough_args}")
        	fi

        	_cmd+=(--file "''${_file}")

        	if [ -z "''${_output}" ]; then
        		"''${_cmd[@]}"
        	else
        		"''${_cmd[@]}" >/dev/null
        	fi
      '';

  # Local AI client config - only included when local-ai tag is present
  ollamaClient = {
    name = "ollama";
    type = "openai-compatible";
    api_base = "http://localhost:11434/v1";
    models = [
      { name = "qwen3.5:9b"; }
      { name = "qwen3-coder:latest"; }
      { name = "jaahas/qwen3.5-uncensored:latest"; }
      {
        name = "nomic-embed-text";
        type = "embedding";
      }
    ];
  };

  # Document loaders for RAG binary format support
  documentLoaders = {
    pdf = "${pkgs.poppler-utils}/bin/pdftotext $1 -";
    docx = "${pkgs.pandoc}/bin/pandoc --to plain $1";
  };
in
{
  programs.aichat = {
    enable = true;
    settings = {
      model = "claude:claude-sonnet-4-6";
      save_session = true;
      clients = [
        {
          type = "claude";
        }
      ]
      ++ lib.optional hasLocalAi ollamaClient;
      document_loaders = lib.mkIf hasLocalAi documentLoaders;
      rag_embedding_model = lib.mkIf hasLocalAi "ollama:nomic-embed-text";
    };
  };

  # Sync model list for updates if a configured model is missing
  home.activation = {
    aichatDirs =
      lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
        ''
          _rags_dir="${config.home.homeDirectory}/.config/aichat/rags"
          _macros_dir="${config.home.homeDirectory}/.config/aichat/macros"
          _functions_dir="${config.home.homeDirectory}/.config/aichat/functions"

          for _dir in "$_rags_dir" "$_macros_dir" "$_functions_dir"; do
            if [ ! -d "$_dir" ]; then
              printf "aichat: creating directory %s\n" "$_dir"
              mkdir -p "$_dir"
            fi
          done
        '';
    aichatSyncModels = lib.mkIf hasLocalAi (
      lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
        ''
          _aichat="${pkgs.aichat}/bin/aichat"
          _model="${config.programs.aichat.settings.model}"

          if ! "$_aichat" --list-models 2>/dev/null | grep -qF "''${_model}"; then
          printf "aichat: model %s not found in local model list, syncing..." "''${_model}"
          "$_aichat" --sync-models || true
          fi
        ''
    );
    aiTtsModel = lib.mkIf hasLocalAi (

      lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
        ''
          _model_dir="${config.home.homeDirectory}/.local/share/piper"
          _model_onnx="''${_model_dir}/en_US-amy-medium.onnx"
          _model_json="''${_model_dir}/en_US-amy-medium.onnx.json"
          _base_url="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium"

          if [ ! -f "''${_model_onnx}" ]; then
            printf "piper: downloading en_US-amy-medium model...\n"
            mkdir -p "''${_model_dir}"
            ${pkgs.curl}/bin/curl -fsSL -o "''${_model_onnx}" "''${_base_url}/en_US-amy-medium.onnx"
            ${pkgs.curl}/bin/curl -fsSL -o "''${_model_json}" "''${_base_url}/en_US-amy-medium.onnx.json"
          fi
        ''
    );
    aiTranscribeModel = lib.mkIf hasLocalAi (
      lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
        ''
          _model_dir="${config.home.homeDirectory}/.local/share/whisper"
          _model_file="''${_model_dir}/ggml-medium.en.bin"
          _url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"

          if [ ! -f "''${_model_file}" ]; then
            printf "whisper: downloading ggml-medium.en model (1.5GB)...\n"
            mkdir -p "''${_model_dir}"
            ${pkgs.curl}/bin/curl -fsSL --progress-bar -o "''${_model_file}" "''${_url}"
          fi
        ''
    );
  };

  home.file.".config/aichat/roles/local-env.md".text = # markdown
    ''
      ---
      ---
      You are a helpful local assistant. You run entirely on the user's machine
      with no data leaving the system. If provided, System context: will contain
      useful details about the current environment.

      You are most likely operating inside the Alacritty terminal emulator on
      systems running NixOS, Nix-Darwin, or other Linux distributions using Nix Home
      Manager. Sessions may run inside Tmux, within a Wayland/Hyprland graphical
      environment on Linux, or on macOS with Nix-Darwin. If provided, System context:
      will contain useful details about the current system environment.

      You are an expert in GNU core utilities, Nix and Home Manager, Bash and POSIX
      shell scripting, and Linux networking. Where applicable, prefer declarative
      Nix/Home Manager solutions over imperative approaches.

      When providing solutions, start with a single clear path rather than presenting
      multiple options upfront. If further steps are needed, preview the next step or
      provide a brief summary of the plan. When a decision point requires branching,
      ask the user which path to take and include your recommended option.

      Responses should facilitate learning — accompany solutions with explanations of
      why they work, not just what to run.
    '';

  home.file.".config/aichat/roles/nix-env.md".text = # markdown
    ''
      ---
      ---
      You are a helpful assistant operating inside the Alacritty terminal emulator on
      systems running NixOS, Nix-Darwin, or other Linux distributions using Nix Home
      Manager. Sessions may run inside Tmux, within a Wayland/Hyprland graphical
      environment on Linux, or on macOS with Nix-Darwin. If provided, System context:
      will contain useful details about the current system environment.

      You are an expert in GNU core utilities, Nix and Home Manager, Bash and POSIX
      shell scripting, and Linux networking. Where applicable, prefer declarative
      Nix/Home Manager solutions over imperative approaches.

      When providing solutions, start with a single clear path rather than presenting
      multiple options upfront. If further steps are needed, preview the next step or
      provide a brief summary of the plan. When a decision point requires branching,
      ask the user which path to take and include your recommended option.

      Responses should facilitate learning — accompany solutions with explanations of
      why they work, not just what to run.
    '';

  home.file.".config/aichat/contexts/make-nix.md".text = # markdown
    ''
      # make-nix Project Context

      This project manages Nix configurations for NixOS, Nix-Darwin, and Nix Home Manager
      across multiple systems. Configurations are declarative and version controlled in a
      public GitHub repository.

      ## Nix Injected Shell Script Instructions

      ### Escape Variable References
      All shell variable references inside Nix multiline strings (''' ... ''') 
      MUST be escaped with '''''${var} and not referenced with ''${var}.

      ### Language Hint
      Always include a luals language hint comment between the function call and the opening
      quotes. Format as:
      pkgs.writeShellScriptBin "name" # sh\n\t'''\n\t\t...\n\t''';
      Rule: comment on same line as function call, opening ''' on next line with one tab
      indent, script body indented one additional tab, closing ''' at one tab indent.

      ### POSIX and Bash shell usage
      Shell scripts should attempt to maintain POSIX compliance, but with using
      Nix library functions such as writeShellScriptBin using Bash only features is
      permissable since nixpkgs will provide an appropriate shell.

      ### Package References
      Any binary not part of pkgs.coreutils should be referenced from nixpkgs:
      grep -> ''${pkgs.gnugrep}/bin/grep
      - Single use: inline directly: ''${pkgs.gnugrep}/bin/grep
      - Two or more uses: define NIX_BINARY variable near top of script

      Exceptions:
      - Binaries that are the subject of an intentional command -v availability check
      must not be referenced via nixpkgs.
      - Exclude binaries that are implicit dependencies of the Nix build environment
      or are themselves Nix management tools (e.g. nix, nixos-rebuild, home-manager).

      ### Heredoc Restriction
      Heredoc syntax (<<EOF ... EOF) must not be used in Nix injected shell strings.
      The heredoc delimiter conflicts with Nix multiline string parsing, causing
      interpolation errors and breaking LSP highlighting from the heredoc onward.

      Rule: Use printf with format strings as the replacement for heredocs:
      output=$(printf "%s\n%s\n" \
      "'''''${var_one}" \
      "'''''${var_two}")

      ### Nix Multiline String Quote Escaping
      To output literal ''' in a Nix multiline string (.text = ''' ... '''):
      - Use 5x single quotes when the ''' must precede a dollar sign to also
      prevent interpolation, producing literal ''${
      - Use 3x single quotes in all other contexts where a literal ''' is needed.
      Note: These rules cannot be demonstrated with literal examples inside a Nix
      multiline string without triggering the very escaping they describe.

      ## Shell Script Conventions

      ### POSIX Compliance
      Unless otherwise specified by context, all scripts should be POSIX compliant.

      ### Defensive Programming
      Default header for all injected shell scripts:
      set -u
      - Do not use set -e or pipefail.
      - Initialize all internal global variables near the top of the script (var="").
      - Use ''${var:-} or ''${var:-default} for optional or externally sourced variables.
      - ALWAYS use double-quotes around variables to prevent globbing: "''${var:-}"
      - Use explicit || error handling where pipeline or command failures need handling.

      ### Variable Scopes
      1. External (environment or Nix interpolation):
      - Format: ALL_CAPS_SNAKE_CASE
      - Declare near top of script
      - Example: WAYLAND_DISPLAY, NIX_BINARY

      2. Internal global (script-wide scope):
      - Format: lower_snake_case
      - Declare near top, initialize as var="" if no immediate value
      - Example: os_info="", hyprland_info=""

      3. Local (function-scoped or loop iterators):
      - Format: _lower_snake_case (leading underscore)
      - Declare in place, use descriptive names over single letters
      - Example: _index=1, _line=""

      ### Formatting
      - All variable references use ''${var} syntax rather than $var.
      - In Nix injected shell strings, runtime variables must be escaped as ''${var}.
      - Nix build-time interpolations use normal ''${} syntax without escaping.

      ### Printf preference
      - Use printf instead of echo unless there is an explicit reason for using echo.

      ### Regex Usage
      Avoid regex where simpler string matching or existing tools suffice.
      When regex is necessary, assign the pattern to a descriptively named
      variable near its point of use and add a comment explaining the pattern.
      Example:
      _client_regex="^(firefox|org\.mozilla\.firefox)$"
      \# Matches Firefox by class name or bundle identifier

      # Final Check
      Double check if you are using scripting code inside Nix. Failure to escape
      shell variables inside Nix is a common mistake.
      ''${pkgs.foo} is intentional Nix interpolation, while every other ''${...} 
      in the script body is a shell variable that must be escaped.
    '';

  home.packages = [
    aichatSearch
    aichatWrapper
  ]
  ++ lib.optionals hasLocalAi [
    pkgs.poppler-utils # pdftotext for PDF RAG loading
    pkgs.pandoc
    # docx/doc RAG loading
    pkgs.pulseaudio # For paplay tts
    pkgs.piper-tts # tts
    whisperPackage # Whisper CPP conditionally built with CUDA support
    aiRead
    aiSpeak
    aiTranscribe
  ];

  programs.bash = {
    shellAliases = {
      "??" = "aichat-ctx nix_env --role nix-env";
      "???" = "aichat-ctx make_nix --role nix-env --session-ctx ~/.config/aichat/contexts/make-nix.md";
    }
    // lib.optionalAttrs hasLocalAi {
      "?qc" = "aichat-ctx local_env --model ollama:qwen3-coder:latest --role local-env";
      "?q9" = "aichat-ctx local_env --model ollama:qwen3.5:9b --role local-env";
      "?qu" = "aichat-ctx local_env --model ollama:jaahas/qwen3.5-uncensored:latest --role local-env";
      "?doc" = "aichat-ctx doc_search --rag documents --role local-env";
    };

    initExtra =
      lib.mkAfter # sh
        ''
          # Load API key only when needed rather than exporting globally
          aichat() {
            CLAUDE_API_KEY=$(cat /run/agenix/anthropic-api-key) \
              command aichat "$@"
          }
        '';
  };
}
