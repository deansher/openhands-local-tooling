#!/bin/bash
# Helper script to set up a clean testing environment for OpenHands
# This ensures consistent test results by clearing any leftover environment variables

echo "🧹 Setting up clean test environment..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ ERROR: Docker is not running! Please start Docker Desktop first."
    return 1
fi

# Save current projects directory
export OPENHANDS_ORIGINAL_PROJECTS_DIR="${OPENHANDS_PROJECTS_DIR:-~/projects}"

# Unset all OpenHands-related environment variables
echo "Clearing OpenHands environment variables..."
unset OPENHANDS_DEFAULT_VERSION
unset OPENHANDS_RUNTIME_VERSION
unset OPENHANDS_PROJECTS_DIR
unset OPENHANDS_LOG_DIR
unset OPENHANDS_LOG_RETENTION_DAYS
unset LLM_MODEL
unset LLM_API_KEY
unset SEARCH_API_KEY
unset SANDBOX_RUNTIME_CONTAINER_IMAGE
unset SANDBOX_ENABLE_GPU
unset SANDBOX_VOLUMES
unset SANDBOX_USER_ID
unset CORE_MAX_ITERATIONS
unset CORE_MAX_BUDGET_PER_TASK
unset AGENT_ENABLE_CLI
unset AGENT_ENABLE_BROWSING_DELEGATE
unset SECURITY_CONFIRMATION_MODE
unset SECURITY_LEVEL

echo "✅ Environment variables cleared"

# Get the directory where this script is located
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback for zsh or other shells
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# If we're being sourced from the repo root, adjust the path
if [[ "$SCRIPT_DIR" == */openhands_local ]] && [[ -f "$SCRIPT_DIR/shell/openhands.sh" ]]; then
    REPO_ROOT="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../shell/openhands.sh" ]]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    echo "Error: Cannot find openhands.sh. Please run from openhands_local directory."
    return 1
fi

# Re-source the OpenHands shell script
echo "Re-sourcing OpenHands shell script..."
source "$REPO_ROOT/shell/openhands.sh"

# Set test projects directory
export OPENHANDS_PROJECTS_DIR=~/oh-test-projects

echo "✅ Clean test environment ready!"
echo ""
echo "Environment:"
echo "  OPENHANDS_DEFAULT_VERSION: $OPENHANDS_DEFAULT_VERSION"
echo "  OPENHANDS_RUNTIME_VERSION: $OPENHANDS_RUNTIME_VERSION"
echo "  OPENHANDS_PROJECTS_DIR: $OPENHANDS_PROJECTS_DIR"
echo ""
echo "To restore your original environment after testing:"
echo "  export OPENHANDS_PROJECTS_DIR=\"\$OPENHANDS_ORIGINAL_PROJECTS_DIR\""
echo "  source $REPO_ROOT/shell/openhands.sh" 