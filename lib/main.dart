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

  Future<void> _loadPdfFromIntent() async {
    try {
      final path = await platform.invokeMethod<String>('getPdfFilePath');
      if (path != null && File(path).existsSync()) {
        setState(() {
          _pdfFile = File(path);
        });
      }
    } catch (e) {
      print("Failed to load intent file: $e");
    }
  }

  Future<void> _pickPDF() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission is required to pick files.')),
        );
        return;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
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
          "Tap the folder icon to open a PDF or use 'Open with' from file manager.",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : SfPdfViewer.file(_pdfFile!),
    );
  }
}
