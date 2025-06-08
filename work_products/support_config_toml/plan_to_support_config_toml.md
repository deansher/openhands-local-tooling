# Specification: Add config.toml Support to OpenHands Local Tooling

## Overview
Enhance the OpenHands local tooling to support reading configuration from TOML files and converting them to Docker environment variables. This will allow users to maintain persistent configuration without repeatedly specifying environment variables.

## Goals
1. Support both global and project-specific configuration files
2. Maintain backward compatibility with existing environment variable approach
3. Follow OpenHands' configuration structure and naming conventions
4. Provide secure handling of sensitive data (API keys)
5. Allow environment variables to override config file values

## Configuration File Locations

### Priority Order (highest to lowest)
1. Environment variables (existing behavior)
2. Project-specific config: `~/projects/[project-path]/.openhands/config.toml`
3. User global config: `~/.openhands/config.toml`
4. System default: `/etc/openhands/config.toml` (optional)

## Implementation Requirements

### 1. TOML Parser Selection
- Use a lightweight TOML parser that works across macOS and Linux
- Options:
  - Python's `toml` module (most reliable, requires Python)
  - `toml-cli` if available
  - `yq` with TOML support
- Implement fallback if parser not available (skip config file support with warning)

### 2. Configuration Structure
Follow OpenHands' config.template.toml structure:

```toml
# ~/.openhands/config.toml or [project]/.openhands/config.toml

[llm]
model = "anthropic/claude-sonnet-4-20250514"
api_key = "sk-..."
search_api_key = "tvly-..."  # Tavily API key
num_retries = 4
retry_min_wait = 5
retry_max_wait = 30
timeout = 300
temperature = 0.0
top_p = 1.0
max_input_tokens = 30000
max_output_tokens = 5000
disable_vision = false

[sandbox]
runtime_container_image = "docker.all-hands.dev/all-hands-ai/runtime:0.41-nikolaik"
enable_gpu = false
volumes = "/additional/path:/workspace/extra:rw"
user_id = 1000

[core]
max_iterations = 250
max_budget_per_task = 0.0

[agent]
enable_cli = false
enable_browsing_delegate = false

[security]
confirmation_mode = "disabled"
security_level = "standard"
```

### 3. Environment Variable Mapping

Create a mapping function that converts TOML keys to Docker environment variables:

```
[llm]
model → LLM_MODEL
api_key → LLM_API_KEY
search_api_key → SEARCH_API_KEY (special case for Tavily)
num_retries → LLM_NUM_RETRIES
retry_min_wait → LLM_RETRY_MIN_WAIT
retry_max_wait → LLM_RETRY_MAX_WAIT
timeout → LLM_TIMEOUT
temperature → LLM_TEMPERATURE
top_p → LLM_TOP_P
max_input_tokens → LLM_MAX_INPUT_TOKENS
max_output_tokens → LLM_MAX_OUTPUT_TOKENS
disable_vision → LLM_DISABLE_VISION

[sandbox]
runtime_container_image → SANDBOX_RUNTIME_CONTAINER_IMAGE
enable_gpu → SANDBOX_ENABLE_GPU
volumes → SANDBOX_VOLUMES
user_id → SANDBOX_USER_ID

[core]
max_iterations → CORE_MAX_ITERATIONS
max_budget_per_task → CORE_MAX_BUDGET_PER_TASK

[agent]
enable_cli → AGENT_ENABLE_CLI
enable_browsing_delegate → AGENT_ENABLE_BROWSING_DELEGATE

[security]
confirmation_mode → SECURITY_CONFIRMATION_MODE
security_level → SECURITY_LEVEL
```

### 4. Integration Points

#### A. Modify `oh` function
- Before building Docker command, call new `load_openhands_config` function
- Pass project path to check for project-specific config
- Apply loaded configuration as environment variables

#### B. Create new functions in openhands.sh:

```bash
# Check if TOML parser is available
_oh_check_toml_parser() {
    # Returns 0 if parser available, 1 if not
    # Sets OH_TOML_PARSER to the parser command
}

# Load configuration from TOML files
load_openhands_config() {
    local project_path="$1"
    # Load in priority order
    # Set environment variables for Docker
}

# Parse TOML file and export variables
_oh_parse_toml_file() {
    local config_file="$1"
    # Parse and export as environment variables
}

# Security check for config files
_oh_check_config_permissions() {
    local config_file="$1"
    # Warn if permissions too open (contains API keys)
}
```

### 5. Security Requirements

1. Check file permissions:
   - Warn if config.toml is world-readable (chmod 644 or higher)
   - Recommend `chmod 600 ~/.openhands/config.toml`
   
2. Never log API keys:
   - Mask sensitive values in debug output
   - Show only first/last 4 characters: `sk-abcd...wxyz`

### 6. New Commands

Add these commands to the tooling:

```bash
oh-config-init [--global|--project]
# Create a template config.toml with comments

oh-config-check [PROJECT_PATH]
# Validate config file and show what would be loaded

oh-config-edit [--global|--project] [PROJECT_PATH]
# Open config in $EDITOR
```

### 7. User Experience Enhancements

1. **First Run Experience**:
   - If no config exists and no LLM_API_KEY set, prompt to create config
   - Offer to run `oh-config-init --global`

2. **Status Display**:
   - Modify `oh-list` to show config source (ENV/Global/Project)
   - Add indicator if using config file vs env vars

3. **Debug Support**:
   - Add `--show-config` flag to `oh` to display resolved configuration
   - Show which config file is being used

### 8. Testing Requirements

Add to the existing test protocol:

1. **Config File Tests**:
   - Test with no config file (existing behavior)
   - Test with global config only
   - Test with project config only
   - Test with both (project should override global)
   - Test environment override of config values

2. **Security Tests**:
   - Test permission warnings
   - Test API key masking in debug output

3. **Parser Fallback Tests**:
   - Test behavior when TOML parser not available

### 9. Documentation Updates

1. Update README.md:
   - Add "Configuration" section after "Environment Variables"
   - Document config file locations and precedence
   - Provide example config.toml
   - Add security best practices

2. Add CONFIG.md:
   - Detailed configuration reference
   - All supported TOML keys
   - Mapping to environment variables
   - Examples for common scenarios

### 10. Implementation Notes

1. **Backward Compatibility**:
   - All existing environment variable behavior must continue working
   - Config files are optional enhancement

2. **Performance**:
   - Cache parsed config for session (avoid re-parsing)
   - Only parse when `oh` commands run, not on shell startup

3. **Error Handling**:
   - Invalid TOML should show clear error with line number
   - Missing parser should gracefully fall back to env vars
   - File permission issues should warn but not block

4. **Special Cases**:
   - Handle arrays/lists in TOML (e.g., multiple volume mounts)
   - Handle boolean values correctly
   - Support comments in config files

### 11. Future Considerations

Structure the implementation to support future enhancements:
- Config file validation against schema
- Migration tool for config format changes
- Integration with OpenHands' config management
- Encrypted storage for sensitive values

