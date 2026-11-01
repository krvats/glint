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

printf '\n%s%s✦ Done.%s Open %sGlint%s from your launcher, press %sSuper+Alt+M%s, or run %sglint --help%s\n' "$(c 214 196 255)" "$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R"
printf '%s  If you were just added to the i2c group, log out and in once.%s\n' "$(c 169 163 207)" "$R"
printf '%s  Remove everything later with one line:  curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash -s -- --uninstall --purge   (or: glint uninstall --all)%s\n' "$(c 169 163 207)" "$R"
printf '\n  %s⭐ Glint is free and tiny. If it saved you time, a star helps others find it:%s\n     %shttps://github.com/krvats/glint%s\n\n' "$(c 255 179 217)" "$R" "$(c 139 230 255)" "$R"
}
main "$@"
