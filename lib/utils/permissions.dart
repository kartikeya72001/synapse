import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> requestPhotosAccess() async {
    // Android 13+ uses granular media permissions
    if (await Permission.photos.status.isDenied ||
        await Permission.photos.status.isPermanentlyDenied) {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) return true;
    }

    // Fallback for Android <13
    if (await Permission.storage.status.isDenied) {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;
    }

    // Already granted
    return await Permission.photos.isGranted ||
        await Permission.photos.isLimited ||
        await Permission.storage.isGranted;
  }

  static Future<bool> requestStorageWriteAccess() async {
    if (Platform.isAndroid) {
      final sdkVersion = int.tryParse(
        Platform.version.split('.').first,
      );
      // Android 10+ (API 29) uses scoped storage; no permission needed
      // for app-accessible dirs like Downloads via MediaStore or SAF.
      // For lower versions, request WRITE_EXTERNAL_STORAGE.
      if (sdkVersion != null && sdkVersion < 29) {
        if (await Permission.storage.status.isDenied) {
          final status = await Permission.storage.request();
          return status.isGranted;
        }
        return await Permission.storage.isGranted;
      }
      return true;
    }
    return true;
  }
}
