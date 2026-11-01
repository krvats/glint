#!/usr/bin/env bash
# ✦ Glint installer  ·  https://github.com/krvats/glint
#   curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash
# One self-contained file: it carries the program inside, so no git clone is needed.
# Read it first if you like:  curl -fsSL <url> | less     (options: --help)

main() {
set -euo pipefail
VERSION="1.1.3"
PREFIX="${GLINT_PREFIX:-$HOME/.local}"
YES=0; DEPS=1; SYNC=auto; KEYS=1; UNINSTALL=0; PURGE=0; DRY=0

usage() { cat <<'U'
Glint installer
  --yes, -y      do not ask anything
  --no-deps      do not install system packages
  --no-sync      do not theme GTK/Qt apps with your Caelestia/pywal colours
  --sync         theme other apps even if no Caelestia/pywal colours exist yet
  --no-keys      do not add the Super+Alt shortcuts
  --uninstall    remove EVERYTHING Glint added and put your files back (add --purge to also drop saved settings)
  --dry-run      show what would happen, change nothing
U
}
for a in "$@"; do case "$a" in
  -y|--yes) YES=1;; --no-deps) DEPS=0;; --no-sync) SYNC=no;; --sync) SYNC=yes;; --no-keys) KEYS=0;;
  --uninstall) UNINSTALL=1;; --purge) PURGE=1;; --dry-run) DRY=1;; -h|--help) usage; return 0;;
  *) echo "unknown option: $a (try --help)"; return 2;; esac; done

