#!/bin/sh
# Revert the /share patch applied by an earlier version of this wrapper.
# /share is enabled again by default; this migration step only touches a Pi
# installation that still carries the old patch marker.
set -eu

PACKAGE_DIR="${PI_PACKAGE_DIR:-/opt/pi-packages/npm/lib/node_modules/@earendil-works/pi-coding-agent}"
TARGET="$PACKAGE_DIR/dist/modes/interactive/interactive-mode.js"
MARKER="pi-docker-share-disabled"

if [ ! -f "$TARGET" ]; then
    exit 0
fi

if ! grep -q "$MARKER" "$TARGET"; then
    exit 0
fi

if ! grep -q 'Sharing is disabled by pi-mono-dockerized.' "$TARGET"; then
    echo "restore-pi-share: marker found but the patch text is unknown; reinstall Pi if /share stays disabled." >&2
    exit 1
fi

BACKUP="$TARGET.pi-docker-restore.bak"
cp "$TARGET" "$BACKUP"

sed -i 's#^\( *\)if (text === "/share") { this.showError("Sharing is disabled by pi-mono-dockerized."); this.editor.setText(""); return; } /\* pi-docker-share-disabled \*/ if (false) {#\1if (text === "/share") {#' "$TARGET"

if ! node --check "$TARGET" >/dev/null 2>&1; then
    mv "$BACKUP" "$TARGET"
    echo "restore-pi-share: patched file failed syntax check; original restored." >&2
    exit 1
fi

rm -f "$BACKUP"
echo "Restored /share in Pi."
