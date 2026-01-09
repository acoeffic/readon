// lib/services/ocr_service.dart

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extract page number from an image
  /// Returns null if no page number could be detected
  Future<int?> extractPageNumber(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Find page number using multiple strategies
      int? pageNumber = _findPageNumber(recognizedText);
      
      return pageNumber;
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  /// Intelligent page number detection
  int? _findPageNumber(RecognizedText text) {
    List<int> candidates = [];
    
    for (TextBlock block in text.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text.trim();
        
        // Strategy 1: Standalone number (most common for page numbers)
        if (RegExp(r'^\d+$').hasMatch(lineText)) {
          int? number = int.tryParse(lineText);
          if (number != null) {
            candidates.add(number);
          }
        }
        
        // Strategy 2: "Page XXX" or "p. XXX" or "p XXX"
        RegExp pagePattern = RegExp(
          r'(?:page|p\.?)\s*(\d+)',
          caseSensitive: false,
        );
        Match? match = pagePattern.firstMatch(lineText);
        if (match != null) {
          int? number = int.tryParse(match.group(1)!);
          if (number != null) {
            candidates.add(number);
          }
        }
        
        // Strategy 3: "XXX |" or "| XXX" (common page number formats)
        RegExp pipePattern = RegExp(r'(\d+)\s*\||\|\s*(\d+)');
        Match? pipeMatch = pipePattern.firstMatch(lineText);
        if (pipeMatch != null) {
          String? numberStr = pipeMatch.group(1) ?? pipeMatch.group(2);
          if (numberStr != null) {
            int? number = int.tryParse(numberStr);
            if (number != null) {
              candidates.add(number);
            }
          }
        }
        
        // Strategy 4: "- XXX -" (centered page numbers)
        RegExp dashPattern = RegExp(r'-\s*(\d+)\s*-');
        Match? dashMatch = dashPattern.firstMatch(lineText);
        if (dashMatch != null) {
          int? number = int.tryParse(dashMatch.group(1)!);
          if (number != null) {
            candidates.add(number);
          }
        }
      }
    }
    
    // Filter out invalid candidates
    candidates = candidates.where((n) {
      // Page numbers are typically between 1 and 9999
      return n > 0 && n < 10000;
    }).toList();
    
    // Remove duplicates
    candidates = candidates.toSet().toList();
    
    if (candidates.isEmpty) return null;
    
    // Heuristic: Take the smallest number
    // (page numbers are usually smaller than dates, ISBNs, etc.)
    candidates.sort();
    
    // If we have multiple candidates, prefer numbers under 1000
    // as they're more likely to be page numbers
    List<int> preferredCandidates = candidates.where((n) => n < 1000).toList();
    if (preferredCandidates.isNotEmpty) {
      return preferredCandidates.first;
    }
    
    return candidates.first;
  }

  /// Get all detected text for debugging
  Future<String> extractAllText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      return recognizedText.text;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Get detailed text blocks for advanced debugging
  Future<List<Map<String, dynamic>>> extractTextBlocks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      List<Map<String, dynamic>> blocks = [];
      
      for (TextBlock block in recognizedText.blocks) {
        blocks.add({
          'text': block.text,
          'rect': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
          'lines': block.lines.map((line) => line.text).toList(),
        });
      }
      
      return blocks;
    } catch (e) {
      print('Error extracting text blocks: $e');
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
