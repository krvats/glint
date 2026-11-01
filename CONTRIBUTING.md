# Contributing to Glint ✦

The easiest way to help is to **add your monitor**:
1. Run `glint report` and open an issue with the file (there is a template).
2. Or add `src/share/monitors/<maker>-<model>.json` with `match` (part of the model name) and `notes`.

Rules of the house
- Never edit a user's file without making a `.glint-bak` backup first.
- Everything must be reversible: `install.sh --uninstall` puts files back.
- Every update and new feature must reach users through the install one-liner or `glint update` alone, never extra manual commands.
- Never override a keybind the user already has.
- Only standard VESA MCCS codes unless a monitor file proves a vendor code.
- `bash tests/run.sh` must pass (fake monitor, no hardware needed). After changing anything in `src/`, run
  `bash tools/build-installer.sh` and commit the regenerated `install.sh`.

Ideas that are very welcome: other compositors for the Screen tab (wlr-randr, KDE, GNOME, X11), more themes sources,
translations, packaging (AUR, Nix, Flatpak, deb, rpm).
