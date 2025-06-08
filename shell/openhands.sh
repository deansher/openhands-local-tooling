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
export OPENHANDS_DEFAULT_VERSION="${OPENHANDS_DEFAULT_VERSION:-0.41}"
# Use the correct runtime version that matches OpenHands 0.41
export OPENHANDS_RUNTIME_VERSION="${OPENHANDS_RUNTIME_VERSION:-0.41-nikolaik}"
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

# TOML parser command (will be set by _oh_check_toml_parser)
OH_TOML_PARSER=""

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

# Check if TOML parser is available
_oh_check_toml_parser() {
    # Try Python with toml module first
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import toml" 2>/dev/null; then
            OH_TOML_PARSER="python3"
            return 0
        fi
    fi
    
    # Try Python 2 as fallback
    if command -v python >/dev/null 2>&1; then
        if python -c "import toml" 2>/dev/null; then
            OH_TOML_PARSER="python"
            return 0
        fi
    fi
    
    # No TOML parser available
    OH_TOML_PARSER=""
    return 1
}

# Check config file permissions for security
_oh_check_config_permissions() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    # Get file permissions
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        perms=$(stat -f "%OLp" "$config_file")
    else
        # Linux
        perms=$(stat -c "%a" "$config_file")
    fi
    
    # Check if world-readable (last digit > 4)
    if [[ ${perms: -1} -ge 4 ]]; then
        echo "${OH_YELLOW}⚠️  Warning: $config_file is world-readable (permissions: $perms)${OH_RESET}"
        echo "   This file may contain API keys. Consider restricting permissions:"
        echo "   chmod 600 $config_file"
        echo ""
    fi
}

# Parse TOML file and export variables
_oh_parse_toml_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Check permissions
    _oh_check_config_permissions "$config_file"
    
    # Parse TOML and export variables using Python
    if [[ "$OH_TOML_PARSER" == "python"* ]]; then
        $OH_TOML_PARSER - "$config_file" << 'EOF'
import sys
import os
try:
    import toml
except ImportError:
    sys.exit(1)

config_file = sys.argv[1]

try:
    with open(config_file, 'r') as f:
        config = toml.load(f)
except Exception as e:
    print("Error parsing {}: {}".format(config_file, e), file=sys.stderr)
    sys.exit(1)

# Mapping of TOML keys to environment variables
mappings = {
    'llm': {
        'model': 'LLM_MODEL',
        'api_key': 'LLM_API_KEY',
        'search_api_key': 'SEARCH_API_KEY',
        'num_retries': 'LLM_NUM_RETRIES',
        'retry_min_wait': 'LLM_RETRY_MIN_WAIT',
        'retry_max_wait': 'LLM_RETRY_MAX_WAIT',
        'timeout': 'LLM_TIMEOUT',
        'temperature': 'LLM_TEMPERATURE',
        'top_p': 'LLM_TOP_P',
        'max_input_tokens': 'LLM_MAX_INPUT_TOKENS',
        'max_output_tokens': 'LLM_MAX_OUTPUT_TOKENS',
        'disable_vision': 'LLM_DISABLE_VISION'
    },
    'sandbox': {
        'runtime_container_image': 'SANDBOX_RUNTIME_CONTAINER_IMAGE',
        'enable_gpu': 'SANDBOX_ENABLE_GPU',
        'volumes': 'SANDBOX_VOLUMES',
        'user_id': 'SANDBOX_USER_ID'
    },
    'core': {
        'max_iterations': 'CORE_MAX_ITERATIONS',
        'max_budget_per_task': 'CORE_MAX_BUDGET_PER_TASK'
    },
    'agent': {
        'enable_cli': 'AGENT_ENABLE_CLI',
        'enable_browsing_delegate': 'AGENT_ENABLE_BROWSING_DELEGATE'
    },
    'security': {
        'confirmation_mode': 'SECURITY_CONFIRMATION_MODE',
        'security_level': 'SECURITY_LEVEL'
    }
}

# Export variables
for section, keys in mappings.items():
    if section in config:
        for key, env_var in keys.items():
            if key in config[section]:
                value = config[section][key]
                # Convert boolean to string
                if isinstance(value, bool):
                    value = 'true' if value else 'false'
                # Handle special formatting for certain values
                if env_var == 'LLM_API_KEY' or env_var == 'SEARCH_API_KEY':
                    # Mask API keys in output
                    if len(str(value)) > 8:
                        masked = "{}...{}".format(value[:4], value[-4:])
                        print("export {}='{}'".format(env_var, value))
                        print("# {} set from config (masked: {})".format(env_var, masked), file=sys.stderr)
                    else:
                        print("export {}='{}'".format(env_var, value))
                else:
                    print("export {}='{}'".format(env_var, value))
EOF
    fi
}

