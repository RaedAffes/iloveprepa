class DocumentItem {
  final String name;
  final int sizeBytes;
  final DateTime? uploadedAt;
  final String contentType;

  const DocumentItem({
    required this.name,
    required this.sizeBytes,
    this.uploadedAt,
    this.contentType = 'application/octet-stream',
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      name: json['name'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      uploadedAt: json['uploadTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['uploadTimestamp'] as num).toInt(),
            )
          : null,
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': sizeBytes,
        'uploadTimestamp': uploadedAt?.millisecondsSinceEpoch,
        'contentType': contentType,
      };

  String get fileName => name.split('/').last;

  String get displayName {
    var base = fileName;
    final dot = base.lastIndexOf('.');
    if (dot > 0) base = base.substring(0, dot);
    return base
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  }

  String get folder => name.contains('/') ? name.split('/').first.trim() : '';

  bool get isPdf => extension == 'pdf';

  String get sizeLabel {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (sizeBytes >= gb) return '${(sizeBytes / gb).toStringAsFixed(1)} GB';
    if (sizeBytes >= mb) return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    if (sizeBytes >= kb) return '${(sizeBytes / kb).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }
}
