#!/usr/bin/env bash
# ✦ Glint installer  ·  https://github.com/krvats/glint
#   curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash
# One self-contained file: it carries the program inside, so no git clone is needed.
# Read it first if you like:  curl -fsSL <url> | less     (options: --help)

main() {
set -euo pipefail
VERSION="1.0.0"
PREFIX="${GLINT_PREFIX:-$HOME/.local}"
YES=0; DEPS=1; SYNC=auto; KEYS=1; UNINSTALL=0; PURGE=0; DRY=0

usage() { cat <<'U'
Glint installer
  --yes, -y      do not ask anything
  --no-deps      do not install system packages
  --no-sync      do not theme GTK/Qt apps with your Caelestia/pywal colours
  --sync         theme other apps even if no Caelestia/pywal colours exist yet
  --no-keys      do not add the Super+Alt shortcuts
  --uninstall    remove Glint and put your files back (add --purge to drop saved settings)
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

[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"
have_sudo() { [ -z "$SUDO" ] || command -v sudo >/dev/null 2>&1; }

# ---------- uninstall ----------
if [ "$UNINSTALL" = 1 ]; then
  say "Uninstalling Glint"
  if [ -x "$PREFIX/bin/glint" ]; then run "$PREFIX/bin/glint" uninstall $([ "$PURGE" = 1 ] && echo --purge) || true; fi
  run rm -f "$PREFIX/bin/glint" "$PREFIX/bin/glint-gui" "$PREFIX/share/applications/glint.desktop" 
  run rm -rf "$PREFIX/share/glint"
  if have_sudo; then run $SUDO rm -f /etc/udev/rules.d/60-glint-i2c.rules /etc/modules-load.d/glint.conf; fi
  ok "Removed. Packages such as ddcutil were left installed."
  return 0
fi

# ---------- find the distro ----------
say "Looking at your system"
. /etc/os-release 2>/dev/null || true
DISTRO="${PRETTY_NAME:-${NAME:-Linux}}"
PM=""
if [ -e /etc/NIXOS ]; then PM=nix
else for p in pacman apt-get dnf zypper xbps-install apk; do command -v "$p" >/dev/null 2>&1 && { PM="$p"; break; }; done; fi
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

# ---------- unpack and install our files ----------
say "Installing Glint into $PREFIX"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
base64 -d <<'__GLINT_PAYLOAD__' | tar xz -C "$TMP"
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
__GLINT_PAYLOAD__
if [ "$DRY" = 1 ]; then
  ok "payload unpacked ($(find "$TMP" -type f | wc -l) files); dry-run stops before copying"
else
  install -Dm755 "$TMP/bin/glint" "$PREFIX/bin/glint"
  install -Dm755 "$TMP/bin/glint-gui" "$PREFIX/bin/glint-gui"
  mkdir -p "$PREFIX/share/glint"
  cp -r "$TMP/share/profiles" "$TMP/share/monitors" "$PREFIX/share/glint/"
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
    $SUDO sh -c '
      install -Dm644 "$1/system/60-glint-i2c.rules" /etc/udev/rules.d/60-glint-i2c.rules
      install -Dm644 "$1/system/glint.conf" /etc/modules-load.d/glint.conf
      rm -f /etc/udev/rules.d/60-cdisplay-i2c.rules /etc/modules-load.d/cdisplay.conf /usr/local/bin/cdisplay /usr/local/bin/cdisplay-gui /usr/local/share/applications/cdisplay.desktop
      modprobe i2c-dev 2>/dev/null || true
      getent group i2c >/dev/null || groupadd -r i2c 2>/dev/null || true
      usermod -aG i2c "$2" 2>/dev/null || true
      udevadm control --reload-rules 2>/dev/null || true
      udevadm trigger --subsystem-match=i2c-dev 2>/dev/null || true
    ' _ "$TMP" "${SUDO_USER:-$USER}" </dev/null && ok "udev rule, i2c-dev module and i2c group" || warn "could not finish the system step"
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
  if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    if [ "$KEYS" = 1 ]; then glint keys on >/dev/null 2>&1 && ok "shortcuts added (Super+Alt+M opens Glint; taken keys were skipped)" || warn "shortcuts not added"; fi
  else warn "Hyprland is not running here: screen settings and shortcuts activate when you run Glint inside Hyprland"; fi
  if [ "$SYNC" != no ] && { [ "$SYNC" = yes ] || [ -f "$HOME/.local/state/caelestia/scheme.json" ] || [ -f "$HOME/.cache/wal/colors.json" ]; }; then
    glint sync on 2>&1 | sed 's/^/  /' || true
  else ok "theme sync not needed (no Caelestia or pywal colours found); Glint itself will use your GTK theme"; fi
fi

# ---------- check ----------
say "Checking everything"
if [ "$DRY" = 1 ]; then ok "dry run finished"; else glint doctor 2>&1 | sed 's/^/  /' || true; fi

printf '\n%s%s✦ Done.%s Open %sGlint%s from your launcher, press %sSuper+Alt+M%s, or run %sglint --help%s\n' "$(c 214 196 255)" "$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R"
printf '%s  If you were just added to the i2c group, log out and in once.%s\n' "$(c 169 163 207)" "$R"
printf '\n  %s⭐ Glint is free and tiny. If it saved you time, a star helps others find it:%s\n     %shttps://github.com/krvats/glint%s\n\n' "$(c 255 179 217)" "$R" "$(c 139 230 255)" "$R"
}
main "$@"
