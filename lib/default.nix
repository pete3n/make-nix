{ lib, ... }:
rec {
  isPlatform = system: platform: lib.strings.hasSuffix ("-" + platform) system;
  isLinux = system: isPlatform system "linux";
  isDarwin = system: isPlatform system "darwin";

  getHomeAttrs = import ./home-attrs.nix { inherit lib; };
  getHomePath = import ./home-path.nix { inherit lib; };

	makeAttrsCtx = makeAttrs: {
		system = makeAttrs.system;
		user = makeAttrs.user;
		host = makeAttrs.host;
		tags = makeAttrs.tags or [];
		specialisations = makeAttrs.specialisations or [];
		isHomeAlone = makeAttrs.isHomeAlone or false;
		useHomebrew = makeAttrs.useHomebrew or false;
		useKeys = makeAttrs.useKeys or false;
		useCache = makeAttrs.useCache or false;
	};
}
