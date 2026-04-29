set history save on
set print pretty on
set pagination off
set confirm off
set history filename ~/.gdb_history
set history size 1000
set auto-load safe-path /

# logging
set logging file ~/gdb.log
set logging overwrite on
set logging redirect off
set logging on

set print array on
set print object on
set width 0
set height 0
set listsize 10

# GDB Dashboard
source ~/bin/gdb-dashboard.py

# Dashboard Configuration
dashboard -layout source assembly registers stack variables expressions threads
dashboard -style syntax_highlighting 'monokai'
dashboard source -style context 5
dashboard registers -style compact True

# Auto-open dashboard on start
define hook-stop
  dashboard
end

