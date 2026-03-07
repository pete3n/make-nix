#!/usr/bin/env sh
set -u

MPD_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/mpd/mpd.conf"
prog="ipod-mpd-copy"
mpd_conf_set=""
playlist=""
use_queue="0"
music_dir_arg=""
playlists_dir_arg=""
ipod_path=""
tmpdir=""
music_dir=""
playlists_dir=""
_track_list=""
track_count="0"

usage() {
  cat <<EOF
Usage: $prog -i <ipod_path> [-p <playlist>] [-q] [-c <mpd.conf>] [-m <music_dir>] [-P <playlists_dir>]

  -i <path>       Path to iPod mounted storage (required)
  -p <playlist>   Copy a saved MPD playlist by name (mpc lsplaylists)
  -q              Copy the current MPD queue instead
  -c <path>       Path to mpd.conf (default: $MPD_CONF)
  -m <path>       Music directory (overrides mpd.conf and default)
  -P <path>       Playlists directory (overrides mpd.conf and default)
  -h              Show this help

EOF
  exit 1
}

parse_mpd_conf_value() {
  _key="$1"
  _file="$2"
  grep -E "^[[:space:]]*${_key}[[:space:]]+" "$_file" 2>/dev/null \
    | tail -1 \
    | sed -E 's/^[[:space:]]*[^ ]+[[:space:]]+"(.+)"[[:space:]]*$/\1/'
}

cleanup() {
  if [ -d "$tmpdir" ]; then
    printf "Cleaning up %s...\n" "${tmpdir}"
    rm -rf "$tmpdir"
  fi
}

while getopts "i:p:qc:m:P:h" opt; do
  case $opt in
    i) ipod_path="$OPTARG" ;;
    p) playlist="$OPTARG" ;;
    q) use_queue="1" ;;
    c) MPD_CONF="$OPTARG"; mpd_conf_set="1" ;;
    m) music_dir_arg="$OPTARG" ;;
    P) playlists_dir_arg="$OPTARG" ;;
    h) usage ;;
    ?) printf "%s: unknown or incomplete option\n" "${prog}" >&2; usage ;;
  esac
done

# Validate required and mutually exclusive arguments
if [ -z "$ipod_path" ]; then
  printf "%s: -i <ipod_path> is required\n" "${prog}" >&2
  usage
fi
if [ -n "$playlist" ] && [ "$use_queue" -eq 1 ]; then
  printf "%s: -p and -q are mutually exclusive\n" "${prog}" >&2
  usage
fi
if [ -z "$playlist" ] && [ "$use_queue" -eq 0 ]; then
  printf "%s: one of -p or -q is required\n" "${prog}" >&2
  usage
fi

if [ ! -d "$ipod_path" ]; then
  printf "%s: iPod path not found: %s\n" "${prog}" "${ipod_path}" >&2
	printf "%s: is the iPod mounted? Try: udisksctl mount -b /dev/sdX\n" "${prog}" >&2
  exit 1
fi
if [ ! -w "$ipod_path" ]; then
  printf "%s: iPod path is not writable: %s\n" "${prog}" "${ipod_path}" >&2
  exit 1
fi

music_dir="${XDG_MUSIC_DIR:-$HOME/Music}"
playlists_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mpd/playlists"

# Override with mpd.conf if present
if [ -f "$MPD_CONF" ]; then
  _parsed_music=$(parse_mpd_conf_value "music_directory" "$MPD_CONF")
  _parsed_playlist=$(parse_mpd_conf_value "playlist_directory" "$MPD_CONF")
  case "$_parsed_music" in
    "~"*) _parsed_music="$HOME${_parsed_music#\~}" ;;
  esac
  case "$_parsed_playlist" in
    "~"*) _parsed_playlist="$HOME${_parsed_playlist#\~}" ;;
  esac
  music_dir="${_parsed_music:-$music_dir}"
  playlists_dir="${_parsed_playlist:-$playlists_dir}"
elif [ -n "$mpd_conf_set" ]; then
  printf "%s: mpd.conf not found at %s\n" "${prog}" "${MPD_CONF}" >&2
  exit 1
fi

