# cursor-manager

Wizard de cursor para **niri**: cambia el tamaño, cambia el tema, e instala
temas nuevos desde un comprimido. Pensado para lanzarse desde el launcher
(Noctalia, fuzzel, wofi, cualquiera que lea `.desktop`), sin abrir un editor
ni recordar dónde vive el bloque `cursor { }`.

```
  Tema actual    Skyrim-by-ru5tyshark-cursors
  Tamaño actual  48

  [n] tamaño   [t] tema   [i] instalar desde archivo   [Enter] salir
```

## Instalación

```bash
git clone https://github.com/Johankyuk/cursor-manager.git
cd cursor-manager
./install.sh
```

HTTPS, no SSH: el repo es público y clonarlo no requiere llave. SSH solo hace
falta para contribuir cambios de vuelta.

`install.sh` es idempotente — si un archivo ya está igual, no lo toca ni deja
un `.bak` de más. Para revertir, `./install.sh --uninstall` (conserva los temas
de cursor instalados y el `environment.d`, que suele usarlo otra cosa).

### Qué instala

| Origen | Destino |
|---|---|
| `bin/cursor-scale` | `~/.local/bin/cursor-scale` |
| `applications/cursor-scale.desktop` | `~/.local/share/applications/` |
| `environment.d/10-path.conf` | `~/.config/environment.d/` |

El tercero es para el resto de tus binarios, no para este wizard: **la sesión
gráfica no hereda el `PATH` de tu shell**, y en Arch `~/.local/bin` no está en
el `PATH` del sistema. Aplica desde el próximo login.

El `.desktop` de este repo **no depende de eso**: invoca el wizard por ruta
`$HOME`. Es a propósito. Si el compositor lo arranca el greeter por PAM
(greetd con `--session niri`, por ejemplo) en vez de activarlo el manager de
usuario, no hereda el entorno del manager y `environment.d` no llega a lo que
lance el launcher. Confirmalo con:

```bash
tr '\0' '\n' < /proc/$(pgrep -x niri)/environ | grep '^PATH='
```

Regla general para `.desktop` propios: ruta vía `$HOME`, nunca confiar en el
`PATH`.

### Requisito: un bloque `cursor` en niri

El wizard edita un bloque existente, no inventa uno. Si no tenés ninguno,
`install.sh` te avisa y te da las dos líneas para crearlo:

```bash
printf 'cursor {\n    xcursor-size 32\n}\n' > ~/.config/niri/cursor.kdl
echo 'include "cursor.kdl"' >> ~/.config/niri/config.kdl
```

## Uso

```bash
cursor-scale                    # menú interactivo
cursor-scale 48                 # solo tamaño
cursor-scale --list             # catálogo de temas instalados
cursor-scale --theme NOMBRE 48  # tema + tamaño
cursor-scale --install ARCHIVO  # instala un tema desde .tar/.zip/.7z
```

### Dónde escribe

1. El bloque `cursor { }` de niri, en el `.kdl` donde efectivamente esté
2. `gsettings org.gnome.desktop.interface` (`cursor-size`, `cursor-theme`)
3. `~/.config/gtk-3.0/settings.ini` y `gtk-4.0`, si existen

Deja un `.bak` con timestamp y **verifica releyendo del disco**. niri recarga
solo al guardar; las apps ya abiertas heredaron `XCURSOR_SIZE` al arrancar y
mantienen el tamaño viejo hasta relanzarlas.

### Catálogo

Escanea, en orden de prioridad (el primero gana, igual que Xcursor al resolver):

```
$XCURSOR_PATH            si está definido
~/.local/share/icons     ← destino de las instalaciones
~/.icons                 legacy: se lee, no se escribe
/usr/local/share/icons
/usr/share/icons         paquetes de pacman
```

Un directorio cuenta como tema si tiene `cursors/` con contenido. El listado
muestra origen, los tamaños nominales reales (parseando la cabecera Xcursor) y
cuántos symlinks rotos tiene:

```
  ● 1. Skyrim-by-ru5tyshark-cursors   usuario  24/32/48/64   144 formas
    2. Adwaita                        sistema  escalable?     59 formas
```

`escalable?` significa que no encontró tamaños nominales — típico de temas SVG
o de los que traen un solo bitmap, y señal de que puede verse borroso si le
subís la escala.

### Instalar temas

`--install` acepta `.tar` (con gzip/bzip2/xz adentro, los detecta solo), `.zip`
y `.7z`; encuentra los directorios `<tema>/cursors/` aunque vengan anidados o
vengan varios en un mismo comprimido; respalda cualquier instalación previa del
mismo nombre; y corrige tres defectos habituales de los temas empaquetados a
mano:

- **Symlinks con ruta absoluta al home de quien empaquetó.** Rotos en cualquier
  otra máquina. Se reescriben como relativos.
- **`cursor.theme` con `Inherits` que no resuelve** a ningún directorio (suele
  apuntar al nombre visible del tema, con espacios y emojis). Se descarta.
- **`index.theme` sin `Inherits`.** Se le agrega `Adwaita` para que las formas
  faltantes caigan en algún lado en vez de desaparecer.

No hay descarga automática: gnome-look y la AUR están detrás de Anubis, que
bloquea a cualquier cliente que no ejecute su challenge de JavaScript. Bajá el
comprimido desde el navegador y pasáselo a `--install`. Los temas de repos
oficiales (`pacman -Ss xcursor`) se instalan con pacman y aparecen solos en el
catálogo.

## Notas de implementación

Tres cosas que costaron encontrar y conviene no volver a pisar:

- **`Path.rglob` no desciende por symlinks de directorio.** Si `~/.config/niri/cfg`
  apunta a otro repo, un `rglob` ve solo los directorios reales que haya al lado
  —típicamente backups— y opera sobre ellos creyendo que son el config vivo.
  Falla silenciosa: la operación reporta éxito, sobre el archivo equivocado. Por
  eso el escaneo usa `os.walk(followlinks=True)` con corte de ciclos.
- **Ordenar rutas alfabéticamente no distingue un directorio activo de su
  backup:** `cfg.bak.NNN/` gana contra `cfg/` porque `.` (46) precede a `/` (47).
  De ahí el filtro explícito de `.bak`, `.old`, `.orig`, `.save`, `.disabled`.
- **Si hay más de un bloque `cursor`, el wizard pregunta** en vez de elegir. Los
  `include` de niri son posicionales y el último gana; adivinar ahí es cómo se
  termina editando un archivo que nadie lee.

## Licencia

MIT. Los temas de cursor que instales tienen la licencia de sus autores.
