class Trip {
  int? id;
  String title;
  String location;
  String date;
  String? coverImage;

  Trip({
    this.id,
    required this.title,
    required this.location,
    required this.date,
    this.coverImage,
  });


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'date': date,
      'cover_image': coverImage,
    };
  }


  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      title: map['title'],
      location: map['location'],
      date: map['date'],
      coverImage: map['cover_image'],
    );
  }
}