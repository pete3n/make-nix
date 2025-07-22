# This Makefile creates a build-target.nix containing an attribute set to configure
# systems, users, and specialisation options for the flake.nix.

ifeq ($(DRY_RUN),1)
	dry_run := --dry-run
else
	dry_run :=
endif

ifeq ($(X11),1)
	display_server := x11
endif

ifeq ($(WAYLAND),1)
	display_server := wayland
endif

ifeq ($(EGPU),1)
	egpu := true
else
	egpu := false
endif

# Autodetect user, host, and system
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

define check_git_dirty
	if [ -n "$$(git status --porcelain)" ]; then \
		echo "\033[1;33m⚠️  Warning: Git tree is dirty.\033[0m"; \
		echo "This may cause 'path does not exist' errors when evaluating flakes."; \
		echo "Make sure all relevant files are tracked with Git using:"; \
		echo "  git add <file>"; \
		echo ""; \
		echo "Or check for accidental changes with:"; \
		echo "  git status"; \
		echo ""; \
	fi
endef

export check_git_dirty

usage:
	@echo "You must provide a make target."
	@echo "Usage:"
	@printf '%s\n' "$$usage_text"

build-target.nix:
	@echo "Writing build-target.nix with:"; \
	echo "  user = $(user)"; \
	echo "  host = $(host)"; \
	echo "  system = $(system)"; \
	echo "  isLinux = $(isLinux)"; \
	echo "  egpu = $(egpu)"; \
	echo "  display_server = $(display_server)"; \
	printf '{ ... }:\n{\n' > build-target.nix; \
	printf '  user = "%s";\n' "$(user)" >> build-target.nix; \
	printf '  host = "%s";\n' "$(host)" >> build-target.nix; \
	printf '  system = "%s";\n' "$(system)" >> build-target.nix; \
	printf '  isLinux = %s;\n' "$(isLinux)" >> build-target.nix; \
	printf '  egpu = %s;\n' "$(egpu)" >> build-target.nix; \
	printf '  display_server = "%s";\n' "$(display_server)" >> build-target.nix; \
	printf '}\n' >> build-target.nix

clean:
	@echo "Removing build-target.nix..."
	rm -f build-target.nix

darwin-home:
	@{ \
		@echo "Switching home-manager config for Darwin..."
		home-manager switch -b backup $(dry-run) --flake .#$(user)@$(host)
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

linux-home:
	@{ \
		echo "Switching home-manager config for Linux..."; \
		home-manager switch -b backup $(dry-run) --flake .#$(user)@$(host); \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

build-darwin-system:
	@{ \ 
		echo "Building system config for Darwin..."; \
		nix build $(dry-run) .#darwinConfigurations.$(host).system \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

activate-darwin-system:
	@echo "Activating system config for Darwin..."
	./result/sw/bin/darwin-rebuild switch --flake .#$(host)

build-linux-system:
	@{ \
		echo "Building system config for Linux..."; \
		nix build $(dry-run) .#nixosConfigurations.$(host).config.system.build.toplevel \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

activate-linux-system:
	@echo "Activating system config for Linux..."
	sudo ./result/sw/bin/nixos-rebuild switch --flake .#$(host)

# Branch to buiding for either Nix-Darwin or NixOS
ifeq ($(isLinux),true)
home: build-target.nix
	$(MAKE) linux-home
else
home: build-target.nix
	$(MAKE) darwin-home
endif

# Branch to buiding for either Nix-Darwin or NixOS
ifeq ($(isLinux),true)
system: build-target.nix
	$(MAKE) build-linux-system
	$(MAKE) activate-linux-system
else
system: build-target.nix
	$(MAKE) build-darwin-system
	$(MAKE) activate-darwin-system
endif

all:
	$(MAKE) system
	$(MAKE) home

flake_check:
	@{ \
	  nix flake check; \
	  status=$$?; \
	  if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
	  fi; \
	}

test: flake_check

set-specialisation-default-boot:
	@echo "Setting default boot entry to: NixOS-$(specialisation)"
	@entry_name=$$( \
	  find /boot/loader/entries -type f -name "nixos-generation-*-specialisation-$(specialisation).conf" \
	  | sort -V \
	  | tail -n1 \
	); \
	if [ -z "$$entry_name" ]; then \
	  echo "No boot entry found for specialisation $(specialisation)"; \
	  exit 1; \
	fi; \
	sudo ln -sf "$$entry_name" /boot/loader/entries/default; \
	echo "Set default boot entry to: $$(basename $$entry_name)"

.PHONY: build-target.nix # Overwrite existing
.PHONY: usage clean home system linux-system darwin-system all test set-specialisation-default-boot
