# make-Nix v0.12
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.
LOG_PATH = /tmp/make-nix.out
UNAME_S := $(shell uname -s)

ifeq ($(BOOT_SPEC),1)
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

.PHONY: help
help:
	@printf "\nYou must provide a make target.\n"
	@sh scripts/print_help.sh

.PHONY: check-dependencies
check-dependencies:
	@sh scripts/check_dependencies.sh

.PHONY: os-check
os-check:
	@if [ "$(UNAME_S)" != "Linux" ] && [ "$(UNAME_S)" != "Darwin" ]; then \
		echo "Unsupported OS: $(UNAME_S)"; \
		exit 1; \
	fi

.PHONY: check-nix-integrity
check-nix-integrity:
	@{ \
		DETERMINATE=$(DETERMINATE) sh scripts/check_nix_integrity.sh; \
	}

.PHONY: launch-installers
launch-installers:
	@{ \
		DETERMINATE=$(DETERMINATE) UNAME_S=$(UNAME_S) sh scripts/launch_installers.sh; \
	}

.PHONY: write-build-target
write-build-target:
	@host="$(host)" user="$(user)" system="$(system)" \
	sh scripts/write_build_target.sh $(if $(spec),spec=$(spec))

.PHONY: check-dirty-warn
check-dirty-warn:
	@sh scripts/check_dirty_warn.sh

.PHONY: remove_nix_installer
remove_nix_installer:
	@{ if [ -f scripts/nix_installer.sh ]; then rm -f scripts/nix_installer.sh; fi; }

.PHONY: remove_build_log
remove_build_log:
	@{ if [ -f $(LOG_PATH) ]; then rm -f $(LOG_PATH); fi; }

.PHONY: clean
clean: remove_nix_installer remove_build_log

.PHONY: build-darwin-home
build-darwin-home:
	@{ \
		LOG_PATH=$(LOG_PATH) DRY_RUN=$(DRY_RUN) sh scripts/build_darwin_home.sh; \
	}

.PHONY: activate-darwin-home
	@{ \
		LOG_PATH=$(LOG_PATH) DRY_RUN=$(DRY_RUN) sh scripts/activate_darwin_home.sh; \
	}

.PHONY: build-linux-home
build-linux-home:
ifeq ($(DRY_RUN),1)
	@{ \
		printf "\n%bDry-run%b %benabled%b: configuration will not be activated.\n" \
			"$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"; \
		printf "Building home-manager configuration for Linux...\n"; \
		script -q -c "nix run nixpkgs#home-manager -- build $(dry_run) \
			--flake .#$(user)@$(host)" $(LOG_PATH); \
	}
else
	@{ \
		printf "Building home-manager config for Linux...\n"; \
		script -q -c "nix run nixpkgs#home-manager -- build --flake .#$(user)@$(host)" $(LOG_PATH); \
	}
endif

.PHONY: activate-linux-home
activate-linux-home:
ifeq ($(DRY_RUN),1)
	@printf "\n%bDry-run%b %benabled%b: skipping home activiation...\n" "$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"
else
	@{
		printf "\nSwitching home-manager configuration...\n"; \
		printf nix run nixpkgs#home-manager -- switch -b backup --flake .#$(user)@$(host); \
		script -q -c "nix run nixpkgs#home-manager -- switch -b backup --flake .#$(user)@$(host)" $(LOG_PATH); \
	}
endif

.PHONY: build-darwin-system
build-darwin-system:
ifeq ($(DRY_RUN),1)
	@{ \
		printf "\n%bDry-run%b %benabled%b, nothing will be built.\n" "$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"; \
		printf nix build --dry-run .#darwinConfigurations.$(host).system --extra-experimental-features 'nix-command flakes'; \
		nix build $(dry_run) .#darwinConfigurations.$(host).system \
		 --extra-experimental-features 'nix-command flakes'; \
	}
else
	@{ \
		printf "\nBuilding system config for Darwin...\n"; \
		printf nix build .#darwinConfigurations.$(host).system --extra-experimental-features 'nix-command flakes'; \
		nix build .#darwinConfigurations.$(host).system \
		 --extra-experimental-features 'nix-command flakes'; \
	}
endif

.PHONY: activate-darwin-system
activate-darwin-system:
ifeq ($(DRY_RUN),1)
	@printf "\n%bDry-run%b %benabled%b: skipping system activiation...\n" "$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"
else
	@printf "Activating system config for Darwin..."
	sudo ./result/sw/bin/darwin-rebuild switch --flake .#$(host)
endif

.PHONY: build-linux-system
build-linux-system:
ifeq ($(DRY_RUN),1)
	@{ \
		printf "\n%bDry-run%b %benabled:%b nothing will be built...\n" "$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"; \
		printf nix build --dry-run .#nixosConfigurations.$(host).config.system.build.toplevel --extra-experimental-features 'nix-command flakes'; \
		script -q -c "nix build $(dry_run) .#nixosConfigurations.$(host).config.system.build.toplevel \
		 --extra-experimental-features 'nix-command flakes'" $(LOG_PATH); \
	}
else
	@{ \
		printf "\nBuilding system config for Linux...\n"; \
		printf nix build .#nixosConfigurations.$(host).config.system.build.toplevel --extra-experimental-features 'nix-command flakes'; \
		script -q -c "nix build .#nixosConfigurations.$(host).config.system.build.toplevel \
		 --extra-experimental-features 'nix-command flakes'" $(LOG_PATH); \
	}
endif

.PHONY: activate-linux-system
activate-linux-system:
ifeq ($(DRY_RUN),1)
	@printf "\n%bDry-run%b %benabled%b: skipping system activiation...\n" "$(BLUE)" "$(RESET)" "$(GREEN)" "$(RESET)"
else
	@printf "\nActivating system config for Linux...\n"
	@sudo ./result/sw/bin/nixos-rebuild switch --flake .#$(host)
endif

.PHONY: home-platforms
home-platforms:
ifeq ($(isLinux),true)
	$(MAKE) build-linux-home activate-linux-home
else
	$(MAKE) build-darwin-home activate-darwin-home
endif

.PHONY: system-platforms
system-platforms:
ifeq ($(isLinux),true)
	$(MAKE) build-linux-system activate-linux-system
else
	$(MAKE) build-darwin-system activate-darwin-system
endif

.PHONY: flake-check
flake-check:
	@{ \
		script -q -c "nix flake check --all-systems --extra-experimental-features 'nix-command flakes'" $(LOG_PATH); \
	}

.PHONY: set-specialisation-boot
set-specialisation-boot:
ifeq ($(boot_special),true)
	@{ \
		spec=$(spec) \
		sh scripts/set_specialisation_boot.sh; \
	}
endif

.PHONY: install-nix
install-nix: os-check check-nix-integrity launch-installers

.PHONY: install-with-clean
install-with-clean:
	@$(MAKE) install-nix || true; \
	$(MAKE) clean

.PHONY: install home system all test
install: check-dependencies install-with-clean
home: check-dependencies write-build-target home-platforms check-dirty-warn clean
system: check-dependencies write-build-target system-platforms check-dirty-warn set-specialisation-boot clean
all: check-dependencies system home clean
test: check-dependencies write-build-target flake-check check-dirty-warn clean
