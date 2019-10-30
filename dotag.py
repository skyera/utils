#!python2.7
from __future__ import print_function
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


def get_files():
    myfiles = []
    for root, dirs, files in os.walk("."):
        visit(myfiles, root, files)
    return myfiles


def main():
    start = time.time()
    print('finding files...')
    files = get_files()
    f = open('cscope.files', 'w')
    for fname in files:
        #f.write('"%s"\n' % fname)
        f.write('%s\n' % fname)
    f.close()

    # tags files
    f = open('tags.files', 'w')
    for fname in files:
        f.write(fname + '\n')
    f.close()
    end = time.time()
    print('Number of files', len(files), 'cpu', int(end - start), 'seconds')
    
    cmd = 'cscope -b -q -k -i cscope.files'
    print(cmd)
    os.system(cmd)
    
    f = open('cscope.files')
    out = open('temp.txt', 'w')
    for line in f:
        path = line.strip('"\n')
        name = os.path.basename(path)
        s = '%s\t%s\t1' % (name, path)
        out.write(s + '\n')
    f.close()
    out.close()

    out = open('filenametags', 'w')
    out.write('!_TAG_FILE_SORTED\t2\t/2=foldcase/\n')
    out.close()
    cmd = 'sort -f temp.txt >> filenametags'
    print(cmd)
    os.system(cmd)
    os.remove('temp.txt')

    cmd = 'ctags -L tags.files'
    print(cmd)
    os.system(cmd)
     
    end = time.time()
    cpu = int(end - start)
    print('cpu', cpu, 'sec')


if __name__ == '__main__':
    main()
