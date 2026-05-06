class TravelDocument {
  final int? id;
  final int tripId;
  final String fileName;
  final String fileType; // 'pdf', 'image'
  final String encryptedFilePath; // path to the encrypted file on disk
  final String originalName;
  final DateTime uploadedAt;

  TravelDocument({
    this.id,
    required this.tripId,
    required this.fileName,
    required this.fileType,
    required this.encryptedFilePath,
    required this.originalName,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'file_name': fileName,
      'file_type': fileType,
      'encrypted_file_path': encryptedFilePath,
      'original_name': originalName,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  factory TravelDocument.fromMap(Map<String, dynamic> map) {
    return TravelDocument(
      id: map['id'],
      tripId: map['trip_id'],
      fileName: map['file_name'],
      fileType: map['file_type'],
      encryptedFilePath: map['encrypted_file_path'],
      originalName: map['original_name'],
      uploadedAt: DateTime.parse(map['uploaded_at']),
    );
  }
}