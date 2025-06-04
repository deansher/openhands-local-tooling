#!/bin/bash
# OpenHands Local Tooling
# Shell integration functions for managing OpenHands instances
#
# Source this file from your ~/.zshrc or ~/.bashrc:
#   source "/path/to/openhands_local/shell/openhands.sh"

# Get the directory where this script is located
OH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OH_REPO_DIR="$(dirname "$OH_SCRIPT_DIR")"

# Configuration
export OPENHANDS_DEFAULT_VERSION="${OPENHANDS_DEFAULT_VERSION:-0.40}"
export OPENHANDS_PROJECTS_DIR="${OPENHANDS_PROJECTS_DIR:-$HOME/projects}"
export OPENHANDS_LOG_DIR="${OPENHANDS_LOG_DIR:-$HOME/.openhands-logs}"
export OPENHANDS_LOG_RETENTION_DAYS="${OPENHANDS_LOG_RETENTION_DAYS:-30}"

# Add bin directory to PATH
export PATH="$OH_REPO_DIR/bin:$PATH"

# Color codes for pretty output
OH_RESET="\033[0m"
OH_BOLD="\033[1m"
OH_GREEN="\033[32m"
OH_YELLOW="\033[33m"
OH_BLUE="\033[34m"
OH_RED="\033[31m"

# Cache for project names
_OH_PROJECTS_CACHE=()
_OH_PROJECTS_CACHE_TIME=0

# Helper function to create a safe container name from a project path
_oh_safe_container_name() {
    local project_path="$1"
    # Replace slashes with double underscores
    echo "$project_path" | sed 's|/|__|g'
}

# Helper function to ensure log directory exists
_oh_ensure_log_dir() {
    mkdir -p "$OPENHANDS_LOG_DIR"
}

# Helper function to get log file path for a project
_oh_get_log_file() {
    local project_path="$1"
    local safe_name=$(_oh_safe_container_name "$project_path")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    echo "$OPENHANDS_LOG_DIR/${safe_name}_${timestamp}.log"
}

# Helper function to clean old logs
_oh_clean_old_logs() {
    if [[ -d "$OPENHANDS_LOG_DIR" ]]; then
        find "$OPENHANDS_LOG_DIR" -name "*.log" -type f -mtime +${OPENHANDS_LOG_RETENTION_DAYS} -delete 2>/dev/null
    fi
}

