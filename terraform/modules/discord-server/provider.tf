# =============================================================================
# DISCORD PROVIDER CONFIGURATION
# =============================================================================
# The Discord provider requires a bot token for authentication.
#
# Setup Instructions:
# 1. Go to https://discord.com/developers/applications
# 2. Click "New Application" → Name it (e.g., "DSS Terraform Bot")
# 3. Go to "Bot" section → Click "Add Bot"
# 4. Enable these Privileged Gateway Intents:
#    - Server Members Intent
#    - Message Content Intent
# 5. Click "Reset Token" and copy the token (this is your DISCORD_TOKEN)
# 6. Go to OAuth2 → URL Generator:
#    - Scopes: bot
#    - Bot Permissions: Administrator (8) or Manage Webhooks + Manage Channels (536870912)
# 7. Copy the generated URL, open in browser, select your server, authorize
#
# Authentication:
# The provider reads the token from DISCORD_TOKEN environment variable.
# Set it via:
#   export DISCORD_TOKEN="your-bot-token-here"
# Or in .envrc (with direnv):
#   export DISCORD_TOKEN="your-bot-token-here"
# =============================================================================

# Provider is configured in the root module or via environment variable
# DISCORD_TOKEN must be set in the environment
