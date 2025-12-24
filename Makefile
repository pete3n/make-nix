# make-Nix v0.1.7
# This Makefile provides targets to install and configure Nix, Nix-Darwin,
# and Nix Home-manager for MacOS and Linux systems. It can build and deploy on
# NixOS and Nix-Darwin managed systems, as well as on other Linux distributions
# using Nix Home-manager configurations.
# Please see https://github.com/pete3n/make-nix for documentation.
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory
SHELL := /bin/sh

UNAME_S := $(shell uname -s)

ifeq ($(shell id -u),0)
	ifneq ($(filter help,$(MAKECMDGOALS)),help)
		$(error Do not run make as root. Run as a normal user; sudo will be used when needed.)
	endif
endif

ifeq ($(origin MAKE_NIX_TMPDIR), undefined)
  MAKE_NIX_TMPDIR := $(shell TMPDIR="$${TMPDIR:-/tmp}"; mktemp -d "$$TMPDIR/make-nix.XXXXXX")
  export MAKE_NIX_TMPDIR
endif

ifeq ($(origin MAKE_NIX_ENV), undefined)
  MAKE_NIX_ENV := $(MAKE_NIX_TMPDIR)/env
  MAKE_NIX_LOG := $(MAKE_NIX_TMPDIR)/log
  MAKE_NIX_INSTALLER := $(MAKE_NIX_TMPDIR)/installer
  export MAKE_NIX_ENV MAKE_NIX_LOG MAKE_NIX_INSTALLER

  # Ensure the files exist before appending
  $(shell : > "$(MAKE_NIX_ENV)")
  $(shell : > "$(MAKE_NIX_LOG)")
  $(shell : > "$(MAKE_NIX_INSTALLER)")

  # Seed the env file with the other paths you want to source in common.sh
  $(shell printf "MAKE_NIX_LOG=%s\n" "$(MAKE_NIX_LOG)" >> "$(MAKE_NIX_ENV)")
  $(shell printf "MAKE_NIX_INSTALLER=%s\n" "$(MAKE_NIX_INSTALLER)" >> "$(MAKE_NIX_ENV)")
  $(shell printf "UNAME_S=%s\n" "$(shell uname -s)" >> "$(MAKE_NIX_ENV)")
endif

define IS_LAST
$(if $(filter $@,$(lastword $(MAKECMDGOALS))),1,0)
endef

#
# Utility targets.
#

.PHONY: set-env
set-env:
	@sh scripts/set_env.sh

.PHONY: check-deps
check-deps:
	@sh scripts/check_deps.sh "$(MAKECMDGOALS)"
.PHONY: clean
clean:
	@sh scripts/clean.sh

.PHONY: help
help: set-env show-help clean

.PHONY: show-help
show-help:
	@sh scripts/print_help.sh -F $(IS_LAST)

#
# Install/uninstall targets.
#

.PHONY: install
install: set-env check-deps installs

.PHONY: installs
installs:
	@sh scripts/installs.sh -F $(IS_LAST)

.PHONY: uninstall
uninstall: set-env uninstalls

.PHONY: uninstalls
uninstalls:
	@sh scripts/uninstalls.sh -F $(IS_LAST)

#
# Configuration targets.
#

# Single-target home configuration.
.PHONY: home
home: set-env check-deps write-nix-attrs build-home activate-home check-dirty-warn clean

# Single-target NixOS or Nix-Darwin system configuration.
.PHONY: system
system: set-env check-deps write-nix-attrs build-system activate-system check-dirty-warn set-spec-boot clean

# Alias all-config.
.PHONY: all
all: all-config

# Execute both system and home targets.
.PHONY: all-config
all-config: set-env check-deps write-nix-attrs all-system all-home clean

# Home target used by all-config (environment setup and cleanup called by all-config.)
.PHONY: all-home
all-home: build-home activate-home check-dirty-warn

# System target used by all-config (environment setup and cleanup called by all-config.)
.PHONY: all-system
all-system: build-system activate-system check-dirty-warn set-spec-boot

# Check all flake configurations.
.PHONY: test
test: set-env check-deps write-nix-attrs flake-check check-dirty-warn clean

#
# Configuration utility targets
#

# Pass imperative configuration attributes from make to flake.nix
.PHONY: write-nix-attrs
write-nix-attrs:
	@sh scripts/write_nix_attrs.sh

# Build flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: build-home
build-home:
	@sh scripts/home.sh -F $(IS_LAST) --build

# Activate flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: activate-home
activate-home:
	@sh scripts/home.sh -F $(IS_LAST) --activate

# Build flake-based system configurations for Linux or Darwin systems.
.PHONY: build-system
build-system:
	@sh scripts/system.sh -F $(IS_LAST) --build

# Activate flake-based system configurations for Linux or Darwin systems.
.PHONY: activate-system
activate-system:
	@sh scripts/system.sh -F $(IS_LAST) --activate

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
