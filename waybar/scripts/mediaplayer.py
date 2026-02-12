#!/usr/bin/env python3
"""
Media player info for Waybar using playerctl.
Outputs JSON format for Waybar's custom module.
"""
import json
import subprocess
import sys


def get_player_status():
    """Get current media player status using playerctl."""
    try:
        # Get player status
        status = subprocess.check_output(
            ["playerctl", "status"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        # Get metadata
        artist = subprocess.check_output(
            ["playerctl", "metadata", "artist"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        title = subprocess.check_output(
            ["playerctl", "metadata", "title"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        # Get player name
        player = subprocess.check_output(
            ["playerctl", "metadata", "playerName"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        # Format text
        if artist and title:
            text = f"{artist} - {title}"
        elif title:
            text = title
        else:
            text = ""

        # Truncate if too long
        max_length = 50
        if len(text) > max_length:
            text = text[:max_length-3] + "..."

        # Create output
        output = {
            "text": text,
            "tooltip": f"{player}: {artist} - {title}",
            "class": status.lower(),
            "alt": player
        }

        print(json.dumps(output))

    except subprocess.CalledProcessError:
        # No player running or no metadata
        print(json.dumps({"text": "", "tooltip": "No media playing"}))
    except Exception as e:
        print(json.dumps({"text": "", "tooltip": f"Error: {e}"}))


if __name__ == "__main__":
    get_player_status()
