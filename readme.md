# 📺 **PiTV — Raspberry Pi TV Dashboard**

**A minimal, Wayland-based kiosk system for Raspberry Pi OS.**
<img width="3352" height="1804" alt="image" src="https://github.com/user-attachments/assets/82f086b3-6324-4392-8f1f-0fb81bc671c5" />

PiTV is a small, reliable setup that turns a Raspberry Pi into a clean, remote-friendly TV interface. Everything is built around stability. With a fullscreen dashboard, a frameless Firefox ESR profile, and predictable location behavior for streaming apps. The system stays simple, uses only a handful of config files, and avoids fragile kiosk flags entirely.

Key Capabilities:

* Boots straight into a fullscreen dashboard designed for remotes and arrow-key input
* Uses a custom Firefox ESR profile with all browser chrome hidden for a TV-friendly look
* Provides an on-screen keyboard that pops up automatically on text inputs
* Reports a consistent geolocation through GeoClue + XDG portals (needed for streaming services)
* Runs fully on Wayland (rpd-labwc) for better window layering and keyboard behavior
* All configuration is isolated and reproducible using systemd, local profiles, and small config files
---

# 🛠️ Requirements

* Raspberry Pi 4 or 5
* Raspberry Pi OS Bookworm (64-bit, Desktop)
* Wayland session: `wayland / rpd-labwc`
* Basic keyboard for initial setup
* Internet 


---

# 1. System Setup

### Flash Raspberry Pi OS

Use Raspberry Pi Imager → **Raspberry Pi OS (64-bit) with desktop**.
Set hostname, user (`pitv`), Wi-Fi, and SSH if needed.

Boot and confirm you are in the correct session:

```bash
echo "$XDG_SESSION_TYPE / $DESKTOP_SESSION"
# expect: wayland / rpd-labwc
```

Fix audio/Wi-Fi using:

```bash
sudo raspi-config
```

### Install required packages

```bash
sudo apt update
sudo apt install -y \
  firefox-esr geoclue-2.0 \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  onboard at-spi2-core gsettings-desktop-schemas dconf-cli \
  x11-utils dbus-x11
```

---

# 2. Static Location (GeoClue + Portal Chain)

### ❓ Why GeoClue?

Modern streaming services (Hulu, Netflix, Max, Disney+) use:

* **HTML5 Geolocation API**
* **XDG Portal → GeoClue2 backend**

This bypasses the IP address entirely.
If the browser can’t provide a valid location, **Hulu refuses to play** or forces error pages.

We use **GeoClue’s static source** so every app sees the same geolocation — stable, reproducible, and spoof-proof.

---

### Create `/etc/geolocation` (lat, lon, altitude, accuracy)

```bash
sudo tee /etc/geolocation >/dev/null <<'EOF'
40.7580
-73.9855
10
1000
EOF

sudo chown geoclue /etc/geolocation
sudo chmod 600 /etc/geolocation
```

---

### Configure GeoClue to *only* use the static source

```bash
UIDNUM=$(id -u)
sudo install -d /etc/geoclue/conf.d
```

```bash
sudo tee /etc/geoclue/conf.d/90-pitv-static.conf >/dev/null <<CONF
[static-source]
enable=true

[wifi]
enable=false
[modem-gps]
enable=false
[3g]
enable=false
[cdma]
enable=false
[compass]
enable=false

[firefox]
allowed=true
system=false
users=$UIDNUM

[firefox-esr]
allowed=true
system=false
users=$UIDNUM

[org.mozilla.firefox]
allowed=true
system=false
users=$UIDNUM
CONF
```

Restart:

```bash
sudo systemctl restart geoclue
```

---

### Enable location service + restart portals

```bash
gsettings set org.gnome.system.location enabled true
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service
```

---

### Verify

```bash
GTK_USE_PORTAL=1 MOZ_ENABLE_WAYLAND=1 firefox-esr https://browserleaks.com/geo
```

You will get a permission popup → Allow → Should show your static NYC coordinates.

---

# 3. Onboard Touch Keyboard (Wayland-Verified)

### Why Onboard?

* Works on Wayland
* Pops up on text inputs
* Proper floating overlay over Firefox
* No weird “touch mode” needed

---

### Apply all sane default settings

```bash
gset() { s=$1; k=$2; v=$3; gsettings writable "$s" "$k" >/dev/null 2>&1 && gsettings set "$s" "$k" "$v"; }
```

Then apply the full config:

```bash
gset org.onboard.auto-show enabled true
gset org.onboard.auto-show hide-on-key-press true
gset org.onboard.auto-show hide-on-key-press-pause 0.2
gset org.onboard.auto-show reposition-method-docked "'prevent-occlusion'"
gset org.onboard.auto-show reposition-method-floating "'prevent-occlusion'"

gset org.onboard.window docking-enabled true
gset org.onboard.window docking-edge "'bottom'"
gset org.onboard.window docking-shrink-workarea false
gset org.onboard.window force-to-top true

gset org.onboard.window.landscape dock-expand true
gset org.onboard.window.landscape dock-width 900
gset org.onboard.window.landscape dock-height 180
gset org.onboard.window.landscape x 20
gset org.onboard.window.landscape y 860

gset org.onboard.window.portrait dock-expand true
gset org.onboard.window.portrait dock-width 650
gset org.onboard.window.portrait dock-height 200
gset org.onboard.window.portrait x 20
gset org.onboard.window.portrait y 860

gset org.onboard start-minimized true
gset org.onboard show-status-icon true
```

