# OpenHands Local Tooling

A comprehensive set of shell commands and utilities for managing OpenHands instances locally with Docker.

## Features

- **Project-based management**: Launch OpenHands for specific projects with automatic port assignment
- **Multiple instances**: Run OpenHands for different projects simultaneously  
- **Version management**: Easy switching between OpenHands versions
- **Logging**: Automatic log management with retention policies
- **Session management**: Save and restore OpenHands sessions
- **Shell integration**: Tab completion and intuitive command names

## How Project Paths Work

OpenHands Local Tooling is designed around a **projects directory structure** that makes managing multiple projects simple and intuitive.

### Project Directory Structure

By default, all your projects live under `~/projects/`:

```
~/projects/
├── myapp/                    # Simple project
├── client-work/
│   ├── website-redesign/     # Nested project  
│   └── mobile-app/           # Another nested project
└── personal/
    ├── blog/                 # Personal projects
    └── experiments/
        └── ai-chatbot/       # Deeply nested project
```

### Using Project Paths

**From anywhere on your system:**
```bash
oh myapp                           # Launch ~/projects/myapp
oh client-work/website-redesign    # Launch ~/projects/client-work/website-redesign  
oh personal/experiments/ai-chatbot # Launch deeply nested project
oh .                               # Launch at projects root (access all projects)
```

**From within a project directory:**
```bash
cd ~/projects/myapp
oh                                 # Launch current directory project
```

**Access all projects (useful for moving code between projects):**
```bash
oh .                               # Mounts entire ~/projects directory
```

### Path Resolution

- **Relative paths** (like `myapp` or `client-work/website-redesign`) are resolved relative to your projects directory
- **Current directory**: Running `oh` with no arguments uses the current directory
- **Projects root**: Using `oh .` mounts the entire projects directory, useful for cross-project operations
- **Tab completion**: Type `oh ` and press tab to see available projects (including `.`)
- **Automatic detection**: The tooling automatically finds all git repositories in your projects directory

This structure keeps your OpenHands instances organized and makes it easy to jump between different projects without navigating complex file paths.

## Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd openhands_local
```

2. Add to your shell configuration (`~/.zshrc` or `~/.bashrc`):
```bash
# OpenHands Local Tooling
source "/path/to/openhands_local/shell/openhands.sh"
```

3. Reload your shell:
```bash
source ~/.zshrc
```

## Commands

### Core Commands
- `oh [PROJECT_PATH]` - Launch OpenHands for a project
- `oh-list` - List all running OpenHands instances  
- `oh-stop [PROJECT_PATH]` - Stop OpenHands for a specific project
- `oh-stop-all` - Stop all OpenHands instances
- `oh-logs [OPTIONS] [PROJECT_PATH]` - View app container logs
- `oh-runtime-logs [OPTIONS] [PROJECT_PATH]` - View runtime container logs
- `oh-containers [OPTIONS]` - Show all containers with relationships

### Convenience Commands
- `ohcd PROJECT_PATH` - Change directory and launch OpenHands
- `oh-version VERSION [PROJECT_PATH]` - Launch with specific OpenHands version
- `oh-clean` - Clean up stopped containers
- `oh-save [PROJECT_PATH]` - Save session state
- `oh-help` - Show all available commands

### Management Commands
- `oh-refresh-cache` - Refresh project list cache for tab completion

## Understanding OpenHands Containers

OpenHands uses a two-container architecture:

1. **App Container** (`openhands-app-*`)
   - Runs the web UI you interact with
   - Handles orchestration and coordination
   - One per project you launch with `oh`
   - View logs with: `oh-logs`

2. **Runtime Container** (`openhands-runtime-*`)
   - Executes your code in a sandboxed environment
   - Downloads and manages MCP tools
   - One per conversation/session within a project
   - View logs with: `oh-runtime-logs`

To see all containers and their relationships:
```bash
oh-containers              # Show all containers
oh-containers -r          # Show only runtime containers
oh-containers -a          # Include stopped containers
```

## Configuration

Set these environment variables in your shell configuration:

```bash
# Default OpenHands version (default: 0.41)
export OPENHANDS_DEFAULT_VERSION="0.41"

# Projects directory (default: ~/projects)  
export OPENHANDS_PROJECTS_DIR="$HOME/projects"

# Log directory (default: ~/.openhands-logs)
export OPENHANDS_LOG_DIR="$HOME/.openhands-logs"

# Log retention in days (default: 30)
export OPENHANDS_LOG_RETENTION_DAYS="30"
```

## Examples

```bash
# Launch OpenHands for current directory
oh

# Launch for a specific project
oh client-work/website-redesign

# Launch at projects root (access all projects)
oh .

# Use a different version
oh-version 0.39 myapp

# View logs  
oh-logs -f myapp

