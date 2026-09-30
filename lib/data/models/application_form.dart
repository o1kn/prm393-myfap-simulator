/// Trạng thái xử lý của một đơn.
enum ApplicationStatus {
  processing('Đang xử lý'),
  approved('Đã được chấp nhận'),
  rejected('Đã bị từ chối');

  const ApplicationStatus(this.label);

  final String label;
}

/// Đơn từ sinh viên gửi phòng đào tạo, document `applications/{id}`.
class ApplicationForm {
  const ApplicationForm({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.type,
    required this.content,
    required this.createdAt,
    this.status = ApplicationStatus.processing,
    this.staffNote = '',
    this.processedBy = '',
    this.processedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String type;
  final String content;
  final DateTime createdAt;
  final ApplicationStatus status;

  /// Phản hồi của cán bộ đào tạo; bắt buộc khi từ chối.
  final String staffNote;
  final String processedBy;
  final DateTime? processedAt;

  factory ApplicationForm.fromMap(String id, Map<String, dynamic> map) =>
      ApplicationForm(
        id: id,
        studentId: map['studentId'] as String,
        studentName: map['studentName'] as String,
        studentCode: map['studentCode'] as String,
        type: map['type'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        status: ApplicationStatus.values.byName(map['status'] as String),
        staffNote: map['staffNote'] as String? ?? '',
        processedBy: map['processedBy'] as String? ?? '',
        processedAt: map['processedAt'] == null
            ? null
            : DateTime.parse(map['processedAt'] as String),
      );

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'studentCode': studentCode,
    'type': type,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'staffNote': staffNote,
    'processedBy': processedBy,
    'processedAt': processedAt?.toIso8601String(),
  };
}
