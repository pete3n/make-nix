deploy-darwin:
	nix build .#darwinConfigurations.macbook.system \
	   --extra-experimental-features 'nix-command flakes'

	./result/sw/bin/darwin-rebuild switch --flake .#macbook
deploy-linux:
	nix build .#nixosConfigurations.framework.config.system.build.toplevel \
	  --extra-experimental-features 'nix-command flakes'
