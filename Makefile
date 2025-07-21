define n


endef

define usage_text
make <home|system|all> [host=<host>] [user=<user>] [system=<system>] [specialisation-flags]

Usage examples:
make home
-- switches home-manager config for current user; autodetects system type.

make home user=joe
-- switches home-manager config for username joe; autodetects system type.

make home user=sam system=aarch64-darwin
-- switches home-manager config for username sam; targets an aarch64-darwin platform.

make system
-- rebuilds and switches current system config; autodetects hostname and system platform.

make system host=workstation1 system=aarch64-linux
-- rebuilds and switches the workstation1 system config; targets an aarch64-linux platform.

make all
-- rebuilds and switches current system and current user home-manager config, autodetects all settings:

make all host=workstation1 system=x86_64-linux user=joe
-- rebuilds and switches the home-manager config for username joe, on the workstation 1 system config; 
targets an x86_64-linux platform.
endef

export usage_text

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
	@echo "You must provide a make target."
	echo "Usage:"
	printf '%s\n' "$$usage_text"

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
	rm -f build-target.nix

darwin-home: build-target.nix
	@echo "Switching home-manager config for Darwin..."
	home-manager switch -b backup --flake .#$(user)@$(host)

linux-home: build-target.nix
	@echo "Switching home-manager config for Linux..."
	home-manager switch -b backup --flake .#$(user)@$(host)

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

# Branch to buiding for either Nix-Darwin or NixOS
home: build-target.nix
ifeq ($(isLinux),true)
	$(MAKE) linux-home

else
	$(MAKE) darwin-home
endif

# Branch to buiding for either Nix-Darwin or NixOS
system: build-target.nix
ifeq ($(isLinux),true)
	$(MAKE) linux-system

else
	$(MAKE) darwin-system
endif

all: build-target.nix
	$(MAKE) system
	$(MAKE) home

test:
	@echo "No tests defined."

.PHONY: build-target.nix # Overwrite existing
.PHONY: usage clean home system linux-system darwin-system all test
