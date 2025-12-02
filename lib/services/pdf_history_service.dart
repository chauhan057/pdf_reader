import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pdf_history.dart';

class PdfHistoryService {
  static const String _boxName = 'pdfHistoryBox';
  static Box<PdfHistory>? _box;
  static String? _storagePath;

  // Get local storage path
  static Future<String> _getLocalStoragePath() async {
    if (_storagePath != null) {
      return _storagePath!;
    }
    
    try {
      // Get application documents directory (local storage)
      final directory = await getApplicationDocumentsDirectory();
      _storagePath = directory.path;
      print('📁 Local Storage Path: $_storagePath');
      return _storagePath!;
    } catch (e) {
      print('❌ Error getting local storage path: $e');
      // Fallback to Hive's default path
      return '';
    }
  }

  // Initialize Hive box with explicit local storage
  static Future<void> init() async {
    try {
      // Get and log local storage path
      final storagePath = await _getLocalStoragePath();
      print('💾 Initializing local storage at: $storagePath');
      
      // Initialize Hive with local storage
      // Hive.initFlutter() already uses local storage, but we verify it
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PdfHistoryAdapter());
        print('✅ PdfHistoryAdapter registered');
      }
      
      // Check if box is already open
      if (_box != null && _box!.isOpen) {
        print('📦 Box already open with ${_box!.length} entries');
        return;
      }
      