# ---------- looks ----------
if [ -t 1 ] || [ -n "${FORCE_COLOR:-}" ]; then
  c() { printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"; }; R=$'\033[0m'; B=$'\033[1m'
else c() { :; }; R=""; B=""; fi
say()  { printf '\n%s%s▸ %s%s\n' "$(c 156 195 255)" "$B" "$*" "$R"; }
ok()   { printf '  %s✓%s %s\n' "$(c 139 230 255)" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$(c 255 179 217)" "$R" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$(c 255 120 140)" "$*" "$R" >&2; exit 1; }
run()  { if [ "$DRY" = 1 ]; then printf '  would run: %s\n' "$*"; else "$@" </dev/null; fi; }
printf '\n'
printf '%s  ✦%s\n' "$(c 255 255 255)" "$R"
printf '%s ┏━┓╻  ╻┏┓╻╺┳╸%s\n' "$(c 214 196 255)" "$R"
printf '%s ┃╺┓┃  ┃┃┗┫ ┃ %s\n' "$(c 156 195 255)" "$R"
printf '%s ┗━┛┗━╸╹╹ ╹ ╹ %s  %sv%s%s\n' "$(c 139 230 255)" "$R" "$(c 169 163 207)" "$VERSION" "$R"
printf '%s your monitor, wearing your rice%s\n' "$(c 169 163 207)" "$R"

if [ "$(id -u)" -eq 0 ]; then SUDO=""
elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"
elif command -v doas >/dev/null 2>&1; then SUDO="doas"
else SUDO="sudo"; fi
have_sudo() { [ -z "$SUDO" ] || command -v "$SUDO" >/dev/null 2>&1; }

# ---------- uninstall ----------
if [ "$UNINSTALL" = 1 ]; then
  say "Uninstalling Glint"
  export PATH="$PREFIX/bin:$PATH"
  if [ "$DRY" = 1 ]; then ok "would remove the program, launcher, shortcuts, theme sync, PATH lines, udev rule, module list and (with --purge) your settings"; return 0; fi
  if command -v glint >/dev/null 2>&1; then
    GLINT_PREFIX="$PREFIX" glint uninstall --all $([ "$PURGE" = 1 ] || echo --keep-settings) || warn "glint could not finish; removing files directly"
  fi
  # belt and braces: also works when glint itself is already broken or missing
  rm -f "$PREFIX/bin/glint" "$PREFIX/bin/glint-gui" "$PREFIX/bin/cdisplay" "$PREFIX/bin/cdisplay-gui" "$PREFIX/share/applications/glint.desktop"
  rm -rf "$PREFIX/share/glint"; rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/glint-restore.desktop"
  [ "$PURGE" = 1 ] && rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/glint" "${XDG_CONFIG_HOME:-$HOME/.config}/cdisplay"
  if have_sudo && { [ -e /etc/udev/rules.d/60-glint-i2c.rules ] || [ -e /etc/modules-load.d/glint.conf ]; }; then
    $SUDO sh -c "rm -f /etc/udev/rules.d/60-glint-i2c.rules /etc/modules-load.d/glint.conf; [ -f /etc/modules ] && sed -i '/^# glint-begin\$/,/^# glint-end\$/d' /etc/modules; udevadm control --reload-rules 2>/dev/null; true" </dev/null || true
  fi
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$PREFIX/share/applications" >/dev/null 2>&1 || true
  ok "Glint is removed. Packages such as ddcutil were left installed (remove them with your package manager if you like)."
  return 0
fi

# ---------- find the distro ----------
say "Looking at your system"
. /etc/os-release 2>/dev/null || true
DISTRO="${PRETTY_NAME:-${NAME:-Linux}}"
PM=""
if [ -e /etc/NIXOS ]; then PM=nix
elif [ -e /run/ostree-booted ] && command -v rpm-ostree >/dev/null 2>&1; then PM=rpm-ostree
else for p in pacman apt-get dnf yum zypper xbps-install apk emerge eopkg; do command -v "$p" >/dev/null 2>&1 && { PM="$p"; break; }; done; fi
ok "$DISTRO ${PM:+(package manager: $PM)}"
command -v python3 >/dev/null 2>&1 || warn "python3 not found (it will be installed with the packages below)"

# ---------- packages ----------
if [ "$DEPS" = 1 ]; then
  say "Installing what Glint needs"
  case "$PM" in
    pacman)       PK="ddcutil i2c-tools python python-gobject gtk4 libadwaita"; OPT="adw-gtk-theme qt6ct"; I="$SUDO pacman -S --needed --noconfirm";;
    apt-get)      PK="ddcutil i2c-tools python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1"; OPT="adw-gtk3 qt6ct"; I="$SUDO apt-get install -y";;
    dnf)          PK="ddcutil i2c-tools python3 python3-gobject gtk4 libadwaita"; OPT="adw-gtk3-theme qt6ct"; I="$SUDO dnf install -y";;
    zypper)       PK="ddcutil i2c-tools python3 python3-gobject typelib-1_0-Gtk-4_0 typelib-1_0-Adw-1"; OPT="qt6ct"; I="$SUDO zypper --non-interactive install";;
    xbps-install) PK="ddcutil i2c-tools python3 python3-gobject gtk4 libadwaita"; OPT="adw-gtk3 qt6ct"; I="$SUDO xbps-install -Sy";;
    apk)          PK="ddcutil i2c-tools python3 py3-gobject3 gtk4.0 libadwaita"; OPT="adw-gtk3 qt6ct"; I="$SUDO apk add";;
    yum)          PK="ddcutil i2c-tools python3 python3-gobject gtk4 libadwaita"; OPT="qt6ct"; I="$SUDO yum install -y";;
    emerge)       PK="app-misc/ddcutil sys-apps/i2c-tools dev-python/pygobject gui-libs/gtk gui-libs/libadwaita"; OPT="gui-apps/qt6ct"; I="$SUDO emerge --noreplace --quiet";;
    eopkg)        PK="ddcutil i2c-tools python3 python3-gobject libgtk-4 libadwaita"; OPT="qt6ct"; I="$SUDO eopkg install -y";;
    rpm-ostree)   PK="ddcutil i2c-tools"; OPT=""; I="$SUDO rpm-ostree install --idempotent --allow-inactive"; warn "Immutable Fedora: packages are layered and need a reboot to appear (GTK 4 and libadwaita are already part of the image).";;
    nix)          PK=""; warn "NixOS: add ddcutil, i2c-tools, python3Packages.pygobject3, gtk4, libadwaita to your config and set hardware.i2c.enable = true;";;
    *)            PK=""; warn "Unknown package manager. Please install: ddcutil, i2c-tools, python3, PyGObject, GTK 4, libadwaita";;
  esac
  if [ -n "$PK" ]; then
    have_sudo || die "sudo is needed to install packages. Install it or run as root, or use --no-deps."
    [ "$PM" = apt-get ] && run $SUDO apt-get update -y || true
    # shellcheck disable=SC2086
    if run $I $PK; then ok "packages ready"; else warn "some packages failed: install these yourself and re-run:  $PK"; fi
    WANT_SYNC=0
    [ "$SYNC" = yes ] && WANT_SYNC=1
    { [ -f "$HOME/.local/state/caelestia/scheme.json" ] || [ -f "$HOME/.cache/wal/colors.json" ]; } && [ "$SYNC" != no ] && WANT_SYNC=1
    if [ "$WANT_SYNC" = 1 ] && [ -n "${OPT:-}" ]; then
      # shellcheck disable=SC2086
      for o in $OPT; do run $I "$o" >/dev/null 2>&1 && ok "$o" || warn "$o not available on $DISTRO (optional, skipped)"; done
    fi
  fi
