#!/usr/bin/env bash
# Junta los 54 FBX de art/export/{creatures,base,props,lobby} en una sola carpeta
# para importarlos de un golpe con File → Import 3D (Cmd+A en el diálogo).
# Son hard links: no ocupan disco extra. La carpeta vive dentro de art/export/ para que
# la ruta relativa de los FBX (../../textures/palette_*.png) siga encontrando la paleta.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/art/export"
DEST="$SRC/_studio_import"

rm -rf "$DEST"
mkdir -p "$DEST"
count=0
for dir in creatures base props lobby; do
	for f in "$SRC/$dir"/*.fbx; do
		ln "$f" "$DEST/$(basename "$f")"
		count=$((count + 1))
	done
done

echo "$count FBX en $DEST"
if command -v pbcopy >/dev/null 2>&1; then
	printf '%s' "$DEST" | pbcopy
	echo "ruta copiada al portapapeles (en el diálogo de Studio: Cmd+Shift+G, Cmd+V, Enter)"
fi
