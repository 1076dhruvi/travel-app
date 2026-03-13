import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip.dart';

class DatabaseService {

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {

    String path = join(await getDatabasesPath(), 'trips.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {

        await db.execute(
          '''
          CREATE TABLE trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            location TEXT,
            date TEXT
          )
          '''
        );

      },
    );
  }

  Future<int> insertTrip(Trip trip) async {

    final db = await database;

    return await db.insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Trip>> getTrips() async {

    final db = await database;

    final List<Map<String, dynamic>> maps =
        await db.query('trips');

    return List.generate(maps.length, (i) {
      return Trip.fromMap(maps[i]);
    });
  }

}