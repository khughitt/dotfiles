#!/bin/bash
# Monitor information and scaling check for Hyprland

echo "======================================"
echo "  Hyprland Monitor Information"
echo "======================================"
echo ""

# Get monitor details
hyprctl monitors

echo ""
echo "======================================"
echo "  Current Configuration"
echo "======================================"
echo ""

# Show current monitor line from config
grep "^monitor=" ~/.config/hypr/hyprland.conf || echo "No explicit monitor configuration found"

echo ""
echo "======================================"
echo "  Recommended Configurations"
echo "======================================"
echo ""

# Get monitor info
MONITORS=$(hyprctl monitors -j | jq -r '.[] | "\(.name) \(.width)x\(.height)@\(.refreshRate) scale:\(.scale)"')

echo "Current monitors:"
echo "$MONITORS"
echo ""

# Parse for recommendations
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    res=$(echo "$line" | awk '{print $2}' | cut -d'@' -f1)
    width=$(echo "$res" | cut -d'x' -f1)

    echo "For monitor: $name ($res)"

    if [ "$width" -ge 3840 ]; then
        echo "  4K/UHD detected - Recommended:"
        echo "    monitor=$name,3840x2160@60,0x0,1.5    # 150% scaling (recommended)"
        echo "    monitor=$name,3840x2160@60,0x0,1.25   # 125% scaling"
        echo "    monitor=$name,3840x2160@60,0x0,2      # 200% scaling"
    elif [ "$width" -ge 3400 ]; then
        echo "  Ultrawide 3440x1440 detected - Recommended:"
        echo "    monitor=$name,3440x1440@100,0x0,1     # No scaling (recommended)"
        echo "    monitor=$name,3440x1440@100,0x0,1.25  # 125% scaling"
        echo "    ✅ Current config looks good!"
    elif [ "$width" -ge 2560 ]; then
        echo "  QHD/1440p detected - Recommended:"
        echo "    monitor=$name,2560x1440@144,0x0,1     # No scaling (recommended)"
        echo "    monitor=$name,2560x1440@144,0x0,1.25  # 125% scaling"
    else
        echo "  1080p or lower - Recommended:"
        echo "    monitor=$name,preferred,auto,1        # No scaling"
    fi
    echo ""
done <<< "$MONITORS"

echo "======================================"
echo "  XWayland Scaling"
echo "======================================"
echo ""
xwayland_scale=$(grep "xwayland" ~/.config/hypr/hyprland.conf | grep "force_zero_scaling" || echo "Not configured")
echo "Current: $xwayland_scale"
echo ""
echo "For better XWayland app scaling, add to hyprland.conf:"
echo "  xwayland {"
echo "    force_zero_scaling = true"
echo "  }"
echo ""

echo "======================================"
echo "  Font Scaling Check"
echo "======================================"
echo ""
echo "Kitty font size check:"
grep "^font_size" ~/.config/kitty/kitty.conf 2>/dev/null || echo "  No kitty config found"
echo ""
echo "If fonts look too large:"
echo "  1. Check monitor scale (above)"
echo "  2. Reduce kitty font_size in ~/.config/kitty/kitty.conf"
echo "  3. Check Firefox: about:config -> layout.css.devPixelsPerPx"
echo ""
