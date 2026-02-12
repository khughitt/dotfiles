#!/bin/bash
# Restore last wallpaper using pywal cache

# Wait for swww daemon to be ready
sleep 1

# Check if pywal cache exists
if [ -f ~/.cache/wal/wal ]; then
  # Get last wallpaper from pywal cache
  WALLPAPER=$(cat ~/.cache/wal/wal)

  if [ -f "$WALLPAPER" ]; then
    echo "Restoring wallpaper: $WALLPAPER"

    # Restore pywal colors
    wal -R -n

    # Set wallpaper with swww
    swww img "$WALLPAPER" \
      --transition-type fade \
      --transition-duration 2 \
      --transition-fps 60
  else
    echo "Cached wallpaper not found: $WALLPAPER"
  fi
else
  echo "No pywal cache found, skipping wallpaper restore"
fi
