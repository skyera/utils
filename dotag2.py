#!/usr/bin/env python3
"""
Create cscope, filename, tag database for source code
"""
import argparse
import sys
import os
import time


FILE_EXTS = ('.c', '.cpp', '.cc', '.h', '.hpp', '.inl', '.cs', '.java', '.mc',
             '.rc', '.idl', '.js', '.ts', '.html', '.py', '.sql', '.sh', '.json')
EXCLUDED_DIRS = ['boost', 'omniorb', 'generated', '_output', '.jazz',
                 'node_modules', 'wabapp',
                 'pythonstandardlibrary', '.vscode',
                 'virtualenv', '3rdParty', 'omniwin',
                 'openthreads']
CSCOPE_FILE_NAME = "cscope.files"
FILENAMETAG_FILE_NAME = "filenametags"


def parse():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(prog='dotag.py',
                                     description="generate cscope/tags data",
                                     epilog="fast search")
    parser.add_argument("-f", '--find', default="py",
                        help='find files method: py (default), find, fd')
    args = parser.parse_args()
    if not args.find in ('py', 'find', 'fd'):
        parser.print_help()
        sys.exit()

    return args.find


def is_excluded(dir_name):
    """Is the directory name excluded?"""
    dir_name = dir_name.lower()
    for exclude_dir in EXCLUDED_DIRS:
        if exclude_dir in dir_name:
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
                if ' ' not in path:
                    files.append(path)
                else:
                    print(path, 'has spaces')


class FindCmd:
    """Generate find command by using find"""
    def __init__(self, excluded_dirs, file_exts):
        self.excluded_dirs = excluded_dirs
        self.file_exts = file_exts
        self.excluded_dirs_str = ''
        self.file_exts_str = ''
        self.find_cmd = ''

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
        self.excluded_dirs_str = ' -or '.join(paths)
        self.excluded_dirs_str = rf'-type d \( {self.excluded_dirs_str} \) -prune'

    def generate_file_exts_str(self):
        """Create exts string"""
        items = []
        for ext in self.file_exts:
            items.append(f'-iname "*{ext}"')
        self.file_exts_str = ' -or '.join(items)
        self.file_exts_str = rf'-type f \( {self.file_exts_str} \)'

    def generate_find_cmd(self):
        if self.excluded_dirs_str != "":
            self.find_cmd = f'find . {self.excluded_dirs_str} -or {self.file_exts_str} \
                    -fprint {CSCOPE_FILE_NAME}'
        else:
            self.find_cmd = f'find . {self.file_exts_str} -fprint {CSCOPE_FILE_NAME} '


class FdCmd:
    def __init__(self, excluded_dirs, file_exts):
        self.excluded_dirs = excluded_dirs
        self.file_exts = file_exts
        self.ext_str = ''
        self.excluded_str = ''
        self.fd_cmd = ''

    def create(self):
        self.create_ext_str()
        self.create_excluded_str()
        self.create_fd_cmd()

    def create_ext_str(self):
        items = []
        for ext in self.file_exts:
            ext = ext.lstrip('.')
            item = f'-e {ext}'
            items.append(item)
        self.ext_str = ' '.join(items)

    def create_excluded_str(self):
        items = []
        for name in self.excluded_dirs:
            item = f'-E "*{name}*"'
            items.append(item)
        self.excluded_str = ' '.join(items)

    def create_fd_cmd(self):
        self.fd_cmd = f'fd {self.ext_str} {self.excluded_str} > {CSCOPE_FILE_NAME}'


def get_files():
    myfiles = []
    for root, _, file_names in os.walk("."):
        visit(myfiles, root, file_names)
    return myfiles


def gnu_find_files():
    cmd = FindCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.create()
    print(cmd.find_cmd)
    os.system(cmd.find_cmd)


def fd_files():
    cmd = FdCmd(EXCLUDED_DIRS, FILE_EXTS)
    cmd.create()
    print(cmd.fd_cmd)
    os.system(cmd.fd_cmd)


def py_find_files():
    files = get_files()
    with open(CSCOPE_FILE_NAME, 'w') as cscope_f:
        for fname in files:
            cscope_f.write('%s\n' % fname)


def log_cpu(msg, start):
    cpu = time.time() - start
    print(msg, 'CPU', cpu, 'seconds')


def collect_files(find_method):
    print('finding files...')
    start = time.time()
    if find_method == "py":
        py_find_files()
    elif find_method == "find":
        gnu_find_files()
    else:
        fd_files()

    num_files = get_number_files()
    log_cpu(f'find files: number of files {num_files}', start)


def run_cscope():
    start = time.time()
    cmd = f'cscope -b -q -k -i {CSCOPE_FILE_NAME}'
    print(cmd)
    os.system(cmd)
    log_cpu('cscope', start)


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
        self.temp_filename = 'temp.txt'
        self.tag_filename = tag_filename

    def run(self):
        self.create_tagfile()
        self.create_tempfile()
        self.sort_append_file()
        os.remove(self.temp_filename)

    def create_tempfile(self):
        cscope_f = open(self.cscope_filename)
        temp_f = open(self.temp_filename, 'w')
        for line in cscope_f:
            path = line.strip('"\n')
            name = os.path.basename(path)
            line = '%s\t%s\t1' % (name, path)
            temp_f.write(line + '\n')
        cscope_f.close()
        temp_f.close()

    def create_tagfile(self):
        with open(self.tag_filename, 'w') as tag_f:
            tag_f.write('!_TAG_FILE_SORTED\t2\t/2=foldcase/\n')

    def sort_append_file(self):
        cmd = f'sort -f {self.temp_filename} >> {self.tag_filename}'
        print(cmd)
        os.system(cmd)


def create_tags():
    start = time.time()
    cmd = f'ctags -L {CSCOPE_FILE_NAME}'
    print(cmd)
    os.system(cmd)
    log_cpu("ctags", start)


def log_find_method(find_method):
    print('find method:', find_method)


def main():
    find_method = parse()
    log_find_method(find_method)

    start = time.time()
    collect_files(find_method)
    run_cscope()
    create_filenametags()
    create_tags()

    log_cpu('Total', start)


if __name__ == '__main__':
    main()
