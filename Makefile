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

ifeq ($(BOOT_SPECIAL),1)
	boot_special := true
else
	boot_special := false
endif

ifndef user
user := $(shell whoami)
$(info user was not passed...)
$(info Defaulting to current user: $(user))
endif

ifndef host
host := $(shell hostname)
$(info host was not passed...)
$(info Defaulting to current hostname: $(host))
endif

ifndef system
system := $(shell nix eval --impure --raw --expr 'builtins.currentSystem')
$(info system was not passed...)
$(info Defaulting to current system: $(system))
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
  $(RED)make$(RESET) $(BOLD)<home|system|all|test>$(RESET) [$(CYAN)host$(RESET)$(RED)=$(RESET)<host>]\
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
	@git add build-target.nix

clean:
	@{ if [ -f build-target.nix ]; then \
			echo "Removing build-target.nix..."; \
			git rm build-target.nix; \
			rm -f build-target.nix; \
		fi; }

darwin-home:
	@{ \
		echo "Switching home-manager config for Darwin..."; \
		home-manager switch -b backup $(dry_run) --flake .#$(user)@$(host); \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			$(check_git_dirty) \
		fi; \
		exit $$status; \
	}

linux-home:
	@{ \
		echo "Switching home-manager config for Linux..."; \
		home-manager switch -b backup $(dry_run) --flake .#$(user)@$(host); \
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
	./result/sw/bin/darwin-rebuild switch --flake .#$(host)
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

test: flake-check clean
home: home-main
system: system-main set-specialisation-boot
all: system home clean

.PHONY: build-target.nix # Overwrite build targets
.PHONY: usage home system all clean test
