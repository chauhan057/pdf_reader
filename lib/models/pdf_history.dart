import 'package:hive/hive.dart';

class PdfHistoryAdapter extends TypeAdapter<PdfHistory> {
  @override
  final int typeId = 0;

  @override
  PdfHistory read(BinaryReader reader) {
    final id = reader.readString();
    final filePath = reader.readString();
    final fileName = reader.readString();
    final openedAt = DateTime.parse(reader.readString());
    final lastAccessedAtStr = reader.readString();
    final lastAccessedAt = lastAccessedAtStr.isEmpty
        ? null
        : DateTime.parse(lastAccessedAtStr);
    final accessCount = reader.readInt();

    // Handle backward compatibility for new fields
    String? localPath;
    if (reader.availableBytes > 0) {
      localPath = reader.readString();
    }

    String? storageUrl;
    if (reader.availableBytes > 0) {
      storageUrl = reader.readString();
    }

    return PdfHistory(
      id: id,
      filePath: filePath,
      fileName: fileName,
      openedAt: openedAt,
      lastAccessedAt: lastAccessedAt,
      accessCount: accessCount,
      localPath: localPath,
      storageUrl: storageUrl,
    );
  }

  @override
  void write(BinaryWriter writer, PdfHistory obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.filePath);
    writer.writeString(obj.fileName);
    writer.writeString(obj.openedAt.toIso8601String());
    writer.writeString(obj.lastAccessedAt?.toIso8601String() ?? '');
    writer.writeInt(obj.accessCount);
    writer.writeString(obj.localPath ?? '');
    writer.writeString(obj.storageUrl ?? '');
  }
}

class PdfHistory extends HiveObject {
  String id;
  String filePath;
  String fileName;
  DateTime openedAt;
  DateTime? lastAccessedAt;
  int accessCount;
  String? localPath;
  String? storageUrl;

  PdfHistory({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.openedAt,
    this.lastAccessedAt,
    this.accessCount = 1,
    this.localPath,
    this.storageUrl,
  });

  // Convert to Map for easy manipulation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'openedAt': openedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'accessCount': accessCount,
      'localPath': localPath,
      'storageUrl': storageUrl,
    };
  }

  // Create from Map
  factory PdfHistory.fromMap(Map<String, dynamic> map) {
    return PdfHistory(
      id: map['id'],
      filePath: map['filePath'],
      fileName: map['fileName'],
      openedAt: DateTime.parse(map['openedAt']),
      lastAccessedAt: map['lastAccessedAt'] != null
          ? DateTime.parse(map['lastAccessedAt'])
          : null,
      accessCount: map['accessCount'] ?? 1,
      localPath: map['localPath'],
      storageUrl: map['storageUrl'],
    );
  }
}
