/// Result class for element detection
class DetectionResult {
  final String status;
  final int? x;
  final int? y;
  final String? screenshotDescription;
  final double? confidence;
  final Map<String, int>? imageSize;
  final String? errorMessage;

  DetectionResult({
    required this.status,
    this.x,
    this.y,
    this.screenshotDescription,
    this.confidence,
    this.imageSize,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'x': x,
      'y': y,
      'screenshot_description': screenshotDescription,
      'confidence': confidence,
      'image_size': imageSize,
      'error_message': errorMessage,
    };
  }
}
