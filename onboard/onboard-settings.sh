#!/usr/bin/env bash
set -euo pipefail

# Helper: only set if key exists
gset() {
  local schema="$1" key="$2" val="$3"
  if gsettings writable "$schema" "$key" >/dev/null 2>&1; then
    gsettings set "$schema" "$key" "$val"
    echo "✓ $schema::$key = $val"
  else
    echo "… skipping $schema::$key (not present)"
  fi
}

echo "== Onboard auto-show =="
gset org.onboard.auto-show enabled true
gset org.onboard.auto-show hide-on-key-press true
gset org.onboard.auto-show hide-on-key-press-pause 0.2
gset org.onboard.auto-show reposition-method-docked "'prevent-occlusion'"
gset org.onboard.auto-show reposition-method-floating "'prevent-occlusion'"

echo "== Window behavior =="
gset org.onboard.window docking-enabled true
gset org.onboard.window docking-edge "'bottom'"
gset org.onboard.window docking-shrink-workarea false
gset org.onboard.window force-to-top true

echo "== Orientation sizes/pos =="
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

echo "== Misc UX =="
gset org.onboard start-minimized true
gset org.onboard show-status-icon true

echo "Done. Restarting Onboard…"
pkill -f onboard || true
onboard &