# Update to latest version
oh-update-version 0.42
```

## Requirements

- Docker Desktop
- macOS or Linux
- Bash or Zsh shell

## License

MIT License - feel free to modify and share!

## Troubleshooting

### Quick Diagnosis

**Check if OpenHands is running:**
```bash
oh-list                    # List app containers
oh-containers              # Show all containers with details
```

**View logs for issues:**
```bash
oh-logs [project-name]           # View app container logs
oh-logs -f [project-name]        # Follow app logs in real-time
oh-runtime-logs [project-name]   # View runtime container logs
oh-runtime-logs -f [project-name] # Follow runtime logs (see MCP downloads)
```

**Debug MCP timeout issues:**
```bash
# Watch both containers during startup
oh-logs -f myproject &           # App logs in background
oh-runtime-logs -f myproject     # Runtime logs in foreground

# Or in separate terminals:
# Terminal 1: oh-logs -f myproject
# Terminal 2: oh-runtime-logs -f myproject
```

**Common Solutions:**

1. **Container startup issues:**
   ```bash
   oh-stop-all    # Stop all instances
   oh-clean       # Clean up old containers
   ```

2. **Port conflicts:**
   - Each project uses a different port automatically
   - Check `oh-list` for current port assignments

3. **Runtime issues:**
   - Ensure Docker Desktop is running
   - Current configuration uses `0.41-nikolaik` runtime with OpenHands `0.41`

### Environment Variables

```bash
OPENHANDS_DEFAULT_VERSION     # OpenHands version (default: 0.41)
OPENHANDS_RUNTIME_VERSION     # Runtime image version (default: 0.41-nikolaik)  
OPENHANDS_PROJECTS_DIR        # Projects directory (default: ~/projects)
OPENHANDS_LOG_DIR            # Log directory (default: ~/.openhands-logs)
```

### Getting Help

- **View all commands:** `oh-help`
- **Command-specific help:** `oh-logs --help`, `oh-stop --help`, etc.
- **GitHub Issues:** [OpenHands Issues](https://github.com/All-Hands-AI/OpenHands/issues)

## Testing Protocol

**Important:** Run this complete testing protocol before committing any changes to ensure all functionality works correctly.

**Note:** Tests use a separate `~/oh-test-projects` directory to avoid interfering with your real projects.

### Pre-Test Setup

```bash
# 1. Ensure Docker Desktop is running
docker info >/dev/null 2>&1 || echo "ERROR: Start Docker Desktop first"

# 2. Save original projects directory and set test directory
export OPENHANDS_ORIGINAL_PROJECTS_DIR="${OPENHANDS_PROJECTS_DIR:-~/projects}"
export OPENHANDS_PROJECTS_DIR=~/oh-test-projects

# 3. Clean up any existing test containers
oh-stop-all
oh-clean

# 4. Create test project structure (if not exists)
mkdir -p ~/oh-test-projects/test-project-1
mkdir -p ~/oh-test-projects/test-category/test-project-2
mkdir -p ~/oh-test-projects/test-deep/nested/test-project-3
cd ~/oh-test-projects/test-project-1 && git init . >/dev/null 2>&1
cd ~/oh-test-projects/test-category/test-project-2 && git init . >/dev/null 2>&1
cd ~/oh-test-projects/test-deep/nested/test-project-3 && git init . >/dev/null 2>&1

# 5. Return to openhands_local directory
cd /path/to/openhands_local
```

### Core Functionality Tests

#### ( ) Test 1: Basic Launch and Stop

```bash
# Launch from project directory
cd ~/oh-test-projects/test-project-1
oh
# Verify: Browser opens, container starts, correct port shown
# Wait for UI to load (10-15 seconds)

# Check it's running
oh-list | grep "test-project-1"
# Verify: Shows test-project-1 with port and status

# Stop it
oh-stop
# Verify: Success message

# Confirm stopped
oh-list | grep "test-project-1"
# Verify: No output (not running)
```

#### ( ) Test 2: Launch by Path

```bash
# Launch nested project
oh test-category/test-project-2
# Verify: Browser opens, correct project name shown

# Launch deeply nested
oh test-deep/nested/test-project-3
# Verify: Browser opens, handles deep paths correctly

# Check both running
oh-list
# Verify: Shows both projects with different ports
```

#### ( ) Test 3: Multiple Instances

```bash
# Launch multiple projects
oh test-project-1
oh test-category/test-project-2
# Verify: Both launch successfully on different ports

# Try launching same project again
oh test-project-1
# Verify: Error message about already running, suggests oh-stop command

# List all
oh-list
# Verify: Shows both running instances
```

#### ( ) Test 4: Projects Root Access

```bash
# Launch at projects root
oh .
# Verify: Launches with "All Projects" display name

# Check containers
oh-containers
# Verify: Shows app container for projects-root

