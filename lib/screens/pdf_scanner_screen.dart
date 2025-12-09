import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../services/pdf_history_service.dart';

class PdfScannerScreen extends StatefulWidget {
  const PdfScannerScreen({Key? key}) : super(key: key);

  @override
  _PdfScannerScreenState createState() => _PdfScannerScreenState();
}

enum ImageFilterType {
  original,
  grayscale,
  blackWhite,
  enhanced,
  sepia,
}

class _ScannedImage {
  final XFile file;
  ImageFilterType filter;
  File? processedFile;

  _ScannedImage({
    required this.file,
    this.filter = ImageFilterType.original,
    this.processedFile,
  });
}

class _PdfScannerScreenState extends State<PdfScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  List<_ScannedImage> _scannedImages = [];
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
                    'Add pages from camera or gallery. Tap filter icon to apply filters. Long press and drag to reorder.',
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
                : ReorderableGridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                    onReorder: _reorderImages,
                    children: List.generate(
                      _scannedImages.length,
                      (index) => _ImageCard(
                        key: ValueKey(_scannedImages[index].file.path),
                        scannedImage: _scannedImages[index],
                        index: index,
                        onDelete: () => _removeImage(index),
                        onFilter: () => _showFilterOptions(index),
                      ),
                    ),
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
                        onPressed: _isProcessing ? null : _showImageSourceDialog,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Page'),
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

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture document'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Pick from Gallery'),
              subtitle: const Text('Select image from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        // Request camera permission
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required'),
              ),
            );
          }
          return;
        }
      } else {
        // Request storage permission for gallery
        final storageStatus = await Permission.photos.request();
        if (!storageStatus.isGranted && !await Permission.storage.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required'),
              ),
            );
          }
          return;
        }
      }

      // Pick image
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _scannedImages.add(_ScannedImage(file: image));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showFilterOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Apply Filter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _FilterOption(
              name: 'Original',
              icon: Icons.image,
              isSelected: _scannedImages[index].filter == ImageFilterType.original,
              onTap: () => _applyFilter(index, ImageFilterType.original),
            ),
            _FilterOption(
              name: 'Grayscale',
              icon: Icons.filter_b_and_w,
              isSelected: _scannedImages[index].filter == ImageFilterType.grayscale,
              onTap: () => _applyFilter(index, ImageFilterType.grayscale),
            ),
            _FilterOption(
              name: 'Black & White',
              icon: Icons.contrast,
              isSelected: _scannedImages[index].filter == ImageFilterType.blackWhite,
              onTap: () => _applyFilter(index, ImageFilterType.blackWhite),
            ),
            _FilterOption(
              name: 'Enhanced',
              icon: Icons.auto_fix_high,
              isSelected: _scannedImages[index].filter == ImageFilterType.enhanced,
              onTap: () => _applyFilter(index, ImageFilterType.enhanced),
            ),
            _FilterOption(
              name: 'Sepia',
              icon: Icons.color_lens,
              isSelected: _scannedImages[index].filter == ImageFilterType.sepia,
              onTap: () => _applyFilter(index, ImageFilterType.sepia),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _applyFilter(int index, ImageFilterType filterType) async {
    Navigator.pop(context);
    
    setState(() {
      _scannedImages[index].filter = filterType;
      _scannedImages[index].processedFile = null; // Reset processed file
      _generatedPdf = null; // Reset PDF
    });

    // Process image with filter
    try {
      final scannedImage = _scannedImages[index];
      final imageBytes = await File(scannedImage.file.path).readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        img.Image processedImage = image;

        switch (filterType) {
          case ImageFilterType.original:
            processedImage = image;
            break;
          case ImageFilterType.grayscale:
            processedImage = img.grayscale(image);
            break;
          case ImageFilterType.blackWhite:
            processedImage = img.grayscale(image);
            processedImage = img.adjustColor(processedImage, brightness: 1.1, contrast: 1.3);
            break;
          case ImageFilterType.enhanced:
            processedImage = img.adjustColor(image, brightness: 1.1, contrast: 1.2, saturation: 1.1);
            break;
          case ImageFilterType.sepia:
            processedImage = img.sepia(image);
            break;
        }

        // Save processed image
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final processedPath = '${directory.path}/processed_${index}_$timestamp.jpg';
        final processedFile = File(processedPath);
        await processedFile.writeAsBytes(img.encodeJpg(processedImage, quality: 90));

        setState(() {
          _scannedImages[index].processedFile = processedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying filter: $e')),
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

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _scannedImages.removeAt(oldIndex);
      _scannedImages.insert(newIndex, item);
      _generatedPdf = null; // Reset PDF if order changes
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

      for (var scannedImage in _scannedImages) {
        // Use processed file if available, otherwise use original
        final imageFile = scannedImage.processedFile ?? File(scannedImage.file.path);
        
        // Read image file
        final imageBytes = await imageFile.readAsBytes();
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
          builder: (context) => _PdfViewerScreen(pdfFile: _generatedPdf!),
        ),
      );
    }
  }
}

class _ImageCard extends StatelessWidget {
  final _ScannedImage scannedImage;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onFilter;

  const _ImageCard({
    required Key key,
    required this.scannedImage,
    required this.index,
    required this.onDelete,
    required this.onFilter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageFile = scannedImage.processedFile ?? File(scannedImage.file.path);
    final hasFilter = scannedImage.filter != ImageFilterType.original;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Page number badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        // Filter indicator
        if (hasFilter)
          Positioned(
            top: 8,
            left: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_alt,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        // Delete button
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
        // Filter button
        Positioned(
          bottom: 8,
          left: 8,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.tune, size: 18, color: Colors.white),
              onPressed: onFilter,
              padding: EdgeInsets.zero,
              tooltip: 'Apply Filter',
            ),
          ),
        ),
        // Drag handle indicator
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.drag_handle,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final File pdfFile;

  const _PdfViewerScreen({required this.pdfFile});

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final xFile = XFile(pdfFile.path);
      await Share.shareXFiles(
        [xFile],
        text: 'Sharing scanned PDF',
        subject: 'Scanned Document',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanned PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(context),
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: SfPdfViewer.file(pdfFile),
    );
  }
}

