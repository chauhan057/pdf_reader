import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

void main() {
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

class _PDFHomeScreenState extends State<PDFHomeScreen> {
  static const platform = MethodChannel('pdf_opener_channel');
  File? _pdfFile;

  @override
  void initState() {
    super.initState();
    _loadPdfFromIntent();
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
          SnackBar(content: Text('Storage permission is required to open PDF.')),
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
        setState(() {
          _pdfFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Reader"),
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _pickPDF,
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
