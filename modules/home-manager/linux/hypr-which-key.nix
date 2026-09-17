# This module integrates wlr-which-key with Hyprland to create self-documenting
# key bind help menus.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    concatLists
    ;
  inherit (builtins)
    hasAttr
    ;

  cfg = config.programs.hyprWhichKey;

  # Generate a config.yaml for wlr-which-key based on the parameters specified from
  # github.com/MaxVerevkin/wlr-which-key/blob/master/README.md
  mkWkCfg =
    {
      style,
      inhibit_compositor_keyboard_shortcuts,
      auto_kbd_layout,
      menu,
    }:
    let
      # padding should default to corner_r
      padding' = if style.padding != null then style.padding else style.cornerRnd;

      # column_padding should default to padding
      columnPadding' = if style.columnPadding != null then style.columnPadding else padding';

      # only configure rows_per_column if it has been set
      rowsPerColumnAttrs = lib.optionalAttrs (style.rowsPerColumn != null) {
        rows_per_column = style.rowsPerColumn;
      };
    in
    lib.generators.toYAML { } (
      {
        # Theming
        font = style.font;
        background = style.background;
        color = style.color;
        border = style.border;
        separator = style.separator;
        border_width = style.borderWidth;
        corner_r = style.cornerRnd;
        padding = padding';
        column_padding = columnPadding';

        # Anchor/margins
        anchor = style.anchor;
        margin_right = style.marginRight;
        margin_left = style.marginLeft;
        margin_bottom = style.marginBottom;
        margin_top = style.marginTop;

        # Other settings
        inhibit_compositor_keyboard_shortcuts = inhibit_compositor_keyboard_shortcuts;
        auto_kbd_layout = auto_kbd_layout;

        # Menu
        menu = menu;
      }
      // rowsPerColumnAttrs
    );

  # Command wlr-which-key runs when a menu entry is selected.
  #
  # wlr-which-key executes SHELL commands, so this always shells out through
  # hyprctl regardless of the compositor's config language. But the ARGUMENT
  # form changed: under Lua, `hyprctl dispatch` is shorthand for
  # `hl.dispatch(...)`, so `hyprctl dispatch workspace 2` is a Lua syntax
  # error. The argument must be a Lua expression.
  mkHyprCmd =
    entry:
    let
      action = (entry.hyprBind.action or { type = "nop"; });
    in
    if action.type == "exec" then
      action.cmd

    else if luaMode then
      let
        call = luaAction action;
      in
      if call == null then "true" else "hyprctl dispatch '${call}'"

    else if action.type == "dispatch" then
      "hyprctl dispatch ${action.dispatch}" + lib.optionalString (action.arg != null) " ${action.arg}"
    else if action.type == "layoutmsg" then
      "hyprctl dispatch layoutmsg ${action.message}"
    else
      "true";

  mkBindHint =
    entry:
    let
      bind = entry.hyprBind or null;
      shown = printHyprKey entry;
      hint = lib.replaceStrings [ "{keys}" ] [ shown ] cfg.settings.hyprKeyDescFormat;

      want =
        if bind == null then
          false
        else if (bind ? showHint) && bind.showHint != null then
          bind.showHint
        else
          true;
    in
    if want && shown != null then hint else "";

  mkMenuEntry = entry: {
    key = entry.menuKey;
    desc = entry.desc + (if cfg.settings.showHyprKeyInDesc then mkBindHint entry else "");
    cmd =
      if entry.cmd != null then
        entry.cmd
      else if entry.hyprBind != null then
        mkHyprCmd entry
      else
        "true"; # Default nop cmd
  };

  expandFromGroupNode =
    seenPath: entry:
    let
      grp = entry.fromGroup;
      nextSeen = seenPath ++ [ grp ];

      group =
        if cfg.settings.menu.groups ? ${grp} then
          cfg.settings.menu.groups.${grp}
        else
          throw "programs.hyprWhichKey: fromGroup references unknown group '${grp}'";

      submenu = submenuForGroup seenPath grp;
    in
    assert lib.assertMsg (!(lib.elem grp seenPath))
      "programs.hyprWhichKey: infinite menu recursion detected while expanding fromGroup: ${lib.concatStringsSep " -> " nextSeen}";
    assert lib.assertMsg (submenu != [ ]) ''
      programs.hyprWhichKey: group '${grp}' expands to an empty submenu.

      Fix one of:
        - define programs.hyprWhichKey.settings.menu.entries.${grp} = [ ... ];
        - define programs.hyprWhichKey.settings.menu.groups.${grp}.submenu = [ ... ];
        - remove '${grp}' from any fromGroup reference (or from submenuGroups).
    '';
    (removeAttrs entry [ "fromGroup" ])
    // {
      key = entry.key or (group.key or grp);
      desc = entry.desc or (group.desc or grp);
      submenu = submenu;
    };

  # Recursively expand submenus. Replace fromGroup with a submenu.
  expandMenuEntries =
    seenPath: entry:
    let
      entryWithExpandedChildren =
        if entry ? submenu then
          entry // { submenu = map (expandMenuEntries seenPath) entry.submenu; }
        else
          entry;
    in
    if entryWithExpandedChildren ? fromGroup then
      expandFromGroupNode seenPath entryWithExpandedChildren
    else
      entryWithExpandedChildren;

  # Public entry point: expand one entry starting from empty seen path
  expandMenuEntry = entry: expandMenuEntries [ ] entry;

  # Build the submenu list for a group:
  # - If groups.<grp>.submenu is set: use it (and expand nested fromGroup inside it)
  # - Fall back to entries.<grp>
  submenuForGroup =
    seenPath: grp:
    let
      group = cfg.settings.menu.groups.${grp} or { };
      sub = group.submenu or null;
      entries = cfg.settings.menu.entries.${grp} or [ ];
    in
    if sub != null then
      map (entry: expandMenuEntries (seenPath ++ [ grp ]) (validateSubmenuEntry entry)) sub
    else
      map mkMenuEntry entries;

  validateEntry =
    entry:
    let
      err = msg: throw "programs.hyprWhichKey: invalid entry (${entry.desc or "<no desc>"}): ${msg}";
      hb = entry.hyprBind or null;
      action = if hb == null then { type = "nop"; } else hb.action;
    in
    if !(entry ? menuKey) then
      err "missing menuKey"
    else if !(entry ? desc) then
      err "missing desc"
    else if hb != null && !(hb ? key) then
      err "hyprBind.key missing"
    # Note: action.cmd / action.dispatch / action.message are module options with
    # default = null, so `action ? attr` is always true. Check the value instead.
    else if action.type == "exec" && action.cmd == null then
      err "hyprBind.action.type=exec requires cmd"
    else if action.type == "dispatch" && action.dispatch == null then
      err "hyprBind.action.type=dispatch requires dispatch"
    else if action.type == "layoutmsg" && action.message == null then
      err "hyprBind.action.type=layoutmsg requires message"
    else if action.type == "luaDispatch" && action.lua == null then
      err "hyprBind.action.type=luaDispatch requires lua"
    else
      entry;

  validateSubmenuEntry =
    entry:
    let
      allowed = [
        "key"
        "desc"
        "cmd"
        "keepOpen"
        "fromGroup"
        "submenu"
      ];
      unknown = lib.filter (k: !(lib.elem k allowed)) (builtins.attrNames entry);

      hasCmd = (entry.cmd or null) != null;
      hasSub = (entry.submenu or null) != null;
      hasFrom = (entry.fromGroup or null) != null;

      n = (if hasCmd then 1 else 0) + (if hasSub then 1 else 0) + (if hasFrom then 1 else 0);

      requireKeyDesc = (hasCmd || hasSub) && !hasFrom;

      recurse = if hasSub then map validateSubmenuEntry entry.submenu else entry.submenu or null;
    in
    if unknown != [ ] then
      throw "programs.hyprWhichKey: submenu entry has unknown keys: ${lib.concatStringsSep ", " unknown}"
    else if n > 1 then
      throw "programs.hyprWhichKey: submenu entry must set at most one of cmd, submenu, or fromGroup"
    else if requireKeyDesc && ((entry.key or null) == null || (entry.desc or null) == null) then
      throw "programs.hyprWhichKey: submenu entry with cmd/submenu must provide key and desc (unless using fromGroup)"
    else
      # return entry with validated/validated-children (optional)
      entry // (if hasSub then { submenu = recurse; } else { });

  # ======================================================================
  # Lua support.
  #
  # home-manager's Lua translation is a MECHANICAL passthrough: it renders
  # settings.<name> as hl.<name>(...) and does not parse hyprlang. Feeding it
  # the old string output produced broken Lua —  hl.$mainMod("SUPER") ($ is
  # not a legal Lua identifier character) and hl.bind("$mainMod, q, exec,
  # alacritty") (valid syntax, wrong semantics: hl.bind takes a combo string
  # and a dispatcher closure).
  #
  # DISPATCHER MAPPINGS ARE NOT INFERRED. hl.dsp was redone from the ground up
  # rather than renamed, so there is no mechanical translation. Every entry in
  # dispatchMap came from running the real config through hyprlang2lua.
  # Structural differences naming alone would have missed:
  #
  #   togglefloating -> window.float({ action = "toggle" })  not toggle_floating()
  #   workspace, 1   -> focus({ workspace = 1 })             not workspace("1")
  #   layoutmsg      -> layout(...)                          not layout_msg(...)
  #
  # Gate changes on `Hyprland --verify-config`, which validates argument
  # tables against the implementation. Valid Lua can still be wrong.
  # ======================================================================

  luaMode = cfg.hypr.configType == "lua";

  # $ is a hyprlang sigil, not part of the name, and not legal in a Lua
  # identifier.
  stripSigil = name: lib.removePrefix "$" name;

  # keyVars -> Lua locals: { "$mainMod" = "SUPER"; } becomes
  # { mainMod = { _var = "SUPER"; }; }, rendered as `local mainMod = "SUPER"`.
  luaKeyVars = lib.mapAttrs' (
    name: value: lib.nameValuePair (stripSigil name) { _var = value; }
  ) cfg.hypr.keyVars;

  # Mods stay Lua VARIABLES rather than being flattened at eval time, so
  # changing keyVars still changes every bind — the property $mainMod had.
  #
  # NOTE the separator: hyprlang2lua emits `mainMod .. shiftMod .. " + F"`,
  # which concatenates to "SUPERSHIFT + F". Every multi-modifier bind in its
  # output is broken that way. " + " must appear BETWEEN mods as well.
  luaComboExpr =
    bind:
    let
      modTerm =
        mod: if cfg.hypr.keyVars ? ${mod} then stripSigil mod else ''"${stripSigil mod}"'';
      terms = (map modTerm (bind.mods or [ ])) ++ [ ''"${bind.key}"'' ];
    in
    lib.generators.mkLuaInline (lib.concatStringsSep '' .. " + " .. '' terms);

  directionNames = {
    l = "left";
    r = "right";
    u = "up";
    d = "down";
  };

  # Numeric workspace ids are Lua NUMBERS; relative ("e+1") and special
  # ("special:magic") are strings. A quoted "1" is not equivalent — the string
  # form silently fails to focus.
  wsArg = arg: if builtins.match "[0-9]+" arg != null then arg else ''"${arg}"'';

  dispatchMap = {
    killactive = _: "hl.dsp.window.close()";
    togglefloating = _: ''hl.dsp.window.float({ action = "toggle" })'';
    pseudo = _: "hl.dsp.window.pseudo()";
    submap = arg: ''hl.dsp.submap("${arg}")'';
    exit = _: "hl.dsp.exit()";

    fullscreen =
      arg:
      let
        mode = if arg == "1" then "maximized" else "fullscreen";
      in
      ''hl.dsp.window.fullscreen({ mode = "${mode}", action = "toggle" })'';

    # TODO: focus takes spelled-out directions while window.move takes single
    # letters — verify with --verify-config; one is plausibly a converter bug.
    movefocus = arg: ''hl.dsp.focus({ direction = "${directionNames.${arg} or arg}" })'';
    movewindow = arg: ''hl.dsp.window.move({ direction = "${arg}" })'';

    workspace = arg: "hl.dsp.focus({ workspace = ${wsArg arg} })";
    movetoworkspace = arg: "hl.dsp.window.move({ workspace = ${wsArg arg} })";
    togglespecialworkspace = arg: ''hl.dsp.workspace.toggle_special("${arg}")'';
  };

  luaAction =
    action:
    if action.type == "exec" then
      ''hl.dsp.exec_cmd("${lib.escape [ ''"'' "\\" ] action.cmd}")''
    else if action.type == "luaDispatch" then
      action.lua
    else if action.type == "layoutmsg" then
      ''hl.dsp.layout("${action.message}")''
    else if action.type == "dispatch" then
      let
        fn =
          dispatchMap.${action.dispatch} or (throw ''
            programs.hyprWhichKey: no Lua mapping for dispatcher '${action.dispatch}'.

            hl.dsp is a structured namespace, not a rename of the hyprlang
            dispatchers, so each needs an explicit mapping.

            Fix one of:
              - run the hyprlang line through hyprlang2lua and add the result
                to dispatchMap in this module, or
              - supply the call directly with action.type = "luaDispatch".
          '');
      in
      fn action.arg
    else
      null;

  # ----------------------------------------------------------------------
  # Bind generation. hyprlang returns a STRING; Lua returns an attrset with
  # _args, which home-manager renders as hl.bind(combo, dispatcher).
  # ----------------------------------------------------------------------
  mkHyprBind =
    entry:
    let
      bind = entry.hyprBind or null;
      action = if bind == null then { type = "nop"; } else (bind.action or { type = "nop"; });
    in
    if bind == null || action.type == "nop" then
      null

    else if luaMode then
      let
        call = luaAction action;
      in
      if call == null then
        null
      else
        {
          _args = [
            (luaComboExpr bind)
            (lib.generators.mkLuaInline call)
          ];
        }

    else
      let
        modsStr = lib.concatStringsSep " " (bind.mods or [ ]);
        prefix = if modsStr == "" then ", ${bind.key}" else "${modsStr}, ${bind.key}";
      in
      if action.type == "dispatch" then
        # `action ? arg` is always true (module option with default = null),
        # so check the value.
        "${prefix}, ${action.dispatch}" + lib.optionalString (action.arg != null) ", ${action.arg}"
      else if action.type == "layoutmsg" then
        "${prefix}, layoutmsg, ${action.message}"
      else if action.type == "exec" then
        "${prefix}, exec, ${action.cmd}"
      else if action.type == "luaDispatch" then
        throw ''
          programs.hyprWhichKey: action.type = "luaDispatch" requires
          configType = "lua". Entry: ${entry.desc or "<no desc>"}
        ''
      else
        null;

  # Display text for bind hints. Independent of config language, but the
  # lookup must handle both spellings since Lua keyVars carry no sigil.
  printHyprMod =
    mod:
    let
      modLookup = cfg.hypr.keyVars.${mod} or cfg.hypr.keyVars."$${mod}" or (stripSigil mod);
    in
    cfg.hypr.printMods.${modLookup} or modLookup;

  printHyprKey =
    entry:
    let
      bind = entry.hyprBind or null;
    in
    if bind == null then
      null
    else
      lib.concatStringsSep "+" ((map printHyprMod (bind.mods or [ ])) ++ [ bind.key ]);

  # Leader bind, built the same way as any other so it is correct under both
  # config languages.
  leaderBind =
    if luaMode then
      {
        _args = [
          (luaComboExpr {
            mods = cfg.settings.leaderMods;
            key = cfg.settings.leaderKey;
          })
          (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${lib.getExe hyprWkToggle}")'')
        ];
      }
    else
      let
        modsStr = lib.concatStringsSep " " cfg.settings.leaderMods;
        prefix =
          if modsStr == "" then ", ${cfg.settings.leaderKey}" else "${modsStr}, ${cfg.settings.leaderKey}";
      in
      "${prefix}, exec, ${lib.getExe hyprWkToggle}";

  allEntries = concatLists (builtins.attrValues cfg.settings.menu.entries);
  validatedEntries = map validateEntry allEntries;
  bindEntries = lib.filter (entry: entry.hyprBind != null) validatedEntries;
  generatedBinds = lib.filter (bind: bind != null) (map mkHyprBind bindEntries);
  finalMenu = map (grp: expandMenuEntry { fromGroup = grp; }) cfg.settings.menu.root;

  yamlText = mkWkCfg {
    style = cfg.settings.style;
    inhibit_compositor_keyboard_shortcuts = cfg.settings.inhibit_compositor_keyboard_shortcuts;
    auto_kbd_layout = cfg.settings.auto_kbd_layout;
    menu = finalMenu;
  };

  hyprWkToggle =
    pkgs.writeShellScriptBin "hypr-wk-toggle" # sh
      ''
        set -eu

        DEBUG_LOG=${if cfg.debugLog then "true" else "false"}

        wk="${lib.getExe cfg.package}"
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
        wk_dir="$state_dir/hypr-which-key"
        ${pkgs.coreutils}/bin/mkdir -p "$wk_dir"

        pidfile="$wk_dir/wlr-which-key.pid"
        ts="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
        log="$wk_dir/wlr-which-key-$ts.log"
        tmp_out="$wk_dir/wlr-which-key-last.log"

        is_alive() { [ -n "''${1:-}" ] && kill -0 "$1" >/dev/null 2>&1; }

        if [ -f "$pidfile" ]; then
        	pid="$(${pkgs.coreutils}/bin/cat "$pidfile" 2>/dev/null || true)"
        if is_alive "$pid"; then
        	kill "$pid" >/dev/null 2>&1 || true
        	rm -f "$pidfile"
        	exit 0
        fi
        	rm -f "$pidfile" # stale
        fi

        set +e
        if [ "$DEBUG_LOG" = "true" ]; then
        	"$wk" "$@" >"$log" 2>&1 &
        else
        	# capture last output for notify without spamming logs
        	"$wk" "$@" >"$tmp_out" 2>&1 &
        fi
        pid="$!"
        set -e

        printf '%s\n' "$pid" >"$pidfile"

        set +e
        wait "$pid"
        rc="$?"
        set -e

        rm -f "$pidfile"

        if [ "$rc" -ne 0 ] && [ "$rc" -ne 143 ]; then
        	if [ "$DEBUG_LOG" = "true" ]; then
        		_tail_out="$(${pkgs.coreutils}/bin/tail -n 15 "$log" 2>/dev/null || true)"
        		_extra="Full log: $log"
        	else
        		_tail_out="$(${pkgs.coreutils}/bin/tail -n 15 "$tmp_out" 2>/dev/null || true)"
        		_extra="(Set programs.hyprWhichKey.debugLog = true for timestamped logs.)"
        	fi

        	msg="$(
        	${pkgs.coreutils}/bin/printf \
        	"wlr-which-key failed (exit %s).\n\nLast lines:\n%s%s" \
        	"$rc" \
        	"$_tail_out" \
        	"$_extra"
        	)"

        	${pkgs.hyprland}/bin/hyprctl notify 3 10000 0 "$msg"

        	exit "$rc"
        fi

        exit 0
      '';
