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

Install required packages:

```bash
sudo apt update
sudo apt install -y \
  firefox-esr geoclue-2.0 \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  onboard at-spi2-core gsettings-desktop-schemas dconf-cli \
  x11-utils dbus-x11
```

Set static geolocation:

```
/etc/geolocation
/etc/geoclue/conf.d/90-pitv-static.conf
```

Restart GeoClue:

```bash
sudo systemctl restart geoclue
```

Enable portals:

```bash
gsettings set org.gnome.system.location enabled true
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service
```

Add Onboard autostart + apply included settings.

Install Firefox kiosk profile:

```
firefox-profile/chrome/userChrome.css
firefox-profile/prefs.js
```

Enable kiosk autostart:

```bash
systemctl --user daemon-reload
systemctl --user enable --now pitv-kiosk.service
```

Add dashboard HTML:

```
dashboard/index.html
```

Reboot — PiTV launches automatically.

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
