#!/usr/bin/env bash
# Offline tests with a fake monitor. Usage: bash tests/run.sh
set -e
cd "$(dirname "$0")/.."
export HOME="$(mktemp -d)"
export GLINT_DDCUTIL="$PWD/tests/fake-ddcutil" FAKE_STATE="$(mktemp -d)" XDG_CONFIG_HOME="$(mktemp -d)" GLINT_HYPRCTL="$PWD/tests/fake-hyprctl" GLINT_HYPR_DIR="$(mktemp -d)"
C="python3 src/bin/glint"
chk() { [ "$(cat "$FAKE_STATE/$1")" = "$2" ] || { echo "FAIL: code $1 expected $2 got $(cat "$FAKE_STATE/$1")"; exit 1; }; echo "ok: code $1 = $2"; }
$C list | grep -q G27Q && echo "ok: monitor detected"
$C set brightness 0;   chk 10 0
$C set brightness max; chk 10 100
$C set brightness 50;  $C step brightness +5; chk 10 55
$C step brightness -10; chk 10 45
$C set colour 6500k;   chk 14 5
$C profile apply night; chk 10 20; chk 14 4; chk 12 45
$C profile save mine; $C profile apply mine; chk 10 20
$C get --json | python3 -c "import json,sys; d=json.load(sys.stdin)['displays'][0]; assert d['values']['brightness']['percent']==20; print('ok: json')"
$C auto status | grep -q off && echo "ok: auto off by default"
$C set brightness 33
$C sync-mode dark; chk 10 33
$C auto on
$C sync-mode dark; chk 10 20
$C set brightness 60; $C sync-mode dark; chk 10 60
$C sync-mode light; chk 10 75
$C doctor >/dev/null || true
echo 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' > "$GLINT_HYPR_DIR/hyprland.lua"
$C screen list | grep -q "DP-1" && echo "ok: screen listed"
$C screen set DP-1 --resolution 2560x1440 --refresh 144 | grep -q "143.98" && echo "ok: 144 -> 143.98"
grep -q "2560 1440 143.98" "$FAKE_STATE/screen" && echo "ok: applied live"
grep -q '143.98' "$XDG_CONFIG_HOME/glint/monitors.lua" && echo "ok: saved lua"
grep -q '143.98' "$XDG_CONFIG_HOME/glint/monitors.conf" && echo "ok: saved conf"
[ "$(tail -n1 "$GLINT_HYPR_DIR/hyprland.lua" | grep -c monitors.lua)" = 1 ] && echo "ok: hook is last line"
$C screen set DP-1 --scale 1.25 >/dev/null; $C screen set DP-1 --rotate 1 >/dev/null
[ "$(grep -c 'glint monitors' "$GLINT_HYPR_DIR/hyprland.lua")" = 1 ] && echo "ok: hook added once"
[ -f "$GLINT_HYPR_DIR/hyprland.lua.glint.bak" ] && echo "ok: backup made"
$C screen set DP-1 --resolution 1920x1080 --refresh 100 2>&1 | grep -q "not available" && echo "ok: bad refresh rejected"
$C screen set DP-1 --resolution 1000x1000 2>&1 | grep -q "not offered" && echo "ok: bad resolution rejected"
$C screen list --json | python3 -c "import json,sys; o=json.load(sys.stdin)['outputs'][0]; assert o['scale']==1.25 and o['transform']==1; print('ok: json screen')"
$C keys list | grep -q "night .*TAKEN" && echo "ok: taken shortcut detected"
$C keys set open "super+alt+m" >/dev/null
grep -q 'hl.bind("SUPER + ALT + Up"' "$XDG_CONFIG_HOME/glint/monitors.lua" && echo "ok: bind written"
grep -q '"SUPER + ALT + N"' "$XDG_CONFIG_HOME/glint/monitors.lua" && { echo "FAIL: overrode a taken bind"; exit 1; } || echo "ok: taken bind left alone"
grep -q '143.98' "$XDG_CONFIG_HOME/glint/monitors.lua" && echo "ok: monitor lines kept with binds"
$C keys set day "SUPER Q" 2>&1 | grep -q "already used" && echo "ok: conflicting choice refused"
$C keys set day "SUPER ALT, F9" >/dev/null; grep -q 'ALT + F9' "$XDG_CONFIG_HOME/glint/monitors.lua" && echo "ok: custom shortcut"
$C keys off >/dev/null; grep -q 'hl.bind' "$XDG_CONFIG_HOME/glint/monitors.lua" && { echo "FAIL: keys off"; exit 1; } || echo "ok: keys off"
# ---- theme ----
mkdir -p "$HOME/.local/state/caelestia"
echo '{"name":"test","flavour":"dusk","mode":"dark","colours":{"primary":"b4befe","onPrimary":"1e1e2e","surface":"11111b","onSurface":"cdd6f4","surfaceContainer":"181825","surfaceContainerHigh":"1e1e2e","error":"f38ba8"}}' > "$HOME/.local/state/caelestia/scheme.json"
$C theme --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['source']=='caelestia' and d['palette']['accent']=='#b4befe' and d['mode']=='dark'; print('ok: follows caelestia scheme')"
$C theme set radius 24 >/dev/null; $C theme set accent "#ff8800" >/dev/null
$C theme --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['radius']==24 and d['palette']['accent']=='#ff8800'; print('ok: radius + accent override')"
$C theme set accent reset >/dev/null; $C theme set source pywal >/dev/null
$C theme --json | python3 -c "import json,sys; assert json.load(sys.stdin)['source']=='system'; print('ok: missing source falls back to system')"
$C theme set source nonsense 2>&1 | grep -q usage && echo "ok: bad theme value refused"
$C theme set source auto >/dev/null
# ---- sync ----
mkdir -p "$XDG_CONFIG_HOME/gtk-4.0"; echo "/* mine */" > "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
$C sync now | grep -q "Synced" && echo "ok: sync now"
grep -q "@define-color accent_bg_color #b4befe" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" && echo "ok: gtk css written"
grep -q "mine" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css.glint-bak" && echo "ok: old gtk css backed up"
python3 -c "import json,os; d=json.load(open(os.environ['HOME']+'/.cache/wal/colors.json')); assert d['colors']['color4']=='#b4befe'; print('ok: wal bridge file')"
$C sync off >/dev/null; grep -q "mine" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" && echo "ok: sync off restores your gtk css"
# ---- pywal source ----
rm "$HOME/.local/state/caelestia/scheme.json"
mkdir -p "$HOME/.cache/wal"; echo '{"special":{"background":"#101010","foreground":"#eeeeee"},"colors":{"color4":"#5588ff"}}' > "$HOME/.cache/wal/colors.json"
$C theme --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['source']=='pywal' and d['palette']['accent']=='#5588ff'; print('ok: follows pywal')"
# ---- migrate from the old name + uninstall ----
printf '%s\n' 'hl.monitor({ output = "" })' '' '-- cdisplay monitors (managed by Monitor Control)' 'pcall(dofile, "/x/cdisplay/monitors.lua")' > "$CDISPLAY_HYPR_DIR/hyprland.lua" 2>/dev/null || printf '%s\n' 'hl.monitor({ output = "" })' '' '-- cdisplay monitors (managed by Monitor Control)' 'pcall(dofile, "/x/cdisplay/monitors.lua")' > "$GLINT_HYPR_DIR/hyprland.lua"
mkdir -p "$XDG_CONFIG_HOME/cdisplay"; rm -rf "$XDG_CONFIG_HOME/glint"; echo '{}' > "$XDG_CONFIG_HOME/cdisplay/screens.json"; echo "x" > "$XDG_CONFIG_HOME/cdisplay/monitors.lua"
$C migrate >/dev/null
[ -d "$XDG_CONFIG_HOME/glint" ] && [ ! -d "$XDG_CONFIG_HOME/cdisplay" ] && echo "ok: old config moved"
grep -q "glint monitors" "$GLINT_HYPR_DIR/hyprland.lua" && ! grep -q "cdisplay" "$GLINT_HYPR_DIR/hyprland.lua" && echo "ok: old hook replaced"
$C uninstall >/dev/null; ! grep -q "glint monitors" "$GLINT_HYPR_DIR/hyprland.lua" && grep -q 'hl.monitor' "$GLINT_HYPR_DIR/hyprland.lua" && echo "ok: uninstall removes only our lines"
# ---- lock-setup + report ----
mkdir -p "$HOME/.config/caelestia" "$HOME/.config/hypr"
echo '{"session":{"commands":{"logout":["loginctl","terminate-user",""],"shutdown":["systemctl","poweroff"]}}}' > "$HOME/.config/caelestia/shell.json"
printf '%s\n' 'general {' '    lock_cmd = pidof hyprlock || hyprlock' '    before_sleep_cmd = loginctl lock-session' '    after_sleep_cmd = hyprctl dispatch dpms on' '}' 'listener {' '    timeout = 300' '    on-timeout = loginctl lock-session' '}' 'listener {' '    timeout = 330' '    on-timeout = hyprctl dispatch dpms off' '}' > "$HOME/.config/hypr/hypridle.conf"
$C lock-setup on >/dev/null
python3 -c "import json,os; d=json.load(open(os.environ['HOME']+'/.config/caelestia/shell.json')); assert d['session']['commands']['logout'][:3]==['qs','-c','caelestia'] and d['session']['commands']['shutdown']==['systemctl','poweroff']; print('ok: power button locks, other buttons untouched')"
grep -q "lock_cmd = qs -c caelestia ipc call lock lock" "$HOME/.config/hypr/hypridle.conf" && echo "ok: hypridle lock_cmd is Caelestia's"
! grep -q "before_sleep_cmd = loginctl lock-session" "$HOME/.config/hypr/hypridle.conf" && ! grep -q "on-timeout = loginctl lock-session" "$HOME/.config/hypr/hypridle.conf" && echo "ok: no auto-lock on sleep or idle"
grep -q "dpms off" "$HOME/.config/hypr/hypridle.conf" && grep -q "dpms on" "$HOME/.config/hypr/hypridle.conf" && echo "ok: screen on/off left alone"
$C lock-setup off >/dev/null; grep -q "terminate-user" "$HOME/.config/caelestia/shell.json" && grep -q "hyprlock" "$HOME/.config/hypr/hypridle.conf" && echo "ok: lock-setup off restores everything"
$C report > "$HOME/report.out"; grep -q "glint-report" "$HOME/report.out" && ! grep -qi "serial" "$HOME/glint-report.txt" && echo "ok: report written without serials"
# ---- laptop panel (no DDC at all) ----
BL="$(mktemp -d)"; mkdir -p "$BL/intel_backlight"; echo 400 > "$BL/intel_backlight/brightness"; echo 1000 > "$BL/intel_backlight/max_brightness"; echo raw > "$BL/intel_backlight/type"
( export GLINT_BACKLIGHT_DIR="$BL" GLINT_DDCUTIL=/nonexistent
  python3 src/bin/glint list | grep -q "backlight intel_backlight" && echo "ok: laptop panel detected without ddcutil"
  python3 src/bin/glint set brightness 70 >/dev/null; [ "$(cat "$BL/intel_backlight/brightness")" = 700 ] && echo "ok: panel brightness set"
  python3 src/bin/glint set brightness 0 >/dev/null; [ "$(cat "$BL/intel_backlight/brightness")" = 1 ] && echo "ok: panel never goes fully black"
  python3 src/bin/glint set contrast 50 2>&1 | grep -q "not supported" && echo "ok: unsupported feature explained"
  python3 src/bin/glint doctor | grep -q "ddcutil missing" && echo "ok: doctor names the install command" )
