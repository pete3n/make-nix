# make-Nix v0.1.4
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.

MAKEFLAGS += --no-print-directory
UNAME_S := $(shell uname -s)

ifeq ($(origin MAKE_NIX_ENV), undefined)
  MAKE_NIX_ENV := $(shell mktemp -t make-nix.env.XXXXXX)
  export MAKE_NIX_ENV
  MAKE_NIX_LOG := $(shell mktemp -t make-nix.log.XXXXXX)
  export MAKE_NIX_LOG
  MAKE_NIX_INSTALLER := $(shell mktemp -t make-nix_installer.XXXXXX)
  export MAKE_NIX_INSTALLER
  $(shell printf "MAKE_NIX_LOG=%s\n" "$(MAKE_NIX_LOG)" >> "$(MAKE_NIX_ENV)")
  $(shell printf "MAKE_NIX_INSTALLER=%s\n" "$(MAKE_NIX_INSTALLER)" >> "$(MAKE_NIX_ENV)")
  $(shell printf "UNAME_S=%s\n" "$(UNAME_S)" >> "$(MAKE_NIX_ENV)")
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
	@sh scripts/check_nix_integrity.sh

.PHONY: launch-installers
launch-installers:
	@sh scripts/launch_installers.sh

.PHONY: write-build-target
write-build-target:
	@sh scripts/write_build_target.sh

.PHONY: check-dirty-warn
check-dirty-warn:
	@sh scripts/check_dirty_warn.sh

.PHONY: clean
clean:
	@sh scripts/clean.sh

.PHONY: build-home
build-home:
	@sh scripts/home.sh --build

.PHONY: activate-home
activate-home:
	@sh scripts/home.sh --activate

.PHONY: build-system
build-system:
	@sh scripts/system.sh --build

.PHONY: activate-system
activate-system:
	@sh scripts/system.sh --activate

.PHONY: flake-check
flake-check:
	@sh scripts/flake_check.sh

.PHONY: set-specialisation-boot
set-specialisation-boot:
	@sh scripts/set_specialisation_boot.sh

.PHONY: installs
installs:
	@sh scripts/installs.sh

.PHONY: home home-all install system system-all all test
home: init-env check-dependencies write-build-target build-home activate-home check-dirty-warn clean
home-all: build-home activate-home check-dirty-warn
install: init-env installs clean
system: init-env check-dependencies write-build-target build-system activate-system check-dirty-warn set-specialisation-boot clean
system-all: build-system activate-system check-dirty-warn set-specialisation-boot
all: init-env check-dependencies write-build-target system-all home-all clean
test: init-env check-dependencies write-build-target flake-check check-dirty-warn clean
