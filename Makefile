# make-Nix v0.1.5
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.
.DEFAULT_GOAL := help
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

#
# Utility targets.
#

.PHONY: set-env
set-env:
	@sh scripts/set_env.sh

.PHONY: check-deps
check-deps:
	@sh scripts/check_deps.sh
.PHONY: clean
clean:
	@sh scripts/clean.sh

.PHONY: help
help: set-env show-help clean

.PHONY: show-help
show-help:
	@sh scripts/print_help.sh

#
# Install targets.
#

# Initialize environment, launch installers, and cleanup.
.PHONY: install
install: set-env installs clean

# Launch installers, including integrity and depdency checks.
.PHONY: installs
installs:
	@sh scripts/installs.sh

#
# Configuration targets.
#

# Home-manager home configuration and activation.
.PHONY: home
home: set-env check-deps write-build-target build-home activate-home check-dirty-warn clean

# NixOS system configuraiton and activation.
.PHONY: system
system: set-env check-deps write-build-target build-system activate-system check-dirty-warn set-spec-boot clean

# Alias all-config.
.PHONY: all
all: all-config

# Configure and activate both system and home.
.PHONY: all-config
all-config: set-env check-deps write-build-target all-system all-home clean

# Home target used by all-config (assumes write target and cleanup handled).
.PHONY: all-home
all-home: build-home activate-home check-dirty-warn

# System target used by all-config (assumes write target and cleanup handled).
.PHONY: all-system
all-system: build-system activate-system check-dirty-warn set-spec-boot

# Check all flake configurations
.PHONY: test
test: set-env check-deps write-build-target flake-check check-dirty-warn clean

#
# Configuration utility targets
#

# Pass imperative configuration from make to Nix via build-target.nix
.PHONY: write-build-target
write-build-target:
	@sh scripts/write_build_target.sh

# Build flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: build-home
build-home:
	@sh scripts/home.sh --build

# Activate flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: activate-home
activate-home:
	@sh scripts/home.sh --activate

# Build flake-based system configurations for Linux or Darwin systems.
.PHONY: build-system
build-system:
	@sh scripts/system.sh --build

# Activate flake-based system configurations for Linux or Darwin systems.
.PHONY: activate-system
activate-system:
	@sh scripts/system.sh --activate

# Set the default boot menu option to the first specified specialisation for a system.
.PHONY: set-spec-boot
set-spec-boot:
	@sh scripts/set_spec_boot.sh

# Check for a dirty git tree and warn on a failed build about the confusing
# missing path error. I should not have to write this...
.PHONY: check-dirty-warn
check-dirty-warn:
	@sh scripts/check_dirty_warn.sh

# Check all flake configurations; called by test.
.PHONY: flake-check
flake-check:
	@sh scripts/flake_check.sh

%:
	@printf "Unknown target: '$@'\n"
	@printf "Valid targets: help install home system all test\n"
	@false
