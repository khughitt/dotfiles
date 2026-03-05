"""Navigate between user prompts in Claude Code (❯) and Codex CLI (›)."""

from kittens.tui.handler import result_handler

def main(args: list[str]) -> str:
    pass


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    direction = args[1] if len(args) > 1 else 'prev'

    # Ensure a regex marker is set for user prompt indicators:
    #   ❯  Claude Code
    #   ›  Codex CLI
    try:
        boss.call_remote_control(w, ('create-marker', f'--match=id:{w.id}', 'regex', '1', '[❯›]'))
    except Exception:
        pass  # Marker likely already exists

    w.scroll_to_mark(prev=(direction == 'prev'), mark=1)