# ---- other compositors / X11 ----
( export GLINT_HYPRCTL=/nonexistent GLINT_WLRRANDR="$PWD/tests/fake-wlr-randr" GLINT_XRANDR="$PWD/tests/fake-xrandr" XDG_SESSION_TYPE=wayland
  python3 src/bin/glint screen list | grep -q "HDMI-A-1" && echo "ok: wlr-randr outputs listed"
  python3 src/bin/glint screen list --json | python3 -c "import json,sys; o=json.load(sys.stdin)['outputs'][0]; assert o['modes']['1920x1080']==['60.00','143.98'] and o['refresh']==60.0; print('ok: wlr modes parsed')"
  python3 src/bin/glint screen set HDMI-A-1 --resolution 1920x1080 --refresh 144 >/dev/null
  grep -q -- "--mode 1920x1080@143.98Hz" "$FAKE_STATE/wlr-last" && echo "ok: wlr-randr called with the exact mode"
  [ -f "$XDG_CONFIG_HOME/autostart/glint-restore.desktop" ] && echo "ok: layout re-applied at login"
  python3 src/bin/glint screen restore >/dev/null && echo "ok: screen restore"
  unset XDG_SESSION_TYPE; export DISPLAY=:0 GLINT_WLRRANDR=/nonexistent
  python3 src/bin/glint screen list --json | python3 -c "import json,sys; o=json.load(sys.stdin)['outputs'][0]; assert o['name']=='eDP-1' and o['refresh']==143.98 and o['modes']['2560x1440']==['143.98','120.00','59.95'] and o['can_scale'] is False; print('ok: xrandr parsed')"
  python3 src/bin/glint screen set eDP-1 --resolution 1920x1080 --refresh 60 >/dev/null
  grep -q -- "--mode 1920x1080 --rate 60.00" "$FAKE_STATE/xrandr-last" && echo "ok: xrandr called" )
