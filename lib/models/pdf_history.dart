import 'package:hive/hive.dart';

class PdfHistoryAdapter extends TypeAdapter<PdfHistory> {
  @override
  final int typeId = 0;

  @override
  PdfHistory read(BinaryReader reader) {
    return PdfHistory(
      id: reader.readString(),
      filePath: reader.readString(),
      fileName: reader.readString(),
      openedAt: DateTime.parse(reader.readString()),
      lastAccessedAt: reader.readString().isEmpty
          ? null
          : DateTime.parse(reader.readString()),
      accessCount: reader.readInt(),
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
  }
}

class PdfHistory extends HiveObject {
  String id;
  String filePath;
  String fileName;
  DateTime openedAt;
  DateTime? lastAccessedAt;
  int accessCount;

  PdfHistory({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.openedAt,
    this.lastAccessedAt,
    this.accessCount = 1,
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
    );
  }
}