# Load OpenHands configuration from TOML files
load_openhands_config() {
    local project_path="$1"
    
    # Check if TOML parser is available
    if ! _oh_check_toml_parser; then
        return 0  # Silently skip if no parser available
    fi
    
    # Configuration file paths in priority order (lowest to highest)
    local config_files=()
    
    # System config (optional)
    if [[ -f "/etc/openhands/config.toml" ]]; then
        config_files+=("/etc/openhands/config.toml")
    fi
    
    # User global config
    if [[ -f "$HOME/.openhands/config.toml" ]]; then
        config_files+=("$HOME/.openhands/config.toml")
    fi
    
    # Project-specific config
    if [[ -n "$project_path" ]] && [[ "$project_path" != "." ]]; then
        local project_config="$OPENHANDS_PROJECTS_DIR/$project_path/.openhands/config.toml"
        if [[ -f "$project_config" ]]; then
            config_files+=("$project_config")
        fi
    fi
    
    # Load configs in order (later ones override earlier ones)
    local loaded_any=false
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Parse and export variables, capturing stdout and stderr separately
            local exports
            local stderr_output
            exports=$(_oh_parse_toml_file "$config_file" 2>&1)
            local exit_code=$?
            
            if [[ $exit_code -eq 0 ]]; then
                # Filter out stderr messages from the exports
                local clean_exports=$(echo "$exports" | grep "^export ")
                # Execute the exports
                eval "$clean_exports"
                loaded_any=true
                echo "${OH_BLUE}📋 Loaded config from: $config_file${OH_RESET}" >&2
            else
                echo "${OH_YELLOW}⚠️  Failed to parse config: $config_file${OH_RESET}" >&2
                echo "$exports" >&2
            fi
        fi
    done
    
    # Show if config was loaded
    if [[ "$loaded_any" == true ]]; then
        echo "${OH_GREEN}✅ Configuration loaded from TOML files${OH_RESET}" >&2
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
        echo "  oh .                  Launch for entire projects directory"
        echo "  oh --show-config      Show configuration that would be used"
        echo "  oh --help            Show this help"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  cd ~/projects/myapp && oh"
        echo "  oh SallyR"
        echo "  oh chat/AdmiredLeadership/cra-backend"
        echo "  oh .                  # Access all projects"
        return 0
    fi
    
    # Handle --show-config flag
    if [[ "$1" == "--show-config" ]]; then
        shift
        local project_arg="$1"
        if [[ -z "$project_arg" ]]; then
            oh-config-check
        else
            oh-config-check "$project_arg"
        fi
        return 0
    fi

    local project_path=""
    local project_display_name=""
    local absolute_project_path=""
    local user_arg=""  # Track original user argument for tips
    
    if [[ $# -eq 0 ]]; then
        # No argument: use current directory
        absolute_project_path="$PWD"
        # Try to get relative path from projects directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
            project_display_name="$rel_path"
            user_arg="$rel_path"
        else
            project_path=$(basename "$PWD")
            project_display_name="$(basename "$PWD") (external)"
            user_arg=""  # No argument for current directory
        fi
    elif [[ "$1" == "." ]]; then
        # Special case: mount entire projects directory
        project_path="projects-root"
        project_display_name="All Projects"
        absolute_project_path="$OPENHANDS_PROJECTS_DIR"
        user_arg="."
    else
        # Argument provided: assume it's a project path relative to ~/projects
        project_path="$1"
        project_display_name="$1"
        absolute_project_path="$OPENHANDS_PROJECTS_DIR/$1"
        user_arg="$1"
        
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
    
    # Load configuration from TOML files
    load_openhands_config "$project_path"
    
    # First-run experience: check if API key is configured
    if [[ -z "$LLM_API_KEY" ]] && ! [[ -f "$HOME/.openhands/config.toml" ]]; then
        echo "${OH_YELLOW}⚠️  No LLM API key configured${OH_RESET}"
        echo ""
        echo "OpenHands needs an API key to function. Would you like to create a config file?"
        echo -n "Create config? (Y/n): "
        read create_config
        if [[ "$create_config" != "n" ]] && [[ "$create_config" != "N" ]]; then
            oh-config-init --global
            echo ""
            echo "Please edit the config file to add your API key:"
            echo "  ${OH_BOLD}oh-config-edit --global${OH_RESET}"
            return 0
        fi
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "${OH_RED}✗ Docker is not running! Please start Docker Desktop.${OH_RESET}"
        return 1
    fi
    
    # Check if already running
    if docker ps -q --filter "name=openhands-app-$safe_container_name" | grep -q .; then
        local existing_port=$(docker port "openhands-app-$safe_container_name" 3000 | cut -d: -f2)
        echo "${OH_YELLOW}⚠️  OpenHands is already running for $project_display_name on port $existing_port${OH_RESET}"
        if [[ -n "$user_arg" ]]; then
            echo "Stop it first with: oh-stop $user_arg"
        else
            echo "Stop it first with: oh-stop"
        fi
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
    echo "🏷️  Version: $OPENHANDS_DEFAULT_VERSION (runtime: $OPENHANDS_RUNTIME_VERSION)"
    echo "📝 Log file: $log_file"
    
    # Build docker run command with environment variables
    local docker_cmd="docker run -d --rm"
    
    # Add environment variables from config or defaults
    docker_cmd="$docker_cmd -e SANDBOX_RUNTIME_CONTAINER_IMAGE=${SANDBOX_RUNTIME_CONTAINER_IMAGE:-docker.all-hands.dev/all-hands-ai/runtime:${OPENHANDS_RUNTIME_VERSION}}"
    docker_cmd="$docker_cmd -e SANDBOX_USER_ID=${SANDBOX_USER_ID:-$(id -u)}"
    
    # Handle SANDBOX_VOLUMES - append project path if additional volumes specified
    if [[ -n "$SANDBOX_VOLUMES" ]]; then
        docker_cmd="$docker_cmd -e SANDBOX_VOLUMES=\"$absolute_project_path:/workspace:rw,$SANDBOX_VOLUMES\""
    else
        docker_cmd="$docker_cmd -e SANDBOX_VOLUMES=\"$absolute_project_path:/workspace:rw\""
    fi
    
    docker_cmd="$docker_cmd -e LOG_ALL_EVENTS=true"
    
    # Add LLM configuration if set
    [[ -n "$LLM_MODEL" ]] && docker_cmd="$docker_cmd -e LLM_MODEL=\"$LLM_MODEL\""
    [[ -n "$LLM_API_KEY" ]] && docker_cmd="$docker_cmd -e LLM_API_KEY=\"$LLM_API_KEY\""
    [[ -n "$SEARCH_API_KEY" ]] && docker_cmd="$docker_cmd -e SEARCH_API_KEY=\"$SEARCH_API_KEY\""
    [[ -n "$LLM_NUM_RETRIES" ]] && docker_cmd="$docker_cmd -e LLM_NUM_RETRIES=\"$LLM_NUM_RETRIES\""
    [[ -n "$LLM_RETRY_MIN_WAIT" ]] && docker_cmd="$docker_cmd -e LLM_RETRY_MIN_WAIT=\"$LLM_RETRY_MIN_WAIT\""
    [[ -n "$LLM_RETRY_MAX_WAIT" ]] && docker_cmd="$docker_cmd -e LLM_RETRY_MAX_WAIT=\"$LLM_RETRY_MAX_WAIT\""
    [[ -n "$LLM_TIMEOUT" ]] && docker_cmd="$docker_cmd -e LLM_TIMEOUT=\"$LLM_TIMEOUT\""
    [[ -n "$LLM_TEMPERATURE" ]] && docker_cmd="$docker_cmd -e LLM_TEMPERATURE=\"$LLM_TEMPERATURE\""
    [[ -n "$LLM_TOP_P" ]] && docker_cmd="$docker_cmd -e LLM_TOP_P=\"$LLM_TOP_P\""
    [[ -n "$LLM_MAX_INPUT_TOKENS" ]] && docker_cmd="$docker_cmd -e LLM_MAX_INPUT_TOKENS=\"$LLM_MAX_INPUT_TOKENS\""
    [[ -n "$LLM_MAX_OUTPUT_TOKENS" ]] && docker_cmd="$docker_cmd -e LLM_MAX_OUTPUT_TOKENS=\"$LLM_MAX_OUTPUT_TOKENS\""
    [[ -n "$LLM_DISABLE_VISION" ]] && docker_cmd="$docker_cmd -e LLM_DISABLE_VISION=\"$LLM_DISABLE_VISION\""
    
    # Add sandbox configuration if set
    [[ -n "$SANDBOX_ENABLE_GPU" ]] && docker_cmd="$docker_cmd -e SANDBOX_ENABLE_GPU=\"$SANDBOX_ENABLE_GPU\""
    
    # Add core configuration if set
    [[ -n "$CORE_MAX_ITERATIONS" ]] && docker_cmd="$docker_cmd -e CORE_MAX_ITERATIONS=\"$CORE_MAX_ITERATIONS\""
    [[ -n "$CORE_MAX_BUDGET_PER_TASK" ]] && docker_cmd="$docker_cmd -e CORE_MAX_BUDGET_PER_TASK=\"$CORE_MAX_BUDGET_PER_TASK\""
    
    # Add agent configuration if set
    [[ -n "$AGENT_ENABLE_CLI" ]] && docker_cmd="$docker_cmd -e AGENT_ENABLE_CLI=\"$AGENT_ENABLE_CLI\""
    [[ -n "$AGENT_ENABLE_BROWSING_DELEGATE" ]] && docker_cmd="$docker_cmd -e AGENT_ENABLE_BROWSING_DELEGATE=\"$AGENT_ENABLE_BROWSING_DELEGATE\""
    
    # Add security configuration if set
    [[ -n "$SECURITY_CONFIRMATION_MODE" ]] && docker_cmd="$docker_cmd -e SECURITY_CONFIRMATION_MODE=\"$SECURITY_CONFIRMATION_MODE\""
    [[ -n "$SECURITY_LEVEL" ]] && docker_cmd="$docker_cmd -e SECURITY_LEVEL=\"$SECURITY_LEVEL\""
    
    # Add volumes and ports
    docker_cmd="$docker_cmd -v /var/run/docker.sock:/var/run/docker.sock"
    docker_cmd="$docker_cmd -v ~/.openhands-state-$safe_container_name:/.openhands-state"
    docker_cmd="$docker_cmd -p $port:3000"
    docker_cmd="$docker_cmd --add-host host.docker.internal:host-gateway"
    docker_cmd="$docker_cmd --name \"openhands-app-$safe_container_name\""
    docker_cmd="$docker_cmd docker.all-hands.dev/all-hands-ai/openhands:${OPENHANDS_DEFAULT_VERSION}"
    
    if eval "$docker_cmd" >/dev/null; then
        
        echo "${OH_GREEN}✅ OpenHands started successfully!${OH_RESET}"
        echo ""
        echo "🌐 URL: ${OH_BOLD}http://localhost:$port${OH_RESET}"
        echo "📝 Project: ${OH_BOLD}$project_display_name${OH_RESET}"
        echo ""
        echo "💡 Tips:"
        echo "  - Start a NEW conversation in the UI for fresh workspace mounts"
        if [[ -n "$user_arg" ]]; then
            echo "  - View logs with: oh-logs $user_arg"
            echo "  - Follow logs with: oh-logs -f $user_arg"
        else
            echo "  - View logs with: oh-logs"
            echo "  - Follow logs with: oh-logs -f"
        fi
        
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
            # Special case for projects-root
            if [[ "$project_name" == "projects-root" ]]; then
                project_name="."
            fi
            local port=$(echo $ports | grep -o '0.0.0.0:[0-9]*->3000' | cut -d: -f2 | cut -d- -f1)
            printf "  %-40s %s    %s\n" "$project_name" "$port" "$container_status"
        done
    fi
    echo ""
    
    # Show config status
    if _oh_check_toml_parser >/dev/null 2>&1; then
        if [[ -f "$HOME/.openhands/config.toml" ]] || [[ -f "/etc/openhands/config.toml" ]]; then
            echo "  ${OH_GREEN}📋 Config files detected${OH_RESET} (use oh-config-check to view)"
        fi
    fi
}

# Stop OpenHands for a specific project
oh-stop() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-stop - Stop OpenHands for a specific project${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-stop PROJECT_PATH    Stop specific project"
        echo "  oh-stop                 Stop project in current directory"
        echo "  oh-stop .               Stop projects root instance"
        echo "  oh-stop --help         Show this help"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-stop SallyR"
        echo "  oh-stop chat/AdmiredLeadership/cra-backend"
        echo "  oh-stop .              # Stop the all-projects instance"
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
    elif [[ "$1" == "." ]]; then
        # Special case: projects root
        project_path="projects-root"
        project_display_name="All Projects"
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
        echo "  oh-version 0.40 .           # Use version 0.40 for all projects"
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
        echo "  oh-save .                 Save state for projects root"
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
    elif [[ "$1" == "." ]]; then
        # Special case: projects root
        project_path="projects-root"
        project_display_name="All Projects"
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
    
    if cp -r "$HOME/.openhands-state-$safe_container_name" "$backup_dir/" 2>/dev/null; then
        echo "${OH_GREEN}✅ Saved session to $backup_dir${OH_RESET}"
    else
        echo "${OH_RED}✗ Failed to save session${OH_RESET}"
        return 1
    fi
}

# View logs for OpenHands instance
oh-logs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-logs - View logs for OpenHands app container${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-logs [PROJECT_PATH]      View recent app logs"
        echo "  oh-logs -f [PROJECT_PATH]   Follow app log output in real-time"
        echo "  oh-logs -n NUM [PROJECT]    Show last NUM lines (default: all)"
        echo "  oh-logs --since TIME [PROJ] Show logs since TIME (e.g. 10m, 1h)"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-logs                     # View app logs for current directory"
        echo "  oh-logs SallyR              # View app logs for SallyR project"
        echo "  oh-logs -f                  # Follow app logs for current directory"
        echo "  oh-logs -n 50               # Show last 50 lines"
        echo "  oh-logs --since 5m          # Show logs from last 5 minutes"
        echo ""
        echo "${OH_BOLD}Note:${OH_RESET} App containers handle the UI and orchestration."
        echo "For code execution logs, use: oh-runtime-logs"
        return 0
    fi
    
    local follow=false
    local num_lines=""
    local since=""
    local project_path=""
    local original_arg=""
    
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
                original_arg="$1"
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
    elif [[ "$project_path" == "." ]]; then
        # Special case: projects root
        project_path="projects-root"
    fi
    
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    local container_name="openhands-app-$safe_container_name"
    
    # Check if container is running
    if ! docker ps -q --filter "name=$container_name" | grep -q .; then
        echo "${OH_RED}✗ No running OpenHands instance for $project_path${OH_RESET}"
        if [[ -n "$original_arg" ]]; then
            echo "Start it with: oh $original_arg"
        else
            echo "Start it with: oh"
        fi
        return 1
    fi
    
    # Build docker logs command
    local docker_cmd="docker logs"
    [[ "$follow" == true ]] && docker_cmd="$docker_cmd -f"
    [[ -n "$num_lines" ]] && docker_cmd="$docker_cmd -n $num_lines"
    [[ -n "$since" ]] && docker_cmd="$docker_cmd --since $since"
    docker_cmd="$docker_cmd $container_name"
    
    # Execute docker logs
    if [[ "$original_arg" == "." ]]; then
        echo "${OH_BLUE}📄 Showing logs for All Projects${OH_RESET}"
    elif [[ -n "$original_arg" ]]; then
        echo "${OH_BLUE}📄 Showing logs for $original_arg${OH_RESET}"
    else
        echo "${OH_BLUE}📄 Showing logs for current directory${OH_RESET}"
    fi
    eval $docker_cmd
}

# View logs for OpenHands runtime container
oh-runtime-logs() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-runtime-logs - View logs for OpenHands runtime container${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-runtime-logs [PROJECT_PATH]      View recent runtime logs"
        echo "  oh-runtime-logs -f [PROJECT_PATH]   Follow runtime log output"
        echo "  oh-runtime-logs -n NUM [PROJECT]    Show last NUM lines"
        echo "  oh-runtime-logs --since TIME [PROJ] Show logs since TIME"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-runtime-logs                     # View runtime logs for current directory"
        echo "  oh-runtime-logs -f myapp            # Follow runtime logs for myapp"
        echo "  oh-runtime-logs -n 100 .            # Last 100 lines for projects root"
        echo ""
        echo "${OH_BOLD}Note:${OH_RESET} Runtime containers execute your code and handle MCP tools"
        return 0
    fi
    
    local follow=false
    local num_lines=""
    local since=""
    local project_path=""
    local original_arg=""
    
    # Parse arguments (same as oh-logs)
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
                original_arg="$1"
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
    elif [[ "$project_path" == "." ]]; then
        # Special case: projects root
        project_path="projects-root"
    fi
    
    # Find runtime containers for this project
    local safe_container_name=$(_oh_safe_container_name "$project_path")
    local runtime_containers=""
    
    # First, check if the app container is running
    local app_container="openhands-app-$safe_container_name"
    if docker ps --filter "name=$app_container" --format "{{.Names}}" | grep -q "^${app_container}$"; then
        # App is running, look for runtime containers by conversation ID in app logs
        local conversation_ids=$(docker logs "$app_container" 2>&1 | grep -oE "conversation_id=[a-f0-9]{32}" | cut -d= -f2 | sort -u | tail -5)
        while IFS= read -r conv_id; do
            if [[ -n "$conv_id" ]] && docker ps --filter "name=openhands-runtime-$conv_id" --format "{{.Names}}" | grep -q "^openhands-runtime-${conv_id}$"; then
                if [[ -n "$runtime_containers" ]]; then
                    runtime_containers="${runtime_containers} openhands-runtime-$conv_id"
                else
                    runtime_containers="openhands-runtime-$conv_id"
                fi
            fi
        done <<< "$conversation_ids"
    fi
    
    if [[ -z "$runtime_containers" ]]; then
        echo "${OH_RED}✗ No running runtime container found for this project${OH_RESET}"
        echo "Runtime containers are created when you start a conversation in OpenHands."
        echo ""
        echo "To list all runtime containers:"
        echo "  docker ps --filter 'name=openhands-runtime-'"
        return 1
    fi
    
    # If multiple runtime containers, use the most recent one
    local runtime_container=$(echo "$runtime_containers" | tr ' ' '\n' | tail -1)
    
    # Build docker logs command
    local docker_cmd="docker logs"
    [[ "$follow" == true ]] && docker_cmd="$docker_cmd -f"
    [[ -n "$num_lines" ]] && docker_cmd="$docker_cmd -n $num_lines"
    [[ -n "$since" ]] && docker_cmd="$docker_cmd --since $since"
    docker_cmd="$docker_cmd $runtime_container"
    
    # Execute docker logs
    if [[ "$original_arg" == "." ]]; then
        echo "${OH_BLUE}📄 Showing runtime logs for All Projects${OH_RESET}"
    elif [[ -n "$original_arg" ]]; then
        echo "${OH_BLUE}📄 Showing runtime logs for $original_arg${OH_RESET}"
    else
        echo "${OH_BLUE}📄 Showing runtime logs for current directory${OH_RESET}"
    fi
    echo "${OH_YELLOW}Runtime container: $runtime_container${OH_RESET}"
    
    # If there are multiple runtime containers, show them
    local container_count=$(echo "$runtime_containers" | tr ' ' '\n' | wc -l | tr -d ' ')
    if [[ $container_count -gt 1 ]]; then
        echo "${OH_YELLOW}Note: Found $container_count runtime containers, showing the most recent${OH_RESET}"
        echo "All runtime containers: $runtime_containers"
    fi
    echo ""
    eval $docker_cmd
}

# Show all OpenHands containers (app and runtime)
oh-containers() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-containers - Show all OpenHands containers with their relationships${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET} oh-containers [OPTIONS]"
        echo ""
        echo "${OH_BOLD}Options:${OH_RESET}"
        echo "  -a, --all        Show stopped containers too"
        echo "  -r, --runtime    Show only runtime containers"
        echo "  --help           Show this help"
        echo ""
        echo "${OH_BOLD}Container Types:${OH_RESET}"
        echo "  App containers:     Main OpenHands UI and orchestration"
        echo "  Runtime containers: Code execution environments (one per conversation)"
        return 0
    fi
    
    local show_all=false
    local runtime_only=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                show_all=true
                shift
                ;;
            -r|--runtime)
                runtime_only=true
                shift
                ;;
            *)
                echo "${OH_RED}Unknown option: $1${OH_RESET}"
                return 1
                ;;
        esac
    done
    
    local docker_filter=""
    if [[ "$show_all" == false ]]; then
        docker_filter=""  # docker ps without -a shows only running containers by default
    else
        docker_filter="-a"  # Show all containers including stopped ones
    fi
    
    if [[ "$runtime_only" == false ]]; then
        echo "${OH_BOLD}🚀 OpenHands App Containers:${OH_RESET}"
        echo ""
        
        local app_containers=$(docker ps $docker_filter --filter "name=openhands-app-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
        if [[ -n "$app_containers" ]]; then
            # Header
            printf "  %-45s %-20s %s\n" "PROJECT" "STATUS" "PORT"
            printf "  %s\n" "────────────────────────────────────────────────────────────────────────────────"
            
            # Process each app container
            docker ps $docker_filter --filter "name=openhands-app-" --format "{{.Names}}|{{.Status}}|{{.Ports}}" 2>/dev/null | while IFS='|' read -r name container_status ports; do
                local safe_name=${name#openhands-app-}
                local project_name=$(echo "$safe_name" | sed 's|__|/|g')
                if [[ "$project_name" == "projects-root" ]]; then
                    project_name="."
                fi
                local port=$(echo $ports | grep -o '0.0.0.0:[0-9]*->3000' | cut -d: -f2 | cut -d- -f1)
                printf "  %-45s %-20s %s\n" "$project_name" "$container_status" "${port:-N/A}"
                
                # Find associated runtime containers
                local conversation_ids=$(docker logs "$name" 2>&1 | grep -oE "conversation_id=[a-f0-9]{32}" | cut -d= -f2 | sort -u | tail -5)
                for conv_id in $conversation_ids; do
                    if docker ps -q $docker_filter --filter "name=openhands-runtime-$conv_id" | grep -q .; then
                        local runtime_status=$(docker ps $docker_filter --filter "name=openhands-runtime-$conv_id" --format "{{.Status}}")
                        printf "    └─ %-41s %-20s\n" "runtime: ${conv_id:0:8}..." "$runtime_status"
                    fi
                done
            done
        else
            echo "  No app containers found"
        fi
        echo ""
    fi
    
    echo "${OH_BOLD}⚙️  OpenHands Runtime Containers:${OH_RESET}"
    echo ""
    
    local runtime_containers=$(docker ps $docker_filter --filter "name=openhands-runtime-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v "NAMES")
    if [[ -n "$runtime_containers" ]]; then
        # Header
        printf "  %-50s %-20s %s\n" "CONTAINER ID" "STATUS" "PORTS"
        printf "  %s\n" "────────────────────────────────────────────────────────────────────────────────"
        
        # Show runtime containers
        docker ps $docker_filter --filter "name=openhands-runtime-" --format "{{.Names}}|{{.Status}}|{{.Ports}}" 2>/dev/null | while IFS='|' read -r name container_status ports; do
            local short_name="${name:0:50}"
            local port_info=$(echo $ports | grep -oE '[0-9]+->')[0:20] || "N/A"
            printf "  %-50s %-20s %s\n" "$short_name" "$container_status" "${port_info}..."
        done
    else
        echo "  No runtime containers found"
        echo "  Runtime containers are created when you start a conversation in OpenHands"
    fi
    echo ""
    
    # Show summary
    local app_count=$(docker ps $docker_filter --filter "name=openhands-app-" -q | wc -l | tr -d ' ')
    local runtime_count=$(docker ps $docker_filter --filter "name=openhands-runtime-" -q | wc -l | tr -d ' ')
    echo "${OH_BOLD}Summary:${OH_RESET} $app_count app container(s), $runtime_count runtime container(s)"
}

# Initialize config file
oh-config-init() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-config-init - Create a template config.toml file${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-config-init --global     Create global config at ~/.openhands/config.toml"
        echo "  oh-config-init --project    Create project config in current directory"
        echo "  oh-config-init              Interactive mode (asks where to create)"
        echo ""
        echo "${OH_BOLD}Examples:${OH_RESET}"
        echo "  oh-config-init --global"
        echo "  cd ~/projects/myapp && oh-config-init --project"
        return 0
    fi
    
    local config_path=""
    local config_type=""
    
    if [[ "$1" == "--global" ]]; then
        config_path="$HOME/.openhands/config.toml"
        config_type="global"
    elif [[ "$1" == "--project" ]]; then
        config_path=".openhands/config.toml"
        config_type="project"
    else
        # Interactive mode
        echo "${OH_BOLD}Where would you like to create the config file?${OH_RESET}"
        echo "1) Global config (~/.openhands/config.toml)"
        echo "2) Project config (current directory)"
        echo -n "Choice (1 or 2): "
        read choice
        
        case "$choice" in
            1)
                config_path="$HOME/.openhands/config.toml"
                config_type="global"
                ;;
            2)
                config_path=".openhands/config.toml"
                config_type="project"
                ;;
            *)
                echo "${OH_RED}Invalid choice${OH_RESET}"
                return 1
                ;;
        esac
    fi
    
    # Create directory if needed
    local config_dir=$(dirname "$config_path")
    mkdir -p "$config_dir"
    
    # Check if file already exists
    if [[ -f "$config_path" ]]; then
        echo "${OH_YELLOW}⚠️  Config file already exists at: $config_path${OH_RESET}"
        echo -n "Overwrite? (y/N): "
        read confirm
        if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
            echo "Cancelled"
            return 0
        fi
    fi
    
    # Create template config file
    cat > "$config_path" << 'EOF'