fi

# ---------- check the pieces really are there, whatever the distro called them ----------
if [ "$DEPS" = 1 ] && [ "$DRY" != 1 ]; then
  command -v python3 >/dev/null 2>&1 || warn "python3 is still missing: Glint cannot run without it"
  command -v ddcutil >/dev/null 2>&1 || warn "ddcutil not found: external monitors need it (laptop panels work without). Install a package called 'ddcutil'"
  python3 -c "import gi; gi.require_version('Gtk','4.0'); gi.require_version('Adw','1')" >/dev/null 2>&1 \
    || warn "The Glint window needs PyGObject, GTK 4 and libadwaita (the glint command works without them). Look for 'python3-gobject' / 'python3-gi', 'gtk4' and 'libadwaita'"
fi

# ---------- unpack and install our files ----------
if [ -x "$PREFIX/bin/glint" ] || command -v glint >/dev/null 2>&1; then say "Upgrading Glint in $PREFIX (your settings, shortcuts and theme sync stay as they are)"
else say "Installing Glint into $PREFIX"; fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
base64 -d <<'__GLINT_PAYLOAD__' | tar xz -C "$TMP"
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
CAIA
__GLINT_PAYLOAD__
if [ "$DRY" = 1 ]; then
  ok "payload unpacked ($(find "$TMP" -type f | wc -l) files); dry-run stops before copying"
else
  install -Dm755 "$TMP/bin/glint" "$PREFIX/bin/glint"
  install -Dm755 "$TMP/bin/glint-gui" "$PREFIX/bin/glint-gui"
  mkdir -p "$PREFIX/share/glint"
  cp -r "$TMP/share/profiles" "$TMP/share/monitors" "$TMP/share/quickshell" "$PREFIX/share/glint/"
  install -Dm644 "$TMP/share/glint.desktop" "$PREFIX/share/applications/glint.desktop"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$PREFIX/share/applications" >/dev/null 2>&1 || true
  ok "glint, glint-gui and the launcher entry"
fi

# make sure ~/.local/bin is reachable
case ":$PATH:" in *":$PREFIX/bin:"*) ;; *)
  warn "$PREFIX/bin is not on your PATH yet"
  if [ "$DRY" != 1 ]; then
    case "${SHELL##*/}" in
      fish) command -v fish >/dev/null 2>&1 && fish -c "fish_add_path -U '$PREFIX/bin'" >/dev/null 2>&1 && ok "added to fish PATH";;
      zsh)  grep -q 'glint-path' "$HOME/.zshrc" 2>/dev/null || printf '\nexport PATH="%s/bin:$PATH" # glint-path\n' "$PREFIX" >> "$HOME/.zshrc"; ok "added to ~/.zshrc";;
      *)    grep -q 'glint-path' "$HOME/.bashrc" 2>/dev/null || printf '\nexport PATH="%s/bin:$PATH" # glint-path\n' "$PREFIX" >> "$HOME/.bashrc"; ok "added to ~/.bashrc";;
    esac
  fi
esac
export PATH="$PREFIX/bin:$PATH"

