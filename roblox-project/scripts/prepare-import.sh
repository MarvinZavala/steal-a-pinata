#!/usr/bin/env bash
# Junta FBX de art/export/{creatures,base,props,lobby} en una sola carpeta
# para importarlos de un golpe con File → Import 3D (Cmd+A en el diálogo).
#   bash scripts/prepare-import.sh                 → los 4 grupos completos
#   bash scripts/prepare-import.sh pollito sandia  → solo esos (para no volver a subir lo que ya está)
# Son hard links: no ocupan disco extra. La carpeta vive dentro de art/export/ para que
# la ruta relativa de los FBX (../../textures/palette_*.png) siga encontrando la paleta.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/art/export"
DEST="$SRC/_studio_import"

rm -rf "$DEST"
mkdir -p "$DEST"
count=0
if [[ $# -gt 0 ]]; then
	for name in "$@"; do
		found="$(find "$SRC/creatures" "$SRC/base" "$SRC/props" "$SRC/lobby" -maxdepth 1 -name "$name.fbx" | head -n 1)"
		if [[ -z "$found" ]]; then
			echo "no existe $name.fbx en art/export" >&2
			exit 1
		fi
		ln "$found" "$DEST/$name.fbx"
		count=$((count + 1))
	done
else
	for dir in creatures base props lobby; do
		for f in "$SRC/$dir"/*.fbx; do
			ln "$f" "$DEST/$(basename "$f")"
			count=$((count + 1))
		done
	done
fi

echo "$count FBX en $DEST"
if command -v pbcopy >/dev/null 2>&1; then
	printf '%s' "$DEST" | pbcopy
	echo "ruta copiada al portapapeles (en el diálogo de Studio: Cmd+Shift+G, Cmd+V, Enter)"
fi
