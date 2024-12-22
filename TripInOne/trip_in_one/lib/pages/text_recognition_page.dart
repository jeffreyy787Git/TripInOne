import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';

class TextRecognitionPage extends StatefulWidget {
  const TextRecognitionPage({super.key});

  @override
  State<TextRecognitionPage> createState() => _TextRecognitionPageState();
}

class _TextRecognitionPageState extends State<TextRecognitionPage> {
  File? _image;
  String _extractedText = '';
  String _translatedText = '';
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();
  final textDetector = GoogleMlKit.vision.textRecognizer();
  final translator = GoogleTranslator();

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _image = File(image.path);
        _isProcessing = true;
        _extractedText = '';
        _translatedText = '';
      });

      final inputImage = InputImage.fromFilePath(_image!.path);
      final recognizedText = await textDetector.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text detected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      try {
        setState(() {
          _extractedText = recognizedText.text;
        });

        final translation = await translator.translate(
          recognizedText.text,
          from: 'auto',
          to: 'zh-tw',
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('translation timeout');
          },
        );

        if (mounted) {
          setState(() {
            _translatedText = translation.text;
            _isProcessing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Translation error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {
            _translatedText = 'Translation failed, please try again';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing image error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition & Translation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select from Gallery'),
                  ),
                ),
              ],
            ),
            if (_image != null) ...[
              const SizedBox(height: 16),
              Image.file(_image!),
            ],
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_extractedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Recognized Text:', 
                style: TextStyle(fontWeight: FontWeight.bold)),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_extractedText),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Translation:', 
                style: TextStyle(fontWeight: FontWeight.bold)),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_translatedText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    textDetector.close();
    super.dispose();
  }
} 