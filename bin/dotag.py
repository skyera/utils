#!/usr/bin/env python3
#
# Create cscope, filename, tag database for source code
#
import argparse
import os
import shlex
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

FILE_EXTS = (
    ".c",
    ".cpp",
    ".cc",
    ".h",
    ".hpp",
    ".inl",
    ".cs",
    ".java",
    ".mc",
    ".rc",
    ".idl",
    ".js",
    ".ts",
    ".html",
    ".py",
    ".sql",
    ".sh",
    ".json",
    ".sdl",
    ".cu",
    ".cuh",
)

EXCLUDED_DIRS = [
    "boost",
    "omniorb",
    "Generated",
    "_output",
    ".jazz5",
    ".jazzShed",
    "node_modules",
    "webapp",
    "OmniORB",
    "Omni",
    "Omni_VS2015",
    "omniwin",
    "PythonStandardLibrary",
    ".vscode",
    "virtualenv",
    "3rdParty",
    "ThirdParty",
    "third_party",
    "OpenThreads",
    "OpenCV",
    "Anaconda",
    "Debug",
    "Release",
    "cudafe1",
]

EXCLUDED_DIRS_LOWER_CASES = [item.lower() for item in EXCLUDED_DIRS]
CSCOPE_FILE_NAME = "cscope.files"
FILENAMETAG_FILE_NAME = "filenametags"


def parse():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        prog="dotag.py", description="generate cscope/tags data", epilog="fast search"
    )
    parser.add_argument(
        "-f",
        "--find",
        choices=["py", "find", "fd"],
        default="fd",
        help="find files method (default: fd)",
    )
    parser.add_argument(
        "-c",
        "--clean",
        action="store_true",
        help="clean old database files before starting",
    )
    args = parser.parse_args()
    return args.find, args.clean


def is_excluded(path):
    """Is the directory name excluded?"""
    path_parts = Path(path).parts
    excluded_dirs = set(EXCLUDED_DIRS_LOWER_CASES)
    return any(part.lower() in excluded_dirs for part in path_parts)


def visit(files, dirpath, file_names):
    """Check filenames and save them"""
    if is_excluded(dirpath):
        return

    for file_name in file_names:
        path = os.path.join(dirpath, file_name)
        if os.path.isfile(path) and not os.path.islink(path):
            _, ext = os.path.splitext(file_name)
            if ext.lower() in FILE_EXTS:
                files.append(path)


def write_cscope_files(files):
    """Write files to cscope.files, skipping those with spaces and printing a warning."""
    with open(CSCOPE_FILE_NAME, "w", encoding="utf-8") as cscope_f:
        for f in files:
            if " " in f:
                print(f"{f} has spaces", file=sys.stderr)
                continue
            cscope_f.write(f"{f}\n")


class FindCmd:
    """Generate find command by using find"""

    def __init__(self, excluded_dirs, file_exts):
        self.excluded_dirs = excluded_dirs
        self.file_exts = file_exts
        self.excluded_dirs_str = ""
        self.file_exts_str = ""
        self.find_cmd = ""

    def create(self):
        """Create the find cmd"""
        self.generate_excluded_dirs_str()
        self.generate_file_exts_str()
        self.generate_find_cmd()

    def generate_excluded_dirs_str(self):
        """Create excluded_str"""
        if not self.excluded_dirs:
            return

        paths = []
        for path in self.excluded_dirs:
            paths.append(f'-iname "*{path}*"')
        self.excluded_dirs_str = " -or ".join(paths)
        self.excluded_dirs_str = rf"-type d \( {self.excluded_dirs_str} \) -prune"

    def generate_file_exts_str(self):
        """Create exts string"""
        items = []
        for ext in self.file_exts:
            items.append(f'-iname "*{ext}"')
        self.file_exts_str = " -or ".join(items)
        self.file_exts_str = rf"-type f \( {self.file_exts_str} \)"

    def generate_find_cmd(self):
        if self.excluded_dirs_str != "":
            self.find_cmd = f'find . {self.excluded_dirs_str} -or {self.file_exts_str} -print'
        else:
            self.find_cmd = f'find . {self.file_exts_str} -print'