# ---- one-command uninstall ----
UH="$(mktemp -d)"; mkdir -p "$UH/.local/bin" "$UH/.local/share/glint" "$UH/.local/share/applications" "$UH/.config/glint"
cp src/bin/glint src/bin/glint-gui "$UH/.local/bin/"; touch "$UH/.local/share/applications/glint.desktop"
printf 'export PATH="%s/.local/bin:$PATH" # glint-path\nalias x=y\n' "$UH" > "$UH/.bashrc"
( export HOME="$UH" XDG_CONFIG_HOME="$UH/.config" GLINT_PREFIX="$UH/.local" GLINT_HYPR_DIR="$UH/.config/hypr" PATH="/usr/bin:/bin"
  mkdir -p "$GLINT_HYPR_DIR"; echo 'hl.monitor({})' > "$GLINT_HYPR_DIR/hyprland.lua"
  python3 "$UH/.local/bin/glint" uninstall --all | grep -q "Glint is gone" && echo "ok: uninstall --all"
  [ ! -e "$UH/.local/bin/glint" ] && [ ! -e "$UH/.local/bin/glint-gui" ] && [ ! -e "$UH/.local/share/glint" ] && [ ! -e "$UH/.local/share/applications/glint.desktop" ] && [ ! -e "$UH/.config/glint" ] && echo "ok: everything removed"
  grep -q "glint-path" "$UH/.bashrc" && { echo "FAIL: PATH line left"; exit 1; } || echo "ok: PATH line removed"
  grep -q "alias x=y" "$UH/.bashrc" && echo "ok: your own shell lines untouched" )
echo "ALL TESTS PASSED"
