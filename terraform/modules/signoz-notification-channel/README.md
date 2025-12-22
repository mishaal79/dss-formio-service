# SigNoz Notification Channel Module

Creates notification channels in SigNoz via REST API.

> **Note**: SigNoz Terraform provider doesn't have a native
> `signoz_notification_channel` resource yet. This module uses the `restapi`
> provider as a workaround.

## Usage

```hcl
module "discord_notification_channel" {
  source = "./modules/signoz-notification-channel"

  signoz_url     = "https://dsselectrical.us.signoz.cloud"
  signoz_api_key = var.signoz_api_key

  channel_name   = "discord-alerts"
  webhook_url    = "https://discord-bot.dev.cloud.dsselectrical.com.au/webhook"
  webhook_secret = var.discord_webhook_secret
  environment    = "dev"
}
```

## Manual Setup (Alternative)

If you prefer to create channels manually via API:

```bash
curl -X POST 'https://dsselectrical.us.signoz.cloud/api/v1/channels' \
  -H 'SIGNOZ-API-KEY: YOUR_API_KEY' \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "name": "discord-alerts-dev",
    "webhook_configs": [{
      "send_resolved": true,
      "url": "https://discord-bot.dev.cloud.dsselectrical.com.au/webhook",
      "http_config": {
        "authorization": {
          "type": "Bearer",
          "credentials": "YOUR_WEBHOOK_SECRET"
        }
      }
    }]
  }'
```

## Inputs

| Name           | Description               | Type   | Required           |
| -------------- | ------------------------- | ------ | ------------------ |
| signoz_url     | SigNoz instance URL       | string | yes                |
| signoz_api_key | SigNoz API key            | string | yes                |
| channel_name   | Notification channel name | string | yes                |
| webhook_url    | Webhook endpoint URL      | string | yes                |
| webhook_secret | Bearer token for auth     | string | no                 |
| send_resolved  | Send resolved alerts      | bool   | no (default: true) |
| environment    | Environment name          | string | no (default: dev)  |

## Outputs

| Name         | Description           |
| ------------ | --------------------- |
| channel_id   | ID of created channel |
| channel_name | Full name of channel  |

## Requirements

```hcl
terraform {
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.18"
    }
  }
}
```
