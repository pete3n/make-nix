define n


endef

ifndef user
  user := $(shell whoami)
  $(info user was not passed...$(n)Defaulting to current user: $(user)$(n))
endif

ifndef host
  host := $(shell hostname)
  $(info host was not passed...$(n)Defaulting to current hostname: $(host)$(n))
endif

ifndef system
  system := $(shell nix eval --impure --raw --expr 'builtins.currentSystem')
  $(info system was not passed...$(n)Defaulting to current system: $(system)$(n))
endif

ifeq ($(findstring linux,$(system)),linux)
  isLinux := true
else
  isLinux := false
endif

usage:
	$(info Usage:$(n) \
		make <home|system|all> [host=<host>] [user=<user>] [system=<system>] [specialisation-flags]$(n) \
		$(n) \
		Examples$(n) \
		$(n) \
		Switch home-manager config for current user, autodetecting system type:$(n) \
		make home$(n) \
		$(n) \
		Switch home-manager config for a specified user, autodetecting system type:$(n) \
	  make home user=joe$(n) \
		$(n) \
		Switch home-manager config for a specified user and a specified system type:$(n) \
		make home user=sam system=aarch64-darwin$(n) \
		$(n) \
		Rebuild and switch current system config, autodetecting hostname and system type:$(n) \
		make system$(n) \
		$(n) \
		Rebuild and switch the specified host config for the specified system type:$(n) \
		make system host=workstation1 system=aarch64-linux$(n) \
		$(n) \
		Rebuild and switch current system and current user home-manager config, autodetecting all:$(n) \
		make all$(n) \
		$(n) \
		Rebuild and switch the specified host config for the specified system type and \
		home-manager configuration for the specified user:$(n) \
		$(n) \
		make all host=workstation1 system=x86_64-linux user=joe$(n))

build-target.nix:
	@echo "Writing build-target.nix with:"; \
	echo "  user = $(user)"; \
	echo "  host = $(host)"; \
	echo "  system = $(system)"; \
	echo "  isLinux = $(isLinux)"; \
	printf '{ ... }:\n{\n' > build-target.nix; \
	printf '  user = "%s";\n' "$(user)" >> build-target.nix; \
	printf '  host = "%s";\n' "$(host)" >> build-target.nix; \
	printf '  system = "%s";\n' "$(system)" >> build-target.nix; \
	printf '  isLinux = %s;\n' "$(isLinux)" >> build-target.nix; \
	printf '}\n' >> build-target.nix

clean:
	@echo "Removing build-target.nix..."
	@rm -f build-target.nix

darwin-system:
	nix build .#darwinConfigurations.$(host).system \
	   --extra-experimental-features 'nix-command flakes'
	
	# Activate system
	./result/sw/bin/darwin-rebuild switch --flake .#$(host)

linux-system:
	nix build .#nixosConfigurations.$(host).config.system.build.toplevel \
	  --extra-experimental-features 'nix-command flakes'

	# Activate system
	sudo ./result/sw/bin/nixos-rebuild switch --flake .#$(host)

home: build-target.nix
	@echo "Switching home-manager config for Darwin..."
	home-manager switch -b backup --flake .#$(user)

# Branch to buiding for either Nix-Darwin or NixOS
system:  build-target.nix
ifeq ($(isLinux),true)
	$(MAKE) linux-system

else
	$(MAKE) darwin-system
endif

all: build-target.nix
	$(MAKE) system
	$(MAKE) home

.PHONY: build-target.nix # Overwrite existing
.PHONY: usage clean home system linux-system darwin-system all
