#!/usr/bin/env python3
import argparse
import sys
import os
import time

print(sys.version_info)
print(sys.version)

file_type_list = ('.c', '.cpp', '.cc', '.h', '.hpp', '.inl', '.cs', '.java', '.mc', '.rc', '.idl', '.js', '.ts', '.html', '.py', '.sql', '.sh', '.json')


ignore_path_list = ['boost', 'omniorb', 'generated', '_output', '.jazz', 
                    'node_modules', 'wabapp', 'ucm_components', 
                    'pythonstandardlibrary', '.vscode',
                    'virtualenv', '3rdParty','omniwin', 
                    'openthreads']


def parse():
    parser = argparse.ArgumentParser(prog='dotag.py',
            description="generate cscope/tags data",
            epilog="speed")
    parser.add_argument("-f", '--find', help='use gnu find', action='store_true')
    args = parser.parse_args()
    return args.find


def ignore_dirpath(dirpath):
    path = dirpath.lower()
    for ignore_path in ignore_path_list:
        if ignore_path in path:
            return True

    return False


def visit(arg, dirpath, namelist):
    if ignore_dirpath(dirpath):
        return

    for name in namelist:
        path = os.path.join(dirpath, name)
        if os.path.isfile(path):
            root, ext = os.path.splitext(name)
            if ext.lower() in file_type_list:
                if ' ' not in path:
                    arg.append(path)
                else:
                    print(path, 'has spaces')


class FindCmd:
    def __init__(self, ignore_paths, file_exts):
        self.ignore_paths = ignore_paths
        self.file_exts = file_exts
        self.ignore_paths_str = ''
        self.find_cmd = ''

    def create(self):
        self.generate_ignore_paths_str()
        self.generate_files_types_str()
        self.generate_find_cmd()
        print(self.find_cmd)

    def generate_ignore_paths_str(self):
        if not self.ignore_paths:
            return

        paths = []
        for path in self.ignore_paths:
            paths.append(f'-iname "*{path}*"')
        self.ignore_paths_str = ' -or '.join(paths)
        self.ignore_paths_str = f'-type d \( {self.ignore_paths_str} \) -prune'

    def generate_files_types_str(self):
        items = []
        for ext in self.file_exts:
            items.append(f'-iname "*{ext}"')
        self.file_types_str = ' -or '.join(items)
        self.file_types_str = f'-type f \( {self.file_types_str} \)'

    def generate_find_cmd(self):
        if self.ignore_paths_str != "":
            self.find_cmd = f'find . {self.ignore_paths_str} -or {self.file_types_str} -fprint cscope.files'
        else:
            self.find_cmd = f'find . {self.file_types_str} -fprint cscope.files'


def get_files():
    myfiles = []
    for root, dirs, files in os.walk("."):
        visit(myfiles, root, files)
    return myfiles


def gnu_find_files():
    cmd = FindCmd(ignore_path_list, file_type_list)
    cmd.create()
    os.system(cmd.find_cmd)


def py_find_files():
    files = get_files()
    with open('cscope.files', 'w') as f:
        for fname in files:
            f.write('%s\n' % fname)


def collect_files(use_gnu_find):
    print('finding files...')
    start = time.time()
    if use_gnu_find:
        gnu_find_files()
    else:
        py_find_files()
    end = time.time()
    cpu = end - start
    print('find files', get_number_files(), 'cpu:', cpu, 'seconds')


def run_cscope():
    start = time.time()
    cmd = 'cscope -b -q -k -i cscope.files'
    print(cmd)
    os.system(cmd)
    end = time.time()
    cpu = end - start
    print('cscope cpu', cpu, 'seconds')


def get_number_files(filename='cscope.files'):
    with open(filename, "r") as f:
        lines = f.readlines()
    return len(lines)


def create_tempfile():
    cscope_f = open('cscope.files')
    temp_f = open('temp.txt', 'w')
    for line in cscope_f:
        path = line.strip('"\n')
        name = os.path.basename(path)
        s = '%s\t%s\t1' % (name, path)
        temp_f.write(s + '\n')
    cscope_f.close()
    temp_f.close()


def create_filenametags():
    create_tempfile()
    add_tag()
    sort_filenametags()
    os.remove('temp.txt')


def add_tag():
    with open('filenametags', 'w') as tag_f:
        tag_f.write('!_TAG_FILE_SORTED\t2\t/2=foldcase/\n')


def sort_filenametags():
    cmd = 'sort -f temp.txt >> filenametags'
    print(cmd)
    os.system(cmd)


def create_tags():
    start = time.time()
    cmd = 'ctags -L cscope.files'
    print(cmd)
    os.system(cmd)
    end = time.time()
    cpu = end - start
    print('ctags cpu', cpu, 'seconds')


def main():
    use_gnu_find = parse()
    if use_gnu_find:
        print('Gnu find')
    else:
        print('py find')
    start = time.time()
    
    collect_files(use_gnu_find)
    run_cscope() 
    create_filenametags()
    create_tags()

    end = time.time()
    cpu = end - start
    print('cpu', cpu, 'seconds')


if __name__ == '__main__':
    main()
