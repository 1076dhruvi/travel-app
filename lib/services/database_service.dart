import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'trips.db');

    return await openDatabase(
      path,
      version: 2, // bumped version
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            location TEXT,
            date TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE packing_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER,
            name TEXT,
            done INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE packing_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER,
              name TEXT,
              done INTEGER
            )
          ''');
        }
      },
    );
  }

  // ---------------- Trips ----------------
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
    final maps = await db.query('trips');
    return maps.map((e) => Trip.fromMap(e)).toList();
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<int> deleteTrip(int id) async {
    final db = await database;
    await db.delete('packing_items', where: 'trip_id = ?', whereArgs: [id]);
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Packing Items ----------------
  Future<int> insertPackingItem(int tripId, String name) async {
    final db = await database;
    return await db.insert('packing_items', {
      'trip_id': tripId,
      'name': name,
      'done': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPackingItems(int tripId) async {
    final db = await database;
    return await db.query(
      'packing_items',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'id ASC',
    );
  }

  Future<int> updatePackingItem(int id, bool done) async {
    final db = await database;
    return await db.update(
      'packing_items',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePackingItem(int id) async {
    final db = await database;
    return await db.delete('packing_items', where: 'id = ?', whereArgs: [id]);
  }
}