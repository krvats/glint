# ✦ Glint: setup, brand kit and launch playbook

Everything you need to publish Glint, make it look like a real brand, and get it in front of the people who will love it.
No tricks: stars come from being useful, easy to try, and easy to talk about.

---

## 1. Publish it (15 minutes)

**The one command** (makes the repo, uploads everything, sets the description and 20 topics, turns on Discussions, tags `v1.0.0`, creates the release, and checks the one-liner is live):
```bash
unzip glint.zip && cd glint && bash tools/publish.sh
```
It uses GitHub's official CLI (`gh`): if it is missing it installs it, then opens your browser **once** to sign in. Options: `--private` (keep it private for now), `--name something-else`. If you are not signed in as `krvats`, it rewrites every link to your username first.
The only thing GitHub has no command for is the social preview picture (see **d** below).

*By hand instead?* Create an empty public repo named `glint` on github.com, then:
```bash
cd glint && bash tests/run.sh && bash tools/build-installer.sh
git init -b main && git add . && git commit -m "Glint 1.0.0"
git remote add origin https://github.com/krvats/glint.git && git push -u origin main
git tag v1.0.0 && git push origin v1.0.0
```

**Check the one-liner works** (the most important test; `publish.sh` already tries it):
```bash
curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | head -3
```
It must print the first lines of the installer. A 404 means the repo is private or `install.sh` is not at the top level.

**d. Dress the repo page** (Settings and the ⚙ next to *About*)
- **Social preview (the picture shown when your link is shared):** run `bash tools/make-social-preview.sh`. It composes the public-domain Hokusai print with the Glint name and tagline into `assets/social-preview.png` (1280×640), using any browser you have installed (needs internet once). Then Settings → General → *Social preview* → upload that file. No browser script? Open `tools/social-preview.html` in a browser, size the window to exactly 1280×640 (DevTools device toolbar) and take a screenshot.
- **Description:** paste the one in section 3.
- **Topics:** paste the list in section 3.
- **Release:** Releases → *Draft a new release* → tag `v1.0.0` → title `Glint 1.0: your monitor, wearing your rice` → paste the notes in section 6.
- Turn on **Discussions** (a friendly place for "does it work on my monitor?").
- Pin the repo on your profile.

**e. Add real screenshots** (biggest conversion win). Take these on your own desktop and save them in `assets/`:
`screenshot-screen.png`, `screenshot-colour.png`, `screenshot-keys.png`, `screenshot-look.png`, plus two shots of the same window under two different Caelestia schemes. Then add them to the README. A short 15 to 20 second clip (section 5) beats everything else.

**f. Optional: the AUR** (Arch users search there first)
1. Create an account at aur.archlinux.org and add your SSH key.
2. `git clone ssh://aur@aur.archlinux.org/glint.git` (it will be empty).
3. Copy `PKGBUILD` and `glint.install` in, run `makepkg -g` and paste the checksum into `sha256sums`, run `makepkg -si` to test, then `makepkg --printsrcinfo > .SRCINFO`.
4. `git add . && git commit -m "glint 1.0.0" && git push`.
Check the name `glint` is free on the AUR first; if not, use `glint-monitor` (change `pkgname`).

---

## 2. Brand kit

**Name:** **Glint**. A tiny flash of light on water; also what a monitor does. Short, easy to type (`glint`), easy to say.
**Elevator pitch (one breath):** "Glint is a tiny control panel for your monitor on Linux: resolution, refresh rate, brightness and colour in one place, and it wears whatever theme you already run."
**Voice:** warm, short sentences, honest about limits. Never "revolutionary". Say what it does and what it doesn't.

**Art direction:** Japanese woodblock prints (ukiyo-e). The repo uses **no self-made art**: it shows public-domain prints by Hokusai from Wikimedia Commons (Great Wave, Red Fuji) and your own real screenshots. Calm scene, one bright spark.
Where to find more free art for wallpapers, banners and posts:
- **Wikimedia Commons** (public-domain prints, with the file page and credit link)
- **The Metropolitan Museum of Art Open Access**, **Art Institute of Chicago**, **Cleveland Museum of Art**, **Rijksmuseum**, **RISD Museum**: their public-domain works are CC0
- **Artvee** (public-domain artworks, free to download)
Always add a credit line and keep the source link, as the README's *Credits* section does.

