#!/usr/bin/env bash
# ✦ Glint installer  ·  https://github.com/krvats/glint
#   curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash
# One self-contained file: it carries the program inside, so no git clone is needed.
# Read it first if you like:  curl -fsSL <url> | less     (options: --help)

main() {
set -euo pipefail
VERSION="1.1.1"
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