in
{
  options.programs.hyprWhichKey =
    let
      submodule = opts: types.submodule { options = opts; };

      mkSubmoduleOption =
        opts:
        mkOption {
          type = submodule opts;
          default = { };
        };

      hyprActionOpts = {
        type = mkOption {
          type = types.enum [
            "nop"
            "exec"
            "dispatch"
            "layoutmsg" # layout-specific messages sent via `layoutmsg` dispatcher (e.g. togglesplit)
            "luaDispatch" # raw hl.dsp call; configType = "lua" only
          ];
          default = "nop";
          description = "Hyprland action type.";
        };

        cmd = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Command for type=exec.";
        };

        dispatch = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Dispatcher name for type=dispatch (e.g., movefocus).";
        };

        arg = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional argument for type=dispatch.";
        };

        lua = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Raw Lua dispatcher call for type=luaDispatch, e.g.
            "hl.dsp.window.resize({ x = 10, y = 0, relative = true })".

            The escape hatch for dispatchers with no dispatchMap entry — hl.dsp
            is a structured namespace, so it cannot be mapped mechanically.
            Has no hyprlang equivalent; using it under configType = "hyprlang"
            is an error rather than a silent skip.
          '';
          example = ''hl.dsp.window.float({ action = "toggle" })'';
        };

        message = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Layout message for type=layoutmsg.
            Generates: bind = MODS, KEY, layoutmsg, MESSAGE
            Use this for dispatchers removed in 0.54 that were folded into layoutmsg
            (e.g. togglesplit, swapsplit).
          '';
        };
      };
      hyprActionModule = submodule hyprActionOpts;

      hyprBindOption = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              mods = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''List of Hyprland modifier variables (e.g. ["$mainMod" "$shiftMod"]).'';
              };

              key = mkOption {
                type = types.str;
                description = ''Hyprland key (e.g. "j", "PRINT").'';
              };

              action = mkOption {
                type = hyprActionModule;
                default = { };
                description = "Hyprland action executed by this bind.";
              };

              # I recommend making this nullable so you can “inherit default behavior”
              # instead of forcing true/false at the entry level.
              showHint = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = ''
                  If set, overrides showBindHints for this entry.
                  null means “use the module default”.
                '';
              };
            };
          }
        );

        default = null;

        description = ''
          If set, this entry generates a Hyprland bind and can optionally show a bind hint in the menu.
          If null, no Hyprland bind is generated.
        '';
      };

      menuEntryOpts = {
        desc = mkOption {
          type = types.str;
          description = "Menu description.";
        };

        menuKey = mkOption {
          type = types.str;
          description = "Key used inside wlr-which-key.";
        };

        cmd = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Command executed when selecting this entry in wlr-which-key.
            Use this for menu-only entries that don't generate a Hyprland bind.
          '';
        };

        hyprBind = hyprBindOption;
      };
      menuEntryModule = submodule menuEntryOpts;

      groupOpts = {
        key = mkOption {
          type = types.str;
          description = ''
            Key binding to enter the group menu.
          '';
        };

        desc = mkOption {
          type = types.str;
          description = ''
            Menu group description.	
          '';
        };

        submenu = mkOption {
          type = types.nullOr (types.listOf types.attrs);
          default = null;
          description = ''
            Optional submenu entries these can be created explicitly with individual
            submenu list entries or from another group using the fromGroup option.
            Example:
            help = {
            	desc = "Help";
            	key = "?";
            	submenu = [
            		{
            			key = "F1";
            			desc = "Searchable help";
            			cmd = "rofi-help-menu";
            		}
            		{
            			fromGroup = "navigation";
            			key = "n";
            			desc = "Navigation";
            		}
            		{
            			fromGroup = "workspaces";
            			key = "w";
            			desc = "Workspaces";
            		}
            	];
            };

            display = {
            	key = "d";
            	desc = "Display";
            	submenu = [
            		{
            			key = "s";
            			desc = "Screenshots";
            			fromGroup = "screenshots";
            		}
            	];
            };
            screenshots = {
            		key = "s";
            		desc = "Screenshots";
            };
          '';
          example = ''
            display = {
            	key = "d";
            	desc = "Display";
            	submenu = [
            		{
            			key = "s";
            			desc = "Screenshots";
            			fromGroup = "screenshots";
            		}
            	];
            };
            screenshots = {
            	key = "s";
            	desc = "Screenshots";
            };
          '';
        };
      };
      groupModule = submodule groupOpts;

      styleOption = {
        anchor = mkOption {
          type = types.str;
          default = "center";
        };
        background = mkOption {
          type = types.str;
          default = "#282828d0";
        };
        border = mkOption {
          type = types.str;
          default = "#4688fa";
        };
        color = mkOption {
          type = types.str;
          default = "#fbf1c7";
        };
        font = mkOption {
          type = types.str;
          default = "JetBrainsMono Nerd Font 24";
        };
        separator = mkOption {
          type = types.str;
          default = " ➜ ";
        };
        borderWidth = mkOption {
          type = types.ints.unsigned;
          default = 2;
        };
        cornerRnd = mkOption {
          type = types.ints.unsigned;
          default = 10;
        };
        padding = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "Defaults to cornerRnd when null.";
        };
        rowsPerColumn = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "No limit when null.";
        };
        columnPadding = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "Defaults to padding when null (and padding defaults to cornerRnd).";
        };
        marginRight = mkOption {
          type = types.ints.unsigned;
          default = 0;
        };
        marginLeft = mkOption {
          type = types.ints.unsigned;
          default = 0;
        };
        marginBottom = mkOption {
          type = types.ints.unsigned;
          default = 0;
        };
        marginTop = mkOption {
          type = types.ints.unsigned;
          default = 0;
        };
      };

      menuOption = {
        groups = mkOption {
          type = types.attrsOf groupModule;
          default = { };
          description = ''
            This is an un-ordered set of menu groups. Groups contain a top level description and 
            a key bind to open the associated menu entry set. The menu.entries sets contain
            the menu leaf entries and can dynamically configure Hyprland keybinds.
            Groups can optionally contain submenus, submenus can be dynamically created 
            from other groups, or can contain a simple key and command combination.
            Submenus can not currently create Hyprland keybinds.
          '';
        };

        entries = mkOption {
          type = types.attrsOf (types.listOf menuEntryModule);
          default = { };
          description = ''
            The entries set contains ordered lists of menu entry attribute sets.
          '';
        };

        root = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Ordered list of group names shown in the root menu.";
        };
      };

      settingsOption = {
        leaderMods = mkOption {
          type = types.listOf types.str;
          default = [ "$mainMod" ];
          description = ''
            Modifiers for the menu leader bind.

            Split from leaderKey because the old combined form
            ("$mainMod, space") is hyprlang syntax with no Lua meaning — it
            would have been emitted verbatim into a Lua string. Every other
            bind in this module already uses separate mods and key.
          '';
          example = [
            "$mainMod"
            "$shiftMod"
          ];
        };

        leaderKey = mkOption {
          type = types.str;
          default = "space";
          description = ''
            Key that opens the wlr-which-key menu, without modifiers.
          '';
          example = "space";
        };

        showHyprKeyInDesc = mkOption {
          type = types.bool;
          default = true;
          description = "Append a formatted Hyprland keybind hint to menu entry descriptions when hyprKey is present.";
        };

        hyprKeyDescFormat = mkOption {
          type = types.str;
          default = " ({keys})";
          description = ''
            Format string for displaying the bind hint.
            Use "{keys}" as the placeholder.
          '';
        };

        style = mkOption {
          type = submodule styleOption;
          default = { };
          description = "Menu style/theming options.";
        };

        inhibit_compositor_keyboard_shortcuts = mkOption {
          type = types.bool;
          default = false;
          description = "Permits key bindings that conflict with compositor key bindings.";
        };

        auto_kbd_layout = mkOption {
          type = types.bool;
          default = false;
          description = "Try to guess the correct keyboard layout to use.";
        };

        menu = mkOption {
          type = submodule menuOption;
          default = { };
          description = "Menu generation settings.";
        };
      };

      hyprOption = {
        configType = mkOption {
          type = types.enum [
            "hyprlang"
            "lua"
          ];
          default = config.wayland.windowManager.hyprland.configType or "hyprlang";
          defaultText = lib.literalMD "Inherited from `wayland.windowManager.hyprland.configType`.";
          description = ''
            Which config language to generate binds for.

            Defaults to whatever the Hyprland module is set to, so the two
            cannot drift. Generating hyprlang bind strings into a Lua file
            produces `hl.bind("$mainMod, q, exec, alacritty")` — syntactically
            valid Lua that means nothing, with no error until Hyprland loads
            it.
          '';
        };

        keyVars = mkOption {
          type = types.attrsOf types.str;
          default = {
            "$mainMod" = "SUPER";
            "$shiftMod" = "SHIFT";
          };
          description = "Hyprland variable definitions exported to merge into hyprland.settings.";
        };

        printMods = mkOption {
          type = types.attrsOf types.str;
          default = {
            "SUPER" = "Super";
            "SHIFT" = "Shift";
            "CTRL" = "Ctrl";
            "ALT" = "Alt";
          };
          description = "How to display modifier names in bind hints.";
        };

        showBindHints = mkOption {
          type = types.bool;
          default = true;
          description = "If true, append bind hints to descriptions by default (entries can override via showBindHint).";
        };

        extraBinds = mkOption {
          type = types.listOf (types.either types.str (types.attrsOf types.anything));
          default = [ ];
          description = ''
            Extra binds appended after generated ones.

            Strings are hyprlang bind lines, valid only when
            configType = "hyprlang". Under Lua they would pass through as
            hl.bind("$mainMod, Q, exec, alacritty") — valid syntax, wrong
            semantics, no error until load time. The assertion below rejects
            them instead.

            Under Lua, supply the attrset form home-manager renders as a
            multi-argument call.
          '';
          example = lib.literalExpression ''
            # configType = "hyprlang"
            [ "$mainMod, Q, exec, alacritty" ]

            # configType = "lua"
            [
              {
                _args = [
                  (lib.generators.mkLuaInline "mainMod .. \" + Q\"")
                  (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"alacritty\")")
                ];
              }
            ]
          '';
        };
      };
    in
    {
      enable = mkEnableOption "Dynamically configure Hyprland keybinds with wlr-which-key menu entries.";

      debugLog = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable per-instance logging output to $XDG_STATE_HOME/hypr-which-key/ or 
          $HOME/.local/state/hypr-which-key/
          Default: false
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.wlr-which-key;
        description = ''
          The wlr-which-key package to use.
        '';
      };

      hypr = mkSubmoduleOption hyprOption // {
        description = ''
          Hyprland-related configuration and bind-hint rendering.
        '';
      };

      settings = mkOption {
        type = submodule settingsOption;
        default = { };
        description = ''
          Settings used to generate wlr-which-key config.yaml.
        '';
      };
    };

  config = mkIf cfg.enable {
    # Warn user if multiple entries use the same key binding.
    # This could be intential for some configurations, so it isn't flagged as an error.
    warnings = lib.mkAfter (
      let
        bindEntries = lib.filter (entry: (entry.hyprBind or null) != null) allEntries;
        byKey = lib.groupBy (
          entry:
          let
            bind = entry.hyprBind;
          in
          lib.concatStringsSep " " (bind.mods ++ [ bind.key ])
        ) bindEntries;

        dupSets = lib.filterAttrs (_key: entries: builtins.length entries > 1) byKey;

        showEntry =
          entry:
          let
            grp = entry.__hyprWhichKeyGroup or "<unknown>";
            menuKey = toString (entry.menuKey or "?");
            desc = entry.desc or "<no desc>";
          in
          "${desc} (group=${grp}, menuKey=${menuKey})";

        mkWarn =
          _key: entries:
          let
            dupKey =
              let
                val = printHyprKey (builtins.head entries);
              in
              if val == null then "<unknown>" else val;
          in
          ''
            programs.hyprWhichKey: duplicate Hyprland bind "${dupKey}" is used by multiple entries:
              - ${lib.concatStringsSep "\n  - " (map showEntry entries)}
          '';
      in
      lib.mapAttrsToList mkWarn dupSets
    );

    assertions =
      let
        groupExists = group: hasAttr group cfg.settings.menu.groups;

        # Groups should only be listed in the menu order list if they exist.
        missingMenuGroups = lib.filter (group: !(groupExists group)) cfg.settings.menu.root;

        # Prettier list output for assertion errors
        # Format [ "entry1" "entry2" "entry3" ] as "'entry1', 'entry2', 'entry3'"
        quoteListEntries = entries: lib.concatStringsSep ", " (map (entry: "'${entry}'") entries);
      in
      [
        {
          assertion = config.xdg.enable or false;
          message = ''
            programs.hyprWhichKey requires xdg to be enabled.

            Fix:
              xdg.enable = true;
          '';
        }
        {
          # A string here under Lua renders as
          # hl.bind("$mainMod, Q, exec, alacritty") — valid Lua, wrong
          # semantics, and no error until Hyprland loads it.
          assertion = !luaMode || lib.all lib.isAttrs cfg.hypr.extraBinds;
          message = ''
            programs.hyprWhichKey.hypr.extraBinds contains hyprlang bind
            strings while configType = "lua".

            Under Lua a bind takes a combo string and a dispatcher closure, so
            a hyprlang line cannot pass through. Supply the attrset form:

              {
                _args = [
                  (lib.generators.mkLuaInline "mainMod .. \" + Q\"")
                  (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"alacritty\")")
                ];
              }
          '';
        }
        {
          assertion = config.wayland.windowManager.hyprland.enable or false;
          message = ''
            programs.hyprWhichKey requires Hyprland to be enabled via Home Manager:

              wayland.windowManager.hyprland.enable = true;
          '';
        }
        {
          assertion = missingMenuGroups == [ ];
          message = ''
            	programs.hyprWhichKey: root references unknown groups:
            		${quoteListEntries missingMenuGroups}

            	Defined groups are:
            		${quoteListEntries (builtins.attrNames cfg.settings.menu.groups)}

            	Fix:
                  - Add the missing groups under programs.hyprWhichKey.settings.menu.groups, or
                  - Remove/rename them in programs.hyprWhichKey.settings.menu.root
          '';
        }
      ];
    xdg.configFile."wlr-which-key/config.yaml".text = yamlText;

    home.packages = [
      cfg.package
      hyprWkToggle
    ];

    wayland.windowManager.hyprland.settings = lib.mkMerge [
      # hyprlang: plain "$name = value" variables.
      # Lua: { name = { _var = value; }; }, rendered as `local name = value`.
      (if luaMode then luaKeyVars else cfg.hypr.keyVars)
      {
        bind = lib.mkAfter ([ leaderBind ] ++ generatedBinds ++ cfg.hypr.extraBinds);
      }
    ];
  };
}
