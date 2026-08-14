# CLIamp Window Control for Omarchy Quattro

A small Omarchy Quattro plugin that keeps the existing CLIamp quake window at
an exact size directly below the top bar. Its bar control uses the classic
Winamp lightning-bolt logo.

The plugin is intentionally narrow:

- Left click toggles the existing CLIamp quake window.
- Right click opens the window settings.
- Horizontal alignment is Left, Center, or Right.
- Width and height use editable numeric fields with 50 px arrow steps.
- The effective keybinding is shown in a human-readable form.
- Hiding the bar icon requires an explicit confirmation.
- The bar icon can be hidden without stopping geometry management.

"Center" affects x only. The y coordinate always starts at the top edge of the
monitor's usable rectangle, directly below its top reserved region.

## Requirements

- Omarchy Quattro with the manifest-based shell plugin runtime
- Hyprland 0.55 or newer with the Lua provider
- `bash`, `jq`, and `hyprctl`
- The existing CLIamp quake integration at
  `~/.config/hypr/scripts/quake_toggle.sh music`
- A client class of exactly `org.omarchy.quake.music`

The plugin does not install CLIamp, change its audio sources, rewrite
Hyprland keybindings, or launch a second process when a CLIamp client exists.

## Install

After the repository is published, install it disabled for review:

```bash
omarchy plugin add \
  https://github.com/ilyaZar/omarchy-cliamp-control.git
~/.config/omarchy/plugins/io.github.ilyazar.cliamp/setup.sh
omarchy plugin enable io.github.ilyazar.cliamp
```

Native `omarchy plugin add` deliberately runs no hooks. The explicit
`setup.sh` step installs only the recovery command, desktop entry, and launcher
icon. It does not enable the plugin.

For local development from this checkout:

```bash
./setup.sh --link-plugin
omarchy plugin enable io.github.ilyazar.cliamp
```

`--link-plugin` creates a link outside the publishable tree at
`~/.config/omarchy/plugins/io.github.ilyazar.cliamp`. The repository itself
contains no symlinks.

## Settings and behavior

Defaults are Center, 1200 px wide, 600 px high, and icon visible. Valid values
are stored inline on the widget's `shell.json` layout entry through the shell's
supported `updateEntryInline` method. The command-line recovery path uses
`omarchy bar put` and `omarchy bar set` instead of editing `shell.json`.

The service reads the same entry from the injected shell configuration. It
applies changes immediately and listens to relevant Hyprland window,
workspace, special-workspace, and monitor events. While no CLIamp client
exists, a fallback check backs off from two seconds to fifteen seconds. There
is no periodic polling after a client is found.

The service targets only `org.omarchy.quake.music`. It never runs the launcher
and therefore cannot create duplicate CLIamp processes. The existing
creation-time 1200 x 600 centered Hyprland rule can remain as a safe fallback;
the plugin is the dynamic geometry owner after the client appears.

## Keybinding

The recommended default is `F12`. Keep the action description exactly
`CLIamp drop-down` so the settings panel can find the effective binding:

```lua
hl.unbind("F12")
o.bind(
  "F12",
  "CLIamp drop-down",
  "command -v cliamp >/dev/null 2>&1 && "
    .. "~/.config/hypr/scripts/quake_toggle.sh music"
)
```

The **Keybinding** row translates Hyprland's effective binding into a friendly
label such as `F12` or `Super+Shift+M`. Selecting the row opens the matching
entry in `~/.config/hypr/bindings.lua` using Omarchy's configured editor. The
plugin only observes this file and never rewrites it.

## Geometry

The helper reads `hyprctl clients -j` and `hyprctl monitors -j`. A present
client selects its reported monitor ID. Only an absent client falls back to the
focused monitor.

Hyprland reports monitor pixel dimensions before output transform. The plugin
swaps width and height for odd transforms, divides by scale, and then applies
the reserved margins in Hyprland's `[left, top, right, bottom]` order:

```text
logical width  = transformed pixel width / scale
logical height = transformed pixel height / scale
usable x       = monitor x + reserved left
usable y       = monitor y + reserved top
usable width   = logical width - reserved left - reserved right
usable height  = logical height - reserved top - reserved bottom
```

Requested width and height are clamped to that usable rectangle. Left uses
`usable x`, Center adds half the remaining horizontal space, and Right uses
the usable right edge minus the clamped width. Every result is integral and
the complete window remains reachable.

The runtime applies the result with current Hyprland Lua dispatchers through
`hyprctl eval`, using an exact client address. It does not use legacy hyprlang
dispatch syntax.

## Hide, disable, and recover

These states are deliberately different:

- **Hide icon** sets `iconVisible` to false. The widget collapses to zero width,
  consumes no bar gap, and its enabled service keeps running. A confirmation
  warns how to restore the icon before applying this action.
- **Disable or remove bar entry** removes the plugin's only `shell.json`
  reference. Omarchy then unloads the third-party service.
- **Remove plugin** removes the plugin checkout and shell registration. Native
  removal does not own the separate recovery integration.

Restore a hidden, disabled, or removed bar entry without creating duplicates:

```bash
cliamp-widget
cliamp-widget show
cliamp-widget hide
cliamp-widget status
```

With no arguments, `cliamp-widget` rescans plugins, idempotently puts the
widget in its default right section when absent, and clears `iconVisible`.

The same no-argument action is installed as the standard XDG desktop entry
**Restore CLIamp Widget**. Omarchy's application library watches
`~/.local/share/applications`, so no Quattro `menu` plugin kind is involved.

## External setup state

`setup.sh` owns only these files:

```text
~/.local/bin/cliamp-widget
~/.local/share/applications/io.github.ilyazar.cliamp.restore.desktop
~/.local/share/icons/hicolor/scalable/apps/io.github.ilyazar.cliamp.svg
```

Remove that integration without touching shell settings or CLIamp:

```bash
./remove.sh
```

For a local development link, use `./remove.sh --unlink-plugin`. For a native
installation, remove the plugin separately:

```bash
omarchy plugin remove io.github.ilyazar.cliamp
```

Modified setup-owned files are preserved rather than deleted.

## Validate

```bash
omarchy plugin validate .
bash -n bin/cliamp-widget scripts/*.sh tests/*.sh *.sh
shellcheck bin/cliamp-widget lib/*.sh scripts/*.sh tests/*.sh *.sh
tests/test_geometry.sh
tests/test_keybindings.sh
tests/test_recovery.sh
tests/test_setup.sh
qmllint -I /usr/share/omarchy/shell Service.qml BarWidget.qml
```

Geometry tests cover landscape and portrait outputs, non-zero origins,
rotation, scaling, all reserved margins, every alignment, multiple widths,
oversized requests, and absent-client to created-client monitor selection.

## Logo license

The unmodified classic Winamp logo is redistributed under the permission and
attribution recorded in [`assets/README.md`](assets/README.md). It is a
trademark of its respective owner. This plugin is unofficial and is not
affiliated with or endorsed by Winamp or its owner. Plugin code is MIT licensed;
the logo keeps its separately documented terms.
