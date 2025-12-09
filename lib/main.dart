import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/pdf_history_service.dart';
import 'screens/history_screen.dart';
import 'screens/features_screen.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('🔥 Firebase initialized successfully');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }

  try {
    await Hive.initFlutter();
    await PdfHistoryService.init();
    // Verify initialization
    PdfHistoryService.verifyPersistence();
  } catch (e) {
    print('❌ Error initializing Hive: $e');
    // Continue anyway - history feature will be disabled
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: PDFHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PDFHomeScreen extends StatefulWidget {
  @override
  _PDFHomeScreenState createState() => _PDFHomeScreenState();
}

class _PDFHomeScreenState extends State<PDFHomeScreen>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('pdf_opener_channel');
  File? _pdfFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPdfFromIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Ensure data is saved when widget is disposed
    _saveData();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Save data when app goes to background
      _saveData();
    }
  }

  Future<void> _saveData() async {
    try {
      // Force flush Hive box to ensure all data is written to disk
      await PdfHistoryService.flush();
      print('💾 Data saved to disk');
    } catch (e) {
      print('❌ Error saving data: $e');
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted) return;

      if (await Permission.storage.request().isGranted) return;

      // For Android 11+ request MANAGE_EXTERNAL_STORAGE
      if (await Permission.manageExternalStorage.isGranted) return;

      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission is required to open PDF.'),
          ),
        );
        openAppSettings(); // Optional: direct user to settings
        throw Exception("Permission not granted");
      }
    }
  }

  Future<void> _loadPdfFromIntent() async {
    try {
      await _requestStoragePermission(); // ask permission first
      final path = await platform.invokeMethod<String>('getPdfFilePath');
      if (path != null && File(path).existsSync()) {
        setState(() {
          _pdfFile = File(path);
        });
        // Save to history - wait for it to complete
        await PdfHistoryService.addToHistory(path);
      }
    } catch (e) {
      print("Error reading file from intent: $e");
    }
  }

  Future<void> _pickPDF() async {
    try {
      await _requestStoragePermission(); // ask permission first

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        setState(() {
          _pdfFile = File(filePath);
        });
        // Save to history - wait for it to complete
        await PdfHistoryService.addToHistory(filePath);
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  Future<void> _openPdfFromPath(String filePath) async {
    try {
      await _requestStoragePermission();
      if (File(filePath).existsSync()) {
        setState(() {
          _pdfFile = File(filePath);
        });
        // Update history access - wait for it to complete
        await PdfHistoryService.addToHistory(filePath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file no longer exists')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening PDF: $e')));
    }
  }

  Future<void> _showHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(onPdfSelected: _openPdfFromPath),
      ),
    );
  }

  void _showFeatures() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeaturesScreen(),
      ),
    );
  }

  Future<void> _sharePDF() async {
    if (_pdfFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No PDF file to share.')));
      return;
    }

    try {
      final xFile = XFile(_pdfFile!.path);
      await Share.shareXFiles(
        [xFile],
        text: 'Sharing PDF file',
        subject: 'PDF Document',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Reader"),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showHistory,
            tooltip: 'View History',
          ),
          if (_pdfFile != null)
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _sharePDF,
              tooltip: 'Share PDF',
            ),
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _pickPDF,
            tooltip: 'Open PDF',
          ),
          IconButton(
            icon: Icon(Icons.apps),
            onPressed: _showFeatures,
            tooltip: 'More Features',
          ),
        ],
      ),
      body: _pdfFile == null
          ? Center(
              child: Text(
                "Tap the folder icon or open a PDF using 'Open with'.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : SfPdfViewer.file(_pdfFile!),
    );
  }
}
