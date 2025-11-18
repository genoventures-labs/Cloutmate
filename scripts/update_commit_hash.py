#!/usr/bin/env python3
"""
Update changelog entry with commit hash
Called by post-commit hook
"""

import json
import sys
import os

CHANGELOG_FILE = "FocusOS/aurora_changelog.json"

def update_latest_entry_with_hash(commit_hash: str):
    """Update the most recent changelog entry with commit hash"""
    if not os.path.exists(CHANGELOG_FILE):
        return
    
    try:
        with open(CHANGELOG_FILE, 'r') as f:
            changelog = json.load(f)
        
        # Update the first entry (newest) with commit hash if it doesn't have one
        if changelog.get("entries") and len(changelog["entries"]) > 0:
            # Find entries without commitHash and update the first one
            for entry in changelog["entries"]:
                if "commitHash" not in entry or entry.get("commitHash") is None:
                    entry["commitHash"] = commit_hash
                    break  # Only update the first entry without a hash
        
        with open(CHANGELOG_FILE, 'w') as f:
            json.dump(changelog, f, indent=2)
    except Exception as e:
        print(f"Error updating changelog with commit hash: {e}", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: update_commit_hash.py <commit_hash>", file=sys.stderr)
        sys.exit(1)
    
    commit_hash = sys.argv[1]
    update_latest_entry_with_hash(commit_hash)