# Stop it
oh-stop .
# Verify: Stops successfully
```

#### ( ) Test 5: Logging Functions

```bash
# Start a project
oh test-project-1

# View app logs
oh-logs test-project-1 | head -20
# Verify: Shows app container logs

# Follow logs (test for 5 seconds)
timeout 5 oh-logs -f test-project-1
# Verify: Shows real-time logs, exits after timeout

# Try runtime logs (before conversation)
oh-runtime-logs test-project-1
# Verify: Shows error about no runtime container

# View last N lines
oh-logs -n 10 test-project-1
# Verify: Shows exactly 10 lines

# View logs since time
oh-logs --since 1m test-project-1
# Verify: Shows recent logs only
```

#### ( ) Test 6: Container Management

```bash
# Show all containers
oh-containers
# Verify: Shows app containers with project names

# Show with runtime filter
oh-containers -r
# Verify: Shows only runtime containers section

# Clean command (with nothing to clean)
oh-clean
# Verify: "No cleanup needed" message
```

#### ( ) Test 7: Version Management

```bash
# Launch with specific version
oh-version 0.40 test-project-1
# Verify: Shows version 0.40 in output

# Check that it used the specified version
oh-list
# Verify: Container running with requested version

# Stop the test container
oh-stop test-project-1
```

#### ( ) Test 8: Error Handling

```bash
# Stop non-existent project
oh-stop nonexistent-project
# Verify: Shows "No running instance found"

# Launch non-existent project
oh fake-project-path
# Verify: Error message, lists available projects

# Logs for stopped project
oh-logs stopped-project
# Verify: Error message about no running instance

# Invalid oh-version
oh-version invalid-version test-project-1
# Verify: Docker pull error (but handled gracefully)
```

#### ( ) Test 9: Quick Commands

```bash
# Test ohcd
ohcd test-project-1
# Verify: Changes directory AND launches OpenHands

# Stop it first
oh-stop

# Test oh-save
oh test-project-1
sleep 5  # Let it start
oh-save test-project-1
# Verify: Creates backup in ~/.openhands-backups/

# Help command
oh-help
# Verify: Shows all commands with formatting
```

#### ( ) Test 10: Tab Completion

```bash
# Test completion cache
oh-refresh-cache
# Verify: Success message

# Manual completion test (zsh)
oh test-pr<TAB>
# Verify: Completes to test-project-1

# Test with nested paths
oh test-cat<TAB>
# Verify: Shows test-category/
```

### Edge Cases

#### ( ) Test 11: Special Characters

```bash
# Create project with spaces (if supported)
mkdir -p ~/oh-test-projects/"test project spaces"
cd ~/oh-test-projects/"test project spaces" && git init .
oh "test project spaces"
# Verify: Handles spaces correctly or shows appropriate error
```

#### ( ) Test 12: Current Directory Outside Projects

```bash
# Launch from outside projects directory
cd /tmp
mkdir test-external && cd test-external
oh
# Verify: Works, shows "(external)" in display name

oh-stop
cd ..
rm -rf test-external
```

#### ( ) Test 13: Concurrent Operations

```bash
# Launch multiple quickly
oh test-project-1 & oh test-category/test-project-2 & oh test-deep/nested/test-project-3
# Verify: All launch without conflicts, different ports

# Stop all
oh-stop-all
# Verify: Stops all instances, shows count
```

### Post-Test Cleanup

```bash
# 1. Stop all instances
oh-stop-all

# 2. Clean up containers
oh-clean

# 3. Verify clean state
oh-list
# Verify: No instances running

oh-containers -a | grep "openhands-"
# Verify: No OpenHands containers remain

# 4. Remove test projects (optional)
rm -rf ~/oh-test-projects/test-project-1
rm -rf ~/oh-test-projects/test-category
rm -rf ~/oh-test-projects/test-deep
rm -rf ~/oh-test-projects/"test project spaces" 2>/dev/null

# 5. Restore original OPENHANDS_PROJECTS_DIR
export OPENHANDS_PROJECTS_DIR="$OPENHANDS_ORIGINAL_PROJECTS_DIR"
```

### Test Checklist Summary

Before committing, ensure all tests pass:

- ( ) Docker Desktop is running
- ( ) Basic launch and stop works
- ( ) Multiple instances run on different ports  
- ( ) Projects root access works
- ( ) Logging commands show appropriate output
- ( ) Container management commands work
- ( ) Version switching works
- ( ) Error messages are helpful
- ( ) Tab completion functions
- ( ) Edge cases handled gracefully
- ( ) All containers cleaned up after tests

**Time estimate:** 15-20 minutes for full protocol

**Quick smoke test** (for minor changes):
```bash
# Just test core functionality
oh test-project-1
oh-list
oh-logs test-project-1 | head -5
oh-stop test-project-1
oh-clean
```

--- 