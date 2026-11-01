#!/usr/bin/env bash
# ✦ Glint installer  ·  https://github.com/krvats/glint
#   curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash
# One self-contained file: it carries the program inside, so no git clone is needed.
# Read it first if you like:  curl -fsSL <url> | less     (options: --help)

main() {
set -euo pipefail
VERSION="1.1.2"
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
