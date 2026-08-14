---
name: shared-shortcuts-release
description: >
  Synchronize and validate the shared shortcut helpers vendored into the btop,
  CLIamp, and keyboard-layout Omarchy plugins. Use when changing shortcut
  formatting, Hyprland binding tracking, XKB option translation, or before
  validating, committing, or releasing any consumer plugin.
---

# Shared Shortcuts Release

Treat `../_shared/shortcuts/` as the source of truth when working from either
plugin root. Never edit `lib/shortcuts/` directly.

After changing a canonical helper or this skill, run:

```bash
../_shared/shortcuts/sync.sh --sync
../_shared/shortcuts/sync.sh --check
```

Review both plugin diffs, then test the shared formatter:

```bash
QT_QPA_PLATFORM=offscreen \
  qml ../_shared/shortcuts/tests/verify.qml
```

Validate each affected plugin from its repository root:

```bash
omarchy plugin validate .
```

Do not commit or release stale vendored copies.