Colours below are inspired by those prints (Prussian blue, paper cream, a touch of ember).

| Colour | Hex | Use |
|---|---|---|
| Night ink | `#0b1b4a` | header, badges |
| Indigo | `#1f3f8f` | gradients, panels |
| Wave blue | `#4a7bd0` | accents |
| Sky | `#9cc3ff` | links, highlights |
| Aqua | `#8be6ff` | badges |
| Rose | `#ffb3d9` | calls to action, stars |
| Paper | `#f7ecd0` | light text |

**Fonts**
- **Headings in images and the typing line:** **Lora Italic** (free, SIL OFL), a calm serif that feels like a printed caption.
- **Code and terminal:** **JetBrains Mono**, which most rices use, so screenshots feel at home.
- **If you build a website later:** pair **Zen Maru Gothic** (rounded, friendly) with Lora. Both are free on Google Fonts.
- GitHub README text always uses GitHub's own font, so any special type has to live inside an image or the typing line.

---

## 3. Search (SEO) kit

**GitHub description** (paste into *About*, 260 characters):
> Glint: a tiny control panel for your monitor on Linux. Resolution, refresh rate, brightness and colour (DDC/CI), themed live like Caelestia or pywal. One-line install for Arch, Debian, Fedora, openSUSE, Void and Alpine. Hyprland-ready.

**Topics** (GitHub allows 20):
`linux` `hyprland` `caelestia` `ddcutil` `ddc-ci` `monitor` `brightness` `refresh-rate` `resolution` `display-settings` `rice` `dotfiles` `unixporn` `wayland` `gtk4` `libadwaita` `material-you` `pywal` `theme` `quickshell`

**How people will search, and where Glint says it:**
| They type | Where it appears |
|---|---|
| "change refresh rate hyprland" | README intro, features table, FAQ |
| "monitor brightness linux ddcutil gui" | description, features, FAQ |
| "caelestia monitor settings" | topics, README title area |
| "hyprland lua monitor config" | README comparison table, blog post below |

**Long-tail article** (this brings in search traffic for years): *"How to set 143.98 Hz on Hyprland's new Lua config (and stop guessing)"*. 600 words: the problem, `hyprctl monitors` to see real modes, why 144 is really 143.98, the manual `hl.monitor{}` line, then "or just use Glint". Post on dev.to or your own page, link the repo at the top and the bottom.

**Other places that rank:** open a PR adding one line to any `awesome-hyprland`, `awesome-wayland` or `awesome-ddcutil`-style list (search GitHub for them). Ask the Caelestia community in their Discussions or Discord whether they are happy for you to share it there. Read each place's rules first.

**Rules for your own writing:** put the keyword in the first 160 characters, write alt text on every image (already done in the README), use real headings, keep the one-liner visible without scrolling.

---

## 4. Launch plan (two weeks, 20 minutes a day)

