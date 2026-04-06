# Holo3 Vision Model Integration for NextDesk

This document describes the integration of the HCompany Holo3 vision model with NextDesk via direct API access.

## Overview

Since OpenRouter does not support the Holo3 model, NextDesk now connects directly to HCompany's API for vision tasks when using Holo3.

## Architecture

```
┌─────────────────┐
│   NextDesk App  │
│                 │
│  VisionService  │──────┐
│                 │      │
└─────────────────┘      │
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│  Holo3Vision    │           │  OpenRouter     │
│  Service        │           │  Service        │
│                 │           │                 │
│ Direct HCompany │           │ Other Models    │
│ API Call        │           │ (Gemini, GPT)   │
└────────┬────────┘           └─────────────────┘
         │
         ▼
┌─────────────────┐
│  HCompany API   │
│  api.hcompany.ai│
│  /v1/chat/      │
│  completions    │
└─────────────────┘
```

## Configuration

### Environment Variables

Set these environment variables before running NextDesk:

```bash
# Required for Holo3 vision model
export HCOMPANY_API_KEY="your-hcompany-api-key"

# Optional: For other models via OpenRouter
export OPENROUTER_API_KEY="your-openrouter-api-key"

# Optional: Specify vision model (default: hcompany/holo3-35b-a3b)
export VISION_MODEL="hcompany/holo3-35b-a3b"

# Optional: Specify chat model (default: google/gemini-3-flash-preview)
export CHAT_MODEL="google/gemini-3-flash-preview"
```

### Getting HCompany API Key

1. Visit [https://hub.hcompany.ai/](https://hub.hcompany.ai/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Generate a new API key
5. Copy and store securely

## Files Modified/Created

### New Files
- `lib/services/holo3_vision_service.dart` - Dedicated service for HCompany Holo3 API calls

### Modified Files
- `lib/config/app_config.dart` - Added HCOMPANY_API_KEY configuration
- `lib/services/config_service.dart` - Added HCompany API key management
- `lib/services/vision_service.dart` - Updated to route Holo3 requests to direct API
- `lib/screens/settings_screen.dart` - Added UI for HCompany API key configuration

## Usage

### Automatic Model Selection

The `VisionService` automatically selects the appropriate backend:

```dart
// When vision model contains 'hcompany' or 'holo3', uses direct HCompany API
final result = await VisionService.detectElementPosition(
  imageBytes,
  "Find the submit button",
  configService,
);
```

### Model Options

**Vision Models:**
- `hcompany/holo3-35b-a3b` - Holo3 (uses direct HCompany API)
- `google/gemini-3-pro-preview` - Gemini 3 Pro (uses OpenRouter)
- `openai/gpt-4o` - GPT-4o (uses OpenRouter)
- `anthropic/claude-3.5-sonnet` - Claude 3.5 Sonnet (uses OpenRouter)

**Chat Models:**
- `google/gemini-3-flash-preview` - Default
- `google/gemini-2.5-pro`
- `openai/gpt-4o-mini`
- `anthropic/claude-3.5-sonnet`

## API Endpoints

### HCompany Holo3 API
- **Base URL:** `https://api.hcompany.ai/v1/chat/completions`
- **Model:** `holo3-35b-a3b`
- **Authentication:** Bearer token via `Authorization` header
- **Format:** OpenAI-compatible Chat Completions API

### Request Format

```json
{
  "model": "holo3-35b-a3b",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Analyze the provided screenshot..."
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,<base64-encoded-image>"
          }
        }
      ]
    }
  ]
}
```

### Response Format

```json
{
  "choices": [
    {
      "message": {
        "content": "{\"x\": 100, \"y\": 200, \"confidence\": 0.95, ...}"
      }
    }
  ]
}
```

## Error Handling

The integration includes comprehensive error handling:

1. **Missing API Key:** Returns error if HCompany API key is not configured
2. **API Failures:** Captures HTTP status codes and response bodies
3. **Invalid JSON:** Handles malformed responses gracefully
4. **Network Errors:** Catches connection timeouts and failures

All errors return a `DetectionResult` with `status: "error"` and descriptive `errorMessage`.

## Testing

To test the Holo3 integration:

1. Configure your HCompany API key in Settings or via environment variable
2. Select `hcompany/holo3-35b-a3b` as the vision model
3. Run a task that requires element detection
4. Monitor logs for API calls to `api.hcompany.ai`

## Migration from OpenRouter

If you were previously using a different vision model:

1. Update `VISION_MODEL` environment variable to `hcompany/holo3-35b-a3b`
2. Set `HCOMPANY_API_KEY` with your HCompany credentials
3. The app will automatically use the direct HCompany API

No code changes required - the routing is handled automatically by `VisionService`.

## Security Best Practices

- Never commit API keys to version control
- Use environment variables in production
- Rotate API keys periodically
- Monitor API usage through HCompany dashboard
- Implement rate limiting if needed

## References

- [HCompany Hub](https://hub.hcompany.ai/)
- [HCompany Quickstart](https://hub.hcompany.ai/quickstart)
- [OpenRouter API Reference](https://openrouter.ai/docs/api/reference/overview)
