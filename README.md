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
- `oh-update-version [VERSION]` - Update default OpenHands version
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

--- 