| When | Do |
|---|---|
| **Day 0** | Publish (section 1). Install it on a second machine or a fresh user to prove the one-liner. Ask 2 or 3 friends on different distros to run it and tell you what broke. Fix, rebuild `install.sh`, push. |
| **Day 1** | Post the screenshots/clip in **r/hyprland** and the Caelestia community. Be there to answer for the next few hours. |
| **Day 2 or 3** | **r/unixporn**: this is a showcase, so post your *rice* with Glint visible, put "Glint" in the details and link the repo in a comment. Follow their screenshot rules. |
| **Day 5** | **Show HN** (Hacker News) on a weekday morning (US time). Title below. Reply to every comment. |
| **Day 7** | Publish the long-tail article. Post to **r/linux_gaming** (refresh rate and colour modes matter to gamers) and **r/archlinux**/**r/CachyOS** with the AUR link if you published it. |
| **Day 10** | Mastodon (#Linux #Hyprland #unixporn #FOSS) and X: the clip plus one line. |
| **Day 14** | Release **v1.1** with what people asked for. Thank everyone by name in the notes. |

**Be human:** one thoughtful post per community, not copy-paste across ten at once. Read their self-promotion rules. If a post is removed, ask the mods why and move on politely.

### Copy-paste drafts

**r/hyprland**
> **Title:** Glint: change resolution, refresh rate, brightness and colour from one small app that follows your Caelestia/pywal colours (one-line install)
>
> I got tired of editing `monitors.lua` to find out 144 Hz is really 143.98, and of using my monitor's joystick for brightness. So I made Glint. Pick a mode from the list your monitor really offers (it auto-reverts if the screen goes black), drag real DDC/CI brightness and colour sliders, and the app and your GTK/Qt apps wear your scheme live.
> Install: `curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash` (one file, `--uninstall` puts everything back).
> Built and used on CachyOS + Hyprland + Caelestia with a Gigabyte G27Q. The package mappings for apt/dnf/zypper/xbps/apk are untested on real machines, so if you try it I'd love to hear what broke. Repo: https://github.com/krvats/glint

**Show HN**
> **Title:** Show HN: Glint – one-line monitor control for Linux (DDC/CI + Hyprland), themed like your rice
>
> *First comment:* "I wanted resolution, refresh rate, brightness and colour in one place instead of config files and a monitor joystick. It's a single Python file plus a GTK4 app. The installer is one self-contained shell script that maps packages for pacman/apt/dnf/zypper/xbps/apk, sets up the i2c permissions, and backs up every file it edits. Honest limits: the Screen tab is Hyprland-only for now; vendor-specific features (overdrive etc.) need community reports. Happy to answer questions."

**Mastodon / X**
> Made a tiny thing for my monitor ✦ Glint: resolution, refresh rate, brightness & colour, and it wears your rice (Caelestia/pywal) live. One-line install, fully reversible. 🌊 https://github.com/krvats/glint #Linux #Hyprland #unixporn #FOSS

---

## 5. Demo assets checklist

**20-second clip storyboard**
1. (0 to 3 s) terminal: paste the one-liner, the banner and green ticks scroll.
2. (3 to 6 s) open Glint with `Super+Alt+M`.
3. (6 to 10 s) Screen tab: choose 143.98, **Apply**, **Keep**.
4. (10 to 13 s) Colour tab: tap **Night**, the monitor warms.
5. (13 to 18 s) switch the Caelestia scheme: Glint and a GTK app recolour themselves.
6. (18 to 20 s) end card: the banner and "⭐ star if it helped".

**Record:** `wf-recorder -g "$(slurp)" -f clip.mp4` (or Kooha/OBS), then `ffmpeg -i clip.mp4 -vf "fps=15,scale=900:-1" clip.gif` for GitHub. Keep it under 10 MB.
**Screenshots:** `grim -g "$(slurp)" shot.png`.

---

## 6. Release notes template

```markdown
## Glint 1.0: your monitor, wearing your rice ✦

- 🖥 **Screen:** resolution, refresh rate (143.98 and friends), scale, rotation, position, with a 12-second safety revert
- ☀ **Colour:** real brightness, contrast, RGB, colour temperature, one-tap looks
- 🎨 **Looks like your rice:** live Caelestia / pywal / gtk.css colours, optional whole-desktop sync
- ⌨ **Shortcuts that never override yours**
- 🚀 **One-line installer** for pacman, apt, dnf, zypper, xbps, apk. Fully reversible.

Install: `curl -fsSL https://raw.githubusercontent.com/krvats/glint/main/install.sh | bash`

Tested daily on CachyOS + Hyprland + Caelestia. Other distros are mapped but need your reports. Run `glint report` and open an issue to add your monitor. If Glint helped, a ⭐ helps others find it.
```

---

## 7. Growing stars the honest way

- **Make the first minute magical:** the one-liner, the doctor with green ticks, the 12-second revert. People star things that just work.
- **Make it easy to help:** the *Add my monitor* template turns every user into a contributor in 30 seconds. Label easy issues `good first issue`.
- **Reply fast:** answer every issue within a day for the first month. Thank people by name in release notes.
- **Ask, kindly, at the right moment:** the installer's last line, the README and the release notes already do. A short "if this saved you time" lands better than a begging banner.
- **Show, don't tell:** a screenshot of a gorgeous rice beats any paragraph. Ask users to share theirs (r/unixporn) and reshare with credit.
- **Don't:** buy stars, trade stars, or spam. Communities notice, and it ends the project's reputation.

Keep it small, keep it honest, keep it pretty. ✦
