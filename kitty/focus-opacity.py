# Focus-driven background opacity for kitty OS windows.
#
# kitty has no built-in "opacity when unfocused" option, but it does fire
# on_focus_change watchers on OS-window focus (boss.on_focus -> Window
# .focus_changed -> call_watchers), so we drive the opacity ourselves.
#
# This only moves the *background*: kitty's background_opacity applies to cells
# whose background matches the default background color (plus anything listed
# in transparent_background_colors). Glyphs and kitty graphics go through
# separate shader paths and stay fully opaque. Text dimming on unfocus is a
# separate knob -- inactive_text_alpha in kitty.conf.
#
# Requires dynamic_background_opacity yes in kitty.conf (already set).
# Wired up via `watcher focus-opacity.py` in kitty.conf; note that reloading
# the kitty config only attaches watchers to windows created after the reload.

from kitty.colors import patch_colors
from kitty.fast_data_types import get_options

# --- knobs -----------------------------------------------------------------
# ACTIVE should match background_opacity in kitty.conf so a window starts out
# at the right value before its first focus event.
ACTIVE_BACKGROUND_OPACITY = 0.95
INACTIVE_BACKGROUND_OPACITY = 0.65
# ---------------------------------------------------------------------------


def _windows_of(boss, os_window_id):
    tm = boss.os_window_map.get(os_window_id)
    return [w for tab in tm for w in tab] if tm is not None else []


def _rescale_transparent_colors(boss, os_window_id, target):
    """Drag transparent_background_colors along with the window background.

    Those colors (nvim's cursorline, lualine, barbar tabs) resolve their opacity
    against the *configured* background_opacity, not the OS window's current
    one -- colors.c does `if (*opacity < 0) *opacity = OPT(background_opacity)`,
    and change_background_opacity never touches OPT. So without this they would
    stay at their kitty.conf opacity while the body around them dims, making an
    unfocused window's chrome stand out as the most solid thing on screen.

    Scaling rather than assigning keeps any explicit `@opacity` from
    kitty.conf meaningful: an entry pinned at half the body stays at half the
    body in both focus states.
    """
    configured = get_options().transparent_background_colors
    if not configured:
        return
    base = get_options().background_opacity or 1.0
    scale = target / base
    scaled = tuple(
        (color, min(1.0, (base if opacity < 0 else opacity) * scale))
        for color, opacity in configured
    )
    patch_colors({}, scaled, windows=_windows_of(boss, os_window_id))


def on_focus_change(boss, window, data):
    target = (
        ACTIVE_BACKGROUND_OPACITY if data["focused"] else INACTIVE_BACKGROUND_OPACITY
    )
    boss._set_os_window_background_opacity(window.os_window_id, target)
    _rescale_transparent_colors(boss, window.os_window_id, target)
