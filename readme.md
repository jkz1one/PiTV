# 📺 **PiTV — Raspberry Pi TV Dashboard**

**A minimal, Wayland-based kiosk system for Raspberry Pi OS.**

PiTV is a small, reliable setup that turns a Raspberry Pi into a clean, remote-friendly TV interface. Everything is built around stability: a fullscreen dashboard, a frameless Firefox ESR profile, and predictable location behavior for streaming apps. The system stays simple, uses only a handful of config files, and avoids fragile kiosk flags entirely.

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

# 📦 Installation Summary


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
