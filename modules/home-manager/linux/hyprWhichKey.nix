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

  # Return the appropriate command for the Hyprland keybind, based on the
  # action type (one of "dispatch", "exec", or "nop").
  mkHyprCmd =
    entry:
    let
      action = (entry.hyprBind.action or { type = "nop"; });
    in
    if action.type == "dispatch" then
      "hyprctl dispatch ${action.dispatch}" + lib.optionalString (action.arg != null) " ${action.arg}"
    else if action.type == "exec" then
      action.cmd
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
    (builtins.removeAttrs entry [ "fromGroup" ])
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
    else if action.type == "exec" && !(action ? cmd) then
      err "hyprBind.action.type=exec missing cmd"
    else if action.type == "dispatch" && !(action ? dispatch) then
      err "hyprBind.action.type=dispatch missing dispatch"
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

  # Returns { modsStr, keyStr } or null
  getHyprBindParts =
    entry:
    let
      bind = entry.hyprBind or null;
    in
    if bind == null then
      null
    else
      {
        modsStr = lib.concatStringsSep " " (bind.mods or [ ]);
        keyStr = bind.key;
      };

  mkHyprBind =
    entry:
    let
      parts = getHyprBindParts entry;
      bind = entry.hyprBind or null;
      action = if bind == null then { type = "nop"; } else (bind.action or { type = "nop"; });
      prefix =
        if parts == null then
          null
        else if parts.modsStr == "" then
          ", ${parts.keyStr}"
        else
          "${parts.modsStr}, ${parts.keyStr}";
    in
    if prefix == null then
      null
    else if action.type == "dispatch" then
      "${prefix}, ${action.dispatch}"
      + lib.optionalString (action ? arg && action.arg != null) ", ${action.arg}"
    else if action.type == "exec" then
      "${prefix}, exec, ${action.cmd}"
    else
      null;

  printHyprMod =
    mod:
    let
      modLookup =
        if lib.isString mod && lib.hasPrefix "$" mod then cfg.hypr.keyVars.${mod} or mod else mod;
    in
    cfg.hypr.printMods.${modLookup} or modLookup;

  printHyprKey =
    entry:
    let
      parts = getHyprBindParts entry;
    in
    if parts == null then
      null
    else
      lib.concatStringsSep "+" (
        (map printHyprMod (lib.splitString " " parts.modsStr)) ++ [ parts.keyStr ]
      );

  allEntries = concatLists (builtins.attrValues cfg.settings.menu.entries);
  validatedEntries = map validateEntry allEntries;
  bindEntries = lib.filter (entry: entry.hyprBind != null) validatedEntries;
  generatedBinds = lib.filter (bind: bind != null) (map mkHyprBind bindEntries);
  finalMenu = map (grp: expandMenuEntry { fromGroup = grp; }) cfg.settings.menu.order;

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

        if [ "$rc" -ne 0 ]; then
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
            These are the top level groups for the menu.
            Groups contain a menu key/description and can optionally contain submenu entries.
          '';
        };

        entries = mkOption {
          type = types.attrsOf (types.listOf menuEntryModule);
          default = { };
          description = "Entry groups: attrsOf(listOf(entry)).";
        };

        order = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Ordered list of group names rendered as top-level menus.";
        };
      };

      settingsOption = {
        leaderKey = mkOption {
          type = types.str;
          default = "$mainMod, space";
          description = ''
            Hyprland bind prefix used to open the wlr-which-key menu.
            Default: "$mainMod, space"
          '';
          example = "$mainMod, space";
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
          type = types.listOf types.str;
          default = [ ];
          description = "Extra Hyprland bind strings to append after generated binds.";
          example = ''
            "$mainMod, Q, exec, alacritty"
            "$mainMod SHIFT, 1, movetoworkspace, 1"
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
        missingMenuGroups = lib.filter (group: !(groupExists group)) cfg.settings.menu.order;

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
          assertion = config.wayland.windowManager.hyprland.enable or false;
          message = ''
            programs.hyprWhichKey requires Hyprland to be enabled via Home Manager:

              wayland.windowManager.hyprland.enable = true;
          '';
        }
        {
          assertion = missingMenuGroups == [ ];
          message = ''
            	programs.hyprWhichKey: order references unknown groups:
            		${quoteListEntries missingMenuGroups}

            	Defined groups are:
            		${quoteListEntries (builtins.attrNames cfg.settings.menu.groups)}

            	Fix:
                  - Add the missing groups under programs.hyprWhichKey.settings.menu.groups, or
                  - Remove/rename them in programs.hyprWhichKey.settings.menu.order.
          '';
        }
      ];
    xdg.configFile."wlr-which-key/config.yaml".text = yamlText;

    home.packages = [
      cfg.package
      hyprWkToggle
    ];

    wayland.windowManager.hyprland.settings = lib.mkMerge [
      cfg.hypr.keyVars
      {
        bind = lib.mkAfter (
          [ "${cfg.settings.leaderKey}, exec, ${lib.getExe hyprWkToggle}" ]
          ++ generatedBinds
          ++ cfg.hypr.extraBinds
        );
      }
    ];
  };
}
