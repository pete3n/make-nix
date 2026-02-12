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
    filter
    concatLists
    ;

  cfg = config.programs.hyprWhichKey;

  groupExists = name: builtins.hasAttr name cfg.settings.menu.groups;
  itemsExists = name: builtins.hasAttr name cfg.settings.menu.items;

  missingMenuGroups = lib.filter (grp: !(groupExists grp)) cfg.settings.menu.submenuGroups;
  missingBindGroups = lib.filter (grp: !(itemsExists grp)) cfg.settings.menu.bindGroups;
  showList = items: lib.concatStringsSep ", " (map (item: "'${item}'") items);

  mkWkCfg =
    {
      style,
      inhibit_compositor_keyboard_shortcuts,
      auto_kbd_layout,
      menu,
    }:
    let
      # derived defaults
      padding' = if style.padding != null then style.padding else style.cornerRnd;

      columnPadding' = if style.columnPadding != null then style.columnPadding else padding';

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

  mkWkMenu =
    { name }:
    pkgs.writeShellScriptBin name # sh
      ''
        	exec ${lib.getExe cfg.package} "$@"
      '';

  mkMenuItem = item: {
    key = item.menuKey;
    desc = item.desc + (if cfg.settings.showHyprKeyInDesc then mkBindHint item else "");
    cmd = mkHyprCmd item;
  };

  expandMenuEntry =
    entry:
    let
      # First, recursively expand any nested submenu entries.
      entry' =
        if entry ? submenu then entry // { submenu = map expandMenuEntry entry.submenu; } else entry;
    in
    # Then, if this entry is a fromGroup shorthand, replace it with a real submenu.
    if entry' ? fromGroup then
      let
        grp = entry'.fromGroup;
      in
      (builtins.removeAttrs entry' [ "fromGroup" ])
      // {
        key = entry'.key or (cfg.settings.menu.groups.${grp}.key or grp);
        desc = entry'.desc or (cfg.settings.menu.groups.${grp}.desc or grp);
        submenu = map mkMenuItem (cfg.settings.menu.items.${grp} or [ ]);
      }
    else
      entry';

  validateItem =
    item:
    let
      die = msg: throw "programs.hyprWhichKey: invalid item (${item.desc or "<no desc>"}): ${msg}";
      hkSet = (item ? hyprKey) && item.hyprKey != null;
      haSet = (item ? hyprAction) && item.hyprAction != null;
      action = item.hyprAction or { type = "nop"; };
    in
    if !(item ? menuKey) then
      die "missing menuKey"
    else if !(item ? desc) then
      die "missing desc"
    else if hkSet && !haSet then
      die "hyprKey set but hyprAction missing"
    else if
      haSet
      && !(lib.elem action.type [
        "nop"
        "exec"
        "dispatch"
      ])
    then
      die "hyprAction.type must be one of nop/exec/dispatch"
    else if action.type == "exec" && !(action ? cmd) then
      die "hyprAction.type=exec missing cmd"
    else if action.type == "dispatch" && !(action ? dispatch) then
      die "hyprAction.type=dispatch missing dispatch"
    else
      item;

  mkHyprCmd =
    item:
    let
      action = item.hyprAction or { type = "nop"; };
    in
    if action.type == "dispatch" then
      "hyprctl dispatch ${action.dispatch}"
      + lib.optionalString (action ? arg && action.arg != null) " ${action.arg}"
    else if action.type == "exec" then
      action.cmd
    else
      "true";

  mkHyprBind =
    item:
    let
      parts = getHyprKeyParts item;
      action = item.hyprAction or { type = "nop"; };
      modsStr = if parts == null then null else parts.modsStr;
      keyStr = if parts == null then null else parts.keyStr;

      # NOTE: When modsStr is "", Hyprland wants ", KEY, ..."
      prefix =
        if parts == null then
          null
        else if modsStr == "" then
          ", ${keyStr}"
        else
          "${modsStr}, ${keyStr}";
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

  # Returns null if the item has no hypr bind.
  getHyprKeyParts =
    item:
    if !(item ? hyprKey) || item.hyprKey == null then
      null
    else
      let
        mods = item.hyprKeyMod or [ ];
        key = item.hyprKey;
      in
      {
        modsList = mods; # ["$mainMod" "$shiftMod"]
        keyStr = key; # "j"
        modsStr = lib.concatStringsSep " " mods; # "$mainMod $shiftMod"  (may be "")
      };

  resolveHyprMod =
    mod:
    # "$mainMod" -> "SUPER" using keyVars; if unknown, keep original
    if lib.hasPrefix "$" mod then cfg.hypr.keyVars.${mod} or mod else mod;

  prettyHyprMod =
    mod:
    let
      resolved = resolveHyprMod mod; # "SUPER"
    in
    cfg.hypr.prettyMods.${resolved} or resolved; # "Super"

  mkBindHint =
    item:
    let
      parts = getHyprKeyParts item;

      # default behavior: module default, overridden by item.showBindHint if present
      wantHint = if item ? showBindHint then item.showBindHint else cfg.hypr.showBindHintsByDefault;

      fmt = cfg.settings.hyprKeyDescFormat;

      prettyKeys =
        if parts == null then
          null
        else
          lib.concatStringsSep "+" ((map prettyHyprMod parts.modsList) ++ [ parts.keyStr ]);

      hint = lib.replaceStrings [ "{keys}" ] [ prettyKeys ] fmt;
    in
    if wantHint && parts != null then hint else "";

  prettyHyprKey =
    item:
    let
      parts = getHyprKeyParts item;
    in
    if parts == null then
      null
    else
      lib.concatStringsSep "+" ((map prettyHyprMod parts.modsList) ++ [ parts.keyStr ]);

  canonicalBindKey =
    item:
    let
      parts = getHyprKeyParts item;
      # Canonicalize: resolve "$mainMod" -> "SUPER", sort mods so order doesn't matter
      modsCanon = lib.sort lib.lessThan (map resolveHyprMod parts.modsList);
    in
    "${lib.concatStringsSep "+" modsCanon}::${parts.keyStr}";

  allItems = map validateItem (
    concatLists (
      map (
        grp: map (item: item // { __hyprWhichKeyGroup = grp; }) (cfg.settings.menu.items.${grp} or [ ])
      ) cfg.settings.menu.bindGroups
    )
  );

  generatedBinds = filter (bind: bind != null) (map mkHyprBind allItems);

  menuFromGroups = map (grp: {
    key = cfg.settings.menu.groups.${grp}.key;
    desc = cfg.settings.menu.groups.${grp}.desc;
    submenu = map mkMenuItem (cfg.settings.menu.items.${grp} or [ ]);
  }) cfg.settings.menu.submenuGroups;

  finalMenu =
    (map expandMenuEntry cfg.settings.menu.prefixEntries)
    ++ menuFromGroups
    ++ (map expandMenuEntry cfg.settings.menu.suffixEntries);

  wrapper = mkWkMenu { name = "hypr-which-key"; };

  execMenuOnce =
    pkgs.writeShellScriptBin "hypr-which-key-exec-once" # sh
      ''
        	set -eu

        	# If already running, do nothing.
        	if ${pkgs.procps}/bin/pgrep -x wlr-which-key >/dev/null 2>&1; then
        		exit 0
        	fi

        	exec ${lib.getExe wrapper} "$@"
      '';

  yamlText = mkWkCfg {
    style = cfg.settings.style;
    inhibit_compositor_keyboard_shortcuts = cfg.settings.inhibit_compositor_keyboard_shortcuts;
    auto_kbd_layout = cfg.settings.auto_kbd_layout;
    menu = finalMenu;
  };

in
{
  options.programs.hyprWhichKey = {
    enable = mkEnableOption "wlr-which-key menu + Hyprland binds.";

    package = mkOption {
      type = types.package;
      default = pkgs.wlr-which-key;
      description = "The wlr-which-key package to use.";
    };

    hypr = {
      keyVars = mkOption {
        type = types.attrsOf types.str;
        default = {
          "$mainMod" = "SUPER";
          "$shiftMod" = "SHIFT";
        };
        description = ''
          Hyprland variable definitions exported to merge into hyprland.settings.
        '';
      };

      prettyMods = mkOption {
        type = types.attrsOf types.str;
        default = {
          "SUPER" = "Super";
          "SHIFT" = "Shift";
          "CTRL" = "Ctrl";
          "ALT" = "Alt";
        };
        description = ''
          How to display modifier names in bind hints.
        '';
      };

      showBindHintsByDefault = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If true, append bind hints to descriptions by default (items can override via showBindHint).
        '';
      };
    };

    settings = mkOption {
      type = types.submodule {
        options = {
          leaderKey = mkOption {
            type = types.str;
            default = "$mainMod, space";
            description = ''
              	Hyprland bind prefix used to open the wlr-which-key menu.
              	Default: "$mainMod, space"
            '';
            example = ''
              	"$mainMod, space"
            '';
          };

          addLeaderBind = mkOption {
            type = types.bool;
            default = true;
            description = ''
              	Whether to add the Hyprland bind that launches the which-key menu.
              	Default: true
            '';
          };

          showHyprKeyInDesc = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Append a formatted Hyprland keybind hint to menu item descriptions when hyprKey is present.
            '';
          };

          hyprKeyDescFormat = mkOption {
            type = types.str;
            default = " ({keys})";
            description = ''
              Format string for displaying the bind hint.
              Use "{keys}" as the placeholder.
              Example: "  [{keys}]" or " ({keys})"
            '';
          };

          style = mkOption {
            type = types.submodule {
              options = {
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
                  description = ''
                    	Defaults to cornerRnd when null.
                  '';
                };
                rowsPerColumn = mkOption {
                  type = types.nullOr types.ints.unsigned;
                  default = null;
                  description = ''
                    	No limit when null.
                  '';
                };
                columnPadding = mkOption {
                  type = types.nullOr types.ints.unsigned;
                  default = null;
                  description = ''
                    	Defaults to padding when null (and padding defaults to cornerRnd).
                  '';
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
            };
            default = { };
            description = "Menu style/theming options.";
          };

          inhibit_compositor_keyboard_shortcuts = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Permits key bindings that conflict with compositor key bindings.
              Default: false
            '';
          };

          auto_kbd_layout = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Try to guess the correct keyboard layout to use.
              Default: false
            '';
          };

          menu = mkOption {
            type = types.submodule {
              options = {
                groups = mkOption {
                  type = types.attrsOf (
                    types.submodule {
                      options = {
                        key = mkOption { type = types.str; };
                        desc = mkOption { type = types.str; };
                      };
                    }
                  );
                  default = { };
                  description = ''
                    These are the top level groups for the menu.
                    Groups are attribute sets containing a menu key and description for the menu item.
                    Example:
                    menu.groups = {
                    	apps = {
                    		key = "a";
                    		desc = "Apps/Launchers";
                    	};
                    	window = {
                    		key = "w";
                    		desc = "Window";
                    	};
                    };
                  '';
                };

                items = mkOption {
                  type = types.attrsOf (types.listOf types.attrs);
                  default = { };
                };
                submenuGroups = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                };
                bindGroups = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                };
                prefixEntries = mkOption {
                  type = types.listOf types.attrs;
                  default = [ ];
                };
                suffixEntries = mkOption {
                  type = types.listOf types.attrs;
                  default = [ ];
                };
              };
            };
            default = { };
            description = "Menu generation settings.";
          };
        };
      };
      default = { };
      description = "Settings used to generate wlr-which-key config.yaml.";
    };

    extraBinds = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        	Extra Hyprland bind strings to append after generated binds.
      '';
      example = ''
        	"$mainMod, Q, exec, alacritty"
        	"$mainMod SHIFT, 1, movetoworkspace, 1"
      '';
    };
  };

  config = mkIf cfg.enable {
    warnings = lib.mkAfter (
      let
        bindItems = lib.filter (item: getHyprKeyParts item != null) allItems;

        byKey = lib.groupBy canonicalBindKey bindItems;

        dupSets = lib.filterAttrs (_key: val: builtins.length val > 1) byKey;

        showItem =
          item:
          let
            grp = item.__hyprWhichKeyGroup or "<unknown>";
            menuKey = toString (item.menuKey or "?");
            desc = item.desc or "<no desc>";
          in
          "${desc} (group=${grp}, menuKey=${menuKey})";

        mkWarn =
          _key: items:
          let
            keyShown =
              let
                val = prettyHyprKey (builtins.head items);
              in
              if val == null then "<unknown>" else val;
          in
          ''
            programs.hyprWhichKey: duplicate Hyprland bind "${keyShown}" is used by multiple items:
              - ${lib.concatStringsSep "\n  - " (map showItem items)}
          '';
      in
      lib.mapAttrsToList mkWarn dupSets
    );

    assertions = [
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
          	programs.hyprWhichKey: submenuGroups references unknown groups:
          		${showList missingMenuGroups}

          	Defined groups are:
          		${showList (builtins.attrNames cfg.settings.menu.groups)}

          	Fix:
                - Add the missing groups under programs.hyprWhichKey.settings.groups, or
                - Remove/rename them in programs.hyprWhichKey.settings.submenuGroups.
        '';
      }
      {
        assertion = missingBindGroups == [ ];
        message = ''
          	programs.hyprWhichKey: bindGroups references groups that have no items defined:
          		${showList missingBindGroups}

          	Currently defined item groups are:
          		${showList (builtins.attrNames cfg.settings.menu.items)}

          	Fix:
                - Add the missing groups under programs.hyprWhichKey.settings.items, or
                - Remove/rename them in programs.hyprWhichKey.settings.bindGroups.
        '';
      }
    ];

    # Install the config where wlr-which-key will actually read it:
    xdg.configFile."wlr-which-key/config.yaml".text = yamlText;

    home.packages = [
      cfg.package
      wrapper
    ];

    wayland.windowManager.hyprland.settings = lib.mkMerge [
      cfg.hypr.keyVars
      {
        bind = lib.mkAfter (
          (
            if cfg.settings.addLeaderBind then
              [ "${cfg.settings.leaderKey}, exec, ${lib.getExe execMenuOnce}" ]
            else
              [ ]
          )
          ++ generatedBinds
          ++ cfg.extraBinds
        );
      }
    ];
  };
}
