// lib/services/ocr_service.dart

import 'package:flutter/foundation.dart';
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
      debugPrint('OCR Error: $e');
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

  /// Extract ISBN from image (book cover or barcode area)
  /// Returns ISBN-13 or ISBN-10 if found
  Future<String?> extractISBN(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // ISBN patterns
      // ISBN-13: 978 or 979 followed by 10 digits (with optional hyphens/spaces)
      // ISBN-10: 10 digits or 9 digits + X (with optional hyphens/spaces)

      final RegExp isbn13Pattern = RegExp(
        r'(?:ISBN[:\-]?\s*)?(?:97[89])[\-\s]?\d[\-\s]?\d{2}[\-\s]?\d{5,6}[\-\s]?\d',
        caseSensitive: false,
      );

      final RegExp isbn10Pattern = RegExp(
        r'(?:ISBN[:\-]?\s*)?\d[\-\s]?\d{2}[\-\s]?\d{5,6}[\-\s]?[\dXx]',
        caseSensitive: false,
      );

      // Also match pure digit sequences that look like ISBNs
      final RegExp pureIsbn13 = RegExp(r'97[89]\d{10}');
      final RegExp pureIsbn10 = RegExp(r'\d{9}[\dXx]');

      String fullText = recognizedText.text;

      // Try ISBN-13 first (preferred)
      Match? match = isbn13Pattern.firstMatch(fullText);
      if (match != null) {
        String isbn = _cleanISBN(match.group(0)!);
        if (_isValidISBN13(isbn)) {
          return isbn;
        }
      }

      // Try pure ISBN-13
      match = pureIsbn13.firstMatch(fullText.replaceAll(RegExp(r'[\s\-]'), ''));
      if (match != null) {
        String isbn = match.group(0)!;
        if (_isValidISBN13(isbn)) {
          return isbn;
        }
      }

      // Try ISBN-10
      match = isbn10Pattern.firstMatch(fullText);
      if (match != null) {
        String isbn = _cleanISBN(match.group(0)!);
        if (_isValidISBN10(isbn)) {
          return isbn;
        }
      }

      // Try pure ISBN-10
      match = pureIsbn10.firstMatch(fullText.replaceAll(RegExp(r'[\s\-]'), ''));
      if (match != null) {
        String isbn = match.group(0)!;
        if (_isValidISBN10(isbn)) {
          return isbn;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting ISBN: $e');
      return null;
    }
  }

  /// Clean ISBN string (remove ISBN prefix, hyphens, spaces)
  String _cleanISBN(String isbn) {
    return isbn
        .toUpperCase()
        .replaceAll(RegExp(r'ISBN[:\-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s\-]'), '');
  }

  /// Validate ISBN-13 checksum
  bool _isValidISBN13(String isbn) {
    if (isbn.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(isbn)) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(isbn[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(isbn[12]);
  }

  /// Validate ISBN-10 checksum
  bool _isValidISBN10(String isbn) {
    if (isbn.length != 10) return false;
    if (!RegExp(r'^\d{9}[\dXx]$').hasMatch(isbn)) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(isbn[i]) * (10 - i);
    }
    int lastDigit = isbn[9].toUpperCase() == 'X' ? 10 : int.parse(isbn[9]);
    sum += lastDigit;

    return sum % 11 == 0;
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
      debugPrint('Error extracting text blocks: $e');
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
