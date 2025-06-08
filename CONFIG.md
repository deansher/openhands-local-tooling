# OpenHands Local Tooling Configuration Reference

This document provides a comprehensive reference for configuring OpenHands Local Tooling using TOML configuration files.

## Configuration File Locations

Configuration files are loaded in the following priority order (later files override earlier ones):

1. **System Config**: `/etc/openhands/config.toml` (optional)
   - For system-wide defaults
   - Useful for shared machines or organizations

2. **Global Config**: `~/.openhands/config.toml`
   - Your personal default configuration
   - Applies to all projects unless overridden

3. **Project Config**: `[project]/.openhands/config.toml`
   - Project-specific settings
   - Overrides global configuration for that project

## Quick Start

```bash
# Create a global configuration file
oh-config-init --global

# Edit your configuration
oh-config-edit --global

# Validate your configuration
oh-config-check
```

## Configuration Sections

### [llm] - Language Model Configuration

Configure the AI model and its parameters.

```toml
[llm]
# The model to use (required for AI features)
model = "anthropic/claude-sonnet-4-20250514"

# API key for your LLM provider
api_key = "sk-ant-..."

# Tavily API key for web search capabilities
search_api_key = "tvly-..."

# Retry configuration for API calls
num_retries = 4              # Number of retries on failure
retry_min_wait = 5           # Minimum wait between retries (seconds)
retry_max_wait = 30          # Maximum wait between retries (seconds)
timeout = 300                # Request timeout (seconds)

# Model parameters
temperature = 0.0            # Randomness (0.0 = deterministic, 2.0 = very random)
top_p = 1.0                 # Nucleus sampling threshold
max_input_tokens = 30000    # Maximum input context size
max_output_tokens = 5000    # Maximum response size

# Feature flags
disable_vision = false       # Disable image understanding capabilities
```

### [sandbox] - Execution Environment Configuration

Configure the sandboxed environment where code runs.

```toml
[sandbox]
# Docker image for the runtime environment
runtime_container_image = "docker.all-hands.dev/all-hands-ai/runtime:0.41-nikolaik"

# Enable GPU support (requires nvidia-docker)
enable_gpu = false

# Additional volumes to mount (comma-separated)
# Format: "host_path:container_path:mode"
volumes = "/data/shared:/workspace/shared:ro,/home/user/models:/workspace/models:rw"

# User ID for file permissions (defaults to current user)
user_id = 1000
```

### [core] - Core Behavior Configuration

Control OpenHands' execution behavior.

```toml
[core]
# Maximum iterations before stopping (prevents infinite loops)
max_iterations = 250

# Maximum budget per task in USD (0.0 = unlimited)
# Useful for controlling API costs
max_budget_per_task = 5.0
```

### [agent] - Agent Feature Configuration

Enable or disable specific agent capabilities.

```toml
[agent]
# Enable command-line interface mode
enable_cli = false

# Enable web browsing capabilities
enable_browsing_delegate = true
```

### [security] - Security Settings

Configure security and safety features.

```toml
[security]
# Confirmation mode for potentially dangerous operations
# Options: "disabled", "enabled"
confirmation_mode = "disabled"

# Overall security level
# Options: "standard", "strict"
security_level = "standard"
```

## Environment Variable Mapping

Each TOML configuration value maps to an environment variable that gets passed to the Docker container:

| TOML Path | Environment Variable |
|-----------|---------------------|
| `llm.model` | `LLM_MODEL` |
| `llm.api_key` | `LLM_API_KEY` |
| `llm.search_api_key` | `SEARCH_API_KEY` |
| `llm.num_retries` | `LLM_NUM_RETRIES` |
| `llm.retry_min_wait` | `LLM_RETRY_MIN_WAIT` |
| `llm.retry_max_wait` | `LLM_RETRY_MAX_WAIT` |
| `llm.timeout` | `LLM_TIMEOUT` |
| `llm.temperature` | `LLM_TEMPERATURE` |
| `llm.top_p` | `LLM_TOP_P` |
| `llm.max_input_tokens` | `LLM_MAX_INPUT_TOKENS` |
| `llm.max_output_tokens` | `LLM_MAX_OUTPUT_TOKENS` |
| `llm.disable_vision` | `LLM_DISABLE_VISION` |
| `sandbox.runtime_container_image` | `SANDBOX_RUNTIME_CONTAINER_IMAGE` |
| `sandbox.enable_gpu` | `SANDBOX_ENABLE_GPU` |
| `sandbox.volumes` | `SANDBOX_VOLUMES` |
| `sandbox.user_id` | `SANDBOX_USER_ID` |
| `core.max_iterations` | `CORE_MAX_ITERATIONS` |
| `core.max_budget_per_task` | `CORE_MAX_BUDGET_PER_TASK` |
| `agent.enable_cli` | `AGENT_ENABLE_CLI` |
| `agent.enable_browsing_delegate` | `AGENT_ENABLE_BROWSING_DELEGATE` |
| `security.confirmation_mode` | `SECURITY_CONFIRMATION_MODE` |
| `security.security_level` | `SECURITY_LEVEL` |

