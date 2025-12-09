import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/pdf_history_service.dart';

class PdfScannerScreen extends StatefulWidget {
  const PdfScannerScreen({Key? key}) : super(key: key);

  @override
  _PdfScannerScreenState createState() => _PdfScannerScreenState();
}

class _PdfScannerScreenState extends State<PdfScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _scannedImages = [];
  bool _isProcessing = false;
  File? _generatedPdf;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Scanner'),
        actions: [
          if (_scannedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Take photos of documents to create a PDF',
                    style: TextStyle(color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),

          // Scanned images grid
          Expanded(
            child: _scannedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No scanned pages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the camera button to start scanning',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _scannedImages.length,
                    itemBuilder: (context, index) {
                      return _ImageCard(
                        imageFile: _scannedImages[index],
                        onDelete: () => _removeImage(index),
                      );
                    },
                  ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_generatedPdf != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _viewPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('View Generated PDF'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _scanDocument,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Page'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_scannedImages.isEmpty || _isProcessing)
                            ? null
                            : _generatePdf,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(_isProcessing
                            ? 'Creating...'
                            : 'Create PDF (${_scannedImages.length})'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanDocument() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to scan documents'),
            ),
          );
        }
        return;
      }

      // Take picture
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _scannedImages.removeAt(index);
      _generatedPdf = null; // Reset PDF if images change
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Pages?'),
        content: const Text('Are you sure you want to remove all scanned pages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _scannedImages.clear();
                _generatedPdf = null;
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (_scannedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final pdf = pw.Document();

      for (var imageFile in _scannedImages) {
        // Read image file
        final imageBytes = await File(imageFile.path).readAsBytes();
        final image = img.decodeImage(imageBytes);

        if (image != null) {
          // Convert to PDF page
          final pdfImage = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }
      }

      // Save PDF to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfPath = '${directory.path}/scanned_$timestamp.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      // Save to history
      await PdfHistoryService.addToHistory(pdfPath);

      setState(() {
        _generatedPdf = file;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating PDF: $e')),
        );
      }
    }
  }

  void _viewPdf() {
    if (_generatedPdf != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Scanned PDF'),
            ),
            body: SfPdfViewer.file(_generatedPdf!),
          ),
        ),
      );
    }
  }
}

class _ImageCard extends StatelessWidget {
  final XFile imageFile;
  final VoidCallback onDelete;

  const _ImageCard({
    required this.imageFile,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(imageFile.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.red,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

