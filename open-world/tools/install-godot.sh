#!/usr/bin/env bash
# Install the Godot editor and export templates pinned in GODOT_VERSION.txt.
# Prints the editor binary path on stdout. Progress goes to stderr.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
world=$(cd "$here/.." && pwd)
version_file="$world/GODOT_VERSION.txt"
read_key() { awk -F= -v key="$1" '$1==key{print $2}' "$version_file"; }

version=$(read_key version)
editor_asset=$(read_key editor_asset)
editor_sha=$(read_key editor_sha512)
templates_asset=$(read_key templates_asset)
templates_sha=$(read_key templates_sha512)
template_dir=$(read_key version_tag)
web_template=$(read_key web_template)

cache="${GODOT_CACHE_DIR:-${RUNNER_TEMP:-/tmp}/godot-${version}}"
mkdir -p "$cache"
base="https://github.com/godotengine/godot/releases/download/${version}"

fetch() {
  local asset="$1" sha="$2" dest="$3"
  if [[ -f "$dest" ]] && echo "$sha  $dest" | sha512sum -c - >&2; then
    return
  fi
  rm -f "$dest"
  echo "Downloading $asset" >&2
  curl -fL --retry 3 -o "$dest" "$base/$asset"
  echo "$sha  $dest" | sha512sum -c - >&2
}

fetch "$editor_asset" "$editor_sha" "$cache/$editor_asset"
fetch "$templates_asset" "$templates_sha" "$cache/$templates_asset"

editor="$cache/${editor_asset%.zip}"
if [[ ! -x "$editor" ]]; then
  unzip -q -o "$cache/$editor_asset" -d "$cache"
  chmod +x "$editor"
fi

templates_home="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$template_dir"
if [[ ! -f "$templates_home/$web_template" ]]; then
  rm -rf "$cache/templates"
  mkdir -p "$cache/templates"
  unzip -q -o "$cache/$templates_asset" -d "$cache/templates"
  mkdir -p "$templates_home"
  cp -a "$cache/templates/templates/." "$templates_home/"
fi

if [[ ! -f "$templates_home/$web_template" ]]; then
  echo "Missing web template $web_template" >&2
  exit 1
fi

printf '%s\n' "$editor"
