#!/usr/bin/env sh

# Script for updating Nix flakes and upgrading profiles

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: update.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

# All functions require the Nix binary
if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found in PATH. Install with make install."
	fi
fi

sh "${script_dir}/attrs.sh --read"

nix profile upgrade '.*'

nix flake update

