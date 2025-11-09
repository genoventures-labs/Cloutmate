#!/usr/bin/env python3
"""
Aurora Changelog Generator
Automatically generates changelog entries from git staged changes
"""

import json
import subprocess
import sys
import os
import re
import uuid
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# Configuration
CHANGELOG_FILE = "Cloutmate/aurora_changelog.json"
CONFIG_FILE = ".changelog-config.json"

def run_git_command(cmd: List[str]) -> str:
    """Run a git command and return output"""
    try:
        result = subprocess.run(
            ["git"] + cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}", file=sys.stderr)
        return ""

def get_staged_files() -> List[Tuple[str, str]]:
    """Get list of staged files with their status"""
    output = run_git_command(["diff", "--cached", "--name-status"])
    files = []
    for line in output.split("\n"):
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) == 2:
            status, filepath = parts
            files.append((status, filepath))
    return files

def get_file_content(filepath: str) -> Optional[str]:
    """Get content of a staged file"""
    try:
        # For new files, get from index
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return f.read()
        else:
            # Try to get from git index
            output = run_git_command(["show", f":{filepath}"])
            return output
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return None

def extract_feature_name(filepath: str, content: str) -> str:
    """Extract feature name from file path or content"""
    filename = os.path.basename(filepath)
    
    # Remove extension
    name = filename.replace(".swift", "")
    
    # Remove common suffixes
    name = re.sub(r"Service$", "", name)
    name = re.sub(r"Model$", "", name)
    name = re.sub(r"View$", "", name)
    
    # Convert camelCase to Title Case
    name = re.sub(r'([a-z])([A-Z])', r'\1 \2', name)
    name = name.title()
    
    return name

def detect_change_type(status: str, filepath: str, content: str) -> str:
    """Detect change type based on file status and content"""
    if status == "A":  # Added
        if "Service.swift" in filepath:
            return "added"
        elif "Model.swift" in filepath or "struct" in content or "class" in content:
            return "added"
        else:
            return "added"
    elif status == "M":  # Modified
        if "buildSystemPrompt" in content:
            return "modified"
        elif "func" in content or "actor" in content:
            return "improved"
        else:
            return "modified"
    elif status == "D":  # Deleted
        return "deprecated"
    else:
        return "modified"

def extract_description(filepath: str, content: str, change_type: str) -> str:
    """Extract description from file content or generate from context"""
    # Look for capability comments
    capability_pattern = r"//\s*(?:NEW|Capability|Feature):\s*(.+)"
    match = re.search(capability_pattern, content, re.IGNORECASE | re.MULTILINE)
    if match:
        return match.group(1).strip()
    
    # Look for doc comments
    doc_pattern = r"///\s*(.+)"
    matches = re.findall(doc_pattern, content)
    if matches:
        return matches[0].strip()
    
    # Generate from file name and change type
    feature_name = extract_feature_name(filepath, content)
    if change_type == "added":
        return f"Added {feature_name} functionality"
    elif change_type == "modified":
        return f"Updated {feature_name}"
    elif change_type == "improved":
        return f"Improved {feature_name}"
    else:
        return f"Changed {feature_name}"

def extract_tags(filepath: str, content: str) -> List[str]:
    """Extract tags from file path and content"""
    tags = []
    
    # Tags from file path
    if "Service" in filepath:
        tags.append("service")
    if "Model" in filepath:
        tags.append("model")
    if "View" in filepath:
        tags.append("ui")
    
    # Tags from directory
    if "Services" in filepath:
        tags.append("backend")
    if "Models" in filepath:
        tags.append("data")
    if "Views" in filepath:
        tags.append("frontend")
    
    # Tags from content
    if "buildSystemPrompt" in content:
        tags.append("system-prompt")
    if "Ollama" in content:
        tags.append("ollama")
    if "actor" in content:
        tags.append("concurrency")
    
    return list(set(tags))  # Remove duplicates

