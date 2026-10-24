import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../../presentation/widgets/update_dialog.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForceUpdate;
  final String currentVersion;

  AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isForceUpdate,
    required this.currentVersion,
  });
}

class AppUpdateService {
  static bool _hasCheckedThisSession = false;

  /// Check for an available update and prompt the user if one is found
  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    // OTA update is specific to Android APK installs
    if (kIsWeb || !Platform.isAndroid) return;
    if (silent && _hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      final response = await ApiClient.get(ApiEndpoints.appVersion);
      if (!response.success || response.data == null) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not check for updates.')),
          );
        }
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final latestVersion = (data['latestVersion'] ?? '1.0.0').toString();
      final latestBuildNumber = (data['latestBuildNumber'] ?? 1) as int;
      final downloadUrl = (data['downloadUrl'] ?? '').toString();
      final releaseNotes = (data['releaseNotes'] ?? 'Bug fixes & enhancements').toString();
      final isForceUpdate = (data['isForceUpdate'] ?? false) as bool;

      // Determine if remote version is newer than installed version
      final isNewer = latestBuildNumber > currentBuildNumber ||
          _compareSemVer(latestVersion, currentVersion) > 0;

      if (isNewer && downloadUrl.isNotEmpty && context.mounted) {
        final updateInfo = AppUpdateInfo(
          latestVersion: latestVersion,
          latestBuildNumber: latestBuildNumber,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          isForceUpdate: isForceUpdate,
          currentVersion: currentVersion,
        );

        showDialog(
          context: context,
          barrierDismissible: !isForceUpdate,
          builder: (ctx) => UpdateDialog(updateInfo: updateInfo),
        );
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spaces is already up to date! (v$currentVersion)'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  /// Execute OTA download and trigger Android PackageInstaller
  static Stream<OtaEvent> runUpdate(String apkUrl) {
    return OtaUpdate().execute(
      apkUrl,
      destinationFilename: 'spaces-update.apk',
    );
  }

  /// Helper to compare two semantic version strings (e.g. "1.0.1" vs "1.0.0")
  static int _compareSemVer(String v1, String v2) {
    try {
      final p1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final p2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (var i = 0; i < 3; i++) {
        final num1 = i < p1.length ? p1[i] : 0;
        final num2 = i < p2.length ? p2[i] : 0;
        if (num1 > num2) return 1;
        if (num1 < num2) return -1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
