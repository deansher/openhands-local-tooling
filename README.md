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
```

**From within a project directory:**
```bash
cd ~/projects/myapp
oh                                 # Launch current directory project
```

### Path Resolution

- **Relative paths** (like `myapp` or `client-work/website-redesign`) are resolved relative to your projects directory
- **Current directory**: Running `oh` with no arguments uses the current directory
- **Tab completion**: Type `oh ` and press tab to see available projects
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
- `oh-logs [OPTIONS] [PROJECT_PATH]` - View logs for an instance

### Convenience Commands
- `ohcd PROJECT_PATH` - Change directory and launch OpenHands
- `oh-version VERSION [PROJECT_PATH]` - Launch with specific OpenHands version
- `oh-clean` - Clean up stopped containers
- `oh-save [PROJECT_PATH]` - Save session state
- `oh-help` - Show all available commands

### Management Commands
- `oh-update-version [VERSION]` - Update default OpenHands version
- `oh-refresh-cache` - Refresh project list cache for tab completion

## Configuration

Set these environment variables in your shell configuration:

```bash
# Default OpenHands version (default: 0.40)
export OPENHANDS_DEFAULT_VERSION="0.40"

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

# Use a different version
oh-version 0.39 myapp

# View logs  
oh-logs -f myapp

# Update to latest version
oh-update-version 0.41
```

## Requirements

- Docker Desktop
- macOS or Linux
- Bash or Zsh shell

## License

MIT License - feel free to modify and share!

## Known Issues

### MCP Timeout Issues with OpenHands 0.40

**Status:** Partially resolved - runtime fixed, MCP timeouts persist

**Issue:** OpenHands 0.40 experiences timeout errors during agent session initialization when setting up MCP (Model Context Protocol) tools.

**Root Cause:** Network timeout when OpenHands tries to communicate with runtime containers to configure MCP tools.

**Current Solution:**
- ✅ **Fixed**: Use correct `0.40-nikolaik` runtime image (was using non-existent `0.32-nikolaik`)
- ✅ **Working**: OpenHands starts successfully and runtime containers initialize
- ⚠️ **Partial**: MCP timeout errors still occur but don't prevent basic functionality

**Workaround:** OpenHands still functions for basic tasks despite MCP timeout warnings in logs.

**Monitoring:** 
- Runtime containers start successfully: ✅
- Agent sessions eventually initialize: ⚠️ (with warnings)
- Basic OpenHands functionality available: ✅

**Related Issues:**
- [GitHub Issue #8862](https://github.com/All-Hands-AI/OpenHands/issues/8862) - Runtime image problems
- [GitHub Issue #8705](https://github.com/All-Hands-AI/OpenHands/issues/8705) - MCP timeout errors

For the latest status, check the OpenHands GitHub issues and releases.

## Troubleshooting

### Quick Diagnosis

**Check if OpenHands is running:**
```bash
oh-list
```

**View logs for issues:**
```bash
oh-logs [project-name]           # View recent logs
oh-logs -f [project-name]        # Follow logs in real-time
oh-logs -n 50 [project-name]     # Show last 50 lines
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
   - Current configuration uses `0.40-nikolaik` runtime with OpenHands `0.40`

4. **MCP timeout warnings:**
   - These are currently expected and don't prevent basic functionality
   - OpenHands will still work for code editing and basic tasks

### Environment Variables

```bash
OPENHANDS_DEFAULT_VERSION     # OpenHands version (default: 0.40)
OPENHANDS_RUNTIME_VERSION     # Runtime image version (default: 0.40-nikolaik)  
OPENHANDS_PROJECTS_DIR        # Projects directory (default: ~/projects)
OPENHANDS_LOG_DIR            # Log directory (default: ~/.openhands-logs)
```

### Getting Help

- **View all commands:** `oh-help`
- **Command-specific help:** `oh-logs --help`, `oh-stop --help`, etc.
- **GitHub Issues:** [OpenHands Issues](https://github.com/All-Hands-AI/OpenHands/issues)

--- 