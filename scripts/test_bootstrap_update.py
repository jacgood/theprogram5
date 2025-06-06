#!/usr/bin/env python3
"""
Test version - Update Bootstrap references on a few sample files
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

# Test on just a few files first
TEST_LIMIT = 5

# Patterns to match Bootstrap CSS references
CSS_PATTERNS = [
    # Local paths
    (r'<link[^>]*href=["\'](?:\./)?(?:\.\./)*((?:assets/|css/|plugins/|vendor/)?(?:.*?/)?bootstrap(?:\.min)?\.css)["\'][^>]*/?>', 'css_local'),
    # Already CDN URLs (various versions)
    (r'<link[^>]*href=["\']((?:https?:)?//(?:maxcdn|stackpath|netdna|cdn\.jsdelivr\.net|unpkg)\.(?:bootstrapcdn\.com|com)/(?:npm/)?bootstrap[@/][^"\']*?bootstrap(?:\.min)?\.css)["\'][^>]*/?>', 'css_cdn'),
]

# Patterns to match Bootstrap JS references
JS_PATTERNS = [
    # Local paths
    (r'<script[^>]*src=["\'](?:\./)?(?:\.\./)*((?:assets/|js/|plugins/|vendor/)?(?:.*?/)?bootstrap(?:\.min|\.bundle(?:\.min)?)?\.js)["\'][^>]*>.*?</script>', 'js_local'),
    # Already CDN URLs (various versions)
    (r'<script[^>]*src=["\']((?:https?:)?//(?:maxcdn|stackpath|netdna|cdn\.jsdelivr\.net|unpkg)\.(?:bootstrapcdn\.com|com)/(?:npm/)?bootstrap[@/][^"\']*?bootstrap(?:\.min|\.bundle(?:\.min)?)?\.js)["\'][^>]*>.*?</script>', 'js_cdn'),
]

def find_test_files():
    """Find a few files with Bootstrap references for testing."""
    html_dir = '/home/jacobgood/theprogram5/html'
    test_files = []
    
    # Look for files with likely Bootstrap references
    patterns_to_check = ['bootstrap.min.css', 'bootstrap.css', 'bootstrap.min.js', 'bootstrap.js']
    
    for root, dirs, files in os.walk(html_dir):
        if len(test_files) >= TEST_LIMIT:
            break
            
        for file in files:
            if len(test_files) >= TEST_LIMIT:
                break
                
            if file.endswith(('.html', '.tpl', '.php')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        if any(pattern in content for pattern in patterns_to_check):
                            test_files.append(filepath)
                except:
                    pass
    
    return test_files

def show_changes(filepath, original, updated):
    """Display what will be changed in a file."""
    print(f"\n{'='*60}")
    print(f"File: {filepath}")
    print(f"{'='*60}")
    
    # Find CSS changes
    for pattern, _ in CSS_PATTERNS:
        original_matches = re.findall(pattern, original, re.IGNORECASE | re.DOTALL)
        if original_matches:
            print("\nCSS References to update:")
            for match in original_matches:
                if isinstance(match, tuple):
                    match = match[0]
                print(f"  - Found: {match}")
            print(f"  → Will replace with: {BOOTSTRAP_CSS_CDN}")
    
    # Find JS changes
    for pattern, _ in JS_PATTERNS:
        original_matches = re.findall(pattern, original, re.IGNORECASE | re.DOTALL)
        if original_matches:
            print("\nJS References to update:")
            for match in original_matches:
                if isinstance(match, tuple):
                    match = match[0]
                print(f"  - Found: {match}")
            print(f"  → Will replace with: {BOOTSTRAP_JS_CDN}")

def update_content(content):
    """Update Bootstrap references in content."""
    # Update CSS references
    for pattern, pattern_type in CSS_PATTERNS:
        def css_replacer(match):
            new_tag = '<link rel="stylesheet" href="' + BOOTSTRAP_CSS_CDN + '"'
            new_tag += ' integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"'
            new_tag += ' crossorigin="anonymous">'
            return new_tag
        
        content = re.sub(pattern, css_replacer, content, flags=re.IGNORECASE | re.DOTALL)
    
    # Update JS references
    for pattern, pattern_type in JS_PATTERNS:
        def js_replacer(match):
            new_tag = '<script src="' + BOOTSTRAP_JS_CDN + '"'
            new_tag += ' integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"'
            new_tag += ' crossorigin="anonymous"></script>'
            return new_tag
        
        content = re.sub(pattern, js_replacer, content, flags=re.IGNORECASE | re.DOTALL)
    
    return content

def main():
    """Test the update process on a few files."""
    print("=== Bootstrap Update Test ===")
    print(f"Testing update to Bootstrap 5.3.3 CDN")
    print(f"Will process up to {TEST_LIMIT} files")
    print("")
    
    # Find test files
    print("Finding test files...")
    test_files = find_test_files()
    
    if not test_files:
        print("No test files found with Bootstrap references")
        return 1
    
    print(f"Found {len(test_files)} test files")
    
    # Process each test file
    for filepath in test_files:
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                original_content = f.read()
            
            updated_content = update_content(original_content)
            
            if updated_content != original_content:
                show_changes(filepath, original_content, updated_content)
                
                # Show a sample of the updated content
                print("\nSample of updated content:")
                lines = updated_content.split('\n')
                for i, line in enumerate(lines):
                    if 'bootstrap' in line.lower() and ('cdn.jsdelivr.net' in line or 'integrity' in line):
                        start = max(0, i - 1)
                        end = min(len(lines), i + 2)
                        print("  ...")
                        for j in range(start, end):
                            print(f"  {j+1}: {lines[j]}")
                        print("  ...")
                        break
            else:
                print(f"\n{filepath}: No Bootstrap references found to update")
                
        except Exception as e:
            print(f"\nError processing {filepath}: {str(e)}")
    
    print("\n" + "="*60)
    print("Test complete!")
    print("\nTo apply changes to all files, run:")
    print("  python3 /home/jacobgood/theprogram5/scripts/update_bootstrap_to_cdn.py")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())