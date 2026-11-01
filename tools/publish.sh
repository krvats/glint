#!/usr/bin/env bash
# ✦ One command: make the GitHub repo, upload everything, tag a release.
#     bash tools/publish.sh            (public repo named "glint" under your account)
#     bash tools/publish.sh --private  (keep it private for now)
#     bash tools/publish.sh --name my-glint
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="glint"; VIS="--public"; TAG="v$(sed -n 's/^VERSION = "\(.*\)"/\1/p' src/bin/glint | head -1)"
while [ $# -gt 0 ]; do case "$1" in
  --private) VIS="--private";; --name) NAME="$2"; shift;; -h|--help) sed -n '2,6p' "$0"; exit 0;;
  *) echo "unknown option: $1"; exit 2;; esac; shift; done

say() { printf '\n\033[1;38;2;156;195;255m▸ %s\033[0m\n' "$*"; }
ok()  { printf '  \033[38;2;139;230;255m✓\033[0m %s\n' "$*"; }
die() { printf '\n\033[38;2;255;120;140m✗ %s\033[0m\n' "$*" >&2; exit 1; }
DESC="Glint: a tiny control panel for your monitor on Linux. Resolution, refresh rate, brightness and colour (DDC/CI), themed live like Caelestia or pywal. One-line install for Arch, Debian, Fedora, openSUSE, Void and Alpine. Hyprland-ready."
TOPICS="linux hyprland caelestia ddcutil ddc-ci monitor brightness refresh-rate resolution display-settings rice dotfiles unixporn wayland gtk4 libadwaita material-you pywal theme quickshell"

say "Checking tools"
command -v git >/dev/null || die "git is not installed. Install it (pacman -S git / apt install git / dnf install git) and run this again."
if ! command -v gh >/dev/null; then
  echo "  GitHub CLI (gh) is missing, trying to install it..."
  if   command -v pacman  >/dev/null; then sudo pacman -S --needed --noconfirm github-cli
  elif command -v dnf     >/dev/null; then sudo dnf install -y gh
  elif command -v zypper  >/dev/null; then sudo zypper --non-interactive install gh
  elif command -v xbps-install >/dev/null; then sudo xbps-install -Sy github-cli
  elif command -v apk     >/dev/null; then sudo apk add github-cli
  elif command -v apt-get >/dev/null; then sudo apt-get install -y gh || die "Install gh from https://github.com/cli/cli#installation and run this again."
  else die "Install the GitHub CLI from https://cli.github.com and run this again."; fi
fi
ok "git and gh are ready"

say "Signing in to GitHub (a browser window opens once)"
if ! gh auth status >/dev/null 2>&1; then gh auth login --hostname github.com --git-protocol https --web; fi
# pushing .github/workflows needs the "workflow" permission
gh auth status 2>&1 | grep -q "workflow" || gh auth refresh --hostname github.com --scopes workflow
gh auth setup-git >/dev/null 2>&1 || true
LOGIN="$(gh api user --jq .login)"; ok "signed in as $LOGIN"

say "Testing before we publish"
bash tests/run.sh | tail -1 | grep -q "ALL TESTS PASSED" || die "tests failed, not publishing"
ok "tests pass"

# README, installer and docs say krvats/glint. Point them at whoever is signed in.
if [ "$LOGIN" != "krvats" ] || [ "$NAME" != "glint" ]; then
  say "Pointing links at $LOGIN/$NAME"
  grep -rIl "krvats/glint" --exclude-dir=.git --exclude=install.sh . | xargs -r sed -i "s#krvats/glint#$LOGIN/$NAME#g"
  sed -i "s#krvats/glint#$LOGIN/$NAME#g" tools/installer.sh.in
  ok "links updated"
fi
bash tools/build-installer.sh >/dev/null && ok "install.sh rebuilt"

if gh repo view "$LOGIN/$NAME" >/dev/null 2>&1; then die "$LOGIN/$NAME already exists. Use another name: bash tools/publish.sh --name something-else"; fi

say "Making the repo and uploading"
[ -d .git ] || { git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }; }
if [ -z "$(git config user.name || true)" ]; then
  git config user.name "$(gh api user --jq '.name // .login')"
  git config user.email "$(gh api user --jq '(.id|tostring) + "+" + .login + "@users.noreply.github.com"')"
fi
git add -A
git commit -q -m "Glint ${TAG#v}: your monitor, wearing your rice" || true
gh repo create "$LOGIN/$NAME" $VIS --description "$DESC" --source . --remote origin --push >/dev/null
ok "uploaded to https://github.com/$LOGIN/$NAME"

say "Dressing the repo (topics, discussions, release)"
args=(); for t in $TOPICS; do args+=(--add-topic "$t"); done
gh repo edit "$LOGIN/$NAME" "${args[@]}" --enable-discussions >/dev/null 2>&1 && ok "description, 20 topics, discussions on" || echo "  (could not set topics; add them in the repo's About box)"
git tag -a "$TAG" -m "Glint ${TAG#v}" 2>/dev/null || true
git push -q origin "$TAG"
gh release create "$TAG" --title "Glint ${TAG#v}: your monitor, wearing your rice" --notes "$(cat <<NOTES
- 🖥 **Screen:** resolution, refresh rate (143.98 and friends), scale, rotation, position, with a 12-second safety revert
- ☀ **Colour:** real brightness, contrast, RGB, colour temperature, one-tap looks
- 🎨 **Wears your rice:** live Caelestia / pywal / gtk.css colours, optional whole-desktop sync
- ⌨ **Shortcuts that never override yours**
- 🚀 **One-line installer** for pacman, apt, dnf, zypper, xbps, apk. Fully reversible.

Install: \`curl -fsSL https://raw.githubusercontent.com/$LOGIN/$NAME/main/install.sh | bash\`

Developed on CachyOS + Hyprland + Caelestia. Other distros are mapped but need your reports: run \`glint report\` and open an issue. If Glint helped, a ⭐ helps others find it.
NOTES
)" >/dev/null && ok "release $TAG created"

if [ "${GLINT_PUBLISH_TEST:-0}" != 1 ]; then
  say "Checking your one-line install works"
  URL="https://raw.githubusercontent.com/$LOGIN/$NAME/main/install.sh"; good=0
  for i in 1 2 3 4 5 6; do curl -fsSL "$URL" 2>/dev/null | head -1 | grep -q '^#!/usr/bin/env bash' && { good=1; break; }; sleep 4; done
  [ "$good" = 1 ] && ok "$URL is live" || echo "  Not live yet (GitHub can take a minute). Try:  curl -fsSL $URL | head -3"
fi

printf '\n\033[1m✦ Done.\033[0m  Your repo:  https://github.com/%s/%s\n' "$LOGIN" "$NAME"
echo "  Share this one-liner:  curl -fsSL https://raw.githubusercontent.com/$LOGIN/$NAME/main/install.sh | bash"
echo "  Last touch (manual, GitHub has no command for it): make the social card with  bash tools/make-social-preview.sh"
echo "  then upload assets/social-preview.png at  https://github.com/$LOGIN/$NAME/settings  (Social preview)."
