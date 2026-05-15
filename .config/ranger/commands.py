from __future__ import (absolute_import, division, print_function)
import os
from ranger.api.commands import Command

class fzf_select(Command):
    """
    :fzf_select
    Find a file using fzf and fd.
    """
    def execute(self):
        import subprocess
        # Using 'fd' for speed and .gitignore respect, matching your bashrc preferences
        if self.quantifier:
            command="fd --type d --hidden --exclude .git | fzf +m --preview 'bat --color=always --style=numbers --line-range :500 {}'"
        else:
            command="fd --hidden --exclude .git | fzf +m --preview 'bat --color=always --style=numbers --line-range :500 {}'"
            
        fzf = self.fm.execute_command(command, stdout=subprocess.PIPE)
        stdout, stderr = fzf.communicate()
        if fzf.returncode == 0:
            fzf_file = os.path.abspath(stdout.decode('utf-8').rstrip('\n'))
            if os.path.isdir(fzf_file):
                self.fm.cd(fzf_file)
            else:
                self.fm.select_file(fzf_file)

class fzf_locate(Command):
    """
    :fzf_locate
    Find a file using fzf and fd starting from the home directory.
    """
    def execute(self):
        import subprocess
        import os
        home = os.path.expanduser('~')
        # Simplified command using absolute paths directly
        command = f"fd --hidden --exclude .git . {home} | fzf -e -i --preview 'bat --color=always --style=numbers --line-range :500 {{}}'"
        fzf = self.fm.execute_command(command, stdout=subprocess.PIPE)
        stdout, stderr = fzf.communicate()
        if fzf.returncode == 0:
            fzf_file = os.path.abspath(stdout.decode('utf-8').rstrip('\n'))
            if os.path.isdir(fzf_file):
                self.fm.cd(fzf_file)
            else:
                self.fm.select_file(fzf_file)
