import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_reader/models/pdf_history.dart';

void main() {
  group('PdfHistory Model Test', () {
    test('should support storageUrl field', () {
      final history = PdfHistory(
        id: '1',
        filePath: '/path/to/file.pdf',
        fileName: 'file.pdf',
        openedAt: DateTime.now(),
        storageUrl: 'https://firebase.storage/file.pdf',
      );

      expect(history.storageUrl, 'https://firebase.storage/file.pdf');
    });

    test('toMap and fromMap should handle storageUrl', () {
      final history = PdfHistory(
        id: '1',
        filePath: '/path/to/file.pdf',
        fileName: 'file.pdf',
        openedAt: DateTime.now(),
        storageUrl: 'https://firebase.storage/file.pdf',
      );

      final map = history.toMap();
      expect(map['storageUrl'], 'https://firebase.storage/file.pdf');

      final newHistory = PdfHistory.fromMap(map);
      expect(newHistory.storageUrl, 'https://firebase.storage/file.pdf');
    });

    test('should handle null storageUrl', () {
      final history = PdfHistory(
        id: '1',
        filePath: '/path/to/file.pdf',
        fileName: 'file.pdf',
        openedAt: DateTime.now(),
      );

      expect(history.storageUrl, null);

      final map = history.toMap();
      expect(map['storageUrl'], null);

      final newHistory = PdfHistory.fromMap(map);
      expect(newHistory.storageUrl, null);
    });
  });
}
