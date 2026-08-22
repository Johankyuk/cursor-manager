#!/usr/bin/env bash
# cursor-manager — instalación
#
# Sin `set -e` a propósito: en un bloque pegado en zsh interactivo, un fallo
# cierra la terminal y deja el sistema a medias. Se encadena con && donde
# importa y se verifica al final.
#
# Uso:
#   ./install.sh              instala
#   ./install.sh --uninstall  desinstala (deja los temas de cursor)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ENV_DIR="$HOME/.config/environment.d"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '%s⚠%s %s\n' "$YELLOW" "$OFF" "$1"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$OFF" "$1"; }
note() { printf '%s  %s%s\n' "$DIM" "$1" "$OFF"; }

# Copia con respaldo. Si el destino ya es idéntico, no hace nada ni deja .bak.
backup_and_copy() {
    local src="$1" dst="$2" mode="${3:-644}"
    [ -f "$src" ] || { bad "no existe en el repo: $src"; return 1; }
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        note "sin cambios: ${dst/#$HOME/\~}"
        return 0
    fi
    mkdir -p "$(dirname "$dst")" || return 1
    if [ -e "$dst" ]; then
        cp -p "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)" && \
            note "respaldo de ${dst/#$HOME/\~}"
    fi
    install -Dm"$mode" "$src" "$dst" && ok "${dst/#$HOME/\~}"
}

# --------------------------------------------------------------- desinstalar
if [ "$1" = "--uninstall" ]; then
    rm -f "$BIN_DIR/cursor-scale" && ok "quitado $BIN_DIR/cursor-scale"
    rm -f "$APP_DIR/cursor-scale.desktop" && ok "quitado el .desktop"
    update-desktop-database "$APP_DIR" 2>/dev/null
    note "se conserva $ENV_DIR/10-path.conf (lo usan otras cosas)"
    note "se conservan los temas en ~/.local/share/icons"
    exit 0
fi

# --------------------------------------------------------------- requisitos
missing=0
command -v python3 >/dev/null || { bad "falta python3"; missing=1; }
command -v niri    >/dev/null || warn "no encuentro niri: el wizard escribe config de niri"
command -v foot    >/dev/null || warn "no encuentro foot: el .desktop lo usa como terminal"
[ "$missing" -eq 0 ] || exit 1

# --------------------------------------------------------------- instalación
echo
backup_and_copy "$REPO_DIR/bin/cursor-scale"                     "$BIN_DIR/cursor-scale" 755
backup_and_copy "$REPO_DIR/applications/cursor-scale.desktop"    "$APP_DIR/cursor-scale.desktop"
backup_and_copy "$REPO_DIR/environment.d/10-path.conf"           "$ENV_DIR/10-path.conf"

update-desktop-database "$APP_DIR" 2>/dev/null

# environment.d aplica recién en el próximo login; esto cubre la sesión actual.
if command -v systemctl >/dev/null && [ -n "$XDG_RUNTIME_DIR" ]; then
    case ":$(systemctl --user show-environment 2>/dev/null | sed -n 's/^PATH=//p'):" in
        *":$BIN_DIR:"*) ok "PATH de systemd --user ya incluye ${BIN_DIR/#$HOME/\~}" ;;
        *) systemctl --user import-environment PATH 2>/dev/null
           systemctl --user set-environment \
               PATH="$BIN_DIR:$(systemctl --user show-environment | sed -n 's/^PATH=//p')" \
               2>/dev/null && ok "PATH de la sesión actual actualizado" ;;
    esac
fi

# --------------------------------------------------------------- bloque niri
NIRI_DIR="$HOME/.config/niri"
if [ -d "$NIRI_DIR" ]; then
    # -L para seguir symlinks: cfg/ suele apuntar a otro repo.
    found="$(find -L "$NIRI_DIR" -name '*.kdl' -not -path '*.bak*' \
             -exec grep -l '^[[:space:]]*cursor[[:space:]]*{' {} + 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
        ok "bloque cursor encontrado en ${found/#$HOME/\~}"
    else
        warn "no hay bloque \`cursor { }\` en la config de niri"
        note "creá uno y agregá el include; después el wizard lo encuentra solo:"
        note "  printf 'cursor {\\n    xcursor-size 32\\n}\\n' > $NIRI_DIR/cursor.kdl"
        note "  echo 'include \"cursor.kdl\"' >> $NIRI_DIR/config.kdl"
    fi
else
    warn "no existe ~/.config/niri — el wizard no tendrá dónde escribir"
fi

# --------------------------------------------------------------- verificación
echo
fail=0
[ -x "$BIN_DIR/cursor-scale" ]        || { bad "no quedó ejecutable el wizard"; fail=1; }
[ -f "$APP_DIR/cursor-scale.desktop" ] || { bad "no quedó el .desktop"; fail=1; }
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" \
    "$BIN_DIR/cursor-scale" 2>/dev/null || { bad "el wizard no parsea"; fail=1; }

if [ "$fail" -eq 0 ]; then
    ok "instalación verificada"
    echo
    note "probá:  cursor-scale --list"
    note "desde el launcher: buscá \"escala\" o \"cursor\""
    note "si el launcher lo abre y cierra al instante, hace falta relogin"
    note "para que ~/.config/environment.d/10-path.conf tome efecto"
else
    exit 1
fi
