import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _textRecognizer = TextRecognizer();

  Future<String?> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final blocks = recognizedText.blocks;
      if (blocks.isEmpty) return null;

      final text = blocks
          .map((block) => block.text)
          .where((t) => t.isNotEmpty)
          .join('\n');

      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