# Override with CLI flags if provided
[ -n "$music_dir_arg" ] && music_dir="$music_dir_arg"
[ -n "$playlists_dir_arg" ] && playlists_dir="$playlists_dir_arg"

# Strip trailing slashes to avoid double-slash in constructed paths
music_dir="${music_dir%/}"
playlists_dir="${playlists_dir%/}"

# Validate resolved paths
if [ ! -d "$music_dir" ]; then
  printf "%s: music directory not found: %s\n" "${prog}" "${music_dir}" >&2
  printf "Use -m to specify manually or -c to provide an mpd.conf\n" >&2
  exit 1
fi

printf "Music directory:    %s\n" "${music_dir}"
printf "Playlist directory: %s\n" "${playlists_dir}"

if [ "${use_queue}" -eq 1 ]; then
  printf "Reading current MPD queue...\n"
  _track_list=$(mpc playlist -f '%file%')
else
  printf "Reading playlist: %s\n" "${playlist}"
  if ! mpc lsplaylists | grep -qxF "${playlist}"; then
    printf "%s: playlist '%s' not found in MPD\n" "${prog}" "${playlist}" >&2
    printf "Available playlists:\n" >&2
    mpc lsplaylists >&2
    exit 1
  fi
  _track_list=$(mpc playlist -f '%file%' "${playlist}")
fi

if [ -z "$_track_list" ]; then
  printf "%s: playlist is empty\n" "${prog}" >&2
  exit 1
fi

track_count=$(printf '%s\n' "$_track_list" | wc -l | tr -d ' ')
printf "Found %s tracks.\n" "${track_count}"

tmpdir=$(mktemp -d)
trap cleanup EXIT INT TERM

printf "\nCopying and converting tracks...\n"
printf '%s\n' "$_track_list" | while IFS= read -r track; do
  _src="${music_dir}/${track}"
  if [ ! -f "$_src" ]; then
    printf "Warning: file not found, skipping: %s\n" "${_src}" >&2
    continue
  fi

  _track_mp3="${track%.*}.mp3"
  _dest="${tmpdir}/${_track_mp3}"
  mkdir -p "$(dirname "$_dest")"

  _ext=$(printf '%s' "${track##*.}" | tr '[:upper:]' '[:lower:]')
  if [ "$_ext" = "mp3" ]; then
    cp "$_src" "$_dest"
  else
    printf "Converting: %s\n" "${track}"
    if ! ffmpeg -i "$_src" -codec:a libmp3lame -b:a 128k \
         -map_metadata 0 -id3v2_version 3 \
         -loglevel error -y "$_dest" < /dev/null; then
      printf "Warning: conversion failed, skipping: %s\n" "${track}" >&2
      rm -f "$_dest"
    fi
  fi
done

_copied=$(find "$tmpdir" -type f -name "*.mp3" | wc -l | tr -d ' ')
_missing=$((track_count - _copied))

if [ "$_missing" -gt 0 ]; then
  printf "Warning: %s track(s) failed or were not found and have been skipped.\n" "${_missing}" >&2
fi

if [ "$_copied" -eq 0 ]; then
  printf "%s: no tracks could be copied\n" "${prog}" >&2
  exit 1
fi

printf "Copied %s tracks to %s\n" "${_copied}" "${tmpdir}"

# Ensure ipod has enough space available
_required_kb=$(du -sk "$tmpdir" | cut -f1)
_available_kb=$(df -k "$ipod_path" | tail -1 | awk '{print $4}')

printf "Required:  %s KB\n" "${_required_kb}"
printf "Available: %s KB\n" "${_available_kb}"

if [ "$_required_kb" -gt "$_available_kb" ]; then
  printf "%s: not enough space on iPod (%s KB required, %s KB available)\n" \
    "${prog}" "${_required_kb}" "${_available_kb}" >&2
  exit 1
fi

printf "\nCopying tracks to iPod...\n"
cp -rv "$tmpdir"/. "$ipod_path"/

printf "\nRunning ipod-shuffle-4g...\n"
if ! ipod-shuffle-4g "$ipod_path"; then
  printf "%s: ipod-shuffle-4g failed" "${prog}" >&2
  exit 1
fi

printf "Done.\n"
