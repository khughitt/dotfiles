#!/bin/env python3
import argparse
import json
import re
import sys
from subprocess import PIPE, run


def get_ws():
    return json.loads(run('i3-msg -t get_workspaces'.split(), stdout=PIPE).stdout)


def to_empty(current=None, strict=False, right=True, move=False, wrap=True, min_num=1):
    """Move to nearest empty numbered workspace"""
    if current is None:
        current = [w for w in get_ws() if w['focused']][0]

    numbered = re.compile('^\d+$' if strict else '^\d+|(\d+:.*)$')

    ns = {w['num'] for w in get_ws() if numbered.match(w['name']) != None and
          (not strict or w['name'] == str(w['num']))}

    if numbered.match(current['name']) is None:
        # If current workspace is unnumbered, pick rightmost or leftmost
        if len(ns) == 0:
            new_ix = min_num
        else:
            new_ix = min(ns) - 1 if right else max(ns) + 1
    else:
        # Find numbered workspace nearest to current
        new_ix = current['num']

    while new_ix in ns:
        new_ix += 1 if right else -1

    # Wrap around
    if new_ix < min_num:
        if wrap:
            new_ix = max(ns) + 1
        else:
            return

    if move:
        s = 'i3-msg move container to workspace {0}; workspace {0}'.format(new_ix)
    else:
        s = 'i3-msg workspace ' + str(new_ix)
    print(s)
    run(s.split())


def to_empty_near(num, relative=False, **kwargs):
    """Move to empty numbered workspace nearest to workspace 'num'"""
    if relative:
        if 0 <= num < len(get_ws()):
            current = get_ws()[num]
        else:
            return
    else:
        ns = [w for w in get_ws() if w['num'] == num]
        current = ns[0] if len(ns) > 0 else {'num': num, 'name': str(num)}
    to_empty(current, **kwargs)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Switch to an empty numbered workspace.')
    parser.add_argument('direction', type=str, nargs='?', default='next',
                        help='either next (default) or prev')
    parser.add_argument('number', type=int, nargs='?',
                        help='workspace to start searching from (default: current)')
    parser.add_argument('-r', '--relative', dest='rel', action='store_true',
                        help='use workspace indices, not numbers (default: no)')
    parser.add_argument('-w', '--nowrap', dest='wrap', action='store_false',
                        help='if at edge, wrap around to other edge (default: yes)')
    parser.add_argument('-s', '--nostrict', dest='strict', action='store_false',
                        help='numbered workspaces have a numeric name (default: yes)')
    parser.add_argument('-m', '--move', dest='move', action='store_true',
                        help='move container to new workspace (default: no)')

    args = parser.parse_args()
    kwargs = {'right': args.direction.lower().strip() == 'next',
              'wrap': args.wrap, 'strict': args.strict, 'move': args.move}

    if type(args.number) is int:
        to_empty_near(args.number, relative=args.rel, **kwargs)
    else:
        to_empty(**kwargs)