def is_user_facing(filepath: str, content: str) -> bool:
    """Determine if change is user-facing"""
    # Services are usually user-facing
    if "Service.swift" in filepath:
        return True
    
    # Views are user-facing
    if "View.swift" in filepath:
        return True
    
    # System prompts affect user experience
    if "buildSystemPrompt" in content:
        return True
    
    # Public APIs are user-facing
    if re.search(r"public\s+(func|struct|class|actor)", content):
        return True
    
    return False

def get_current_version() -> str:
    """Get current version from git tags or default"""
    # Try to get latest tag
    tag = run_git_command(["describe", "--tags", "--abbrev=0"])
    if tag:
        # Extract version number
        match = re.search(r"v?(\d+\.\d+)", tag)
        if match:
            return match.group(1)
    
    # Load from existing changelog
    if os.path.exists(CHANGELOG_FILE):
        try:
            with open(CHANGELOG_FILE, 'r') as f:
                changelog = json.load(f)
                return changelog.get("currentVersion", "9.0")
        except:
            pass
    
    return "9.0"

def generate_changelog_entries() -> List[Dict]:
    """Generate changelog entries from staged changes"""
    staged_files = get_staged_files()
    entries = []
    
    if not staged_files:
        return entries
    
    current_version = get_current_version()
    now = datetime.utcnow().isoformat() + "Z"
    
    for status, filepath in staged_files:
        # Only process Swift files in Cloutmate directory
        if not filepath.endswith(".swift") or not filepath.startswith("Cloutmate/"):
            continue
        
        # Skip changelog file itself
        if "aurora_changelog.json" in filepath:
            continue
        
        content = get_file_content(filepath)
        if not content:
            continue
        
        change_type = detect_change_type(status, filepath, content)
        feature_name = extract_feature_name(filepath, content)
        description = extract_description(filepath, content, change_type)
        tags = extract_tags(filepath, content)
        user_facing = is_user_facing(filepath, content)
        
        # Generate impact description
        impact = f"Affects {feature_name} functionality"
        if change_type == "added":
            impact = f"Adds new {feature_name} capability"
        elif change_type == "improved":
            impact = f"Enhances {feature_name} performance or features"
        
        entry = {
            "id": str(uuid.uuid4()),
            "date": now,
            "version": current_version,
            "feature": feature_name,
            "changeType": change_type,
            "description": description,
            "impact": impact,
            "userFacing": user_facing,
            "tags": tags,
            "commitHash": None  # Will be set by post-commit hook
        }
        
        entries.append(entry)
    
    return entries

def load_existing_changelog() -> Dict:
    """Load existing changelog or create new one"""
    if os.path.exists(CHANGELOG_FILE):
        try:
            with open(CHANGELOG_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading changelog: {e}", file=sys.stderr)
    
    # Create new changelog
    return {
        "currentVersion": get_current_version(),
        "lastUpdated": datetime.utcnow().isoformat() + "Z",
        "entries": []
    }

def merge_changelog(existing: Dict, new_entries: List[Dict]) -> Dict:
    """Merge new entries with existing changelog"""
    if not new_entries:
        return existing
    
    # Prepend new entries (newest first)
    existing_entries = existing.get("entries", [])
    merged_entries = new_entries + existing_entries
    
    # Update metadata
    existing["lastUpdated"] = datetime.utcnow().isoformat() + "Z"
    existing["entries"] = merged_entries
    
    return existing

def main():
    """Main function"""
    # Change to repo root
    repo_root = run_git_command(["rev-parse", "--show-toplevel"])
    if repo_root:
        os.chdir(repo_root)
    
    # Generate new entries
    new_entries = generate_changelog_entries()
    
    if not new_entries:
        print("No changelog entries to generate")
        return 0
    
    # Load and merge
    changelog = load_existing_changelog()
    changelog = merge_changelog(changelog, new_entries)
    
    # Write updated changelog
    try:
        with open(CHANGELOG_FILE, 'w') as f:
            json.dump(changelog, f, indent=2)
        print(f"Generated {len(new_entries)} changelog entries")
        return 0
    except Exception as e:
        print(f"Error writing changelog: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())