# ---------- let your user talk to the monitor (needs root, once) ----------
say "Letting you talk to your monitor without sudo"
if [ "${GLINT_SKIP_SYSTEM:-0}" = 1 ]; then warn "skipped (GLINT_SKIP_SYSTEM=1)"
elif ! have_sudo; then warn "no sudo: ask an admin to install $TMP/system/* (udev rule, i2c-dev module, i2c group)"
else
  if [ "$DRY" != 1 ]; then
    mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/glint"
    $SUDO sh -c '
      install -Dm644 "$1/system/60-glint-i2c.rules" /etc/udev/rules.d/60-glint-i2c.rules
      if [ -d /run/systemd/system ] || [ -d /etc/modules-load.d ]; then
        install -Dm644 "$1/system/glint.conf" /etc/modules-load.d/glint.conf
      elif [ -f /etc/modules ] && ! grep -q "^i2c-dev" /etc/modules; then
        printf "# glint-begin\ni2c-dev\n# glint-end\n" >> /etc/modules
      fi
      rm -f /etc/udev/rules.d/60-cdisplay-i2c.rules /etc/modules-load.d/cdisplay.conf /usr/local/bin/cdisplay /usr/local/bin/cdisplay-gui /usr/local/share/applications/cdisplay.desktop
      modprobe i2c-dev 2>/dev/null || true
      getent group i2c >/dev/null || groupadd -r i2c 2>/dev/null || addgroup -S i2c 2>/dev/null || true
      if ! id -nG "$2" 2>/dev/null | tr " " "\n" | grep -qx i2c; then
        { usermod -aG i2c "$2" 2>/dev/null || adduser "$2" i2c 2>/dev/null || gpasswd -a "$2" i2c 2>/dev/null; } && touch "$3" || true
      fi
      udevadm control --reload-rules 2>/dev/null || true
      udevadm trigger --subsystem-match=i2c-dev 2>/dev/null || true
    ' _ "$TMP" "${SUDO_USER:-$USER}" "${XDG_CONFIG_HOME:-$HOME/.config}/glint/added-i2c-group" </dev/null && ok "udev rule, i2c-dev module and i2c group" || warn "could not finish the system step"
  else ok "would add udev rule, i2c-dev module and i2c group"; fi
fi
if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi nvidia && lsmod 2>/dev/null | grep -q '^nvidia '; then
  warn "NVIDIA driver detected: if brightness/colour do not respond, add  nvidia.NVreg_RegistryDwords=\"RMUseSwI2c=0x01;RMI2cSpeed=100\"  to your kernel command line."
fi

# ---------- wire it into your desktop ----------
say "Wiring it into your desktop"
if [ "$DRY" = 1 ]; then ok "would upgrade old settings, hook monitor settings into Hyprland, add shortcuts, sync theme"
else
  glint migrate >/dev/null 2>&1 && ok "settings ready" || true
  if [ "$(glint pill status 2>/dev/null)" = on ]; then glint pill restart >/dev/null 2>&1 && ok "hover icon refreshed" || true; fi
  if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    if [ "$KEYS" = 1 ]; then glint keys on >/dev/null 2>&1 && ok "shortcuts added (Super+Alt+M opens Glint; taken keys were skipped)" || warn "shortcuts not added"; fi
  else
    warn "Not running inside Hyprland: Glint still controls brightness and colour. Resolution and refresh rate work here through wlr-randr (wlroots/Sway) or xrandr (X11) if installed."
    warn "Shortcuts: bind these in your own desktop settings:  glint profile apply night   ·   glint step brightness +10   ·   glint-gui"
  fi
  if [ "$SYNC" != no ] && { [ "$SYNC" = yes ] || [ -f "$HOME/.local/state/caelestia/scheme.json" ] || [ -f "$HOME/.cache/wal/colors.json" ]; }; then
    glint sync on 2>&1 | sed 's/^/  /' || true
  else ok "theme sync not needed (no Caelestia or pywal colours found); Glint itself will use your GTK theme"; fi
fi

# ---------- check ----------
say "Checking everything"
if [ "$DRY" = 1 ]; then ok "dry run finished"; else glint doctor 2>&1 | sed 's/^/  /' || true; fi

printf '\n%s%s✦ Done.%s Open %sGlint%s from your launcher, press %sSuper+Alt+M%s, or just type %sglint%s. Small panel: %sglint popup%s. Update later: %sglint update%s\n' "$(c 214 196 255)" "$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R"
printf '%s  If you were just added to the i2c group, log out and in once.%s\n' "$(c 169 163 207)" "$R"
printf '%s  Remove everything later with one line:  curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash -s -- --uninstall --purge   (or: glint uninstall --all)%s\n' "$(c 169 163 207)" "$R"
printf '\n  %s⭐ Glint is free and tiny. If it saved you time, a star helps others find it:%s\n     %shttps://github.com/krvats/glint%s\n\n' "$(c 255 179 217)" "$R" "$(c 139 230 255)" "$R"
}
main "$@"
