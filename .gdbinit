# History Settings
set history save on
set history filename ~/.gdb_history
set history size 10000
set history remove-duplicates 50

# Safety & UI Settings
set pagination off
set confirm off
set auto-load safe-path $debugdir:$datadir:~

# Printing & Formatting (Ideal for CGDB)
set print pretty on
set print array on
set print object on
set print vtbl on
set print asm-demangle on
set listsize 10

# Logging
set logging enabled off
set logging file ~/gdb.log
set logging overwrite on
set logging redirect off
set logging enabled on
