# make-Nix v0.11
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.

REQUIRED_UTILS = cat curl cut find git hostname printf sh shasum sudo uname whoami

# nix-2.30.1 install script 
NIX_INSTALL_URL=https://releases.nixos.org/nix/nix-2.30.1/install
# sha1 hash as of 22-Jul-2025
NIX_INSTALL_HASH="b8ef91a7faf2043a1a3705153eb38881a49de158"

# Determinate Systems Nix installer 3.8.2
DETERMINATE_INSTALL_URL=https://raw.githubusercontent.com/DeterminateSystems/nix-installer/6beefac4d23bd9a0b74b6758f148aa24d6df3ca9/nix-installer.sh
# sha1 hash as of 22-Jul-2025
DETERMINATE_INSTALL_HASH="ac1bc597771e10eecf2cb4e85fc35c4848981a70"

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

ifeq ($(BOOT_SPECIAL),1)
	boot_special := true
else
	boot_special := false
endif

ifndef user
user := $(shell whoami)
endif

ifndef host
host := $(shell hostname)
endif

ifndef system
system := $(shell nix eval --impure --raw --expr 'builtins.currentSystem')
endif

ifeq ($(findstring linux,$(system)),linux)
	isLinux := true
else
	isLinux := false
endif

# ANSI escape sequences for formatting
BOLD=\033[1m
BLUE=\033[1;34m
CYAN=\033[1;36m
GREEN=\033[1;32m
MAGENTA=\033[0;35m
RED=\033[0;31m
YELLOW=\033[1;33m
RESET=\033[0m

define usage_text
  $(RED)make$(RESET) $(BOLD)<install|home|system|all|test>$(RESET) [$(CYAN)host$(RESET)$(RED)=$(RESET)<host>]\
[$(CYAN)user$(RESET)$(RED)=$(RESET)<user>] [$(CYAN)system$(RESET)$(RED)=$(RESET)<system>]\
[$(BLUE)option variables$(RESET)]

  Option variables:
  $(BLUE)DRY_RUN$(RESET)$(RED)=$(RESET)1 $(GREEN)-\
Evaluate the target but do not build or switch the configuration.$(RESET)
  $(BLUE)EGPU$(RESET)$(RED)=$(RESET)1 $(GREEN)- Build the eGPU host specialisation.$(RESET)
  $(BLUE)WAYLAND$(RESET)$(RED)=$(RESET)1 $(GREEN)- Build the Wayland host specialisation.$(RESET)
  $(BLUE)X11$(RESET)$(RED)=$(RESET)1 $(GREEN)-\
Build the X11 host specialisation.$(RESET)
  $(BLUE)BOOT_SPECIAL$(RESET)$(RED)=$(RESET)1 $(GREEN)-\
Set the default boot menu option to the built specialisation.$(RESET)
  $(BLUE)SINGLE_USER$(RESET)$(RED)=$(RESET)1 $(GREEN)Install Nix for single-user mode.$(RESET)
  $(BLUE)DETERMINATE$(RESET)$(RED)=$(RESET)1 $(GREEN)User the Determinate Systems installer.$(RESET)
  $(BLUE)NIX_DARWIN$(RESET)$(RED)=$(RESET)1 $(GREEN)Install Nix-Darwin for MacOS.$(RESET)

  Usage examples:
  $(GREEN)- Switch the home-manager configuration for current user; autodetect system type:$(RESET)
    $(RED)make$(RESET) $(BOLD)home$(RESET)

  $(GREEN)- Switch the home-manager configuration for user joe; autodetect system type:$(RESET)
    $(RED)make$(RESET) $(BOLD)home$(RESET) $(CYAN)user$(RESET)$(RED)=$(RESET)joe

  $(GREEN)- Switch the home-manager configuration for user sam; target an aarch64-darwin platform:$(RESET)
    $(RED)make$(RESET) $(BOLD)home$(RESET) $(CYAN)user$(RESET)$(RED)=$(RESET)sam\
$(CYAN)system$(RESET)$(RED)=$(RESET)aarch64-darwin

  $(GREEN)- Rebuild and switch the current system's configuration; autodetect hostname and system platform:$(RESET)
    $(RED)make$(RESET) $(BOLD)system$(RESET)

  $(GREEN)- Rebuild and switch the system configuration for host workstation1; target an aarch64-linux platform:$(RESET)
    $(RED)make$(RESET) $(BOLD)system $(CYAN)host$(RESET)=workstation1 $(CYAN)system$(RESET)=aarch64-linux

  $(GREEN)- Rebuild and switch the current system's configuration and current user's home-manager configuration;
    autodetect all settings:$(RESET)
    $(RED)make$(RESET) $(BOLD)all$(RESET)

  $(GREEN)- Evaluate the current system's configuration and current user's home-manager config;
    autodetect all settings:$(RESET)
    $(RED)make$(RESET) $(BOLD)all$(RESET) $(BLUE)DRY_RUN$(RESET)$(RED)=$(RESET)1

  $(GREEN)- Rebuild and switch the current system's configuration and current user's home-manager configuration;
    autodetect all settings:$(RESET)
    $(RED)make$(RESET) $(BOLD)all$(RESET) $(BLUE)WAYLAND$(RESET)$(RED)=$(RESET)1\
$(BLUE)BOOT_SPECIAL$(RESET)$(RED)=$(RESET)1

  $(GREEN)- Rebuild and switch the system configuration for host workstation1,\
and home-manager configuration for user joe;
    target an x86_64-linux platform:$(RESET)
    $(RED)make$(RESET) $(BOLD)all$(RESET) $(CYAN)host$(RESET)$(RED)=$(RESET)workstation1\
$(CYAN)system$(RESET)$(RED)=$(RESET)x86_64-linux $(CYAN)user$(RESET)$(RED)=$(RESET)joe

  $(GREEN)- Run '$(RESET)$(RED)nix flake check$(RESET)$(GREEN)' for all system and home-manager configurations:$(RESET)
    $(RED)make$(RESET) $(BOLD)test$(RESET)
endef

export usage_text

usage:
	@printf "\nYou must provide a make target.\n"
	@printf "Usage:\n"
	@printf '%b\n' "$$usage_text"

dep_check:
	@missing=0; \
	for cmd in $(REQUIRED_UTILS); do \
		if ! command -v $$cmd >/dev/null 2>&1; then \
			echo "Missing: $$cmd"; \
			missing=1; \
		fi; \
	done; \
	if [ "$$missing" -eq 0 ]; then \
		echo "✅ All required dependencies are installed."; \
	else \
		echo "❌ Some dependencies are missing."; \
		exit 1; \
	fi

os_check:
	@{ UNAME_S=$$(uname -s); case $$UNAME_S in Linux|Darwin) \
			;; \
			*) echo "Unsupported OS: $$UNAME_S"; exit 1 ;; \
		esac; }

integrity_check:
	@$(if $(DETERMINATE), \
		scripts/nix_integrity.sh $(DETERMINATE_INSTALL_URL) $(DETERMINATE_INSTALL_HASH), \
		scripts/nix_integrity.sh $(NIX_INSTALL_URL) $(NIX_INSTALL_HASH))

run_nix_installer:
	@{ \
		printf "\n>>> Installing Nix...\n"; \
	 	if [ -z "$(DETERMINATE)" ]; then \
			INSTALL_FLAGS="$(if $(SINGLE_USER),--no-daemon,--daemon)"; \
		else \
			INSTALL_FLAGS="install"; \
		fi; \
		./scripts/nix_installer.sh $$INSTALL_FLAGS; \
	}

maybe_install_nix_darwin:
	@if [ "$(NIX_DARWIN)" = "1" ]; then \
		if [ "$$(uname -s)" = "Darwin" ]; then \
			sudo nix run .#nix-darwin.darwin-rebuild -- switch; \
		else \
			printf "Skipping nix-darwin install: macOS not detected.\n"; \
		fi; \
	fi

define check_git_dirty
	if [ -n "$$(git status --porcelain)" ]; then \
		printf '$(YELLOW)⚠️ Warning: Git tree is dirty!\n$(RESET)'; \
		printf "This may cause an '$(RED)error:$(RESET) path $(MAGENTA)/nix/store/...$(RESET) does not exist' error message when evaluating flakes.\n"; \
		printf "Make sure all relevant files are tracked with Git using:\n"; \
		printf "  $(RED)git add$(RESET) <file>\n\n"; \
		printf "Or check for accidental changes with:\n"; \
		printf "  $(RED)git status$(RESET)\n\n"; \
	fi
endef

export check_git_dirty

build-target.nix:
	@{ \
		echo ""; \
		echo "Writing build-target.nix with:"; \
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
		printf '}\n' >> build-target.nix; \
	}	
	@git add --sparse build-target.nix

remove_build_target:
	@{ \
		printf "\n Cleaning up...\n"; \
		if [ -f build-target.nix ]; then \
			git rm --sparse --cached --ignore-unmatch --quiet -f build-target.nix; \
			rm -f build-target.nix; \
		fi; \
	}

remove_nix_installer:
	@{ if [ -f scripts/nix_installer.sh ]; then rm -f scripts/nix_installer.sh; fi; }

clean: remove_build_target remove_nix_installer

darwin-home:
	@{ \
		echo "Switching home-manager config for Darwin..."; \
		nix run nixpkgs#home-manager -- switch -b backup $(dry_run) --flake .#$(user)@$(host); \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

linux-home:
	@{ \
		echo "Switching home-manager config for Linux..."; \
		nix run nixpkgs#home-manager -- switch -b backup $(dry_run) --flake .#$(user)@$(host); \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

build-darwin-system:
	@echo ""
ifeq ($(DRY_RUN),1)
	@{ \
		echo "Dry-run enabled, nothing will be built."; \
		echo nix build --dry-run .#darwinConfigurations.$(host).system --extra-experimental-features 'nix-command flakes'; \
		nix build $(dry_run) .#darwinConfigurations.$(host).system \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}
else
	@{ \
		echo "Building system config for Darwin..."; \
		echo nix build .#darwinConfigurations.$(host).system --extra-experimental-features 'nix-command flakes'; \
		nix build .#darwinConfigurations.$(host).system \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}
endif

activate-darwin-system:
	@echo ""
ifeq ($(DRY_RUN),1)
	@echo "Dry-run enabled, skipping system activation."
else
	@echo "Activating system config for Darwin..."
	sudo ./result/sw/bin/darwin-rebuild switch --flake .#$(host)
endif

build-linux-system:
	@echo ""
ifeq ($(DRY_RUN),1)
	@{ \
		echo "Dry-run enabled, nothing will be built."; \
		echo nix build --dry-run .#nixosConfigurations.$(host).config.system.build.toplevel --extra-experimental-features 'nix-command flakes'; \
		nix build $(dry_run) .#nixosConfigurations.$(host).config.system.build.toplevel \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}
else
	@{ \
		echo "Building system config for Linux..."; \
		echo nix build .#nixosConfigurations.$(host).config.system.build.toplevel --extra-experimental-features 'nix-command flakes'; \
		nix build .#nixosConfigurations.$(host).config.system.build.toplevel \
		 --extra-experimental-features 'nix-command flakes'; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}
endif

activate-linux-system:
	@echo ""
ifeq ($(DRY_RUN),1)
	@echo "Dry-run enabled, skipping system activation."
else
	@echo ""
	@echo "Activating system config for Linux..."
	@sudo ./result/sw/bin/nixos-rebuild switch --flake .#$(host)
endif

home-main: build-target.nix
	@echo ""
ifeq ($(isLinux),true)
	$(MAKE) linux-home
else
	$(MAKE) darwin-home
endif

system-main: build-target.nix
ifeq ($(isLinux),true)
	$(MAKE) build-linux-system activate-linux-system
else
	$(MAKE) build-darwin-system activate-darwin-system
endif

flake-check: build-target.nix
	@{ \
	  nix flake check --all-systems --extra-experimental-features 'nix-command flakes'; \
	  status=$$?; \
	  if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
	  fi; \
	}

# Determine the specialisation name
specialisation := $(strip \
  $(if $(WAYLAND),wayland) \
  $(if $(X11),x11) \
)$(if $(EGPU),_egpu)

set-specialisation-boot:
ifeq ($(boot_special),true)
	@{ \
		echo ""; \
		echo "Attempting to set default boot option for specialisation..."; \
		conf_file=$$(grep '^default ' /boot/loader/loader.conf | cut -d' ' -f2); \
		special_conf=$${conf_file%.conf}-specialisation-$(specialisation).conf; \
		if [ -f "/boot/loader/entries/$$special_conf" ]; then \
			echo "Found /boot/loader/entries/$$special_conf"; \
			echo "Backing up /boot/loader/loader.conf"; \
			sudo cp /boot/loader/loader.conf /boot/loader/loader.backup; \
			echo "Setting default boot to $$special_conf"; \
			sudo sed -i "s|^default .*|default $$special_conf|" /boot/loader/loader.conf; \
		else \
			echo "⚠️ Specialisation config not found: /boot/loader/entries/$$special_conf"; \
			exit 1; \
		fi \
	}
endif

install_nix: os_check integrity_check run_nix_installer maybe_install_nix_darwin
install-with-clean:
	@$(MAKE) install_nix || true; \
	$(MAKE) clean

install: dep_check install-with-clean
home: dep_check home-main
system: dep_check system-main set-specialisation-boot
all: dep_check system home clean
test: dep_check flake-check clean

.PHONY: build-target.nix # Overwrite build targets
.PHONY: usage install home system all clean test
