#!/usr/bin/env bash
# Installs/updates the AI-hot-keys text rephrase tool.
# Safe to re-run: every step is idempotent.
set -euo pipefail

REPO_URL="https://github.com/tathagatankit/AI-hot-keys.git"
INSTALL_DIR="$HOME/AI-hot-keys"
REPHRASE_LINK="$HOME/.hammerspoon/rephrase"
INIT_LUA="$HOME/.hammerspoon/init.lua"
KEYCHAIN_SERVICE="rightclick-rephrase"

echo "== AI-hot-keys installer =="
echo ""

# 1. Homebrew is required; we don't bootstrap it ourselves.
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required but wasn't found."
  echo "Install it from https://brew.sh, then re-run this installer."
  exit 1
fi

# 2. Hammerspoon
if [ -d "/Applications/Hammerspoon.app" ]; then
  echo "Hammerspoon already installed, skipping."
else
  echo "Installing Hammerspoon..."
  brew install --cask hammerspoon
fi

# 3. Clone or update the repo
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing install at $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --ff-only
elif [ -e "$INSTALL_DIR" ]; then
  echo "Error: $INSTALL_DIR exists but isn't a git repository."
  echo "Move or remove it, then re-run this installer."
  exit 1
else
  echo "Cloning into $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 4. Symlink into Hammerspoon's config dir. Refuse to touch a real
#    directory/file there (only ever replace our own prior symlink).
mkdir -p "$HOME/.hammerspoon"
if [ -e "$REPHRASE_LINK" ] && [ ! -L "$REPHRASE_LINK" ]; then
  echo "Error: $REPHRASE_LINK exists and isn't a symlink (looks like a manual prior setup)."
  echo "Move or remove it, then re-run this installer."
  exit 1
fi
ln -sf "$INSTALL_DIR/hammerspoon/rephrase" "$REPHRASE_LINK"

# 5. Wire up init.lua (create it if missing, never duplicate the line)
touch "$INIT_LUA"
if ! grep -q 'require("rephrase.init")' "$INIT_LUA"; then
  echo 'require("rephrase.init")' >> "$INIT_LUA"
fi

# 6. Local config -- never overwrite a returning user's customized config
CONFIG_LUA="$INSTALL_DIR/hammerspoon/rephrase/config.lua"
if [ ! -f "$CONFIG_LUA" ]; then
  cp "$INSTALL_DIR/hammerspoon/rephrase/config.lua.example" "$CONFIG_LUA"
fi

# 7. Gemini API key -- prompt to set or replace it, hidden input either way.
# Reads from /dev/tty explicitly, not plain stdin: when this script is run
# as `curl ... | bash`, stdin is the pipe carrying the script's own source,
# already at EOF by the time execution reaches here -- a plain `read` would
# silently return empty instead of actually waiting for the user to type.
# /dev/tty is the real keyboard/terminal regardless of how the script itself
# was invoked.
echo ""
HAD_KEY=false
if security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w >/dev/null 2>&1; then
  HAD_KEY=true
fi

# `-r /dev/tty` only checks permission bits, not whether it's actually
# attachable (e.g. no controlling terminal at all), so actually try to open it.
if (exec 3< /dev/tty) 2>/dev/null; then
  if [ "$HAD_KEY" = true ]; then
    echo "A Gemini API key is already stored in Keychain."
    read -r -s -p "Enter a new key to replace it, or press Enter to keep the existing one: " API_KEY < /dev/tty
  else
    echo "Get a Gemini API key from https://aistudio.google.com/apikey"
    echo "(separate from any ChatGPT/Gemini consumer subscription -- this is a pay-as-you-go API key)."
    read -r -s -p "Paste your Gemini API key: " API_KEY < /dev/tty
  fi
  echo ""
else
  echo "No interactive terminal available to prompt for a Gemini API key -- skipping."
  API_KEY=""
fi

if [ -n "${API_KEY:-}" ]; then
  security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w "$API_KEY" -U
  echo "API key stored in Keychain."
elif [ "$HAD_KEY" = false ]; then
  echo "No key entered -- the tool won't work until you add one. Run this later:"
  echo "  security add-generic-password -a \"\$USER\" -s \"$KEYCHAIN_SERVICE\" -w \"YOUR_KEY_HERE\""
fi

# 8. Launch Hammerspoon
open -a Hammerspoon

# 9. The one step macOS requires a human for: Accessibility permission.
echo ""
echo "One last step only you can do -- macOS requires manual approval here:"
echo "  System Settings -> Privacy & Security -> Accessibility -> enable Hammerspoon"
echo "Opening System Settings to that pane now..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

echo ""
echo "Done. Once Hammerspoon is enabled in Accessibility, select text anywhere and press ⌘⌥R."
echo "Settings (hotkey, model, formatting mode) live at: $CONFIG_LUA"
