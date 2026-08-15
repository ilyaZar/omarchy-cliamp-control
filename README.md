# CLIamp Window Control for Omarchy Quattro

A self-contained Omarchy Quattro plugin that turns the stock CLIamp terminal
into a configurable drop-down window. Its bar control uses the classic Winamp
lightning-bolt logo.

- Left click shows or hides the CLIamp drop-down.
- Right click opens alignment and size settings.
- Horizontal alignment is Left, Center, or Right.
- Width and height use editable numeric fields with 50 px arrow steps.
- The effective stock launch binding is shown in a human-readable form.
- Hiding the bar icon requires explicit confirmation.
- Geometry management continues while the bar icon is hidden.

"Center" affects x only. The y coordinate starts at the top of the monitor's
usable rectangle, below any reserved screen area.

## Requirements

- Omarchy Quattro with the manifest-based shell plugin runtime
- Hyprland 0.55 or newer with the Lua provider
- `bash`, `jq`, and `hyprctl`
- `cliamp`, which is included in a standard Omarchy installation

The plugin does not change CLIamp's audio sources or rewrite Hyprland
keybindings. It uses Omarchy's stock `org.omarchy.cliamp` app ID and native TUI
launcher. Existing `org.omarchy.quake.music` windows remain supported so users
can migrate without creating a second CLIamp process.

## Install

Install and enable the plugin with Omarchy's native plugin command:

```bash
omarchy plugin add \
  https://github.com/ilyaZar/omarchy-cliamp-control.git --enable
```

No setup hook or user-configuration change is required. Omarchy clones the
complete runtime, launcher, recovery helper, and assets into the plugin
checkout.

For local development, link this checkout into the plugin directory and
rescan before enabling it:

```bash
ln -s "$PWD" \
  ~/.config/omarchy/plugins/io.github.ilyazar.cliamp
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.ilyazar.cliamp
```

## Settings and behavior

Defaults are Center, 1200 px wide, 600 px high, and icon visible. Valid values
are stored inline on the widget's `shell.json` layout entry through the shell's
supported `updateEntryInline` method. The recovery helper uses `omarchy bar`
commands instead of editing `shell.json`.

The service listens for relevant Hyprland window, workspace, special-workspace,
and monitor events. It selects `org.omarchy.cliamp`, with the old
`org.omarchy.quake.music` class as a fallback. A tiled stock CLIamp window is
floated before its exact size and position are applied.

While no client exists, a fallback check backs off from two seconds to fifteen
seconds. There is no periodic polling after a client is found. If CLIamp was
removed from the preinstalled packages, the settings panel reports that it is
not installed.

Left click calls the included `scripts/toggle_cliamp.sh` helper. It reuses an
existing supported client or launches stock CLIamp through
`omarchy-launch-or-focus-tui cliamp`. A stock client is moved to the dedicated
`special:cliamp` workspace and shown or hidden without creating duplicates.

## Keybinding

Stock Omarchy binds `Super+Shift+Alt+M` to `Music TUI`. That binding launches or
focuses CLIamp, and the plugin then owns its floating geometry. The settings
panel discovers this effective binding directly from Hyprland.

For true keyboard show/hide behavior, replace the stock binding in
`~/.config/hypr/bindings.lua` with the included helper:

```lua
hl.unbind("SUPER + SHIFT + ALT + M")
o.bind(
  "SUPER + SHIFT + ALT + M",
  "CLIamp drop-down",
  "~/.config/omarchy/plugins/io.github.ilyazar.cliamp/"
    .. "scripts/toggle_cliamp.sh"
)
```

The **Launch keybinding** row opens the personal bindings file in Omarchy's
configured editor. It recognizes the stock `Music TUI` action and the optional
`CLIamp drop-down` override. The plugin never rewrites the file.

## Geometry

The helper reads `hyprctl clients -j` and `hyprctl monitors -j`. A present
client selects its reported monitor ID. Only an absent client falls back to the
focused monitor.

Hyprland reports monitor pixel dimensions before output transform. The plugin
swaps width and height for odd transforms, divides by scale, and applies the
reserved margins in Hyprland's `[left, top, right, bottom]` order:

```text
logical width  = transformed pixel width / scale
logical height = transformed pixel height / scale
usable x       = monitor x + reserved left
usable y       = monitor y + reserved top
usable width   = logical width - reserved left - reserved right
usable height  = logical height - reserved top - reserved bottom
```

Requested dimensions are clamped to the usable rectangle. Left uses
`usable x`, Center adds half the remaining horizontal space, and Right uses the
usable right edge minus the clamped width. Every result is integral and keeps
the complete window reachable.

The runtime floats tiled clients, then applies the result with current
Hyprland Lua dispatchers through `hyprctl eval` and an exact client address. It
does not use legacy hyprlang dispatch syntax.

## Hide and recover

These states are deliberately different:

- **Hide icon** sets `iconVisible` to false. The widget consumes no bar gap and
  its enabled service keeps running.
- **Remove bar entry** removes the widget while leaving the installed plugin
  available.
- **Remove plugin** removes its checkout and shell registration.

Restore a hidden or removed bar entry with the helper inside the native plugin
checkout:

```bash
~/.config/omarchy/plugins/io.github.ilyazar.cliamp/bin/cliamp-widget
```

The helper rescans plugins, idempotently puts the widget in its default right
section when absent, and clears `iconVisible`. It also supports `show`, `hide`,
and `status` subcommands.

Remove the plugin without leaving external setup files behind:

```bash
omarchy plugin remove io.github.ilyazar.cliamp
```

## Validate

```bash
omarchy plugin validate .
bash -n bin/cliamp-widget lib/*.sh scripts/*.sh tests/*.sh *.sh
shellcheck bin/cliamp-widget lib/*.sh scripts/*.sh tests/*.sh *.sh
tests/test_geometry.sh
tests/test_apply_geometry.sh
tests/test_toggle.sh
tests/test_keybindings.sh
tests/test_recovery.sh
qmllint -I /usr/share/omarchy/shell Service.qml BarWidget.qml
```

The tests cover transformed and scaled monitors, reserved margins, exact
floating geometry, stock and legacy client selection, launch/show/hide
behavior, effective binding targeting, and idempotent icon recovery.

## Logo license

The unmodified classic Winamp logo is redistributed under the permission and
attribution recorded in [`assets/README.md`](assets/README.md). It is a
trademark of its respective owner. This plugin is unofficial and is not
affiliated with or endorsed by Winamp or its owner. Plugin code is MIT
licensed; the logo keeps its separately documented terms.