---

### Autostart Onboard

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/onboard.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Onboard
Exec=onboard
X-GNOME-Autostart-enabled=true
EOF
```

---

# 4. Dashboard (Fullscreen HTML)

Place your dashboard:

```
/home/pitv/dashboard/index.html
```

---

# 5. Firefox ESR (Frameless)

### Why no `--kiosk`?

Firefox `--kiosk` breaks Onboard overlays on Wayland; windows become immovable and layered incorrectly.

Instead we use a **custom profile** with **userChrome.css** to hide all chrome.

---

### Create the Firefox profile

```bash
mkdir -p ~/.mozilla/firefox/kiosk-profile/chrome
```

**Hide chrome:**

```bash
cat > ~/.mozilla/firefox/kiosk-profile/chrome/userChrome.css <<'EOF'
#TabsToolbar,
#nav-bar,
#PersonalToolbar,
#toolbar-menubar { visibility: collapse !important; }
#sidebar-header { display: none !important; }
EOF
```

**Profile preferences:**

```bash
cat > ~/.mozilla/firefox/kiosk-profile/prefs.js <<'EOF'
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.sessionstore.resume_session_once", false);
user_pref("browser.startup.homepage", "file:///home/pitv/dashboard/index.html");
user_pref("browser.startup.page", 1);
EOF
```

---

# 6. Autostart Firefox via systemd (User-Level)

### Why systemd instead of an autostart .desktop?

* More reliable on Wayland
* Automatically respawns on crash
* Delays until the graphical session is fully ready
* Clean, idempotent, reproducible

---

```bash
mkdir -p ~/.config/systemd/user
```

Create the unit:

```bash
cat > ~/.config/systemd/user/pitv-kiosk.service <<'UNIT'
[Unit]
Description=PiTV Firefox Dashboard
After=graphical-session.target

[Service]
Type=simple
Environment=MOZ_ENABLE_WAYLAND=1
Environment=GTK_USE_PORTAL=1
ExecStart=/usr/bin/firefox-esr -profile %h/.mozilla/firefox/kiosk-profile --new-window file:///home/pitv/dashboard/index.html
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
UNIT
```

Enable:

```bash
systemctl --user daemon-reload
systemctl --user enable --now pitv-kiosk.service
```

**FULL BUILD INSTRUCTIONS IN *SETUP.MD***

---

#  Optional Extras (QoL)

These tweaks aren’t part of the core build but can improve the experience.

###  Top Bar Tweaks (Panel Size / Autohide)

You can adjust the Wayland top panel by editing config in `~/.config/lxpanel/...`:

* shrink the panel height
* change icon/padding
* enable autohide

These work but can behave inconsistently across Raspberry Pi OS updates, so PiTV leaves the panel untouched by default.

###  Remote Control Support

PiTV supports any device that sends arrow keys + Enter.
Common options:

* USB air-mouse remotes
* Bluetooth navigation remotes
* HDMI-CEC via `cec-client` (depends on your TV)

The dashboard UI is already optimized for arrow-key navigation.

---

#  Editing the Dashboard Tiles

All tiles on the PiTV home screen are defined in:

```
dashboard/index.html
```

Each tile is a simple block:

```html
<button class="tile" data-tile
  data-url="https://www.netflix.com"
  data-bg="https://example.com/netflix.jpg">
  <div class="tile-art"></div>
  <div class="tile-inner">
    <div class="tile-label">Netflix</div>
    <div class="tile-sub">Movies</div>
  </div>
</button>
```

---

# 📁 Repository Structure

```
pitv/
├── readme.md
├── setup.md
├── dashboard/
│   └── index.html
│
├── geoclue/
│   ├── geolocation-example
│   └── 90-pitv-static.conf
│
├── firefox-profile/
│   ├── chrome/userChrome.css
│   └── prefs.js
│
├── onboard/
│   ├── onboard-settings.sh
│   └── onboard.desktop
│
└──systemd/
    └── pitv-kiosk.service
```

---

#  Verification Checklist

| Component     | Expect                | Command                                       |
| ------------- | --------------------- | --------------------------------------------- |
| Session       | `wayland / rpd-labwc` | `echo "$XDG_SESSION_TYPE / $DESKTOP_SESSION"` |
| GeoClue       | active                | `systemctl status geoclue`                    |
| Static coords | 4 lines               | `sudo cat /etc/geolocation`                   |
| Portals       | active                | `systemctl --user status xdg-desktop-portal`  |
| Dashboard     | loads on boot         | `systemctl --user status pitv-kiosk.service`  |
| Onboard       | auto-popup            | focus any text input                          |

---
