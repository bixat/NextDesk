# Qwen Vision API Integration

This document explains how to use the Qwen Vision API as an alternative to Gemini for UI element detection.

## Overview

The application now supports two vision providers:
- **Gemini Vision API** (default) - Google's Gemini 2.5 Flash model
- **Qwen Vision API** - Alibaba Cloud's Qwen 2.5 VL 72B Instruct model

## Configuration

### 1. Get Your Qwen API Key

1. Visit [Dashscope Console](https://dashscope.console.aliyun.com/)
2. Sign up or log in to your account
3. Navigate to API Keys section
4. Create a new API key or copy an existing one

### 2. Update Configuration

Edit `lib/config/app_config.dart`:

```dart
class AppConfig {
  // ... other config ...
  
  /// Qwen API Key (Dashscope)
  static const String qwenApiKey = 'sk-your-actual-api-key-here';
  
  /// Vision provider: 'gemini' or 'qwen'
  static const String visionProvider = 'qwen';  // Change to 'qwen'
}
```

## How It Works

### Qwen Vision API Implementation

The Qwen integration follows the OpenAI-compatible API format provided by Dashscope:

```dart
// Endpoint
https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions

// Model
qwen2.5-vl-72b-instruct

// Request Format
{
  "model": "qwen2.5-vl-72b-instruct",
  "messages": [
    {
      "role": "system",
      "content": [{"type": "text", "text": "System instruction..."}]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "image_url",
          "min_pixels": 1505280,  // (1920/2) * 28 * 28
          "max_pixels": 12042240, // (1920*2) * 28 * 28
          "image_url": {"url": "data:image/png;base64,<base64_image>"}
        },
        {"type": "text", "text": "Locate the center of..."}
      ]
    }
  ],
  "response_format": {"type": "json_object"}
}
```

### Response Format

The Qwen API returns coordinates in JSON format:

```json
{
  "x": 123,
  "y": 456,
  "confidence": 0.95,
  "image_size": {
    "width": 1920,
    "height": 1080
  }
}
```

## Features

### Qwen-Specific Features

1. **Configurable Image Resolution**
   - `min_pixels`: Minimum pixels for image processing (default: 1505280)
   - `max_pixels`: Maximum pixels for image processing (default: 12042240)
   - These values are optimized for typical desktop resolutions (1920x1080)

2. **JSON Response Format**
   - Enforced JSON output via `response_format` parameter
   - More reliable parsing compared to markdown-wrapped responses

3. **Image Size Detection**
   - Returns the detected image dimensions
   - Useful for validation and debugging

4. **Confidence Scores**
   - Returns confidence level for each detection
   - Helps assess detection reliability

## Usage Example

The vision service automatically uses the configured provider:

```dart
import 'package:desktop_agent/services/vision_service.dart';
import 'dart:typed_data';

// Capture or load screenshot
Uint8List imageBytes = await captureScreenshot();

// Detect element (automatically uses Qwen if configured)
final result = await VisionService.detectElementPosition(
  imageBytes,
  'video recording icon',
);

if (result.status == 'success') {
  print('Element found at: (${result.x}, ${result.y})');
  print('Confidence: ${result.confidence}');
  print('Image size: ${result.imageSize}');
} else {
  print('Error: ${result.errorMessage}');
}
```

## Switching Between Providers

To switch between Gemini and Qwen, simply change the `visionProvider` in `app_config.dart`:

```dart
// Use Gemini
static const String visionProvider = 'gemini';

// Use Qwen
static const String visionProvider = 'qwen';
```

No code changes are required - the `VisionService` automatically routes to the correct implementation.

## Comparison: Gemini vs Qwen

| Feature | Gemini | Qwen |
|---------|--------|------|
| Model | Gemini 2.5 Flash | Qwen 2.5 VL 72B |
| Response Format | Text (may include markdown) | Enforced JSON |
| Image Size Info | No | Yes |
| Confidence Score | Default (0.9) | Returned by API |
| Resolution Control | No | Yes (min/max pixels) |
| API Format | Google AI | OpenAI-compatible |

## Troubleshooting

### Common Issues

1. **API Key Error**
   - Ensure your Qwen API key is correctly set in `app_config.dart`
   - Verify the key is active in Dashscope console

2. **Invalid JSON Response**
   - Check if the API is returning proper JSON
   - Review error message in `DetectionResult.errorMessage`

3. **Element Not Found**
   - Try more descriptive element descriptions
   - Ensure the screenshot contains the element
   - Check if coordinates are null in the response

4. **Rate Limiting**
   - Qwen API has rate limits based on your account tier
   - Implement retry logic if needed

### Debug Mode

To see detailed API responses, check the error messages:

```dart
final result = await VisionService.detectElementPosition(imageBytes, description);
if (result.status == 'error') {
  print('Error details: ${result.errorMessage}');
}
```

## Performance Considerations

- **Image Size**: Larger images take longer to process. The app automatically resizes screenshots to 1/3 of original size.
- **API Latency**: Qwen API typically responds in 2-5 seconds depending on image complexity.
- **Cost**: Monitor your Dashscope usage to avoid unexpected charges.

## Original Python Script Reference

The Dart implementation is based on this Python script:

```python
from openai import OpenAI
import base64

client = OpenAI(
    api_key="sk-your-key",
    base_url="https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
)

base64_image = base64.b64encode(image_bytes).decode("utf-8")

response = client.chat.completions.create(
    model="qwen2.5-vl-72b-instruct",
    messages=[...],
    response_format={"type": "json_object"}
)
```

## Next Steps

1. Test the integration with your Qwen API key
2. Compare results between Gemini and Qwen for your use case
3. Choose the provider that works best for your needs
4. Consider implementing fallback logic to try both providers

## Support

For issues specific to:
- **Qwen API**: Visit [Dashscope Documentation](https://help.aliyun.com/zh/dashscope/)
- **This Integration**: Open an issue in the project repository