      // Try to open existing box first (don't delete existing data)
      try {
        // Open box - Hive stores in local app directory
        _box = await Hive.openBox<PdfHistory>(_boxName);
        
        // Verify box is open and accessible
        if (!_box!.isOpen) {
          throw Exception('Box opened but not accessible');
        }
        
        final entryCount = _box!.length;
        print('✅ Local storage box opened successfully');
        print('   📍 Storage Location: Local device (app documents directory)');
        print('   📊 Current entries: $entryCount');
        
        // Verify we can read data
        if (entryCount > 0) {
          final firstEntry = _box!.values.first;
          print('   ✅ Verified: First entry - ${firstEntry.fileName}');
        }
      } catch (e) {
        print('❌ Error opening local storage box: $e');
        // Only delete and recreate if it's a corruption error
        if (e.toString().contains('corrupt') || e.toString().contains('invalid')) {
          print('⚠️ Attempting to recover from corruption...');
          try {
            await Hive.deleteBoxFromDisk(_boxName);
            _box = await Hive.openBox<PdfHistory>(_boxName);
            print('✅ Local storage box recreated after corruption');
          } catch (recreateError) {
            print('❌ Error recreating box: $recreateError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('❌ Critical error initializing local storage: $e');
      rethrow;
    }
  }

  // Get the box instance
  static Box<PdfHistory> get box {
    if (_box == null) {
      throw Exception('PdfHistoryService not initialized. Call init() first.');
    }
    return _box!;
  }

  // CREATE - Add or update PDF to history
  static Future<void> addToHistory(String filePath) async {
    try {
      // Ensure box is initialized
      if (_box == null || !_box!.isOpen) {
        print('⚠️ Box not available, reinitializing...');
        await init();
        if (_box == null || !_box!.isOpen) {
          print('❌ Failed to initialize box, skipping history save');
          return;
        }
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ File does not exist: $filePath');
        return; // Silently skip if file doesn't exist
      }

      final fileName = file.path.split('/').last.split('\\').last;
      final existingEntry = _findByPath(filePath);

      if (existingEntry != null) {
        // UPDATE - File already in history, update access info
        existingEntry.lastAccessedAt = DateTime.now();
        existingEntry.accessCount = (existingEntry.accessCount) + 1;
        await existingEntry.save();
        // Force flush to disk to ensure persistence
        await box.flush();
        print('✅ Updated history: $fileName (count: ${existingEntry.accessCount})');
      } else {
        // CREATE - New entry
        final historyEntry = PdfHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: filePath,
          fileName: fileName,
          openedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
          accessCount: 1,
        );
        await box.add(historyEntry);
        // Force flush to disk to ensure persistence
        await box.flush();
        print('✅ Added to history: $fileName (Total entries: ${box.length})');
        
        // Verify it was saved
        final verifyEntry = _findByPath(filePath);
        if (verifyEntry != null) {
          print('✅ Verified: Entry saved successfully');
        } else {
          print('❌ Warning: Entry not found after save!');
        }
      }
    } catch (e) {
      // Log error but don't break the app
      print('❌ Error adding to history: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // READ - Get all history entries
  static List<PdfHistory> getAllHistory() {
    try {
      if (_box == null || !_box!.isOpen) {
        print('⚠️ Box not open, returning empty list');
        return [];
      }
      final history = box.values.toList()
        ..sort((a, b) => b.lastAccessedAt?.compareTo(a.lastAccessedAt ?? DateTime(1970)) ?? 0);
      print('📖 Retrieved ${history.length} history entries');
      return history;
    } catch (e) {
      print('❌ Error getting history: $e');
      return [];
    }
  }

  // READ - Get history by ID
  static PdfHistory? getById(String id) {
    try {
      if (_box == null || !_box!.isOpen) {
        return null;
      }
      return box.values.firstWhere((entry) => entry.id == id);
    } catch (e) {
      return null;
    }
  }

  // READ - Find by file path
  static PdfHistory? _findByPath(String filePath) {
    try {
      if (_box == null || !_box!.isOpen) {
        return null;
      }
      return box.values.firstWhere(
        (entry) => entry.filePath == filePath,
        orElse: () => throw Exception('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  // UPDATE - Update history entry
  static Future<void> updateHistory(PdfHistory history) async {
    try {
      if (_box == null || !_box!.isOpen) {
        return;
      }
      await history.save();
      // Force flush to disk to ensure persistence
      await box.flush();
    } catch (e) {
      print('Error updating history: $e');
      // Don't throw - just log
    }
  }

  // DELETE - Delete a history entry
  static Future<void> deleteHistory(String id) async {
    try {
      if (_box == null || !_box!.isOpen) {
        return;
      }
      final entry = getById(id);
      if (entry != null) {
        await entry.delete();
        // Force flush to disk to ensure persistence
        await box.flush();
      }
    } catch (e) {
      print('Error deleting history: $e');
      // Don't throw - just log
    }
  }

  // DELETE - Delete all history
  static Future<void> deleteAllHistory() async {
    try {
      if (_box == null || !_box!.isOpen) {
        return;
      }
      await box.clear();
      // Force flush to disk to ensure persistence
      await box.flush();
    } catch (e) {
      print('Error deleting all history: $e');
      // Don't throw - just log
    }
  }

  // DELETE - Delete history entries with non-existent files
  static Future<void> cleanInvalidEntries() async {
    try {
      if (_box == null || !_box!.isOpen) {
        return;
      }
      final invalidEntries = <PdfHistory>[];
      for (var entry in box.values) {
        if (!File(entry.filePath).existsSync()) {
          invalidEntries.add(entry);
        }
      }
      for (var entry in invalidEntries) {
        await entry.delete();
      }
      // Force flush to disk after cleaning
      if (invalidEntries.isNotEmpty) {
        await box.flush();
      }
    } catch (e) {
      print('Error cleaning invalid entries: $e');
      // Don't throw - just log the error
    }
  }

  // Get history count
  static int getHistoryCount() {
    try {
      if (_box == null || !_box!.isOpen) {
        return 0;
      }
      return box.length;
    } catch (e) {
      return 0;
    }
  }

  // Force flush all data to disk
  static Future<void> flush() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.flush();
        print('Hive box flushed to disk');
      }
    } catch (e) {
      print('Error flushing box: $e');
    }
  }

  // Close the box (called on app termination) - DON'T CALL THIS UNLESS APP IS CLOSING
  static Future<void> close() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.flush(); // Flush before closing
        await _box!.close();
        _box = null; // Reset after closing
        print('✅ Hive box closed and flushed');
      }
    } catch (e) {
      print('❌ Error closing box: $e');
    }
  }

  // Verify data persistence - for debugging
  static void verifyPersistence() {
    try {
      if (_box == null || !_box!.isOpen) {
        print('❌ Local storage box is not open');
        return;
      }
      print('📋 Local Storage Status:');
      print('   ✅ Storage Type: Local Device Storage');
      print('   📍 Storage Path: ${_storagePath ?? "App Documents Directory"}');
      print('   📦 Box Name: $_boxName');
      print('   🔓 Is Open: ${_box!.isOpen}');
      print('   📊 Entry Count: ${_box!.length}');
      if (_box!.length > 0) {
        print('   📄 Sample Entry: ${_box!.values.first.fileName}');
      }
      print('   💾 Data Location: Stored locally on device (not cloud)');
    } catch (e) {
      print('❌ Error verifying local storage: $e');
    }
  }
  
  // Get storage info for user
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final storagePath = await _getLocalStoragePath();
      return {
        'type': 'Local Device Storage',
        'path': storagePath,
        'boxName': _boxName,
        'isOpen': _box?.isOpen ?? false,
        'entryCount': _box?.length ?? 0,
        'isLocal': true,
      };
    } catch (e) {
      return {
        'type': 'Local Device Storage',
        'error': e.toString(),
        'isLocal': true,
      };
    }
  }
}

