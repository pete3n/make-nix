# make-Nix v0.13
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.

MAKEFLAGS += --no-print-directory

ifeq ($(origin MAKE_NIX_ENV), undefined)
  MAKE_NIX_ENV := $(shell mktemp -t make-nix.env.XXXXXX)
  export MAKE_NIX_ENV
  MAKE_NIX_LOG := $(shell mktemp -t make-nix.log.XXXXXX)
  MAKE_NIX_INSTALLER := $(shell mktemp -t make-nix_installer.XXXXXX)
  $(shell printf "MAKE_NIX_LOG=%s\n" "$(MAKE_NIX_LOG)" >> "$(MAKE_NIX_ENV)")
  $(shell printf "MAKE_NIX_INSTALLER=%s\n" "$(MAKE_NIX_INSTALLER)" >> "$(MAKE_NIX_ENV)")
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
help: init-env show-help clean

.PHONY: show-help
show-help:
	@if [ "$(MAKECMDGOALS)" = "" ]; then \
		printf "\nYou must provide a make target.\n"; \
		sh scripts/print_help.sh; \
	else sh scripts/print_help.sh; fi

.PHONY: init-env
init-env:
	@sh scripts/set_environment.sh

.PHONY: check-dependencies
check-dependencies:
	@sh scripts/check_dependencies.sh

.PHONY: installer-os-check
installer-os-check:
	@if [ "$(UNAME_S)" != "Linux" ] && [ "$(UNAME_S)" != "Darwin" ]; then \
		echo "Unsupported OS: $(UNAME_S)"; \
		exit 1; \
	fi

.PHONY: check-nix-integrity
check-nix-integrity:
	@MAKE_NIX_ENV=$(MAKE_NIX_ENV)sh scripts/check_nix_integrity.sh

.PHONY: launch-installers
launch-installers:
	@UNAME_S=$(UNAME_S) sh scripts/launch_installers.sh

.PHONY: write-build-target
write-build-target:
	@BUILD_TARGET_HOST="$(host)" \
	BUILD_TARGET_USER="$(user)" BUILD_TARGET_SYSTEM="$(system)" \
	BUILD_TARGET_IS_LINUX=$(isLinux) BUILD_TARGET_SPECIALISATIONS=$(spec) \
	sh scripts/write_build_target.sh

.PHONY: check-dirty-warn
check-dirty-warn:
	@sh scripts/check_dirty_warn.sh

.PHONY: clean
clean:
	@sh scripts/clean.sh

.PHONY: build-darwin-home
build-darwin-home:
	@BUILD_DARWIN_HOST=$(host) BUILD_DARWIN_USER=$(user) \
	sh scripts/build_darwin_home.sh

.PHONY: activate-darwin-home
activate-darwin-home:
	@ACTIVATE_DARWIN_HOST=$(host) ACTIVATE_DARWIN_USER=$(user) \
	sh scripts/activate_darwin_home.sh

.PHONY: build-linux-home
build-linux-home:
	@BUILD_LINUX_HOST=$(host) BUILD_LINUX_USER=$(user) \
	sh scripts/build_linux_home.sh

.PHONY: activate-linux-home
activate-linux-home:
	@ACTIVATE_LINUX_HOST=$(host) ACTIVATE_LINUX_USER=$(user) \
	sh scripts/activate_linux_home.sh

.PHONY: build-darwin-system
build-darwin-system:
	@BUILD_DARWIN_HOST=$(host) sh scripts/build_darwin_system.sh

.PHONY: activate-darwin-system
activate-darwin-system:
	@ACTIVATE_DARWIN_HOST=$(host) sh scripts/activate_darwin_system.sh

.PHONY: build-linux-system
build-linux-system:
	@BUILD_LINUX_HOST=$(host) sh scripts/build_linux_system.sh

.PHONY: activate-linux-system
activate-linux-system:
	@ACTIVATE_LINUX_HOST=$(host) sh scripts/activate_linux_system.sh

.PHONY: home-platforms
home-platforms:
ifeq ($(isLinux),true)
	$(MAKE) build-linux-home check-dirty-warn activate-linux-home
else
	$(MAKE) build-darwin-home check-dirty-warn activate-darwin-home
endif

.PHONY: system-platforms
system-platforms:
ifeq ($(isLinux),true)
	$(MAKE) build-linux-system check-dirty-warn activate-linux-system
else
	$(MAKE) build-darwin-system check-dirty-warn activate-darwin-system
endif

.PHONY: flake-check
flake-check:
	@sh scripts/flake_check.sh

.PHONY: set-specialisation-boot
set-specialisation-boot:
	@sh scripts/set_specialisation_boot.sh

.PHONY: install-nix
install-nix: installer-os-check check-nix-integrity launch-installers

.PHONY: install-with-clean
install-with-clean:
	@$(MAKE) install-nix || true; \
	$(MAKE) clean

.PHONY: install home system all test
install: init-env check-dependencies install-with-clean
home: init-env check-dependencies write-build-target home-platforms check-dirty-warn clean
system: init-env check-dependencies write-build-target system-platforms check-dirty-warn set-specialisation-boot clean
all: init-env check-dependencies system-platforms home-platforms clean
test: init-env check-dependencies write-build-target flake-check check-dirty-warn clean
