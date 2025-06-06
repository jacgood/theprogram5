#!/usr/bin/env python3
"""
Update Bootstrap references to latest CDN version (5.3.3)
This script systematically updates all Bootstrap CSS and JS references to use CDN links.
"""

import os
import re
import sys
from pathlib import Path
import shutil
from datetime import datetime

# Bootstrap 5.3.3 CDN URLs
BOOTSTRAP_CSS_CDN = 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css'
BOOTSTRAP_JS_CDN = 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js'

# Backup directory
BACKUP_DIR = 'bootstrap_update_backup_' + datetime.now().strftime('%Y%m%d_%H%M%S')

# Patterns to match Bootstrap CSS references
CSS_PATTERNS = [
    # Local paths (handles multi-line tags)
    (r'<link[^>]*?href\s*=\s*["\'](?:\./)?(?:\.\./)*((?:assets/|css/|plugins/|vendor/)?(?:.*?/)?bootstrap(?:\.min)?\.css)["\'][^>]*?/?>', 'css_local'),
    # Already CDN URLs (various versions)
    (r'<link[^>]*?href\s*=\s*["\']((?:https?:)?//(?:maxcdn|stackpath|netdna|cdn\.jsdelivr\.net|unpkg)\.(?:bootstrapcdn\.com|com)/(?:npm/)?bootstrap[@/][^"\']*?bootstrap(?:\.min)?\.css)["\'][^>]*?/?>', 'css_cdn'),
    # @import in CSS files
    (r'@import\s+(?:url\s*\(\s*)?["\'](?:\./)?(?:\.\./)*((?:assets/|css/|plugins/|vendor/)?(?:.*?/)?bootstrap(?:\.min)?\.css)["\'](?:\s*\))?;?', 'css_import'),
]

# Patterns to match Bootstrap JS references
JS_PATTERNS = [
    # Local paths (handles multi-line tags)
    (r'<script[^>]*?src\s*=\s*["\'](?:\./)?(?:\.\./)*((?:assets/|js/|plugins/|vendor/)?(?:.*?/)?bootstrap(?:\.min|\.bundle(?:\.min)?)?\.js)["\'][^>]*?>.*?</script>', 'js_local'),
    # Already CDN URLs (various versions)
    (r'<script[^>]*?src\s*=\s*["\']((?:https?:)?//(?:maxcdn|stackpath|netdna|cdn\.jsdelivr\.net|unpkg)\.(?:bootstrapcdn\.com|com)/(?:npm/)?bootstrap[@/][^"\']*?bootstrap(?:\.min|\.bundle(?:\.min)?)?\.js)["\'][^>]*?>.*?</script>', 'js_cdn'),
]

# File extensions to process
FILE_EXTENSIONS = ['.html', '.htm', '.php', '.tpl', '.dna', '.inc', '.css', '.js', '.txt', '.TXT']

# Statistics
stats = {
    'files_processed': 0,
    'files_updated': 0,
    'css_references_updated': 0,
    'js_references_updated': 0,
    'errors': []
}

def should_process_file(filepath):
    """Check if file should be processed based on extension."""
    return any(filepath.endswith(ext) for ext in FILE_EXTENSIONS)

def create_backup(filepath, backup_base_dir):
    """Create backup of file before modification."""
    rel_path = os.path.relpath(filepath, start='/home/jacobgood/theprogram5')
    backup_path = os.path.join(backup_base_dir, rel_path)
    backup_dir = os.path.dirname(backup_path)
    
    os.makedirs(backup_dir, exist_ok=True)
    shutil.copy2(filepath, backup_path)

