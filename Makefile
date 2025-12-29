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
	@sh scripts/validate_args.sh "$(MAKECMDGOALS)"

.PHONY: set-env
set-env:
	@sh scripts/set_env.sh

.PHONY: check-deps
check-deps:
	@sh scripts/check_deps.sh "$(MAKECMDGOALS)"

.PHONY: pre-checks
pre-checks: validate-args set-env check-deps

.PHONY: clean
clean:
	@sh scripts/clean.sh

.PHONY: help
help: set-env show-help

.PHONY: show-help
show-help:
	@sh scripts/print_help.sh

#
# Install/uninstall targets.
#

.PHONY: install
install: pre-checks install-sh clean

.PHONY: install-all
install-all: install-sh

.PHONY: install-sh
install-sh:
	@sh scripts/installs.sh

.PHONY: uninstall
uninstall: pre-checks uninstall-sh

.PHONY: uninstall-sh
uninstall-sh:
	@sh scripts/uninstalls.sh

#
# Check targets.
#

.PHONY: check
check: check-all

.PHONY: check-all
check-all: pre-checks check-nix-attrs clean

.PHONY: check-home
check-home: pre-checks check-nix-attrs-home clean

.PHONY: check-system
check-system: pre-checks check-nix-attrs-system clean

# Check previous configuration based on username and hostname
.PHONY: check-nix-attrs
check-nix-attrs:
	@sh "scripts/attrs.sh" --check-all

# Check previous home configuration based on username and hostname
.PHONY: check-nix-attrs-home
check-nix-attrs-home:
	@sh "scripts/attrs.sh" --check-home

# Check previous system configuration based on username and hostname
.PHONY: check-nix-attrs-system
check-nix-attrs-system:
	@sh "scripts/attrs.sh" --check-system

#
# Build targets.
#

# Pass imperative configuration attributes from make to flake.nix
.PHONY: write-nix-attrs
write-nix-attrs:
	@sh "scripts/attrs.sh" --write

.PHONY: build
build: build-all

.PHONY: build-all
build-all: pre-checks write-nix-attrs build-system-all build-home-all clean

.PHONY: build-system
build-system: pre-checks write-nix-attrs build-system-sh check-dirty-warn clean

.PHONY: build-system-all
build-system-all: build-system-sh check-dirty-warn

.PHONY: build-home
build-home: pre-checks write-nix-attrs build-home-sh check-dirty-warn clean

.PHONY: build-home-all
build-home-all: build-home-sh check-dirty-warn

# Build flake-based system configurations for Linux or Darwin systems.
.PHONY: build-system-sh
build-system-sh:
	@sh scripts/system.sh --build

# Build flake-based Home-manager configurations for Linux or Darwin systems.
.PHONY: build-home-sh
build-home-sh:
	@sh scripts/home.sh --build

# Check for a dirty git tree and warn on a failed build about the confusing
# missing path error. I should not have to write this...
.PHONY: check-dirty-warn
check-dirty-warn-sh:
	@sh scripts/check_dirty_warn.sh

.PHONY: set-spec-boot
set-spec-boot:
	@sh scripts/set_spec_boot.sh

#
# Switch targets.
#

.PHONY: switch
switch: switch-all

.PHONY: switch-all
switch-all: pre-checks write-nix-attrs build-system-all build-home-all switch-system-sh switch-home-sh clean

.PHONY: switch-system
switch-system: pre-checks write-nix-attrs switch-system-sh check-dirty-warn set-spec-boot clean

.PHONY: switch-home
switch-home: pre-checks write-nix-attrs switch-home-sh check-dirty-warn clean

# No pre-checks, write-nix-attrs, or clean for all target
.PHONY: switch-system-all
switch-all: build-system-all switch-system-sh

# No pre-checks, write-nix-attrs, or clean for all target
.PHONY: switch-home-all
switch-all: build-home-all switch-home-sh

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

.PHONY: test
test: pre-checks check-nix-attrs check-dirty-warn
# Set the default boot menu option to the first specified specialisation for a system.

.PHONY: all
all: pre-checks install-all write-nix-attrs build-system-all build-home-all \
	switch-system-all switch-home-all set-spec-boot

%:
	@printf "Unknown target: '$@'\n"
	@printf "Valid targets: help all install check switch update uninstall\n"
	@printf "Valid sub-targets: check-system check-home build-system build-home switch-system switch-home\n"
	@false
