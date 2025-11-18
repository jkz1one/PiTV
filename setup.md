1️⃣ System Setup

Flash OS
Use Raspberry Pi Imager → Raspberry Pi OS (64-bit) with desktop.
Configure username (pitv), Wi-Fi, and SSH if desired.
Boot to the desktop and verify the session:

```
echo "$XDG_SESSION_TYPE / $DESKTOP_SESSION"
# → wayland / rpd-labwc
```

**If audio or Wi-Fi misbehave, fix them in sudo raspi-config.**

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
40.7585
-73.9852
10
1000
EOF
sudo chown geoclue /etc/geolocation
sudo chmod 600 /etc/geolocation
```
*(You can replace these with any location you want — the values here are just a demo.)*

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

Create /home/pitv/dashboard/index.html 
```
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>PiTV Dashboard</title>
<meta name="viewport" content="width=device-width,initial-scale=1" />
<style>
  :root {
    --bg: #050509;
    --card: #15151b;
    --border: #252531;
    --accent: #6c8bff;
    --accent-soft: rgba(108,139,255,0.18);
    --text: #f3f3fb;
    --muted: #8a8a95;
   }
  * { box-sizing: border-box; }

  body {
    margin: 0;
    padding: 0;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", 
Roboto, sans-serif;
    background: radial-gradient(circle at top, #11111a 0, #050509 55%, 
#020206 100%);
    color: var(--text);
    height: 100vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  header {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 22px;
    border-bottom: 1px solid var(--border);
    background: linear-gradient(180deg, rgba(10,10,18,0.95), 
rgba(5,5,9,0.9));
    box-shadow: 0 6px 16px rgba(0,0,0,0.28);
  }

  header::after {
    content: "";
    position: absolute;
    left: 0; right: 0; bottom: -1px;
    height: 26px;
    background: linear-gradient(180deg, rgba(0,0,0,0.18), transparent);
    pointer-events: none;
  }

  .title-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .title-block h1 {
    font-size: 18px;
    font-weight: 600;
    margin: 0;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .title-block span {
    font-size: 11px;
    color: var(--muted);
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .clock {
    font-size: 13px;
    color: var(--muted);
    min-width: 74px;
    text-align: right;
  }

  .reload-btn {
    border-radius: 999px;
    padding: 6px 14px;
    font-size: 12px;
    border: 1px solid var(--border);
    background: radial-gradient(circle at top, var(--accent-soft), 
rgba(10,10,18,0.9));
    color: var(--text);
    display: inline-flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    outline: none;
  }
  .reload-btn span.icon {
    font-size: 11px;
    transform-origin: center;
  }
  .reload-btn:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .reload-btn:active .icon {
    transform: rotate(180deg);
  }

  main {
    flex: 1;
    display: flex;
    align-items: flex-start;   /* anchor tiles toward top */
    justify-content: center;   /* center horizontally */
    padding: 24px 24px 20px;   /* less bottom padding = less empty space 
*/
  }

  .grid-wrapper {
    width: 100%;
    max-width: 1400px;         /* slightly wider grid */
    margin: 0 auto;
  }

  /* 3 across, 2 down */
  .tile-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 24px;                 /* more breathing room between columns */
  }

  @media (max-width: 900px) {
    .tile-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 640px) {
    .tile-grid {
      grid-template-columns: 1fr;
    }
  }

  .tile {
    position: relative;
    border-radius: 18px;
    border: 1px solid var(--border);
    background-color: #0b0b12;
    padding: 18px 18px 16px;
    text-align: left;
    cursor: pointer;
    outline: none;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    min-height: 190px;         /* slightly taller tiles */
    overflow: hidden;
    transition: transform 180ms ease-out;  /* bounce feel */
  }

  /* image layer */
  .tile-art {
    position: absolute;
    inset: 0;
    background-size: cover;
    background-position: center;
    filter: saturate(1.05);
    transform: scale(1.05);
    z-index: 0;
    transition: transform 260ms ease-out;  /* smooth zoom */
  }

  /* gradient overlay on top of image */
  .tile::before {
    content: "";
    position: absolute;
    inset: 0;
    border-radius: inherit;
    background-image:
      radial-gradient(circle at top left, rgba(108,139,255,0.12), 
rgba(5,5,12,0.75));
    box-shadow: 0 0 0 0 rgba(108,139,255,0.0);
    transition: box-shadow 120ms ease-out, transform 120ms ease-out, 
border-color 120ms ease-out, background-image 120ms ease-out;
    z-index: 1;
    pointer-events: none;
  }

  .tile-inner {
    position: relative;
    z-index: 2;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .tile-label {
    font-size: 18px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    text-shadow: 0 0 6px rgba(0,0,0,0.55);
  }

  .tile-sub {
    font-size: 11px;
    color: var(--muted);
    letter-spacing: 0.12em;
    text-transform: uppercase;
    text-shadow: 0 0 4px rgba(0,0,0,0.6);
  }

  .tile[data-selected="true"],
  .tile:focus-visible {
    border-color: var(--accent);
    transform: translateY(-1px);  /* slight lift */
  }

  .tile[data-selected="true"]::before,
  .tile:focus-visible::before {
    background-image:
      radial-gradient(circle at top left, rgba(108,139,255,0.45), 
rgba(5,5,12,0.96));
    box-shadow:
      0 0 0 2px rgba(108,139,255,0.45),
      0 8px 22px rgba(108,139,255,0.25);  /* outer glow */
  }

  .tile[data-selected="true"] .tile-art,
  .tile:focus-visible .tile-art {
    transform: scale(1.08);       /* zoom on selection */
  }

  .tile:hover::before {
    box-shadow: 0 0 0 1px rgba(108,139,255,0.3);
  }

  footer {
    padding: 6px 18px 10px;
    font-size: 11px;
    color: var(--muted);
    display: flex;
    justify-content: center;
    align-items: center;
    border-top: 1px solid var(--border);
    background: radial-gradient(circle at bottom, rgba(15,15,24,0.9), 
rgba(4,4,8,0.95));
  }

  .footer-keys {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .keycap {
    border-radius: 6px;
    border: 1px solid #2e2e3a;
    padding: 1px 6px;
    font-size: 10px;
    background: #101018;
  }

  /* fade overlay for open transition */
  #fade {
    position: fixed;
    inset: 0;
    background: #000;
    opacity: 0;
    pointer-events: none;
    transition: opacity 280ms ease-out;
    z-index: 999;
  }
</style>
</head>
<body>
<header>
  <div class="title-block">
    <h1>PiTV</h1>
    <span>ARROW KEYS TO MOVE · ENTER TO OPEN</span>
  </div>
  <div class="header-actions">
    <div class="clock" id="clock">--:--</div>
    <button class="reload-btn" id="reload-btn" type="button">
      <span class="icon">⟳</span>
      <span>Reload Dashboard</span>
    </button>
  </div>
</header>

<main>
  <div class="grid-wrapper">
    <div class="tile-grid" id="tile-grid">
      <!-- 1 -->
      <button class="tile" data-tile data-url="https://www.netflix.com" 
data-bg="https://images.ctfassets.net/y2ske730sjqp/1aONibCke6niZhgPxuiilC/2c401b05a07288746ddf3bd3943fbc76/BrandAssets_Logos_01-Wordmark.jpg?w=940">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">Netflix</div>
          <div class="tile-sub">Movies</div>
        </div>
      </button>

      <!-- 2 -->
      <button class="tile" data-tile data-url="https://www.hulu.com" 
data-bg="https://s10019.cdn.ncms.io/wp-content/uploads/2025/07/Hulu-on-DIRECTV.png">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">Hulu</div>
          <div class="tile-sub">Live TV</div>
        </div>
      </button>

      <!-- 3 -->
      <button class="tile" data-tile data-url="https://www.youtube.com" 
data-bg="https://images.indianexpress.com/2023/05/youtube-logo-featured.jpg">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">YouTube</div>
          <div class="tile-sub">Video</div>
        </div>
      </button>

      <!-- 4 -->
      <button class="tile" data-tile data-url="https://www.disneyplus.com" 
data-bg="https://m.media-amazon.com/images/I/719t3jd2NeL.png">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">Disney+</div>
          <div class="tile-sub">Streaming</div>
        </div>
      </button>

      <!-- 5 -->
      <button class="tile" data-tile data-url="https://hbomax.com" 
data-bg="https://variety.com/wp-content/uploads/2023/04/Max-Logo-Warner-Bros.-Discovery.png">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">HBO MAX</div>
          <div class="tile-sub">HBO</div>
        </div>
      </button>

      <!-- 6 -->
      <button class="tile" data-tile 
data-url="https://browserleaks.com/geo" 
data-bg="https://www.shutterstock.com/shutterstock/videos/3465164651/thumb/1.jpg?ip=x480">
        <div class="tile-art"></div>
        <div class="tile-inner">
          <div class="tile-label">Geo Test</div>
          <div class="tile-sub">Debug</div>
        </div>
      </button>
    </div>
  </div>
</main>

<footer>
  <div class="footer-keys">
    <span class="keycap">↑ ↓ ← →</span> Move
    <span class="keycap">Enter</span> Open
    <span class="keycap">R</span> Reload
  </div>
</footer>

<div id="fade"></div>

<script>
  // Simple digital clock (local time)
  function updateClock() {
    var el = document.getElementById('clock');
    if (!el) return;
    var d = new Date();
    var h = String(d.getHours()).padStart(2, '0');
    var m = String(d.getMinutes()).padStart(2, '0');
    el.textContent = h + ':' + m;
  }
  updateClock();
  setInterval(updateClock, 30000);

  var tiles = 
Array.prototype.slice.call(document.querySelectorAll('[data-tile]'));
  var cols = 3; // keep in sync with grid-template-columns repeat(3, ...)

  // Apply background images with gradient overlay already defined in CSS
  tiles.forEach(function(tile) {
    var art = tile.querySelector('.tile-art');
    var bg = tile.getAttribute('data-bg');
    if (art && bg) {
      art.style.backgroundImage = "url('" + bg + "')";
    }
  });

  var currentIndex = 0;

  function selectTile(index) {
    if (!tiles.length) return;
    if (index < 0) index = 0;
    if (index >= tiles.length) index = tiles.length - 1;
    currentIndex = index;
    tiles.forEach(function(t, i) {
      t.dataset.selected = String(i === currentIndex);
    });
    tiles[currentIndex].focus();
  }

  function openWithFade(url) {
    var f = document.getElementById('fade');
    if (!f || !url) {
      if (url) window.location.href = url;
      return;
    }
    f.style.pointerEvents = 'auto';
    f.style.opacity = '1';
    setTimeout(function() {
      window.location.href = url;
    }, 250);
  }

  tiles.forEach(function(tile, index) {
    tile.addEventListener('click', function() {
      var url = tile.getAttribute('data-url');
      if (url) openWithFade(url);
    });
    tile.addEventListener('focus', function() {
      currentIndex = index;
      selectTile(currentIndex);
    });
  });

  document.addEventListener('keydown', function(ev) {
    if (!tiles.length) return;

    switch (ev.key) {
      case 'ArrowRight':
        ev.preventDefault();
        if ((currentIndex + 1) % cols !== 0 && currentIndex + 1 < 
tiles.length) {
          selectTile(currentIndex + 1);
        }
        break;
      case 'ArrowLeft':
        ev.preventDefault();
        if (currentIndex % cols !== 0) {
          selectTile(currentIndex - 1);
        }
        break;
      case 'ArrowDown':
        ev.preventDefault();
        if (currentIndex + cols < tiles.length) {
          selectTile(currentIndex + cols);
        }
        break;
      case 'ArrowUp':
        ev.preventDefault();
        if (currentIndex - cols >= 0) {
          selectTile(currentIndex - cols);
        }
        break;
      case 'Enter':
      case ' ':
        ev.preventDefault();
        var tile = tiles[currentIndex];
        var url = tile.getAttribute('data-url');
        if (url) openWithFade(url);
        break;
      case 'r':
      case 'R':
        ev.preventDefault();
        window.location.reload();
        break;
    }
  });

  // Auto-select the first tile on load
  if (tiles.length) {
    selectTile(0);
  }

  var reloadBtn = document.getElementById('reload-btn');
  if (reloadBtn) {
    reloadBtn.addEventListener('click', function() {
      window.location.reload();
    });
  }
</script>
</body>
</html>
```


5️⃣ Firefox Profile (Frameless Window)
```
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
