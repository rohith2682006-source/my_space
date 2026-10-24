import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../presentation/widgets/top_alert_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../providers/files_provider.dart';
import '../../providers/spaces_provider.dart';
import 'package:cross_file/cross_file.dart';

class IntentReceiverService {
  static final IntentReceiverService instance =
      IntentReceiverService._internal();
  IntentReceiverService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  bool _isInitialized = false;

  void initialize(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    // For sharing images/files coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            _handleSharedFiles(context, value);
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // For sharing images/files coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      _handleSharedFiles(context, value);
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  void _handleSharedFiles(
    BuildContext context,
    List<SharedMediaFile> sharedFiles,
  ) async {
    if (sharedFiles.isEmpty) return;

    final spacesProvider = Provider.of<SpacesProvider>(context, listen: false);
    final filesProvider = Provider.of<FilesProvider>(context, listen: false);

    // Wait until spaces are loaded
    if (spacesProvider.spaces.isEmpty) {
      await spacesProvider.fetchSpaces();
    }

    if (spacesProvider.spaces.isEmpty) {
      if (context.mounted) {
        TopAlertBar.showSuccess(
          context,
          'No space available to upload shared files.',
        );
      }
      return;
    }

    // Default to the first space if none is selected
    final targetSpaceId = spacesProvider.spaces.first.id;

    if (context.mounted) {
      TopAlertBar.showSuccess(
        context,
        'Uploading ${sharedFiles.length} shared file(s)...',
      );
    }

    final uploadItems = <UploadItem>[];
    for (var sharedFile in sharedFiles) {
      final file = XFile(sharedFile.path);
      try {
        final bytes = await file.readAsBytes();
        final filename = sharedFile.path.split('/').last;
        uploadItems.add(UploadItem(filename: filename, bytes: bytes));
      } catch (e) {
        debugPrint("Failed to read file: $e");
      }
    }

    if (uploadItems.isNotEmpty) {
      final successCount = await filesProvider.uploadMultipleFiles(
        spaceId: targetSpaceId,
        items: uploadItems,
      );

      if (context.mounted) {
        TopAlertBar.showSuccess(
          context,
          'Successfully uploaded $successCount shared file(s).',
        );
      }
    }

    // Clear intent to avoid processing it again
    ReceiveSharingIntent.instance.reset();
  }
}