# OpenHands Configuration File
# This file uses TOML format: https://toml.io/

[llm]
# LLM model to use (e.g., "anthropic/claude-sonnet-4-20250514", "openai/gpt-4")
# model = "anthropic/claude-sonnet-4-20250514"

# API key for the LLM provider
# api_key = "sk-..."

# Tavily API key for web search capabilities
# search_api_key = "tvly-..."

# Retry configuration
# num_retries = 4
# retry_min_wait = 5
# retry_max_wait = 30
# timeout = 300

# Model parameters
# temperature = 0.0
# top_p = 1.0
# max_input_tokens = 30000
# max_output_tokens = 5000

# Disable vision capabilities
# disable_vision = false

[sandbox]
# Runtime container image
# runtime_container_image = "docker.all-hands.dev/all-hands-ai/runtime:0.41-nikolaik"

# Enable GPU support
# enable_gpu = false

# Additional volumes to mount (comma-separated)
# volumes = "/additional/path:/workspace/extra:rw"

# User ID for the sandbox
# user_id = 1000

[core]
# Maximum iterations for task completion
# max_iterations = 250

# Maximum budget per task (0.0 = unlimited)
# max_budget_per_task = 0.0

[agent]
# Enable CLI mode
# enable_cli = false

# Enable browsing delegate
# enable_browsing_delegate = false

