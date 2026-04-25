#!/usr/bin/env python3
#
# Create cscope, filename, tag database for source code
#
import argparse
import datetime
import os
import shlex
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
    "*cudafe1*",
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
    args = parser.parse_args()
    return args.find


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
                if " " not in path:
                    files.append(path)
                else:
                    print(path, "has spaces")


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
            self.find_cmd = f'find . {self.excluded_dirs_str} -or {self.file_exts_str} \
                    -print | grep -v " " > {CSCOPE_FILE_NAME}'
        else:
            self.find_cmd = (
                f'find . {self.file_exts_str} -print | grep -v " " > {CSCOPE_FILE_NAME}'
            )


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

        files = [
            f for f in result.stdout.splitlines()
            if not Path(f).is_symlink() and " " not in f
        ]
        with open(CSCOPE_FILE_NAME, "w", encoding="utf-8") as cscope_f:
            for line in files:
                cscope_f.write(f"{line}\n")


def get_files():
    myfiles = []
    for root, _, file_names in os.walk("."):
        visit(myfiles, root, file_names)
    return myfiles


def gnu_find_files():
    cmd = FindCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.create()
    print(cmd.find_cmd)
    subprocess.run(cmd.find_cmd, shell=True, check=True)


def fd_files():
    cmd = FdCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.build_cmd()
    cmd.run_fd()


def py_find_files():
    files = get_files()
    with open(CSCOPE_FILE_NAME, "w", encoding="utf-8") as cscope_f:
        for fname in files:
            cscope_f.write(f"{fname}\n")


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


def main():
    find_method = parse()
    print(sys.version)
    print(datetime.datetime.now())
    log_find_method(find_method)

    start = time.time()
    
    # 1. Collect files (Sequential, as it creates the base file)
    collect_files(find_method)
    
    # 2. Run post-processing tasks in parallel
    print("Starting post-processing (parallel)...")
    with ThreadPoolExecutor() as executor:
        executor.submit(run_cscope)
        executor.submit(create_filenametags)
        executor.submit(create_tags)

    log_cpu("Total", start)


if __name__ == "__main__":
    main()
