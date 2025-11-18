# 📺 PiTV — Raspberry Pi TV Dashboard

**A minimal, Wayland-based kiosk system.**

PiTV delivers a clean, reliable, living room ready experience on Raspberry Pi OS (BookWorm).

Key Capabilities:

* Boots directly into a fullscreen, remote-friendly dashboard
* Frameless Firefox ESR profile optimized for TV display
* On-screen keyboard that auto-shows on text fields and stays above apps
* Stable static-location behavior via GeoClue + XDG portals
* Fully Wayland-native (rpd-labwc), no Chromium, no fragile kiosk flags
* Reproducible setup using isolated config files and a systemd user service

---

# 🛠️ Requirements

* Raspberry Pi 4 or 5
* Raspberry Pi OS Bookworm (64-bit, Desktop)
* Wayland session: `wayland / rpd-labwc`
* Basic keyboard for initial setup
* Internet 

---

# 📦 Installation Summary

1️⃣ System Setup

Flash OS
Use Raspberry Pi Imager → Raspberry Pi OS (64-bit) with desktop.
Configure username (pitv), Wi-Fi, and SSH if desired.
Boot to the desktop and verify the session:

```
echo "$XDG_SESSION_TYPE / $DESKTOP_SESSION"
# → wayland / rpd-labwc
```

If audio or Wi-Fi misbehave, fix them in sudo raspi-config.

Install packages

```
sudo apt update
sudo apt install -y \
  firefox-esr geoclue-2.0 \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  onboard at-spi2-core gsettings-desktop-schemas dconf-cli \
  x11-utils dbus-x11
```

2️⃣ Static Location (GeoClue + Portal Chain)

Create /etc/geolocation with fixed coordinates and lock its permissions:

```
sudo tee /etc/geolocation >/dev/null <<'EOF'
40.7580
-73.9855
10
1000
EOF
sudo chown geoclue /etc/geolocation
sudo chmod 600 /etc/geolocation
```

Allow only the static source and whitelist Firefox ESR for the current UID:

```
UIDNUM=$(id -u)
sudo install -d /etc/geoclue/conf.d
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

sudo systemctl restart geoclue
```

Enable the desktop-wide location toggle and start the portals:

```
gsettings set org.gnome.system.location enabled true
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service
```

Test:

```
GTK_USE_PORTAL=1 MOZ_ENABLE_WAYLAND=1 firefox-esr https://browserleaks.com/geo
```

Allow the prompt → site shows the static NYC coordinates.

3️⃣ Onboard Touch Keyboard Setup (Verified Wayland)

Apply sane defaults:

```
gset() { s=$1; k=$2; v=$3;
  gsettings writable "$s" "$k" >/dev/null 2>&1 && gsettings set "$s" "$k" "$v";
}

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
gset org.onboard.window.portrait  dock-expand true
gset org.onboard.window.portrait  dock-width 650
gset org.onboard.window.portrait  dock-height 200
gset org.onboard.window.portrait  x 20
gset org.onboard.window.portrait  y 860

gset org.onboard start-minimized true
gset org.onboard show-status-icon true
```

Autostart Onboard at every login:

```
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/onboard.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Onboard
Exec=onboard
X-GNOME-Autostart-enabled=true
EOF
```


Expected behavior → auto-pops on text fields, hides afterward, docked bottom, handle visible when idle.

4️⃣ Dashboard (Fullscreen HTML)

Create /home/pitv/dashboard/index.html — compact dark UI with arrow-key navigation and Reload button.
(Full HTML included in current working version; do not alter theme or layout without preserving keyboard and reload behavior.)

```
5️⃣ Firefox Profile (Frameless Window)
mkdir -p ~/.mozilla/firefox/kiosk-profile/chrome
cat > ~/.mozilla/firefox/kiosk-profile/chrome/userChrome.css <<'EOF'
#TabsToolbar,
#nav-bar,
#PersonalToolbar,
#toolbar-menubar { visibility: collapse !important; }
#sidebar-header { display: none !important; }
EOF

cat > ~/.mozilla/firefox/kiosk-profile/prefs.js <<'EOF'
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.sessionstore.resume_session_once", false);
user_pref("browser.startup.homepage", "file:///home/pitv/dashboard/index.html");
user_pref("browser.startup.page", 1);
EOF
```

6️⃣ Autostart Firefox via Systemd (User Unit)

```
mkdir -p ~/.config/systemd/user
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

systemctl --user daemon-reload
systemctl --user enable --now pitv-kiosk.service
```

Firefox launches maximized to the dashboard each boot; Onboard floats above it.

7️⃣ Verification Checklist
Component	Expect	Command
Session	wayland / rpd-labwc	echo "$XDG_SESSION_TYPE / $DESKTOP_SESSION"
GeoClue	active	systemctl status geoclue
Static coords	4 lines	sudo cat /etc/geolocation
Portal	active	systemctl --user status xdg-desktop-portal
Portal toggle	true	gsettings get org.gnome.system.location enabled
Dashboard	loads on boot	systemctl --user status pitv-kiosk.service
Onboard	auto-popup + handle	focus text box

8️⃣ Guiding Rules

Don't use Chromium

Don't use --kiosk flags (breaks keyboard layering)

Firefox ESR + GeoClue + portal chain = working static location

Onboard must stay force-to-top and start-minimized

Use systemd user service for reproducible autostart (no .desktop autostarts for Firefox)

Only edit:

```
/etc/geolocation

/etc/geoclue/conf.d/90-pitv-static.conf

~/.mozilla/firefox/kiosk-profile/*

~/dashboard/index.html

~/.config/systemd/user/pitv-kiosk.service
```

Apply edits →

```
systemctl --user daemon-reload
systemctl --user restart pitv-kiosk
sudo systemctl restart geoclue
```

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
├── README.md
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
├── systemd/
│   └── pitv-kiosk.service
│
└── screenshots/
    ├── dashboard.jpg
    ├── geoclue.jpg
    └── kiosk.jpg
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
