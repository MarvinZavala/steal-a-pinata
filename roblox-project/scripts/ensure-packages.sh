#!/usr/bin/env bash
# Wally no crea Packages/ cuando el paquete no tiene dependencias, y Rojo
# falla si default.project.json apunta a una carpeta que no existe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$ROOT/Packages/init.luau" ]]; then
	mkdir -p "$ROOT/Packages"
	printf '%s\n' '--!strict' '-- Placeholder: Wally lo reemplaza cuando haya dependencias.' 'return {}' >"$ROOT/Packages/init.luau"
	echo "wrote $ROOT/Packages/init.luau"
fi