## Common Scenarios

### Personal Development Setup

Create `~/.openhands/config.toml`:

```toml
[llm]
model = "anthropic/claude-sonnet-4-20250514"
api_key = "sk-ant-..."
temperature = 0.0

[core]
max_iterations = 300
max_budget_per_task = 10.0
```

### Project with Custom Runtime

Create `~/projects/myapp/.openhands/config.toml`:

```toml
[sandbox]
# Use a custom runtime with your project's dependencies pre-installed
runtime_container_image = "mycompany/openhands-runtime:latest"

# Mount additional resources
volumes = "/home/user/data:/workspace/data:ro"

[core]
# This project needs more iterations for complex tasks
max_iterations = 500
```

### GPU-Enabled Machine Learning Project

```toml
[llm]
model = "openai/gpt-4"
api_key = "sk-..."

[sandbox]
enable_gpu = true
runtime_container_image = "docker.all-hands.dev/all-hands-ai/runtime:0.41-nikolaik"
volumes = "/data/models:/workspace/models:ro,/data/datasets:/workspace/datasets:ro"
```

### Cost-Controlled Configuration

```toml
[llm]
model = "openai/gpt-3.5-turbo"  # Cheaper model
max_output_tokens = 2000        # Limit response size

[core]
max_budget_per_task = 1.0       # $1 limit per task
max_iterations = 100            # Fewer iterations
```

## Security Best Practices

1. **File Permissions**: Always set restrictive permissions on config files containing API keys:
   ```bash
   chmod 600 ~/.openhands/config.toml
   ```

2. **API Key Storage**: Consider using environment variables for API keys instead of storing them in config files:
   ```bash
   # In your shell configuration
   export LLM_API_KEY="sk-..."
   ```
   Then omit the `api_key` from your config file.

3. **Project Configs**: Be cautious about committing project config files to version control if they contain sensitive data.

4. **Validation**: Always run `oh-config-check` after making changes to ensure your configuration is valid.

## Troubleshooting

### TOML Parser Not Found

If you see "No TOML parser available", install the Python toml module:

```bash
pip install toml
# or
pip3 install toml
```

### Configuration Not Loading

1. Check file permissions:
   ```bash
   ls -la ~/.openhands/config.toml
   ```

2. Validate TOML syntax:
   ```bash
   python3 -c "import toml; toml.load('$HOME/.openhands/config.toml')"
   ```

3. Run config check:
   ```bash
   oh-config-check
   ```

### Environment Variables Not Set

Environment variables from config files are only set when launching OpenHands with `oh`. They don't persist in your shell. To see what would be set:

```bash
oh-config-check [project]
```

## Advanced Features

### Dynamic Configuration

You can use shell scripts to generate configuration dynamically:

```bash
#!/bin/bash
# generate-config.sh
cat > .openhands/config.toml << EOF
[llm]
model = "${MODEL:-anthropic/claude-sonnet-4-20250514}"
api_key = "$(pass show openai/api-key)"  # Using password manager
EOF
```

### Multiple Profiles

While not directly supported, you can achieve multiple profiles using symlinks:

```bash
# Create profile configs
mkdir ~/.openhands/profiles
vim ~/.openhands/profiles/dev.toml
vim ~/.openhands/profiles/prod.toml

# Switch profiles
ln -sf ~/.openhands/profiles/dev.toml ~/.openhands/config.toml
```

## Migration from Environment Variables

If you're currently using environment variables, here's how to migrate:

1. Create a config file:
   ```bash
   oh-config-init --global
   ```

2. Transfer your environment variables to the config file:
   ```bash
   # If you have: export LLM_MODEL="anthropic/claude-sonnet-4-20250514"
   # Add to config.toml:
   # [llm]
   # model = "anthropic/claude-sonnet-4-20250514"
   ```

3. Remove the environment variables from your shell configuration

4. Test the configuration:
   ```bash
   oh-config-check
   ```

## Future Enhancements

The configuration system is designed to support future enhancements:

- Schema validation
- Encrypted storage for sensitive values
- Configuration profiles
- Remote configuration sources
- Hot-reloading of configuration changes

For the latest updates and features, check the project repository.