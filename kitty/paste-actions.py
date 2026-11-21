# kitty paste filter, enabled by `filter` in kitty.conf's paste_actions.
#
# Double-clicking a path at the end of a sentence selects the sentence's period
# too. When a paste is a single absolute or ~ path whose trailing [.,;:] run is
# not part of a real file name, drop that run. The check needs both: the pasted
# path must not exist and the trimmed one must, so real names ending in a
# period survive. Relative paths are left alone: kitty cannot see the shell's
# working directory. kitty loads this file once per process; restart kitty
# after editing it.
import os
import re

_TRAILING = re.compile(r"[.,;:]+$")


def filter_paste(text: str) -> str:
    candidate = text.strip()
    if not candidate.startswith(("/", "~")) or any(c.isspace() for c in candidate):
        return text
    trimmed = _TRAILING.sub("", candidate)
    if trimmed == candidate:
        return text
    if os.path.exists(os.path.expanduser(candidate)):
        return text
    if not os.path.exists(os.path.expanduser(trimmed)):
        return text
    return trimmed
