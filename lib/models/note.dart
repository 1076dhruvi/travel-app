class Note {
  final int? id;
  final int tripId;
  final String title;
  final String content;
  final String timestamp;
  final int color;
  final bool isPinned;
  final String? reminderTime;

  Note({
    this.id,
    required this.tripId,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.color,
    this.isPinned = false,
    this.reminderTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'reminder_time': reminderTime,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      tripId: map['trip_id'],
      title: map['title'],
      content: map['content'],
      timestamp: map['timestamp'],
      color: map['color'],
      isPinned: map['is_pinned'] == 1,
      reminderTime: map['reminder_time'],
    );
  }
}