[security]
# Confirmation mode: "disabled", "enabled"
# confirmation_mode = "disabled"

# Security level: "standard", "strict"
# security_level = "standard"
EOF
    
    # Set appropriate permissions
    chmod 600 "$config_path"
    
    echo "${OH_GREEN}✅ Created config template at: $config_path${OH_RESET}"
    echo ""
    echo "Next steps:"
    echo "1. Edit the file to add your configuration:"
    echo "   ${OH_BOLD}$EDITOR $config_path${OH_RESET}"
    echo ""
    echo "2. Uncomment and set the values you need"
    echo ""
    echo "3. Test your configuration:"
    echo "   ${OH_BOLD}oh-config-check${OH_RESET}"
    
    if [[ "$config_type" == "global" ]]; then
        echo ""
        echo "This global config will apply to all projects unless overridden."
    else
        echo ""
        echo "This project config will override global settings for this project."
    fi
}

# Check config files
oh-config-check() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-config-check - Validate config files and show what would be loaded${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-config-check [PROJECT_PATH]    Check config for specific project"
        echo "  oh-config-check                   Check config for current directory"
        echo ""
        echo "Shows which config files would be loaded and their values"
        return 0
    fi
    
    local project_path=""
    
    if [[ $# -eq 0 ]]; then
        # No argument: use current directory
        local rel_path=$(_oh_get_project_path "$PWD")
        if [[ -n "$rel_path" ]]; then
            project_path="$rel_path"
        else
            project_path=$(basename "$PWD")
        fi
    else
        project_path="$1"
    fi
    
    echo "${OH_BOLD}🔍 Checking OpenHands configuration...${OH_RESET}"
    echo ""
    
    # Check if TOML parser is available
    if ! _oh_check_toml_parser; then
        echo "${OH_YELLOW}⚠️  No TOML parser available${OH_RESET}"
        echo "Install Python toml module to enable config file support:"
        echo "  pip install toml"
        return 1
    fi
    
    echo "${OH_GREEN}✅ TOML parser available: $OH_TOML_PARSER${OH_RESET}"
    echo ""
    
    # Build list of config files
    local config_files=()
    
    # System config (optional)
    if [[ -f "/etc/openhands/config.toml" ]]; then
        config_files+=("/etc/openhands/config.toml")
    fi
    
    # User global config
    if [[ -f "$HOME/.openhands/config.toml" ]]; then
        config_files+=("$HOME/.openhands/config.toml")
    fi
    
    # Project-specific config
    if [[ -n "$project_path" ]] && [[ "$project_path" != "." ]]; then
        local project_config="$OPENHANDS_PROJECTS_DIR/$project_path/.openhands/config.toml"
        if [[ -f "$project_config" ]]; then
            config_files+=("$project_config")
        fi
    fi
    
    # Check config files in order
    echo "${OH_BOLD}Configuration files (in priority order):${OH_RESET}"
    echo ""
    
    # System config
    if [[ -f "/etc/openhands/config.toml" ]]; then
        echo "1. System config: /etc/openhands/config.toml ${OH_GREEN}[EXISTS]${OH_RESET}"
        _oh_check_config_permissions "/etc/openhands/config.toml"
    else
        echo "1. System config: /etc/openhands/config.toml ${OH_YELLOW}[NOT FOUND]${OH_RESET}"
    fi
    
    # Global config
    if [[ -f "$HOME/.openhands/config.toml" ]]; then
        echo "2. Global config: $HOME/.openhands/config.toml ${OH_GREEN}[EXISTS]${OH_RESET}"
        _oh_check_config_permissions "$HOME/.openhands/config.toml"
    else
        echo "2. Global config: $HOME/.openhands/config.toml ${OH_YELLOW}[NOT FOUND]${OH_RESET}"
    fi
    
    # Project config
    if [[ -n "$project_path" ]] && [[ "$project_path" != "." ]]; then
        local project_config="$OPENHANDS_PROJECTS_DIR/$project_path/.openhands/config.toml"
        if [[ -f "$project_config" ]]; then
            echo "3. Project config: $project_config ${OH_GREEN}[EXISTS]${OH_RESET}"
            _oh_check_config_permissions "$project_config"
        else
            echo "3. Project config: $project_config ${OH_YELLOW}[NOT FOUND]${OH_RESET}"
        fi
    fi
    
    echo ""
    echo "${OH_BOLD}Environment variables that would be set:${OH_RESET}"
    echo ""
    
    # Show what would be loaded from each config file
    # Need to ensure TOML parser is available
    _oh_check_toml_parser
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            echo "From $config_file:"
            local exports=$(_oh_parse_toml_file "$config_file" 2>/dev/null | grep "^export ")
            if [[ -n "$exports" ]]; then
                echo "$exports" | while read line; do
                    # Extract variable name and value
                    local var_name=$(echo "$line" | sed "s/export \([^=]*\)=.*/\1/")
                    local var_value=$(echo "$line" | sed "s/export [^=]*='\(.*\)'/\1/")
                    
                    # Mask sensitive values
                    if [[ "$var_name" == "LLM_API_KEY" ]] || [[ "$var_name" == "SEARCH_API_KEY" ]]; then
                        if [[ ${#var_value} -gt 8 ]]; then
                            echo "  $var_name=${var_value:0:4}...${var_value: -4}"
                        else
                            echo "  $var_name=***"
                        fi
                    else
                        echo "  $var_name=$var_value"
                    fi
                done
            fi
            echo ""
        fi
    done
}

# Edit config file
oh-config-edit() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "${OH_BOLD}oh-config-edit - Edit OpenHands config file${OH_RESET}"
        echo ""
        echo "${OH_BOLD}Usage:${OH_RESET}"
        echo "  oh-config-edit --global              Edit global config"
        echo "  oh-config-edit --project [PATH]      Edit project config"
        echo "  oh-config-edit                       Interactive mode"
        echo ""
        echo "Opens config file in \$EDITOR (default: vi)"
        return 0
    fi
    
    local config_path=""
    local editor="${EDITOR:-vi}"
    
    if [[ "$1" == "--global" ]]; then
        config_path="$HOME/.openhands/config.toml"
    elif [[ "$1" == "--project" ]]; then
        local project_path="$2"
        if [[ -z "$project_path" ]]; then
            # Use current directory
            local rel_path=$(_oh_get_project_path "$PWD")
            if [[ -n "$rel_path" ]]; then
                config_path="$OPENHANDS_PROJECTS_DIR/$rel_path/.openhands/config.toml"
            else
                config_path=".openhands/config.toml"
            fi
        else
            config_path="$OPENHANDS_PROJECTS_DIR/$project_path/.openhands/config.toml"
        fi
    else
        # Interactive mode
        echo "${OH_BOLD}Which config file would you like to edit?${OH_RESET}"
        echo "1) Global config (~/.openhands/config.toml)"
        echo "2) Project config (current directory)"
        echo -n "Choice (1 or 2): "
        read choice
        
        case "$choice" in
            1)
                config_path="$HOME/.openhands/config.toml"
                ;;
            2)
                config_path=".openhands/config.toml"
                ;;
            *)
                echo "${OH_RED}Invalid choice${OH_RESET}"
                return 1
                ;;
        esac
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$config_path" ]]; then
        echo "${OH_YELLOW}Config file doesn't exist: $config_path${OH_RESET}"
        echo -n "Create it? (Y/n): "
        read confirm
        if [[ "$confirm" != "n" ]] && [[ "$confirm" != "N" ]]; then
            mkdir -p "$(dirname "$config_path")"
            oh-config-init --global >/dev/null 2>&1 || oh-config-init --project >/dev/null 2>&1
        else
            return 0
        fi
    fi
    
    # Edit the file
    $editor "$config_path"
    
    echo ""
    echo "${OH_GREEN}✅ Finished editing: $config_path${OH_RESET}"
    echo ""
    echo "Test your configuration with: oh-config-check"
}

# Show all commands
oh-help() {
    echo "${OH_BOLD}OpenHands Project Management Commands${OH_RESET}"
    echo ""
    echo "${OH_BOLD}Core Commands:${OH_RESET}"
    echo "  ${OH_GREEN}oh${OH_RESET} [PROJECT_PATH]          Launch OpenHands"
    echo "  ${OH_GREEN}oh-list${OH_RESET}              List running instances"
    echo "  ${OH_GREEN}oh-stop${OH_RESET} [PROJECT_PATH]    Stop specific instance"
    echo "  ${OH_GREEN}oh-stop-all${OH_RESET}          Stop all instances"
    echo "  ${OH_GREEN}oh-clean${OH_RESET}             Clean up old containers"
    echo ""
    echo "${OH_BOLD}Logging Commands:${OH_RESET}"
    echo "  ${OH_GREEN}oh-logs${OH_RESET} [OPTIONS] [PROJECT]   View app container logs"
    echo "  ${OH_GREEN}oh-runtime-logs${OH_RESET} [OPTIONS] [PROJECT]   View runtime container logs"
    echo "  ${OH_GREEN}oh-containers${OH_RESET} [OPTIONS]   Show all containers with relationships"
    echo ""
    echo "${OH_BOLD}Configuration Commands:${OH_RESET}"
    echo "  ${OH_GREEN}oh-config-init${OH_RESET} [--global|--project]   Create config template"
    echo "  ${OH_GREEN}oh-config-check${OH_RESET} [PROJECT]             Check config files"
    echo "  ${OH_GREEN}oh-config-edit${OH_RESET} [--global|--project]   Edit config file"
    echo ""
    echo "${OH_BOLD}Convenience Commands:${OH_RESET}"
    echo "  ${OH_GREEN}ohcd${OH_RESET} PROJECT_PATH         CD to project and launch"
    echo "  ${OH_GREEN}oh-version${OH_RESET} VER       Use specific OpenHands version"
    echo "  ${OH_GREEN}oh-save${OH_RESET} [PROJECT_PATH]    Save session state"
    echo "  ${OH_GREEN}oh-refresh-cache${OH_RESET}     Refresh project list cache"
    echo "  ${OH_GREEN}oh-help${OH_RESET}              Show this help"
    echo ""
    echo "${OH_BOLD}Configuration:${OH_RESET}"
    echo "  OPENHANDS_DEFAULT_VERSION     Current: ${OPENHANDS_DEFAULT_VERSION}"
    echo "  OPENHANDS_RUNTIME_VERSION     Current: ${OPENHANDS_RUNTIME_VERSION}"
    echo "  OPENHANDS_PROJECTS_DIR        Current: ${OPENHANDS_PROJECTS_DIR}"
    echo ""
    echo "${OH_BOLD}Config Files:${OH_RESET}"
    echo "  Global: ~/.openhands/config.toml"
    echo "  Project: [project]/.openhands/config.toml"
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
    
    # Include '.' as an option for projects root
    projects=("." ${_OH_PROJECTS_CACHE[@]})
    
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
    
    # Include '.' as an option for projects root
    COMPREPLY=($(compgen -W ". ${_OH_PROJECTS_CACHE[*]}" -- "$cur"))
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
    compdef _oh_complete oh-runtime-logs
    compdef _oh_complete oh-containers
    compdef _oh_complete oh-config-check
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
    complete -F _oh_complete_bash oh-runtime-logs
    complete -F _oh_complete_bash oh-containers
    complete -F _oh_complete_bash oh-config-check
fi 