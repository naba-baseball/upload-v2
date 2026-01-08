#!/bin/bash
#
# SessionStart hook for Claude Code on the web
# Installs project dependencies (Mise, Elixir, Node, etc.)
#

set -e

# Only run in remote (web) environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  echo "Not running in Claude Code remote environment, skipping setup"
  exit 0
fi

echo "=== Setting up Claude Code web environment ==="

# Install Mise (if not already installed)
if ! command -v mise &> /dev/null; then
  echo "Installing Mise..."
  curl https://mise.run | sh

  # Add mise to PATH for this session
  export PATH="$HOME/.local/bin:$PATH"

  # Persist mise PATH for subsequent bash commands
  if [ -n "$CLAUDE_ENV_FILE" ]; then
    echo "PATH=$HOME/.local/bin:\$PATH" >> "$CLAUDE_ENV_FILE"
  fi
fi

# Activate mise
eval "$(mise activate bash)"

# Trust and install tools from project's mise config
echo "Installing tools via Mise..."
mise trust --all 2>/dev/null || true
mise install

# Persist mise environment for subsequent bash commands
if [ -n "$CLAUDE_ENV_FILE" ]; then
  mise env >> "$CLAUDE_ENV_FILE"
fi

# Verify installations
echo "Verifying installations..."
elixir --version
node --version

# Install Elixir dependencies
echo "Installing Elixir dependencies..."
mix local.hex --force
mix local.rebar --force
mix deps.get

# Install frontend assets (esbuild, tailwind)
echo "Setting up assets..."
mix assets.setup 2>/dev/null || true

echo "=== Claude Code web environment setup complete ==="
