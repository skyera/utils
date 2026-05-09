import os
import re
import shutil
import argparse
import time
from pathlib import Path

def convert_zim_to_obsidian(content):
    # 1. Remove Zim Header Metadata
    lines = content.splitlines()
    start_index = 0
    for i, line in enumerate(lines):
        if line.startswith('======') or (i > 3 and line.strip() == ''):
            start_index = i
            break
    content = '\n'.join(lines[start_index:])

    # 2. Convert Headers
    def replace_header(match):
        equals = match.group(1)
        title = match.group(2).strip()
        level = 7 - len(equals)
        level = max(1, min(6, level))
        return f"{'#' * level} {title}"

    content = re.sub(r'^(={1,6})\s+(.*?)\s+\1$', replace_header, content, flags=re.MULTILINE)

    # 3. Formatting
    content = re.sub(r'(?<!:)\/\/(.*?)\/\/', r'*\1*', content) # Italics
    content = re.sub(r'__(.*?)__', r'<u>\1</u>', content)      # Underline
    
    # 4. Checkboxes
    content = content.replace('[ ]', '- [ ]')
    content = content.replace('[x]', '- [x]')
    content = content.replace('[*]', '- [/]')

    # 5. Images
    def replace_image(match):
        path = match.group(1)
        path = re.sub(r'^\.\\|^\.\/', '', path).split('?')[0]
        return f"![[{path}]]"
    content = re.sub(r'\{\{(.*?)\}\}', replace_image, content)

    # 6. Links
    def replace_link(match):
        link_part = match.group(1)
        if '|' in link_part:
            parts = link_part.split('|', 1)
            url = parts[0]
            text = parts[1] if len(parts) > 1 else url
            return f"[{text}]({url})" if url.startswith('http') else f"[[{url}|{text}]]"
        return f"[[{link_part}]]"
    content = re.sub(r'\[\[(.*?)\]\]', replace_link, content)

    return content

def main(src_folder, dest_folder):
    src_path, dest_path = Path(src_folder), Path(dest_folder)
    if not src_path.exists():
        print(f"Error: Source folder '{src_folder}' does not exist.")
        return

    # Count total files first for progress tracking
    print("Scanning files...")
    all_files = []
    for root, _, files in os.walk(src_path):
        for file in files:
            if file.endswith('.txt') or file.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.pdf')):
                all_files.append(Path(root) / file)
    
    total_files = len(all_files)
    if total_files == 0:
        print("No files found to convert.")
        return

    if not dest_path.exists():
        dest_path.mkdir(parents=True)

    print(f"Starting conversion of {total_files} files: {src_path} -> {dest_path}")
    
    start_time = time.time()
    processed_count = 0

    for src_file in all_files:
        rel_path = src_file.relative_to(src_path)
        dest_file_path = dest_path / rel_path
        
        # Ensure destination directory exists
        dest_file_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            skip = False
            if src_file.suffix == '.txt':
                dest_file = dest_file_path.with_suffix('.md')
                if dest_file.exists() and dest_file.stat().st_mtime >= src_file.stat().st_mtime:
                    skip = True
                else:
                    with open(src_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    with open(dest_file, 'w', encoding='utf-8') as f:
                        f.write(convert_zim_to_obsidian(content))
            else:
                # For attachments
                if dest_file_path.exists() and dest_file_path.stat().st_mtime >= src_file.stat().st_mtime:
                    skip = True
                else:
                    shutil.copy2(src_file, dest_file_path)
        except Exception as e:
            print(f"\nError processing {src_file}: {e}")

        processed_count += 1
        
        # Calculate Progress and ETA
        elapsed = time.time() - start_time
        avg_time = elapsed / processed_count
        remaining_files = total_files - processed_count
        eta_seconds = remaining_files * avg_time
        
        percent = (processed_count / total_files) * 100
        
        # Format ETA
        if eta_seconds > 60:
            eta_str = f"{int(eta_seconds // 60)}m {int(eta_seconds % 60)}s"
        else:
            eta_str = f"{int(eta_seconds)}s"

        # Update progress line
        status = "Skipped" if skip else "Processing"
        print(f"\rProgress: [{processed_count}/{total_files}] {percent:.1f}% | ETA: {eta_str} | {status}: {rel_path.name[:30]:<30}", end="", flush=True)

    print(f"\n\nConversion complete in {elapsed:.1f} seconds!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert Zim Wiki to Obsidian Markdown.")
    parser.add_argument("-i", "--input", required=True, help="Path to the Zim Wiki 'Notes' folder.")
    parser.add_argument("-o", "--output", required=True, help="Path to the desired Obsidian vault output folder.")
    
    args = parser.parse_args()
    main(args.input, args.output)
