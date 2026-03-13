class Trip {
  int? id;
  String title;
  String location;
  String date;

  Trip({
    this.id,
    required this.title,
    required this.location,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'date': date,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      title: map['title'],
      location: map['location'],
      date: map['date'],
    );
  }
}