class FdCmd:
    def __init__(self, excluded_patterns, file_exts):
        self.excluded_patterns = excluded_patterns
        self.file_exts = file_exts
        self.fd_cmd = ["fd", "--type", "f", "--ignore-case"]

    def build_cmd(self):
        for ext in self.file_exts:
            self.fd_cmd.extend(["-e", ext.lstrip(".")])

        for pat in self.excluded_patterns:
            self.fd_cmd.extend(["--exclude", pat])

    def run_fd(self):
        print("Running fd")
        print(" ".join(shlex.quote(x) for x in self.fd_cmd))

        result = subprocess.run(
            self.fd_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            print(result.stderr, file=sys.stderr)
            sys.exit(1)

        files = result.stdout.splitlines()
        write_cscope_files(files)


def get_files():
    myfiles = []
    for root, _, file_names in os.walk("."):
        visit(myfiles, root, file_names)
    return myfiles


def gnu_find_files():
    if os.name == "nt":
        try:
            result = subprocess.run(
                ["find", "--version"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False,
            )
            if "GNU findutils" not in result.stdout:
                print("Error: 'find' is not GNU find. On Windows, ensure Git Bash or Cygwin is in your PATH.", file=sys.stderr)
                sys.exit(1)
        except FileNotFoundError:
            print("Error: 'find' command not found.", file=sys.stderr)
            sys.exit(1)

    cmd = FindCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.create()
    print(cmd.find_cmd)
    result = subprocess.run(cmd.find_cmd, shell=True, check=True, stdout=subprocess.PIPE, text=True)
    files = result.stdout.splitlines()
    write_cscope_files(files)


def fd_files():
    cmd = FdCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.build_cmd()
    cmd.run_fd()


def py_find_files():
    files = get_files()
    write_cscope_files(files)


def log_cpu(msg, start):
    cpu = time.time() - start
    print(msg, "CPU", cpu, "seconds")


def collect_files(find_method):
    print("finding files...")
    start = time.time()
    if find_method == "py":
        py_find_files()
    elif find_method == "find":
        gnu_find_files()
    else:
        fd_files()

    num_files = get_number_files()
    log_cpu(f"find files: number of files {num_files}", start)


def run_cscope():
    start = time.time()
    cmd = ["cscope", "-b", "-q", "-k", "-i", CSCOPE_FILE_NAME]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    log_cpu("cscope", start)


def get_number_files(filename=CSCOPE_FILE_NAME):
    with open(filename, "r", encoding="utf-8") as cscope_f:
        lines = cscope_f.readlines()
    return len(lines)


def create_filenametags():
    start = time.time()
    print("creating filenametags (in-memory sort)...")
    
    lines = []
    with open(CSCOPE_FILE_NAME, "r", encoding="utf-8") as f:
        for line in f:
            path = line.strip('"\n')
            name = Path(path).name
            lines.append(f"{name}\t{path}\t1\n")
    
    # Python's sort is stable and efficient. 
    # key=str.lower emulates 'sort -f' (fold-case)
    lines.sort(key=str.lower)
    
    with open(FILENAMETAG_FILE_NAME, "w", encoding="utf-8") as f:
        f.write("!_TAG_FILE_SORTED\t2\t/2=foldcase/\n")
        f.writelines(lines)
        
    log_cpu("filenametags", start)


def create_tags():
    start = time.time()
    cmd = ["ctags", "-L", CSCOPE_FILE_NAME]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    log_cpu("ctags", start)


def log_find_method(find_method):
    print("find method:", find_method)


def check_sort_version():
    """Verify that 'sort' is the GNU version, especially on Windows."""
    sort_cmd = "sort.exe" if os.name == "nt" else "sort"
    # Use shutil.which to ensure we respect the updated os.environ['PATH']
    executable = shutil.which(sort_cmd)
    if not executable:
        return False
    
    try:
        result = subprocess.run(
            [executable, "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if "GNU coreutils" in result.stdout:
            return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass
    return False


def try_apply_setpath():
    """Try to find and run setpath.bat, applying its PATH changes to os.environ."""
    script_dir = os.path.dirname(os.path.realpath(__file__))
    setpath_bat = os.path.join(script_dir, "setpath.bat")

    if not os.path.exists(setpath_bat):
        print(f"[ERROR] {setpath_bat} not found.", file=sys.stderr)
        return

    # Run the batch file and capture the environment changes
    try:
        result = subprocess.run(
            f'"{setpath_bat}" >nul && set',
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    if key.upper() == "PATH":
                        os.environ["PATH"] = value
    except Exception as e:
        print(f"[ERROR] Failed to execute setpath.bat: {e}", file=sys.stderr)


def main():
    find_method, clean = parse()
    log_find_method(find_method)

    if os.name == "nt" and not check_sort_version():
        print("[INFO] GNU sort not found. Attempting to run setpath.bat...", file=sys.stderr)
        try_apply_setpath()
        if not check_sort_version():
            print("[ERROR] GNU sort not found even after running setpath.bat. Quitting.", file=sys.stderr)
            sys.exit(1)
        print("[INFO] GNU sort detected after environment update.")

    # Cleanup old database files to prevent tool-level state conflicts
    if clean:
        print("Cleaning old database files...")
        for f in [CSCOPE_FILE_NAME, "cscope.out", "cscope.in.out", "cscope.po.out", "tags"]:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError:
                    pass

    start = time.time()
    
    # 1. Collect files (Sequential, as it creates the base file)
    collect_files(find_method)
    
    # 2. Run post-processing tasks in parallel
    print("Starting post-processing (parallel)...")
    with ThreadPoolExecutor() as executor:
        futures = [
            executor.submit(run_cscope),
            executor.submit(create_filenametags),
            executor.submit(create_tags),
        ]
        # Wait for all tasks to complete and raise exceptions if any occurred
        for future in futures:
            future.result()

    log_cpu("Total", start)


if __name__ == "__main__":
    main()
