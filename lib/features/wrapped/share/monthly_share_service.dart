import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;
import 'package:url_launcher/url_launcher.dart';
import '../monthly/monthly_wrapped_data.dart';
import 'monthly_share_card.dart';
import 'share_format.dart';

// ==========================================================================
// Service — self-contained for monthly wrapped sharing
// ==========================================================================

/// Captures a [MonthlyWrappedShareCard] and handles all share actions
/// (social apps, generic share sheet, save to gallery).
class MonthlyShareService {
  final _screenshotController = ScreenshotController();

  Future<Uint8List?> captureCard({
    required MonthlyWrappedData data,
    required ShareFormat format,
  }) async {
    final card = MonthlyWrappedShareCard(data: data, format: format);
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  /// Opens the native share sheet with the image.
  Future<void> shareGeneric({
    required Uint8List imageBytes,
    required int year,
    required int month,
    Rect? sharePositionOrigin,
  }) async {
    final file = await _saveTempFile(imageBytes, year, month);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Mon wrapped lecture #Lexsta',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Saves image to temp, opens the target app via URL scheme.
  /// Falls back to native share sheet if the app is not installed.
  /// Returns true if the app was opened, false if fallback was used.
  Future<bool> shareToApp({
    required Uint8List imageBytes,
    required String urlScheme,
    required int year,
    required int month,
    Rect? sharePositionOrigin,
  }) async {
    // Save to temp so it's ready to paste in the target app
    final file = await _saveTempFile(imageBytes, year, month);

    // Try opening the app
    final uri = Uri.parse(urlScheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }

    // App not installed — fallback to native share sheet
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Mon wrapped lecture #Lexsta',
      sharePositionOrigin: sharePositionOrigin,
    );
    return false;
  }

  /// Saves the image to the device photo gallery.
  Future<bool> saveToGallery({
    required Uint8List imageBytes,
    required int year,
    required int month,
  }) async {
    final result = await ImageGallerySaverPlus.saveImage(
      imageBytes,
      name: 'readon_wrapped_${year}_$month',
    );
    return result != null && (result['isSuccess'] == true);
  }

  Future<File> _saveTempFile(Uint8List bytes, int year, int month) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/readon_wrapped_${year}_$month.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}
