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
    "wabapp",
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
abspath = False


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
        help="find files method(defualt: py)",
    )
    parser.add_argument(
        "-a", "--abspath", action="store_true", help="store absolute path"
    )
    args = parser.parse_args()
    if not args.find in ("py", "find", "fd"):
        parser.print_help()
        sys.exit()

    return args.find, args.abspath


def is_excluded(path):
    """Is the directory name excluded?"""
    path = path.lower()
    for excluded_dir in EXCLUDED_DIRS_LOWER_CASES:
        if excluded_dir in path:
            return True
    return False


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
                    -print | grep -v " " >  {CSCOPE_FILE_NAME}'
        else:
            self.find_cmd = (
                f'find . {self.file_exts_str} -print | grep -v " " {CSCOPE_FILE_NAME} '
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

        files = result.stdout.splitlines()
        files = [f for f in files if not Path(f).is_symlink()]
        with open(CSCOPE_FILE_NAME, "w", encoding="utf-8") as cscope_f:
            for line in files:
                cscope_f.write(f"{line}\n")


def get_files():
    myfiles = []
    curr_dir = "."
    if abspath:
        curr_dir = os.getcwd()
    for root, _, file_names in os.walk(curr_dir):
        visit(myfiles, root, file_names)
    return myfiles


def gnu_find_files():
    cmd = FindCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.create()
    print(cmd.find_cmd)
    os.system(cmd.find_cmd)


def fd_files():
    cmd = FdCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.build_cmd()
    cmd.run_fd()


def py_find_files():
    files = get_files()
    with open(CSCOPE_FILE_NAME, "w") as cscope_f:
        for fname in files:
            cscope_f.write("%s\n" % fname)


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
    cmd = f"cscope -b -q -k -i {CSCOPE_FILE_NAME}"
    print(cmd)
    os.system(cmd)
    log_cpu("cscope", start)


def get_number_files(filename=CSCOPE_FILE_NAME):
    with open(filename, "r") as cscope_f:
        lines = cscope_f.readlines()
    return len(lines)


def create_filenametags():
    creator = FilenametagsCreator(CSCOPE_FILE_NAME, FILENAMETAG_FILE_NAME)
    creator.run()


class FilenametagsCreator:
    """Create filenametag for lookupfile"""

    def __init__(self, cscope_filename, tag_filename):
        self.cscope_filename = cscope_filename
        self.temp_filename = "temp.txt"
        self.tag_filename = tag_filename

    def run(self):
        self.create_tagfile()
        self.create_tempfile()
        self.sort_append_file()
        os.remove(self.temp_filename)

    def create_tempfile(self):
        cscope_f = open(self.cscope_filename)
        temp_f = open(self.temp_filename, "w")
        for line in cscope_f:
            path = line.strip('"\n')
            name = os.path.basename(path)
            line = "%s\t%s\t1" % (name, path)
            temp_f.write(line + "\n")
        cscope_f.close()
        temp_f.close()

    def create_tagfile(self):
        with open(self.tag_filename, "w") as tag_f:
            tag_f.write("!_TAG_FILE_SORTED\t2\t/2=foldcase/\n")

    def sort_append_file(self):
        cmd = f"sort -f {self.temp_filename} >> {self.tag_filename}"
        print(cmd)
        os.system(cmd)


def create_tags():
    start = time.time()
    cmd = f"ctags -L {CSCOPE_FILE_NAME}"
    print(cmd)
    os.system(cmd)
    log_cpu("ctags", start)


def log_find_method(find_method, abspath):
    print("find method:", find_method, "abspath:", abspath)


def main():
    print(sys.version)
    print(datetime.datetime.now())
    global abspath
    find_method, abspath = parse()
    log_find_method(find_method, abspath)

    start = time.time()
    collect_files(find_method)
    run_cscope()
    create_filenametags()
    create_tags()

    log_cpu("Total", start)


if __name__ == "__main__":
    main()
