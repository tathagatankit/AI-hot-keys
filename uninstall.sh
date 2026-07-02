#!/usr/bin/env bash
# Removes AI-hot-keys. Only touches things it recognizes as its own;
# deleting the stored API key and the cloned repo require confirmation.
set -euo pipefail

INSTALL_DIR="$HOME/AI-hot-keys"
REPHRASE_LINK="$HOME/.hammerspoon/rephrase"
INIT_LUA="$HOME/.hammerspoon/init.lua"
KEYCHAIN_SERVICE="rightclick-rephrase"

echo "== AI-hot-keys uninstaller =="
echo ""

# Remove the symlink, but only if it points into our install dir --
# never touch a symlink (or directory) that points somewhere else.
if [ -L "$REPHRASE_LINK" ]; then
  TARGET=$(readlink "$REPHRASE_LINK")
  case "$TARGET" in
    "$INSTALL_DIR"/*)
      rm "$REPHRASE_LINK"
      echo "Removed symlink at $REPHRASE_LINK"
      ;;
    *)
      echo "Leaving $REPHRASE_LINK alone -- it points elsewhere ($TARGET)."
      ;;
  esac
fi

# Remove the require line from init.lua, leaving everything else intact.
# (grep -v exits 1 when it filters out every line, e.g. an init.lua that
# only ever had this one line in it -- that's an expected outcome here,
# not a failure, so don't let it trip set -e.)
if [ -f "$INIT_LUA" ] && grep -q 'require("rephrase.init")' "$INIT_LUA"; then
  grep -v 'require("rephrase.init")' "$INIT_LUA" > "$INIT_LUA.tmp" || true
  mv "$INIT_LUA.tmp" "$INIT_LUA"
  echo "Removed the rephrase require line from $INIT_LUA"
fi

# Ask before deleting the Keychain entry
if security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w >/dev/null 2>&1; then
  read -r -p "Delete the stored Gemini API key from Keychain? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE"
    echo "Deleted the stored API key."
  fi
fi

# Ask before deleting the cloned repo
if [ -d "$INSTALL_DIR" ]; then
  read -r -p "Delete the cloned repo at $INSTALL_DIR? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Deleted $INSTALL_DIR"
  fi
fi

echo ""
echo "Done. Restart Hammerspoon (or reload its config) for the change to take effect."
