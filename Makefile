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

#
# Utility targets.
#

.PHONY: validate-args
validate-args:
	@sh "scripts/validate_args.sh" $(MAKECMDGOALS)

.PHONY: set-env
set-env:
	@sh "scripts/set_env.sh"

.PHONY: check-deps
check-deps:
	@sh "scripts/check_deps.sh" $(MAKECMDGOALS)

.PHONY: prep-goal
prep-goal: validate-args set-env check-deps

.PHONY: clean
clean: prep-goal clean-sh

.PHONY: clean-sh
clean-sh: 
	@sh "scripts/clean.sh"

.PHONY: help
help: set-env show-help

.PHONY: show-help
show-help:
	@sh "scripts/print_help.sh"

#
# Install/uninstall targets.
#

.PHONY: install
install: prep-goal write-attrs-sh install-sh clean-sh

.PHONY: install-sh
install-sh:
	@sh "scripts/installs.sh"

.PHONY: uninstall
uninstall: prep-goal uninstall-sh

.PHONY: uninstall-sh
uninstall-sh:
	@sh "scripts/uninstalls.sh" $(MAKECMDGOALS)

#
# Check targets.
#

.PHONY: check
check: prep-goal check-sh clean-sh

.PHONY: check-read
check-read: prep-goal read-attrs-sh clean-sh

.PHONY: check-home
check-home: prep-goal check-home-sh clean-sh

.PHONY: check-system
check-system: prep-goal check-system-sh clean-sh

# Check previous configuration based on username and hostname
.PHONY: check-sh
check-sh:
	@sh "scripts/attrs.sh" --check-all

# Check previous home configuration based on username and hostname
.PHONY: check-home-sh
check-home-sh:
	@sh "scripts/attrs.sh" --check-home

# Check previous system configuration based on username and hostname
.PHONY: check-system-sh
check-system-sh:
	@sh "scripts/attrs.sh" --check-system

# Pass imperative configuration attributes from make to flake.nix
.PHONY: write-attrs-sh
write-attrs-sh:
	@sh "scripts/attrs.sh" --write

# Read imperative configuration attributes
.PHONY: read-attrs-sh
read-attrs-sh:
	@sh "scripts/attrs.sh" --read

#
# Build targets.
#

.PHONY: build
build: prep-goal write-attrs-sh check-sh build-system-sh build-home-sh clean-sh

.PHONY: build-system
build-system: prep-goal write-attrs-sh check-system-sh build-system-sh clean-sh

.PHONY: build-home
build-home: prep-goal write-attrs-sh check-home-sh build-home-sh clean-sh

# Build flake-based system configurations for Linux or Darwin systems.
.PHONY: build-system-sh
build-system-sh:
	@sh "scripts/system.sh" --build

# Build flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: build-home-sh
build-home-sh:
	@sh "scripts/home.sh" --build

# Check for a dirty git tree and warn on a failed build about the confusing
# missing path error. I should not have to write this...
.PHONY: warn-if-dirty-sh
warn-if-dirty-sh-sh:
	@sh "scripts/common.sh [warn_if_dirty]"

.PHONY: warn-test
warn-test: prep-goal warn-if-dirty-sh clean-sh

.PHONY: set-boot-sh
set-boot-sh:
	@sh "scripts/set_boot.sh"

#
# Switch targets.
#

.PHONY: switch
switch: prep-goal write-attrs-sh check-sh switch-system-sh switch-home-sh \
	set-boot-sh clean-sh

.PHONY: switch-system
switch-system: prep-goal write-attrs-sh check-system-sh switch-system-sh \
	set-boot-sh clean-sh

.PHONY: switch-home
switch-home: prep-goal write-attrs-sh check-home-sh switch-home-sh clean-sh

# Build and activate flake-based system configurations for Linux or Darwin systems.
.PHONY: switch-system-sh
switch-system-sh:
	@sh scripts/system.sh --switch

# Activate flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: activate-home-sh
activate-home-sh:
	@sh scripts/home.sh --activate

# Build and activate flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: switch-home-sh
switch-home-sh:
	@sh scripts/home.sh --switch

.PHONY: update
update: prep-goal update-sh clean-sh

.PHONY: update-sh
update-sh:
	@sh scripts/update.sh

.PHONY: test
test: prep-goal check-nix-attrs warn-if-dirty-sh
# Set the default boot menu option to the first specified specialisation for a system.

.PHONY: all
all: prep-goal write-attrs-sh install-sh check-sh warn-if-dirty-sh \
	switch-system-sh switch-home-sh set-boot-sh clean-sh

%:
	@printf "Unknown target: '$@'\n"
	@printf "Valid targets: help all install check switch update uninstall\n"
	@printf "Valid sub-targets: check-system check-home build-system build-home switch-system switch-home\n"
	@false
