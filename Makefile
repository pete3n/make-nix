deploy-macbook:
	nix build .#darwinConfigurations.MacBook-Pro.system \
	   --extra-experimental-features 'nix-command flakes'

	./result/sw/bin/darwin-rebuild switch --flake .#MacBook-Pro
i
