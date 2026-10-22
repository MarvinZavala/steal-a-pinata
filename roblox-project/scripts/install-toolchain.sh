#!/usr/bin/env bash
# Instala rojo, wally, selene, stylua y lune en las versiones de rokit.toml.
# Si `rokit` está en PATH y puede bajar los tools, lo usa. Si GitHub responde 403,
# baja los mismos tags con `gh release download`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${TOOLCHAIN_BIN:-$HOME/.local/bin}"
mkdir -p "$DEST"

if command -v rokit >/dev/null 2>&1; then
	if (cd "$ROOT" && rokit install --no-trust-check); then
		echo "rokit install ok"
		exit 0
	fi
	echo "rokit install falló; usando gh release download" >&2
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "hace falta rokit o gh" >&2
	exit 1
fi

ver() {
	sed -n "s/^$1 = \".*@\\(.*\\)\"/\\1/p" "$ROOT/rokit.toml" | head -n 1
}

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS-$ARCH" in
Linux-x86_64) PLATFORM="linux-x86_64" ;;
Linux-aarch64 | Linux-arm64) PLATFORM="linux-aarch64" ;;
Darwin-arm64) PLATFORM="macos-aarch64" ;;
Darwin-x86_64) PLATFORM="macos-x86_64" ;;
*)
	echo "plataforma no soportada por el fallback: $OS $ARCH (usá rokit install)" >&2
	exit 1
	;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
	local repo="$1"
	local tag="$2"
	local pattern="$3"
	local bin="$4"
	rm -rf "$TMP/work"
	mkdir -p "$TMP/work"
	gh release download "$tag" --repo "$repo" --pattern "$pattern" --dir "$TMP/work" --clobber
	unzip -o "$TMP/work"/*.zip -d "$TMP/work/out" >/dev/null
	local found
	found="$(find "$TMP/work/out" -type f -name "$bin" | head -n 1)"
	if [[ -z "$found" ]]; then
		echo "no encontré el binario $bin en $pattern" >&2
		find "$TMP/work/out" -type f >&2
		exit 1
	fi
	install -m 755 "$found" "$DEST/$bin"
	echo "installed $bin -> $DEST/$bin"
}

ROJO_V="$(ver rojo)"
WALLY_V="$(ver wally)"
SELENE_V="$(ver selene)"
STYLUA_V="$(ver stylua)"
LUNE_V="$(ver lune)"

fetch "rojo-rbx/rojo" "v${ROJO_V}" "rojo-${ROJO_V}-${PLATFORM}.zip" rojo

case "$OS" in
Linux) WALLY_PAT="wally-v${WALLY_V}-linux.zip" ;;
Darwin) WALLY_PAT="wally-v${WALLY_V}-macos.zip" ;;
esac
fetch "UpliftGames/wally" "v${WALLY_V}" "$WALLY_PAT" wally

case "$OS" in
Linux) SELENE_PAT="selene-${SELENE_V}-linux.zip" ;;
Darwin) SELENE_PAT="selene-${SELENE_V}-macos.zip" ;;
esac
fetch "Kampfkarren/selene" "${SELENE_V}" "$SELENE_PAT" selene

case "$PLATFORM" in
linux-x86_64) STY_PAT="stylua-linux-x86_64.zip" ;;
linux-aarch64) STY_PAT="stylua-linux-aarch64.zip" ;;
macos-aarch64) STY_PAT="stylua-macos-aarch64.zip" ;;
macos-x86_64) STY_PAT="stylua-macos-x86_64.zip" ;;
esac
fetch "JohnnyMorganz/StyLua" "v${STYLUA_V}" "$STY_PAT" stylua
fetch "lune-org/lune" "v${LUNE_V}" "lune-${LUNE_V}-${PLATFORM}.zip" lune

echo "toolchain en $DEST (agregalo al PATH)"
