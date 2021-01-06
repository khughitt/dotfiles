#!/usr/bin/env python
# -*- coding: utf-8 -*-
# renameworkspace.py - Renaming i3 workspaces with https://github.com/acrisci/i3ipc-python while keeping the <number>: <letter> prefix for keyboard navigation.
# Written in 2017 by Fahrstuhl

# To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.

# You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import i3ipc
import re

class WorkspaceRenamer(object):
    
    def __init__(self):
        self.i3 = i3ipc.Connection()

    def findFocusedWorkspace(self):
        focused = self.i3.get_tree().find_focused()
        workspace = focused.workspace()
        return workspace

    def getWorkspacePrefix(self):
        workspace = self.findFocusedWorkspace()
        prefix = workspace.name.split(':')[0]
        if prefix is None:
            raise LookupError("No workspace name found")
        return prefix[0]

    def interactiveRenameCurrentWorkspace(self):
        prefix = self.getWorkspacePrefix()
        rename_cmd = 'rename workspace to "{} %s"'.format(prefix)
        input_cmd = """exec i3-input -F '{}' -P "Rename workspace to: {} " """.format(rename_cmd, prefix)
        print(rename_cmd)
        print(input_cmd)
        self.i3.command(input_cmd)

def main():
    renamer = WorkspaceRenamer()
    renamer.interactiveRenameCurrentWorkspace()

if __name__ == "__main__":
    main()
