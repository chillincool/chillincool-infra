#!/bin/bash
# Setup virtual environment for media app configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "Creating virtual environment..."
python3 -m venv "$VENV_DIR"

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "Installing dependencies..."
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "✓ Setup complete!"
echo ""
echo "To use the script:"
echo "  source scripts/venv/bin/activate"
echo "  ./scripts/configure-media-apps.py"
echo ""
echo "To deactivate when done:"
echo "  deactivate"
