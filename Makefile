ifndef host
  $(error "host is not set. Please provide with either: \
		make deploy-darwin host=myHost user=myUser _OR_\
		make deploy-linux host=myHost user=myUser")
endif

ifndef user
  $(error "user is not set. Please provide with either: \
		make deploy-darwin host=myHost user=myUser _OR_ \
		make deploy-linux host=myHost user=myUser")
endif

deploy-darwin:
	nix build .#darwinConfigurations.$(host).system \
	   --extra-experimental-features 'nix-command flakes'
	
	# Activate system
	./result/sw/bin/darwin-rebuild switch --flake .#$(host)

	# Build and switch home-manager config
	home-manager switch --flake .#$(user)@$(host)

deploy-linux:
	nix build .#nixosConfigurations.$(host).config.system.build.toplevel \
	  --extra-experimental-features 'nix-command flakes'

	# Activate system
	sudo ./result/sw/bin/nixos-rebuild switch --flake .#$(host)

	# Build and switch home-manager config
	home-manager switch --flake .#$(user)@$(host)

