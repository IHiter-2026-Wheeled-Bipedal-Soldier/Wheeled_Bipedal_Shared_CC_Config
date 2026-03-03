#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Git Commit-Push-PR Workflow
One-command workflow: commit → push → create pull request
Integrates with auto-commit.py for intelligent commit message generation.
"""

import subprocess
import sys
import os
import json
import re
import io
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from urllib.parse import urlparse

# Fix encoding on Windows
if sys.platform == 'win32':
    # Set UTF-8 encoding for stdout/stderr
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

class CommitPushPRWorkflow:
    """Manages the complete commit → push → PR create workflow."""
    
    def __init__(self, 
                 custom_description: str = '',
                 target_branch: str = '',
                 draft: bool = False,
                 title: str = '',
                 body: str = '',
                 auto_group: bool = False):
        """
        Args:
            custom_description: Custom commit message
            target_branch: Target branch for PR (auto-detect if empty)
            draft: Create PR as draft
            title: Custom PR title
            body: Custom PR body
            auto_group: Force grouping by module
        """
        self.custom_description = custom_description
        self.target_branch = target_branch
        self.draft = draft
        self.pr_title = title
        self.pr_body = body
        self.auto_group = auto_group
        self.project_root = self._find_project_root()
        self.current_branch = self._get_current_branch()
        self.commits_created = []
        self.pr_url = None
        self.remote_url = None
        
    def _find_project_root(self) -> Path:
        """Find the git repository root."""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--show-toplevel'],
                capture_output=True,
                text=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
            return Path(result.stdout.strip())
        except:
            return Path.cwd()
    
    def _get_current_branch(self) -> str:
        """Get the current git branch name."""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
            return result.stdout.strip()
        except:
            return 'HEAD'
    
    def _get_remote_url(self) -> str:
        """Get the remote repository URL."""
        try:
            result = subprocess.run(
                ['git', 'config', '--get', 'remote.origin.url'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
            return result.stdout.strip()
        except:
            return ''
    
    def _is_protected_branch(self, branch: str) -> bool:
        """Check if the branch is a protected branch."""
        protected = ['main', 'master', 'develop', 'release', 'production', 'stable']
        return any(branch.lower() == p or branch.lower().startswith(p + '/') for p in protected)
    
    def validate_environment(self) -> Tuple[bool, str]:
        """Validate prerequisites. Returns (success, message)."""
        # Check if in git repo
        try:
            subprocess.run(
                ['git', 'status'],
                cwd=self.project_root,
                capture_output=True,
                check=True
            )
        except:
            return False, "[FAIL] Not in a git repository"
        
        # Check for uncommitted changes
        try:
            result = subprocess.run(
                ['git', 'status', '--porcelain'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
            if not result.stdout.strip():
                return False, "[FAIL] No changes to commit"
        except:
            return False, "[FAIL] Failed to check git status"
        
        # Check if current branch is protected
        if self._is_protected_branch(self.current_branch):
            return False, f"[FAIL] Cannot push to protected branch '{self.current_branch}'. Please switch to a feature/working branch."
        
        # Check remote configuration
        if not self._get_remote_url():
            return False, "[FAIL] No remote repository configured (origin)"
        
        # Check if GitHub CLI is available (if needed for PR creation)
        try:
            subprocess.run(
                ['gh', '--version'],
                capture_output=True,
                check=False
            )
        except FileNotFoundError:
            print("[WARN] GitHub CLI (gh) not found. PR will still be created but with web URL only.")
        
        return True, "[OK] Environment validated"
    
    def step_1_commit(self) -> bool:
        """Step 1: Execute commit using auto-commit.py logic."""
        print("\n[*] Step 1: Committing changes...")
        
        try:
            # Build arguments for auto-commit.py
            script_path = self.project_root / '.claude' / 'hooks' / 'auto-commit.py'
            
            if not script_path.exists():
                # Fallback: manual commit
                print("  ⚠️  auto-commit.py not found, using manual commit")
                return self._manual_commit()
            
            args = []
            if self.auto_group:
                args.append('--auto-group')
            if self.custom_description:
                args.append(self.custom_description)
            
            # Set environment variable for hook context
            env = os.environ.copy()
            env.pop('HOOK_TRIGGERED', None)
            env.pop('HOOK_EVENT_TYPE', None)
            
            result = subprocess.run(
                ['python3', str(script_path)] + args,
                cwd=self.project_root,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                env=env
            )
            
            if result.returncode != 0:
                print(f"  [!] Commit failed: {result.stderr}")
                return False
            
            # Extract commit messages from output
            for line in result.stdout.split('\n'):
                if line.startswith(('  ', 'CPST:', 'CPED:')):
                    self.commits_created.append(line.strip())
            
            print(result.stdout)
            print("  [+] Commit successful")
            return True
            
        except Exception as e:
            print(f"  [!] Commit error: {e}")
            return False
    
    def _manual_commit(self) -> bool:
        """Fallback manual commit if auto-commit.py is not available."""
        try:
            # Stage all changes
            subprocess.run(
                ['git', 'add', '.'],
                cwd=self.project_root,
                check=True,
                capture_output=True
            )
            
            # Generate default message
            message = self.custom_description or "Update code changes"
            if not message.startswith(('修改', '优化', '添加', '删除')):
                message = f"修改 - {message}"
            
            # Ensure max 72 chars
            if len(message) > 72:
                message = message[:69] + "..."
            
            subprocess.run(
                ['git', 'commit', '-m', message],
                cwd=self.project_root,
                check=True,
                capture_output=True
            )
            
            self.commits_created.append(message)
            return True
        except Exception as e:
            print(f"  [!] Manual commit failed: {e}")
            return False
    
    def step_2_push(self) -> bool:
        """Step 2: Push changes to remote."""
        print("\n[*] Step 2: Pushing to remote...")
        
        try:
            # Push to remote (create upstream if not exists)
            result = subprocess.run(
                ['git', 'push', '-u', 'origin', self.current_branch],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            
            if result.returncode != 0:
                # Might be a non-FF push, try with --force-with-lease
                if 'rejected' in result.stderr.lower() or 'failed' in result.stderr.lower():
                    print("  [i] Attempting push with merge strategy...")
                    result = subprocess.run(
                        ['git', 'push', 'origin', self.current_branch],
                        cwd=self.project_root,
                        capture_output=True,
                        text=True,
                        encoding='utf-8',
                        errors='replace'
                    )
                
                if result.returncode != 0:
                    print(f"  [!] Push failed:")
                    print(f"     {result.stderr}")
                    return False
            
            # Extract push result
            if 'Branch' in result.stdout and 'set up to track' in result.stdout:
                print(f"  [+] Push successful (new branch created)")
            elif result.returncode == 0:
                print(f"  [+] Push successful")
            
            print(f"     Target: origin/{self.current_branch}")
            return True
            
        except Exception as e:
            print(f"  [!] Push error: {e}")
            return False
    
    def step_3_detect_target_branch(self) -> str:
        """Step 3: Detect target branch for PR."""
        print("\n[*] Step 3: Detecting target branch...")
        
        if self.target_branch:
            print(f"  [+] Using specified target: {self.target_branch}")
            return self.target_branch
        
        # Priority order:
        # 1. develop
        # 2. main or master
        # 3. Git default branch
        
        try:
            # List remote branches
            result = subprocess.run(
                ['git', 'branch', '-r'],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                check=True,
                encoding='utf-8',
                errors='replace'
            )
            remote_branches = [b.strip().replace('origin/', '') 
                             for b in result.stdout.split('\n') 
                             if 'origin/' in b and 'HEAD' not in b]
            
            # Check for develop
            if 'develop' in remote_branches:
                print(f"  [+] Target: develop (found in remote branches)")
                return 'develop'
            
            # Check for main or master
            if 'main' in remote_branches:
                print(f"  [+] Target: main")
                return 'main'
            elif 'master' in remote_branches:
                print(f"  [+] Target: master")
                return 'master'
            
            # Default to first remote branch (usually main/master)
            if remote_branches:
                target = remote_branches[0]
                print(f"  [+] Target: {target} (default remote branch)")
                return target
            
        except:
            pass
        
        # Fallback to main
        print(f"  [WARN] Could not auto-detect, using default: main")
        return 'main'
    
    def step_4_create_pr(self, target_branch: str) -> bool:
        """Step 4: Create pull request."""
        print("\n[*] Step 4: Creating pull request...")
        
        self.remote_url = self._get_remote_url()
        
        try:
            # Try using GitHub CLI
            return self._create_pr_with_gh(target_branch)
        except FileNotFoundError:
            # Fallback: generate web URL
            return self._create_pr_web_url(target_branch)
    
    def _create_pr_with_gh(self, target_branch: str) -> bool:
        """Create PR using GitHub CLI (gh)."""
        try:
            # Build gh pr create command
            cmd = ['gh', 'pr', 'create', f'--base={target_branch}']
            
            if self.pr_title:
                cmd.append(f'--title={self.pr_title}')
            else:
                # Use first commit message as title
                title = self._extract_pr_title()
                cmd.append(f'--title={title}')
            
            if self.pr_body:
                cmd.append(f'--body={self.pr_body}')
            else:
                # Generate default body from commits
                body = self._generate_pr_body()
                if body:
                    cmd.append(f'--body={body}')
            
            if self.draft:
                cmd.append('--draft')
            
            result = subprocess.run(
                cmd,
                cwd=self.project_root,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            
            if result.returncode != 0:
                # gh might not be authenticated
                if 'authentication' in result.stderr.lower() or 'not authenticated' in result.stderr.lower():
                    print("  [WARN] GitHub CLI not authenticated, falling back to web URL")
                    return self._create_pr_web_url(target_branch)
                else:
                    print(f"  [!] gh command failed: {result.stderr}")
                    return False
            
            # Extract PR URL from output
            for line in result.stdout.split('\n'):
                if 'github.com' in line and '/pull/' in line:
                    self.pr_url = line.strip()
                    break
            
            if not self.pr_url:
                # Parse from gh output
                match = re.search(r'https://github\.com/[^/]+/[^/]+/pull/\d+', result.stdout)
                if match:
                    self.pr_url = match.group()
            
            if self.pr_url:
                draft_text = " (Draft)" if self.draft else ""
                print(f"  [+] PR created{draft_text}: {self.pr_url}")
                return True
            else:
                print("  [WARN] PR may have been created but URL not found")
                print(result.stdout)
                return True
                
        except FileNotFoundError:
            raise
        except Exception as e:
            print(f"  [!] PR creation error: {e}")
            return False
    
    def _create_pr_web_url(self, target_branch: str) -> bool:
        """Create PR web URL as fallback (no actual PR created)."""
        if not self.remote_url:
            print("  [!] Cannot create PR: no remote URL found")
            return False
        
        # Convert SSH to HTTPS if needed
        web_url = self._convert_to_https_url(self.remote_url)
        if not web_url:
            print("  [!] Cannot create PR: invalid remote URL")
            return False
        
        # Create compare URL
        pr_draft_param = '&draft=1' if self.draft else ''
        compare_url = f"{web_url}/compare/{target_branch}...{self.current_branch}?expand=1{pr_draft_param}"
        
        self.pr_url = compare_url
        
        draft_text = " (Draft)" if self.draft else ""
        print(f"  [WARN] PR not created automatically (gh not available)")
        print(f"  [i] Create PR manually: {compare_url}")
        print(f"\n  Or just visit: {web_url}/pulls")
        
        return True
    
    def _convert_to_https_url(self, url: str) -> Optional[str]:
        """Convert SSH git URL to HTTPS."""
        # SSH format: git@github.com:user/repo.git
        if url.startswith('git@'):
            # Extract domain and path
            match = re.match(r'git@([^:]+):(.+?)(?:\.git)?$', url)
            if match:
                domain, path = match.groups()
                return f"https://{domain}/{path}"
        
        # Already HTTPS
        if url.startswith('http'):
            return url.rstrip('/').replace('.git', '')
        
        return None
    
    def _extract_pr_title(self) -> str:
        """Extract PR title from commit messages."""
        if self.commits_created:
            # Get first commit message and clean it
            first_commit = self.commits_created[0]
            # Remove prefixes like "修改", "CPST:", etc.
            cleaned = re.sub(r'^(CPST:|CPED:|修改|优化|添加|删除)\s*', '', first_commit)
            cleaned = re.sub(r'^[A-Z]+\s*-\s*', '', cleaned)
            return cleaned[:60]  # Limit to 60 chars
        
        return f"PR from {self.current_branch}"
    
    def _generate_pr_body(self) -> str:
        """Generate PR body from commit messages."""
        if not self.commits_created:
            return ""
        
        body = "## Changes\n\n"
        for commit in self.commits_created[:5]:  # Limit to 5 commits
            # Clean up commit message
            clean_msg = re.sub(r'^(CPST:|CPED:)\s*', '', commit)
            body += f"- {clean_msg}\n"
        
        if len(self.commits_created) > 5:
            body += f"\n... and {len(self.commits_created) - 5} more commits\n"
        
        return body
    
    def show_summary(self):
        """Display final summary."""
        print("\n" + "="*60)
        print("[OK] All Tasks Completed Successfully")
        print("="*60)
        
        if self.commits_created:
            print("\n[Commits]:")
            for commit in self.commits_created[:3]:  # Show first 3
                print(f"  + {commit}")
            if len(self.commits_created) > 3:
                print(f"  ... and {len(self.commits_created) - 3} more")
        
        print(f"\n[Push]:")
        print(f"  + Target: origin/{self.current_branch}")
        print(f"  + Status: OK")
        
        if self.pr_url:
            print(f"\n[PR]:")
            print(f"  + URL: {self.pr_url}")
            print(f"  + Base: {self._get_target_branch()} <- {self.current_branch}")
            draft_status = " (Draft: YES)" if self.draft else " (Draft: NO)"
            print(f"  + Status: OPEN{draft_status}")
        
        print("\n" + "="*60)
    
    def _get_target_branch(self) -> str:
        """Get the last detected target branch."""
        if self.target_branch:
            return self.target_branch
        return "main"  # Default fallback
    
    def run(self) -> bool:
        """Execute the complete workflow."""
        print("[>>] Commit-Push-PR Workflow Started\n")
        
        # Validate environment
        valid, msg = self.validate_environment()
        print(msg)
        if not valid:
            return False
        
        # Step 1: Commit
        if not self.step_1_commit():
            return False
        
        # Step 2: Push
        if not self.step_2_push():
            return False
        
        # Step 3: Detect target branch
        target_branch = self.step_3_detect_target_branch()
        
        # Step 4: Create PR
        if not self.step_4_create_pr(target_branch):
            print("\n[WARN] PR creation failed, but commits and push succeeded")
        
        # Show summary
        self.show_summary()
        
        return True


def parse_arguments():
    """Parse command-line arguments."""
    args = sys.argv[1:]
    
    custom_description = ''
    target_branch = ''
    draft = False
    title = ''
    body = ''
    auto_group = False
    
    i = 0
    while i < len(args):
        arg = args[i]
        
        if arg == '--target':
            if i + 1 < len(args):
                target_branch = args[i + 1]
                i += 2
            else:
                i += 1
        elif arg == '--title':
            if i + 1 < len(args):
                title = args[i + 1]
                i += 2
            else:
                i += 1
        elif arg == '--body':
            if i + 1 < len(args):
                body = args[i + 1]
                i += 2
            else:
                i += 1
        elif arg == '--draft':
            draft = True
            i += 1
        elif arg == '--auto-group':
            auto_group = True
            i += 1
        else:
            # Everything else is custom description
            custom_description = ' '.join(args[i:])
            break
    
    return {
        'custom_description': custom_description,
        'target_branch': target_branch,
        'draft': draft,
        'title': title,
        'body': body,
        'auto_group': auto_group
    }


def main():
    """Main entry point."""
    try:
        args = parse_arguments()
        
        workflow = CommitPushPRWorkflow(
            custom_description=args['custom_description'],
            target_branch=args['target_branch'],
            draft=args['draft'],
            title=args['title'],
            body=args['body'],
            auto_group=args['auto_group']
        )
        
        success = workflow.run()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\n[!] Execution cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[!] Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