# Helper function to get the relative project path from the projects directory
_oh_get_project_path() {
    local input_path="$1"
    local abs_projects_dir=$(cd "$OPENHANDS_PROJECTS_DIR" 2>/dev/null && pwd || echo "$OPENHANDS_PROJECTS_DIR")
    local abs_input_path=$(cd "$input_path" 2>/dev/null && pwd || echo "$input_path")
    
    # If it's already a relative path within projects dir, return it
    if [[ "$abs_input_path" == "$abs_projects_dir"/* ]]; then
        echo "${abs_input_path#$abs_projects_dir/}"
    else
        echo ""
    fi
}

# Main OpenHands launcher
oh() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh - Launch OpenHands for a project${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh                    Launch for current directory"
        echo "  oh PROJECT_PATH       Launch for ~/projects/PROJECT_PATH"
        echo "  oh --help            Show this help"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  cd ~/projects/myapp && oh"
        echo "  oh SallyR"
        echo "  oh chat/AdmiredLeadership/cra-backend"
        return 0
    fi

    local project_path=""
    local project_display_name=""
    local absolute_project_path=""
    
    if [[ $# -eq 0 ]]; then
        # No argument: use current directory
        absolute_project_path="$PWD"
        # Try to get relative path from projects directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
            project_display_name="$rel_path"
        else
            project_path=$(basename "$PWD")
            project_display_name="$(basename "$PWD") (external)"
        fi
    else
        # Argument provided: assume it's a project path relative to ~/projects
        project_path="$1"
        project_display_name="$1"
        absolute_project_path="$OPENHANDS_PROJECTS_DIR/$1"
        
        if [[ ! -d "$absolute_project_path" ]]; then
            echo "${OH_RED}✗ Project directory $absolute_project_path not found!${OH_RESET}"
            echo "Available projects in $OPENHANDS_PROJECTS_DIR:"
            # Find all git repositories and show their paths relative to projects dir
            find "$OPENHANDS_PROJECTS_DIR" -name ".git" -type d 2>/dev/null | \
                grep -v '/.history/' | \
                sed 's|/\.git$||' | \
                sed "s|^$OPENHANDS_PROJECTS_DIR/||" | \
                grep -v "^$" | \
                sort | \
                head -50 | \
                sed 's/^/  /'
            local total_count=$(find "$OPENHANDS_PROJECTS_DIR" -name ".git" -type d 2>/dev/null | grep -v '/.history/' | wc -l)
            if [[ $total_count -gt 50 ]]; then
                echo "  ... and $((total_count - 50)) more git repositories"
            fi
            return 1
        fi
    fi
    
    # Create safe container name
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "${OH_RED}✗ Docker is not running! Please start Docker Desktop.${OH_RESET}"
        return 1
    fi
    
    # Check if already running
    if docker ps -q --filter "name=openhands-app-$safe_container_name" | grep -q .; then
        local existing_port=$(docker port "openhands-app-$safe_container_name" 3000 | cut -d: -f2)
        echo "${OH_YELLOW}⚠️  OpenHands is already running for $project_display_name on port $existing_port${OH_RESET}"
        echo "Stop it first with: oh-stop $project_path"
        return 1
    fi
    
    # Stop any existing containers for this project
    echo "${OH_BLUE}🧹 Cleaning up any existing containers for $project_display_name...${OH_RESET}"
    docker stop $(docker ps -q --filter "name=openhands-.*-$safe_container_name") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=openhands-.*-$safe_container_name") 2>/dev/null || true
    
    # Use a different port for each project
    local port=$((3000 + $(echo "$safe_container_name" | cksum | cut -d' ' -f1) % 1000))
    
    # Ensure log directory exists and clean old logs
    _oh_ensure_log_dir
    _oh_clean_old_logs
    
    # Get log file path
    local log_file=$(_oh_get_log_file "$project_path")
    
    echo "${OH_BLUE}🚀 Starting OpenHands for $project_display_name...${OH_RESET}"
    echo "📁 Project: $absolute_project_path"
    echo "🔌 Port: $port"
    echo "🏷️  Version: $OPENHANDS_DEFAULT_VERSION"
    echo "📝 Log file: $log_file"
    
    if docker run -d --rm \
        -e SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:${OPENHANDS_DEFAULT_VERSION}-nikolaik \
        -e SANDBOX_USER_ID=$(id -u) \
        -e SANDBOX_VOLUMES="$absolute_project_path:/workspace:rw" \
        -e LOG_ALL_EVENTS=true \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v ~/.openhands-state-$safe_container_name:/.openhands-state \
        -p $port:3000 \
        --add-host host.docker.internal:host-gateway \
        --name "openhands-app-$safe_container_name" \
        docker.all-hands.dev/all-hands-ai/openhands:${OPENHANDS_DEFAULT_VERSION} >/dev/null; then
        
        echo "${OH_GREEN}✅ OpenHands started successfully!${OH_RESET}"
        echo ""
        echo "🌐 URL: ${OH_BOLD}http://localhost:$port${OH_RESET}"
        echo "📝 Project: ${OH_BOLD}$project_display_name${OH_RESET}"
        echo ""
        echo "💡 Tips:"
        echo "  - Start a NEW conversation in the UI for fresh workspace mounts"
        echo "  - View logs with: oh-logs $project_path"
        echo "  - Follow logs with: oh-logs -f $project_path"
        
        # Wait a moment and open browser
        sleep 2
        open "http://localhost:$port"
    else
        echo "${OH_RED}✗ Failed to start OpenHands${OH_RESET}"
        return 1
    fi
}

# List running OpenHands instances
oh-list() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-list - List all running OpenHands instances${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} oh-list"
        return 0
    fi
    
    echo "${OH_BOLD}🔍 Running OpenHands instances:${OH_RESET}"
    echo ""
    
    local instances=$(docker ps --filter "name=openhands-app-" --format "{{.Names}}|{{.Ports}}|{{.Status}}" 2>/dev/null)
    
    if [[ -z "$instances" ]]; then
        echo "  No instances running"
    else
        echo "  ${OH_BOLD}PROJECT${OH_RESET}                                    ${OH_BOLD}PORT${OH_RESET}    ${OH_BOLD}STATUS${OH_RESET}"
        echo "  ─────────────────────────────────────────────────────────────────"
        echo "$instances" | while IFS='|' read -r name ports container_status; do
            local safe_name=${name#openhands-app-}
            # Convert safe name back to project path
            local project_name=$(echo "$safe_name" | sed 's|__|/|g')
            local port=$(echo $ports | grep -o '0.0.0.0:[0-9]*->3000' | cut -d: -f2 | cut -d- -f1)
            printf "  %-40s %s    %s\n" "$project_name" "$port" "$container_status"
        done
    fi
    echo ""
}

# Stop OpenHands for a specific project
oh-stop() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-stop - Stop OpenHands for a specific project${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-stop PROJECT_PATH    Stop specific project"
        echo "  oh-stop                 Stop project in current directory"
        echo "  oh-stop --help         Show this help"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-stop SallyR"
        echo "  oh-stop chat/AdmiredLeadership/cra-backend"
        return 0
    fi
    
    local project_path=""
    local project_display_name=""
    
    if [[ $# -eq 0 ]]; then
        # No argument: use current directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
            project_display_name="$rel_path"
        else
            project_path=$(basename "$PWD")
            project_display_name="$(basename "$PWD")"
        fi
    else
        project_path="$1"
        project_display_name="$1"
    fi
    
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    
    echo "${OH_BLUE}🛑 Stopping OpenHands for $project_display_name...${OH_RESET}"
    
    local stopped_app=$(docker stop $(docker ps -q --filter "name=openhands-app-$safe_container_name") 2>/dev/null)
    local stopped_runtime=$(docker stop $(docker ps -q --filter "name=openhands-runtime-.*$safe_container_name") 2>/dev/null)
    
    if [[ -n "$stopped_app" ]] || [[ -n "$stopped_runtime" ]]; then
        docker rm $(docker ps -aq --filter "name=openhands-.*-$safe_container_name") 2>/dev/null || true
        echo "${OH_GREEN}✅ Stopped OpenHands for $project_display_name${OH_RESET}"
    else
        echo "${OH_YELLOW}⚠️  No running instance found for $project_display_name${OH_RESET}"
    fi
}

# Stop all OpenHands instances
oh-stop-all() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-stop-all - Stop all OpenHands instances${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} oh-stop-all"
        return 0
    fi
    
    echo "${OH_BLUE}🛑 Stopping all OpenHands instances...${OH_RESET}"
    
    local count=$(docker ps -q --filter "name=openhands-" | wc -l | tr -d ' ')
    
    if [[ "$count" -eq 0 ]]; then
        echo "${OH_YELLOW}⚠️  No running instances found${OH_RESET}"
        return 0
    fi
    
    docker stop $(docker ps -q --filter "name=openhands-") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=openhands-") 2>/dev/null || true
    
    echo "${OH_GREEN}✅ Stopped $count instance(s)${OH_RESET}"
}

# Clean up old runtime containers
oh-clean() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-clean - Clean up stopped OpenHands containers${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} oh-clean"
        echo ""
        echo "Removes all stopped OpenHands runtime containers"
        return 0
    fi
    
    echo "${OH_BLUE}🧹 Cleaning up old OpenHands containers...${OH_RESET}"
    
    local count=$(docker ps -aq --filter "name=openhands-runtime-" --filter "status=exited" | wc -l | tr -d ' ')
    
    if [[ "$count" -eq 0 ]]; then
        echo "${OH_GREEN}✅ No cleanup needed${OH_RESET}"
        return 0
    fi
    
    docker rm $(docker ps -aq --filter "name=openhands-runtime-" --filter "status=exited") 2>/dev/null || true
    echo "${OH_GREEN}✅ Removed $count container(s)${OH_RESET}"
}

# Quick cd and launch
ohcd() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
        echo "${OH_BOLD}ohcd - Change to project directory and launch OpenHands${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} ohcd PROJECT_PATH"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  ohcd SallyR"
        echo "  ohcd chat/AdmiredLeadership/cra-backend"
        return 0
    fi
    
    local project_path="$OPENHANDS_PROJECTS_DIR/$1"
    if [[ ! -d "$project_path" ]]; then
        echo "${OH_RED}✗ Project directory $project_path not found!${OH_RESET}"
        return 1
    fi
    
    cd "$project_path" && oh
}

# Launch with specific version
oh-version() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
        echo "${OH_BOLD}oh-version - Launch OpenHands with specific version${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} oh-version VERSION [PROJECT_PATH]"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-version 0.38             # Use version 0.38 for current dir"
        echo "  oh-version main SallyR      # Use main branch for SallyR"
        echo ""
        echo "${OH_BOLD}Available versions:${OH_RESET} 0.28, 0.35, 0.38, 0.39, 0.40, main"
        return 0
    fi
    
    local version="$1"
    local old_version="$OPENHANDS_DEFAULT_VERSION"
    export OPENHANDS_DEFAULT_VERSION="$version"
    
    shift
    oh "$@"
    
    export OPENHANDS_DEFAULT_VERSION="$old_version"
}

# Save OpenHands session
oh-save() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-save - Save OpenHands session state${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-save [PROJECT_PATH]    Save state for project"
        echo "  oh-save                   Save state for current directory"
        return 0
    fi
    
    local project_path=""
    local project_display_name=""
    
    if [[ $# -eq 0 ]]; then
        # No argument: use current directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
            project_display_name="$rel_path"
        else
            project_path=$(basename "$PWD")
            project_display_name="$(basename "$PWD")"
        fi
    else
        project_path="$1"
        project_display_name="$1"
    fi
    
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    
    if ! docker ps -q --filter "name=openhands-app-$safe_container_name" | grep -q .; then
        echo "${OH_RED}✗ No running OpenHands instance for $project_display_name${OH_RESET}"
        return 1
    fi
    
    local backup_dir="$HOME/.openhands-backups/$safe_container_name-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo "${OH_BLUE}💾 Saving session for $project_display_name...${OH_RESET}"
    
    if docker cp "$HOME/.openhands-state-$safe_container_name" "$backup_dir/" 2>/dev/null; then
        echo "${OH_GREEN}✅ Saved session to $backup_dir${OH_RESET}"
    else
        echo "${OH_RED}✗ Failed to save session${OH_RESET}"
        return 1
    fi
}

# View logs for OpenHands instance
oh-logs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-logs - View logs for OpenHands instance${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-logs [PROJECT_PATH]      View recent logs for project"
        echo "  oh-logs -f [PROJECT_PATH]   Follow log output in real-time"
        echo "  oh-logs -n NUM [PROJECT]    Show last NUM lines (default: all)"
        echo "  oh-logs --since TIME [PROJ] Show logs since TIME (e.g. 10m, 1h)"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-logs                     # View logs for current directory"
        echo "  oh-logs SallyR              # View logs for SallyR project"
        echo "  oh-logs -f                  # Follow logs for current directory"
        echo "  oh-logs -n 50               # Show last 50 lines"
        echo "  oh-logs --since 5m          # Show logs from last 5 minutes"
        echo ""
        echo "${OH_BOLD}Note:${OH_RESET} This is a wrapper around 'docker logs' with project name resolution"
        return 0
    fi
    
    local follow=false
    local num_lines=""
    local since=""
    local project_path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow)
                follow=true
                shift
                ;;
            -n|--lines)
                num_lines="$2"
                shift 2
                ;;
            --since)
                since="$2"
                shift 2
                ;;
            *)
                project_path="$1"
                shift
                ;;
        esac
    done
    
    # Determine project path
    if [[ -z "$project_path" ]]; then
        # No argument: use current directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
        else
            project_path=$(basename "$PWD")
        fi
    fi
    
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    local container_name="openhands-app-$safe_container_name"
    
    # Check if container is running
    if ! docker ps -q --filter "name=$container_name" | grep -q .; then
        echo "${OH_RED}✗ No running OpenHands instance for $project_path${OH_RESET}"
        echo "Start it with: oh $project_path"
        return 1
    fi
    
    # Build docker logs command
    local docker_cmd="docker logs"
    [[ "$follow" == true ]] && docker_cmd="$docker_cmd -f"
    [[ -n "$num_lines" ]] && docker_cmd="$docker_cmd -n $num_lines"
    [[ -n "$since" ]] && docker_cmd="$docker_cmd --since $since"
    docker_cmd="$docker_cmd $container_name"
    
    # Execute docker logs
    echo "${OH_BLUE}📄 Showing logs for $project_path${OH_RESET}"
    eval $docker_cmd
}

# Show all commands
oh-help() {
    echo "${OH_BOLD}OpenHands Project Management Commands${OH_RESET}"
    echo ""
    echo "${OH_BOLD}Commands:${OH_RESET}"
    echo "  ${OH_GREEN}oh${OH_RESET} [PROJECT_PATH]          Launch OpenHands"
    echo "  ${OH_GREEN}oh-list${OH_RESET}              List running instances"
    echo "  ${OH_GREEN}oh-stop${OH_RESET} [PROJECT_PATH]    Stop specific instance"
    echo "  ${OH_GREEN}oh-stop-all${OH_RESET}          Stop all instances"
    echo "  ${OH_GREEN}oh-clean${OH_RESET}             Clean up old containers"
    echo "  ${OH_GREEN}oh-logs${OH_RESET} [OPTIONS] [PROJECT]   View Docker logs"
    echo "  ${OH_GREEN}ohcd${OH_RESET} PROJECT_PATH         CD to project and launch"
    echo "  ${OH_GREEN}oh-version${OH_RESET} VER       Use specific OpenHands version"
    echo "  ${OH_GREEN}oh-save${OH_RESET} [PROJECT_PATH]    Save session state"
    echo "  ${OH_GREEN}oh-refresh-cache${OH_RESET}     Refresh project list cache"
    echo "  ${OH_GREEN}oh-update-version${OH_RESET}    Update default OpenHands version"
    echo "  ${OH_GREEN}oh-help${OH_RESET}              Show this help"
    echo ""
    echo "${OH_BOLD}Configuration:${OH_RESET}"
    echo "  OPENHANDS_DEFAULT_VERSION     Current: ${OPENHANDS_DEFAULT_VERSION}"
    echo "  OPENHANDS_PROJECTS_DIR        Current: ${OPENHANDS_PROJECTS_DIR}"
    echo ""
    echo "Add --help to any command for detailed usage"
}

# Tab completion for project names
_oh_complete() {
    local -a projects
    local current_time=$(date +%s)
    local cache_age=$((current_time - _OH_PROJECTS_CACHE_TIME))
    
    # Refresh cache if it's older than 60 seconds or empty
    if [[ ${#_OH_PROJECTS_CACHE[@]} -eq 0 ]] || [[ $cache_age -gt 60 ]]; then
        # Find git repositories, but limit depth to avoid long searches
        # Use -prune to stop descending into .git directories for efficiency
        _OH_PROJECTS_CACHE=($(find "$OPENHANDS_PROJECTS_DIR" \
            -name ".git" -type d \
            -not -path "*/.history/*" \
            -prune \
            2>/dev/null | \
            sed 's|/\.git$||' | \
            sed "s|^$OPENHANDS_PROJECTS_DIR/||" | \
            grep -v "^$" | \
            sort))
        _OH_PROJECTS_CACHE_TIME=$current_time
    fi
    
    projects=($_OH_PROJECTS_CACHE)
    
    # Handle completion differently for zsh vs bash
    if [[ -n "$ZSH_VERSION" ]]; then
        _describe 'project' projects
    elif [[ -n "$BASH_VERSION" ]]; then
        COMPREPLY=($(compgen -W "${projects[*]}" -- "${COMP_WORDS[COMP_CWORD]}"))
    fi
}

# Bash completion function for OpenHands commands
_oh_complete_bash() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local -a projects
    local current_time=$(date +%s)
    local cache_age=$((current_time - _OH_PROJECTS_CACHE_TIME))
    
    # Refresh cache if it's older than 60 seconds or empty
    if [[ ${#_OH_PROJECTS_CACHE[@]} -eq 0 ]] || [[ $cache_age -gt 60 ]]; then
        _OH_PROJECTS_CACHE=($(find "$OPENHANDS_PROJECTS_DIR" \
            -name ".git" -type d \
            -not -path "*/.history/*" \
            -prune \
            2>/dev/null | \
            sed 's|/\.git$||' | \
            sed "s|^$OPENHANDS_PROJECTS_DIR/||" | \
            grep -v "^$" | \
            sort))
        _OH_PROJECTS_CACHE_TIME=$current_time
    fi
    
    COMPREPLY=($(compgen -W "${_OH_PROJECTS_CACHE[*]}" -- "$cur"))
}

# Function to refresh the project cache manually
oh-refresh-cache() {
    _OH_PROJECTS_CACHE=()
    _OH_PROJECTS_CACHE_TIME=0
    echo "${OH_GREEN}✅ Project cache cleared. It will be refreshed on next tab completion.${OH_RESET}"
}

# Enable tab completion for the commands (zsh)
if [[ -n "$ZSH_VERSION" ]]; then
    # Ensure completion system is loaded
    autoload -Uz compinit
    compinit -d ~/.zcompdump-$ZSH_VERSION
    
    # Set up completions for all commands
    compdef _oh_complete oh
    compdef _oh_complete oh-stop
    compdef _oh_complete ohcd
    compdef _oh_complete oh-save
    compdef _oh_complete oh-version
    compdef _oh_complete oh-logs
fi

# Enable tab completion for the commands (bash)
if [[ -n "$BASH_VERSION" ]]; then
    # Set up completions for all commands
    complete -F _oh_complete_bash oh
    complete -F _oh_complete_bash oh-stop
    complete -F _oh_complete_bash ohcd
    complete -F _oh_complete_bash oh-save
    complete -F _oh_complete_bash oh-version
    complete -F _oh_complete_bash oh-logs
fi 