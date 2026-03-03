#!/usr/bin/env python3
"""
Git Auto-Commit Logic
Analyzes changed files, groups by module, and commits with structured messages.
Supports both hook-triggered (automatic) and manual (skill-invoked) modes.
"""

import subprocess
import sys
import os
import json
import shlex
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Clear git environment variables to avoid interference
for var in ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY']:
    os.environ.pop(var, None)

class CommitAnalyzer:
    """Analyzes code changes and generates intelligent commit messages."""
    
    # Module path patterns
    MODULE_PATTERNS = {
        'Chassis': ['Application/Chassis/', 'Global/GlobalDeclare_Chassis'],
        'Gimbal': ['Application/Gimbal/', 'Global/GlobalDeclare_Gimbal'],
        'Shooter': ['Application/Shooter/', 'Global/GlobalDeclare_Shooter'],
        'Algorithm': ['API/Algorithm'],
        'Communication': ['Communication/'],
        'FreeRTOS': ['FreeRTOS/'],
        'Hook': ['.claude/hooks/'],
        'Skill': ['.claude/skills/'],
        'Config': ['Project/', 'User/main.c', 'User/IRQHandler_Config.c', 'settings'],
        'Doc': ['.md', '.txt'],
    }
    
    CHANGE_TYPE_MAP = {
        'M': '修改',
        'A': '添加',
        'D': '删除',
        'R': '重命名',
        '??': '新增',
    }
    
    def __init__(self, hook_event: str = '', custom_description: str = '', auto_group: bool = False):
        """
        Args:
            hook_event: 'stop' or 'prompt_submit' when triggered by hook, empty for manual
            custom_description: Custom description from user (for manual invocation)
            auto_group: Whether to auto-group by module
        """
        self.hook_event = hook_event
        self.custom_description = custom_description
        self.auto_group = auto_group
        self.project_root = self._find_project_root()
        self.changes = {}  # {module_name: [(file, status), ...]}
        
    def _find_project_root(self) -> Path:
        """Find the git repository root."""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--show-toplevel'],
                capture_output=True,
                text=True,
                check=True
            )
            return Path(result.stdout.strip())
        except:
            return Path.cwd()
    
    def get_changes(self) -> bool:
        """Fetch changes from git status. Returns True if changes exist."""
        try:
            result = subprocess.run(
                ['git', 'status', '--porcelain'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                check=True
            )
            
            if not result.stdout.strip():
                return False
            
            # Parse git status output
            for line in result.stdout.strip().split('\n'):
                if not line or len(line) < 4:
                    continue
                status = line[:2].strip()
                filepath = line[3:].strip()
                
                # Normalize filepath
                filepath = self._normalize_filepath(filepath)
                
                # Handle quoted file names (files with spaces)
                if filepath.startswith('"') and filepath.endswith('"'):
                    try:
                        filepath = shlex.split(filepath)[0]
                    except (ValueError, IndexError):
                        filepath = filepath[1:-1]  # Fallback: just remove quotes
                
                # Skip directories (path ends with /)
                if filepath.endswith('/'):
                    continue
                
                # Skip special paths
                if '__pycache__' in filepath or '.pyc' in filepath:
                    continue
                
                if not filepath:
                    continue
                
                module = self._classify_module(filepath)
                
                if module not in self.changes:
                    self.changes[module] = []
                self.changes[module].append((filepath, status))
            
            return True
        except Exception as e:
            print(f"Error getting changes: {e}", file=sys.stderr)
            return False
    
    def _normalize_filepath(self, filepath: str) -> str:
        """Normalize file path to ensure consistency."""
        # Handle quoted paths (files with spaces like "claude build resources/...")
        if filepath.startswith('"') and filepath.endswith('"'):
            try:
                filepath = shlex.split(filepath)[0]
            except (ValueError, IndexError):
                filepath = filepath[1:-1]
        
        # Ensure .claude paths have the leading dot (PowerShell sometimes strips it)
        if filepath.startswith('claude/') and not filepath.startswith('.claude/'):
            filepath = '.' + filepath
        
        return filepath
    
    def _classify_module(self, filepath: str) -> str:
        """Classify file to module based on path."""
        filepath_lower = filepath.lower()
        
        # Normalize path by removing leading dot/slash
        normalized_path = filepath_lower.lstrip('./')
        
        for module, patterns in self.MODULE_PATTERNS.items():
            for pattern in patterns:
                pattern_lower = pattern.lower().lstrip('./')
                if pattern_lower in normalized_path or pattern_lower in filepath_lower:
                    return module
        
        return 'Other'
    
    def _infer_change_type(self, module: str) -> str:
        """Infer change type (修复/优化/添加) based on module and file names."""
        # If custom description provided, try to extract type from it
        if self.custom_description:
            if '修复' in self.custom_description or 'fix' in self.custom_description.lower():
                return '修复'
            elif '优化' in self.custom_description or 'optim' in self.custom_description.lower():
                return '优化'
            elif '添加' in self.custom_description or 'add' in self.custom_description.lower():
                return '添加'
        
        # Heuristic: check if it's mostly deletions
        if module in self.changes:
            delete_count = sum(1 for _, status in self.changes[module] if status == 'D')
            total = len(self.changes[module])
            if delete_count > total * 0.5:
                return '删除'
        
        # Default: determine by module type
        if module in ['Algorithm', 'Config']:
            return '优化'
        elif module in ['Chassis', 'Gimbal', 'Shooter']:
            return '修改'
        else:
            return '更新'
    
    def generate_message(self, module: str, prefix: str = '') -> str:
        """Generate commit message for a module."""
        change_type = self._infer_change_type(module)
        
        # Build message components
        if prefix:
            prefix_part = f"{prefix}: "
        elif self.hook_event == 'stop':
            prefix_part = "CPED: "
        elif self.hook_event == 'prompt_submit':
            prefix_part = "CPST: "
        else:
            prefix_part = ""
        
        message = f"{prefix_part}{change_type} {module}"
        
        # Add custom description if available
        if self.custom_description:
            message += f" - {self.custom_description[:50]}"  # Limit to 50 chars
        else:
            # Try to infer description from changed files
            if module in self.changes:
                files = [f.split('/')[-1] for f, _ in self.changes[module][:2]]
                message += f" - {', '.join(files)}"
        
        # Ensure max 72 chars (git convention)
        if len(message) > 72:
            message = message[:69] + "..."
        
        return message
    
    def commit_changes(self) -> List[str]:
        """Execute git commits. Returns list of commit messages created."""
        if not self.changes:
            return []
        
        commits = []
        
        # Determine grouping strategy:
        # - Hook triggered with multiple modules → separate commits
        # - Auto-group flag → separate commits
        # - Otherwise → try to use single commit
        should_group = self.auto_group or (self.hook_event and len(self.changes) > 1)
        
        if should_group:
            # Group by module - separate commits per module
            for module in sorted(self.changes.keys()):
                if self._do_commit_module(module, commits):
                    commits.append(module)
        else:
            # Single commit for all changes (or when only one module)
            files = []
            for module_files in self.changes.values():
                files.extend([f for f, _ in module_files])
            
            if files:
                try:
                    # Add each file individually
                    for filepath in files:
                        subprocess.run(
                            ['git', 'add', filepath],
                            cwd=self.project_root,
                            check=True,
                            capture_output=True
                        )
                    
                    # Use first module if only one, otherwise use "Multi"
                    primary_module = list(self.changes.keys())[0] if len(self.changes) == 1 else "Multi"
                    message = self.generate_message(primary_module)
                    
                    subprocess.run(
                        ['git', 'commit', '-m', message],
                        cwd=self.project_root,
                        check=True,
                        capture_output=True
                    )
                    commits.append(message)
                except Exception as e:
                    print(f"Error committing: {e}", file=sys.stderr)
        
        return commits
    
    def _do_commit_module(self, module: str, existing_commits: List) -> bool:
        """Commit changes for a single module. Returns True if successful."""
        files = [f for f, _ in self.changes[module]]
        if not files:
            return False
        
        try:
            # Use git add with each file individually to avoid path parsing issues
            for filepath in files:
                subprocess.run(
                    ['git', 'add', filepath],
                    cwd=self.project_root,
                    check=True,
                    capture_output=True
                )
            
            message = self.generate_message(module)
            
            subprocess.run(
                ['git', 'commit', '-m', message],
                cwd=self.project_root,
                check=True,
                capture_output=True
            )
            return True
        except Exception as e:
            print(f"Error committing {module}: {e}", file=sys.stderr)
            return False
    
    def show_summary(self, commits: List[str]):
        """Print summary of changes and commits."""
        print("\n=== Git Commit Summary ===")
        print(f"Total modules changed: {len(self.changes)}")
        for module in sorted(self.changes.keys()):
            print(f"  - {module}: {len(self.changes[module])} files")
        
        if commits:
            print(f"\nCommits created ({len(commits)}):")
            for i, commit in enumerate(commits, 1):
                print(f"  {i}. {commit}")
        
        # Show last N commits
        try:
            result = subprocess.run(
                ['git', 'log', '--oneline', '-3'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                check=True
            )
            print("\nLatest commits:")
            for line in result.stdout.strip().split('\n'):
                print(f"  {line}")
        except:
            pass


def main():
    """Main entry point. Parse arguments and execute commits."""
    args = sys.argv[1:]
    
    hook_event = os.environ.get('HOOK_EVENT_TYPE', '')  # 'stop' or 'prompt_submit'
    custom_description = ''
    auto_group = False
    
    # Parse arguments
    if args:
        if args[0] == '--auto-group':
            auto_group = True
            if len(args) > 1:
                custom_description = ' '.join(args[1:])
        else:
            custom_description = ' '.join(args)
    
    # Create analyzer and process
    analyzer = CommitAnalyzer(
        hook_event=hook_event,
        custom_description=custom_description,
        auto_group=auto_group
    )
    
    if not analyzer.get_changes():
        if not os.environ.get('HOOK_TRIGGERED'):
            print("No changes to commit.")
        sys.exit(0)
    
    commits = analyzer.commit_changes()
    
    if commits or not hook_event:
        analyzer.show_summary(commits)
    
    sys.exit(0)


if __name__ == '__main__':
    main()
