import 'dart:io';
import 'package:flutter/material.dart';
import '../models/pdf_history.dart';
import '../services/pdf_history_service.dart';

class HistoryScreen extends StatefulWidget {
  final Function(String) onPdfSelected;

  const HistoryScreen({Key? key, required this.onPdfSelected})
    : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PdfHistory> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Clean invalid entries first
      await PdfHistoryService.cleanInvalidEntries();
      final history = PdfHistoryService.getAllHistory();
      setState(() {
        _historyList = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  Future<void> _deleteHistory(String id) async {
    try {
      await PdfHistoryService.deleteHistory(id);
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('History entry deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  Future<void> _deleteAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All History'),
        content: const Text('Are you sure you want to delete all history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PdfHistoryService.deleteAllHistory();
        await _loadHistory();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('All history deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting all: $e')));
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF History'),
        actions: [
          if (_historyList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteAllHistory,
              tooltip: 'Delete All',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No PDF history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open a PDF to add it to history',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                itemCount: _historyList.length,
                itemBuilder: (context, index) {
                  final history = _historyList[index];
                  // Check if original file exists
                  final originalExists = File(history.filePath).existsSync();
                  // Check if local copy exists
                  final localExists =
                      history.localPath != null &&
                      File(history.localPath!).existsSync();
                  // Check if cloud backup exists
                  final hasCloudBackup = history.storageUrl != null;

                  // File is accessible if any exists
                  final isAccessible =
                      originalExists || localExists || hasCloudBackup;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAccessible
                            ? Colors.blue
                            : Colors.grey,
                        child: Icon(Icons.picture_as_pdf, color: Colors.white),
                      ),
                      title: Text(
                        history.fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isAccessible
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Opened: ${_formatDate(history.openedAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (history.lastAccessedAt != null)
                            Text(
                              'Last accessed: ${_formatDate(history.lastAccessedAt!)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            'Accessed ${history.accessCount} time${history.accessCount > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (!originalExists && localExists)
                            const Text(
                              'Using local copy',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (!originalExists && !localExists && hasCloudBackup)
                            const Text(
                              'Available in cloud (tap to download)',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (!isAccessible)
                            const Text(
                              'File not found',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          if (isAccessible)
                            PopupMenuItem(
                              value: 'open',
                              child: const Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 20),
                                  SizedBox(width: 8),
                                  Text('Open'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: const Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'open' && isAccessible) {
                            String? path;
                            if (originalExists) {
                              path = history.filePath;
                            } else if (localExists) {
                              path = history.localPath;
                            } else if (hasCloudBackup) {
                              // Download from cloud
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Downloading from cloud...'),
                                ),
                              );
                              path =
                                  await PdfHistoryService.downloadFromFirebase(
                                    history.storageUrl!,
                                    history.fileName,
                                  );
                              if (path != null) {
                                // Update local path in history
                                history.localPath = path;
                                await history.save();
                                setState(() {}); // Refresh UI
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Download failed'),
                                  ),
                                );
                                return;
                              }
                            }

                            if (path != null) {
                              widget.onPdfSelected(path);
                              Navigator.pop(context);
                            }
                          } else if (value == 'delete') {
                            _deleteHistory(history.id);
                          }
                        },
                      ),
                      onTap: isAccessible
                          ? () async {
                              String? path;
                              if (originalExists) {
                                path = history.filePath;
                              } else if (localExists) {
                                path = history.localPath;
                              } else if (hasCloudBackup) {
                                // Download from cloud
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Downloading from cloud...'),
                                  ),
                                );
                                path =
                                    await PdfHistoryService.downloadFromFirebase(
                                      history.storageUrl!,
                                      history.fileName,
                                    );
                                if (path != null) {
                                  // Update local path in history
                                  history.localPath = path;
                                  await history.save();
                                  setState(() {}); // Refresh UI
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Download failed'),
                                    ),
                                  );
                                  return;
                                }
                              }

                              if (path != null) {
                                widget.onPdfSelected(path);
                                Navigator.pop(context);
                              }
                            }
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
