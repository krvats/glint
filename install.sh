#!/usr/bin/env bash
# ✦ Glint installer  ·  https://github.com/krvats/glint
#   curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash
# One self-contained file: it carries the program inside, so no git clone is needed.
# Read it first if you like:  curl -fsSL <url> | less     (options: --help)

main() {
set -euo pipefail
VERSION="1.1.0"
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
4/Xf4Pr/AdNhr1sACAIA
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
