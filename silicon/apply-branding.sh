#!/usr/bin/env bash
# =====================================================================
#  Aplica la marca "Silicon-Remote" al código de RustDesk antes de compilar.
#  Lo ejecuta automáticamente el workflow .github/workflows/silicon-windows.yml.
#  Para cambiar nombre/servidor/clave, edita SOLO las tres variables de abajo.
#  Para cambiar logo o iconos, sustituye los archivos de la carpeta silicon/.
# =====================================================================
set -euo pipefail

APP_NAME="Silicon-Remote"
SERVER="176.101.73.91"
KEY="uUEHDdeOL65EiwTLzvVnvGsExddBvvTqXb3GMoq4g+c="

cd "$(dirname "$0")/.."
B=silicon

# Reemplaza una cadena literal en un archivo y falla si no la encuentra
# (así, si RustDesk cambia su código en una versión futura, el build se para y lo ves).
replace() {
  local file="$1" old="$2" new="$3"
  python3 - "$file" "$old" "$new" <<'PY'
import sys
f, old, new = sys.argv[1:4]
s = open(f, encoding="utf-8").read()
if old not in s:
    sys.exit(f"ERROR: no se encontró en {f}:\n  {old}")
open(f, "w", encoding="utf-8", newline="").write(s.replace(old, new))
print(f"OK  {f}: {old[:60]}...")
PY
}

echo "==> Nombre, servidor y clave"
CFG=libs/hbb_common/src/config.rs
replace "$CFG" 'RwLock::new("RustDesk".to_owned())' "RwLock::new(\"$APP_NAME\".to_owned())"
replace "$CFG" 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];' "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"$SERVER\"];"
replace "$CFG" 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";' "pub const RS_PUB_KEY: &str = \"$KEY\";"

# VARIANTE=soporte  -> ejecutable solo para RECIBIR conexiones (tipo "QuickSupport"):
#                      sin botón Instalar, sin poder conectarse a otros, sin ajustes de red
#                      (no se ve ni se puede cambiar el servidor ni la clave).
# VARIANTE=completo -> cliente normal (instalable, para conectarte tú a los equipos).
VARIANTE="${VARIANTE:-soporte}"
echo "==> Variante: $VARIANTE"
if [ "$VARIANTE" = "soporte" ]; then
  # Opciones "duras": no se pueden cambiar desde la interfaz
  replace "$CFG" \
    'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' \
    'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new([("conn-type", "incoming"), ("disable-installation", "Y"), ("disable-settings", "Y"), ("disable-account", "Y"), ("disable-ab", "Y")].iter().map(|(k, v)| (k.to_string(), v.to_string())).collect());'
  # Opciones de interfaz: ocultar red/servidor/proxy, ayudas, y bloquear cambio de ID
  replace "$CFG" \
    'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' \
    'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new([("hide-network-settings", "Y"), ("hide-server-settings", "Y"), ("hide-proxy-settings", "Y"), ("hide-websocket-settings", "Y"), ("hide-help-cards", "Y"), ("disable-change-id", "Y")].iter().map(|(k, v)| (k.to_string(), v.to_string())).collect());'
elif [ "$VARIANTE" != "completo" ]; then
  echo "ERROR: VARIANTE debe ser 'soporte' o 'completo'"; exit 1
fi

echo "==> Metadatos del .exe (Propiedades -> Detalles)"
replace Cargo.toml 'ProductName = "RustDesk"' "ProductName = \"$APP_NAME\""
replace Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$APP_NAME\""
RC=flutter/windows/runner/Runner.rc
replace "$RC" 'VALUE "FileDescription", "RustDesk Remote Desktop"' "VALUE \"FileDescription\", \"$APP_NAME\""
replace "$RC" 'VALUE "ProductName", "RustDesk"' "VALUE \"ProductName\", \"$APP_NAME\""

echo "==> Iconos y logo"
cp -v "$B/icon.ico" res/icon.ico
cp -v "$B/icon.ico" res/tray-icon.ico
cp -v "$B/icon.ico" flutter/windows/runner/resources/app_icon.ico
cp -v "$B/icon.png" res/icon.png
cp -v "$B/icon.png" flutter/assets/icon.png      # icono dentro de la app
cp -v "$B/logo.png" flutter/assets/logo.png      # logo de la pantalla de inicio (máx. 300x60)

echo "==> Marca Silicon-Remote aplicada"
