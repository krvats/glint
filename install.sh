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
if [ -x "$PREFIX/bin/glint" ] || command -v glint >/dev/null 2>&1; then say "Upgrading Glint in $PREFIX (your settings, shortcuts and theme sync stay as they are)"
else say "Installing Glint into $PREFIX"; fi
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
