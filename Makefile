# make-Nix v0.12
# This Makefile provides targets to install and configure Nix and NixOS for 
# MacOS and Linux systems. It can build and deploy both NixOS system and 
# Nix Home-manager configurations.
# Please see https://github.com/pete3n/dotfiles for documentation.
UNAME_S := $(shell uname -s)

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
	@sh scripts/check_nix_integrity.sh

.PHONY: launch-installers
launch-installers:
	@export UNAME_S=$(UNAME_S); \ 
	sh scripts/launch_installers.sh

.PHONY: write-build-target
write-build-target:
	@export BUILD_TARGET_HOST="$(host)"; \
	export BUILD_TARGET_USER="$(user)"; \
	export BUILD_TARGET_SYSTEM="$(system)"; \
	sh scripts/write_build_target.sh $(if $(spec),spec=$(spec));

.PHONY: check-dirty-warn
check-dirty-warn:
	@sh scripts/check_dirty_warn.sh

.PHONY: clean
clean: 
	@sh scripts/clean.sh

.PHONY: build-darwin-home
build-darwin-home:
	@export BUILD_DARWIN_HOST=$(host); \
	export BUILD_DARWIN_USER=$(user); \
	sh scripts/build_darwin_home.sh

.PHONY: activate-darwin-home
activate-darwin-home:
	@export ACTIVATE_DARWIN_HOST=$(host); \
	export ACTIVATE_DARWIN_USER=$(user); \
	sh scripts/activate_darwin_home.sh

.PHONY: build-linux-home
build-linux-home:
	@export BUILD_LINUX_HOST=$(host); \
	export BUILD_LINUX_USER=$(user); \
	sh scripts/build_linux_home.sh

.PHONY: activate-linux-home
activate-linux-home:
	@export ACTIVATE_LINUX_HOST=$(host); \
	export ACTIVATE_LINUX_USER=$(user); \
	sh scripts/activate_linux_home.sh

.PHONY: build-darwin-system
build-darwin-system:
	@export BUILD_DARWIN_HOST=$(host); \
	sh scripts/build_darwin_system.sh

.PHONY: activate-darwin-system
activate-darwin-system:
	@export ACTIVATE_DARWIN_HOST=$(host); \
	sh scripts/activate_darwin_system.sh

.PHONY: build-linux-system
build-linux-system:
	@export BUILD_LINUX_HOST=$(host); \
	sh scripts/build_linux_system.sh

.PHONY: activate-linux-system
activate-linux-system:
	@export ACTIVATE_LINUX_HOST=$(host); \
	sh scripts/activate_linux_system.sh

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
	@script -q -c "nix flake check --all-systems --extra-experimental-features \
		'nix-command flakes'" $(LOG_PATH)

.PHONY: set-specialisation-boot
set-specialisation-boot:
		sh scripts/set_specialisation_boot.sh

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