def update_css_reference(match, pattern_type):
    """Replace CSS reference with CDN URL."""
    stats['css_references_updated'] += 1
    
    # Extract the full tag
    full_match = match.group(0)
    
    # For @import statements
    if '@import' in full_match:
        return f'@import "{BOOTSTRAP_CSS_CDN}";'
    
    # For link tags, preserve other attributes
    # Extract attributes
    attrs = re.findall(r'(\w+)=["\']([^"\']+)["\']', full_match)
    attr_dict = {attr[0]: attr[1] for attr in attrs if attr[0] != 'href'}
    
    # Build new link tag
    new_tag = '<link rel="stylesheet" href="' + BOOTSTRAP_CSS_CDN + '"'
    
    # Add integrity and crossorigin for CDN
    new_tag += ' integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"'
    new_tag += ' crossorigin="anonymous"'
    
    # Preserve other attributes
    for attr, value in attr_dict.items():
        if attr not in ['rel', 'integrity', 'crossorigin']:
            new_tag += f' {attr}="{value}"'
    
    new_tag += '>'
    return new_tag

def update_js_reference(match, pattern_type):
    """Replace JS reference with CDN URL."""
    stats['js_references_updated'] += 1
    
    # Build new script tag with integrity
    new_tag = '<script src="' + BOOTSTRAP_JS_CDN + '"'
    new_tag += ' integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"'
    new_tag += ' crossorigin="anonymous"></script>'
    
    return new_tag

def process_file(filepath):
    """Process a single file to update Bootstrap references."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        stats['errors'].append(f"Error reading {filepath}: {str(e)}")
        return False
    
    original_content = content
    
    # Update CSS references
    for pattern, pattern_type in CSS_PATTERNS:
        content = re.sub(pattern, lambda m: update_css_reference(m, pattern_type), content, flags=re.IGNORECASE | re.DOTALL)
    
    # Update JS references
    for pattern, pattern_type in JS_PATTERNS:
        content = re.sub(pattern, lambda m: update_js_reference(m, pattern_type), content, flags=re.IGNORECASE | re.DOTALL)
    
    # Check if content changed
    if content != original_content:
        try:
            # Create backup
            create_backup(filepath, os.path.join('/home/jacobgood/theprogram5', BACKUP_DIR))
            
            # Write updated content
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            
            stats['files_updated'] += 1
            return True
        except Exception as e:
            stats['errors'].append(f"Error writing {filepath}: {str(e)}")
            return False
    
    return False

def main():
    """Main function to process all files."""
    print("=== Bootstrap to CDN Update Script ===")
    print(f"Updating to Bootstrap 5.3.3")
    print(f"Backup directory: {BACKUP_DIR}")
    print("")
    
    # Get all files in html directory
    html_dir = '/home/jacobgood/theprogram5/html'
    
    if not os.path.exists(html_dir):
        print(f"Error: {html_dir} does not exist")
        return 1
    
    print("Scanning for files to update...")
    files_to_process = []
    
    for root, dirs, files in os.walk(html_dir):
        for file in files:
            filepath = os.path.join(root, file)
            if should_process_file(filepath):
                files_to_process.append(filepath)
    
    total_files = len(files_to_process)
    print(f"Found {total_files} files to process")
    print("")
    
    # Process files
    for i, filepath in enumerate(files_to_process, 1):
        if i % 100 == 0:
            print(f"Progress: {i}/{total_files} files processed...")
        
        stats['files_processed'] += 1
        process_file(filepath)
    
    # Print summary
    print("\n=== Update Summary ===")
    print(f"Files processed: {stats['files_processed']}")
    print(f"Files updated: {stats['files_updated']}")
    print(f"CSS references updated: {stats['css_references_updated']}")
    print(f"JS references updated: {stats['js_references_updated']}")
    
    if stats['errors']:
        print(f"\nErrors encountered: {len(stats['errors'])}")
        for error in stats['errors'][:10]:  # Show first 10 errors
            print(f"  - {error}")
        if len(stats['errors']) > 10:
            print(f"  ... and {len(stats['errors']) - 10} more errors")
    
    print(f"\nBackup created at: {BACKUP_DIR}")
    print("\nUpdate complete!")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())