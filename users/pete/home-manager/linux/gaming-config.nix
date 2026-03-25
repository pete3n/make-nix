{ pkgs, ... }:
{
	home.packages = with pkgs; [
		heroic
		mod._86Box
	];

	programs = {
		lutris.enable = true;
	};
}
