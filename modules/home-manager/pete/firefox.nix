{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  # Function to recursively collect .cer files
  collectCerts = dirPath: let
    list = builtins.readDir dirPath;
    paths =
      lib.mapAttrsToList (
        name: type:
          if type == "directory"
          then collectCerts "${dirPath}/${name}"
          else if lib.hasSuffix ".cer" name
          then ["${dirPath}/${name}"]
          else []
      )
      list;
  in
    lib.flatten paths;

  certPath = "${pkgs.dod-certs}/dod-certs/_DoD";
  certs = collectCerts certPath;

  concatenatedCerts = pkgs.stdenv.mkDerivation {
    name = "concatenated-certs";
    buildInputs = [pkgs.coreutils];
    buildCommand = ''
      cat ${lib.concatStringsSep " " certs} > $out
    '';
  };
  openscLibPath = "${pkgs.opensc}/lib/opensc-pkcs11.so";
in {
  home.packages = lib.mkAfter (with pkgs; [
    dod-certs
  ]);

  programs.firefox = {
    enable = true;
    policies = {
      SecurityDevices.Add = {
        # Enable openSC smartcart reader
        OpenSC = openscLibPath;
      };
      Certificates = {
        # Import DoD certificates
        ImportEnterpriseRoots = true;
        Install = concatenatedCerts;
      };
    };
    profiles.pete3n = {
      bookmarks = {};
      extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
        ublock-origin
        tridactyl
      ];
      bookmarks = {};
      settings = {
        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.download.useDownloadDir" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.startup.homepage" = "https://start.duckduckgo.com";
        "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"nav-bar":["back-button","forward-button","stop-reload-button","home-button","urlbar-container","downloads-button","library-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list"],"currentVersion":18,"newElementCount":4}'';
        "dom.security.https_only_mode" = true;
        "identity.fxaccounts.enabled" = false;
        "privacy.trackingprotection.enabled" = true;
        "signon.rememberSignons" = false;
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = ["firefox.desktop"];
    "text/xml" = ["firefox.desktop"];
    "x-scheme-handler/http" = ["firefox.desktop"];
    "x-scheme-handler/https" = ["firefox.desktop"];
  };
}
