import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf_reader/models/pdf_history.dart';
import 'package:pdf_reader/services/pdf_history_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  // Create a temporary directory for the test
  late Directory testDir;
  late Directory documentsDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('pdf_test_');
    documentsDir = Directory('${testDir.path}/documents');
    await documentsDir.create();

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          return null;
        });

    // Initialize Hive for testing
    Hive.init(testDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PdfHistoryAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (testDir.existsSync()) {
      await testDir.delete(recursive: true);
    }
  });

  test(
    'PdfHistoryService copies file to local storage and persists it',
    () async {
      // 1. Create a dummy PDF file in a "download" location
      final downloadDir = Directory('${testDir.path}/downloads');
      await downloadDir.create();
      final originalFile = File('${downloadDir.path}/test.pdf');
      await originalFile.writeAsString('dummy pdf content');

      // 2. Add to history
      // We need to call init() to setup the box
      await PdfHistoryService.init();
      await PdfHistoryService.addToHistory(originalFile.path);

      // 3. Verify entry exists
      final history = PdfHistoryService.getAllHistory();
      expect(history.length, 1);
      final entry = history.first;
      expect(entry.filePath, originalFile.path);
      expect(entry.localPath, isNotNull);

      // 4. Verify local file exists
      final localFile = File(entry.localPath!);
      expect(localFile.existsSync(), isTrue);
      expect(await localFile.readAsString(), 'dummy pdf content');

      // 5. Delete original file
      await originalFile.delete();
      expect(originalFile.existsSync(), isFalse);

      // 6. Verify "cleanInvalidEntries" doesn't remove it because local copy exists
      await PdfHistoryService.cleanInvalidEntries();
      final historyAfterClean = PdfHistoryService.getAllHistory();
      expect(historyAfterClean.length, 1);

      // 7. Verify we can still access the local file
      expect(File(historyAfterClean.first.localPath!).existsSync(), isTrue);
    },
  );
}
