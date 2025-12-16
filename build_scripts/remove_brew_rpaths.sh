#!/usr/bin/env bash

# Remove rpaths on some libraries to homebrew directories that
# appear sometimes on m-series chips (prefer bundled from @loader_path/..)

set -e

DAEMON_DIR="dist/daemon"

if [ ! -d "$DAEMON_DIR" ]; then
  echo "Daemon directory not found at $DAEMON_DIR"
  exit 0
fi

# Find all .so and .dylib files
find "$DAEMON_DIR" -type f \( -name "*.so" -o -name "*.dylib" \) | while read -r lib; do
  # Check for homebrew rpaths
  if otool -l "$lib" 2>/dev/null | grep -q "/opt/homebrew"; then
    echo "Removing homebrew rpath from: $lib"
    # Get all homebrew rpaths and remove them
    otool -l "$lib" | grep -A2 "LC_RPATH" | grep "/opt/homebrew" | awk '{print $2}' | while read -r rpath; do
      install_name_tool -delete_rpath "$rpath" "$lib" 2>/dev/null || true
    done
  fi
done

echo "Homebrew rpath cleanup complete"
