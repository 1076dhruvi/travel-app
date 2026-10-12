import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip.dart';
import '../models/note.dart';
import '../models/document.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = join(await getDatabasesPath(), 'trips.db');

    return await openDatabase(
      dbPath,
      version: 8,
      onCreate: (db, version) async {
        // ================= TRIPS =================
        await db.execute('''
          CREATE TABLE trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            location TEXT,
            date TEXT,
            budget REAL DEFAULT 0,
            days INTEGER DEFAULT 1,
            cover_image TEXT
          )
        ''');

        // ================= DOCUMENTS =================
        await db.execute('''
          CREATE TABLE travel_documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER,
            file_name TEXT,
            file_type TEXT,
            encrypted_file_path TEXT,
            original_name TEXT,
            uploaded_at TEXT
          )
        ''');

        // ================= PACKING ITEMS =================
        await db.execute('''
          CREATE TABLE packing_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER,
            name TEXT,
            done INTEGER
          )
        ''');

        // ================= EXPENSES =================
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER,
            title TEXT,
            amount REAL,
            category TEXT,
            date TEXT
          )
        ''');

        // ================= NOTES =================
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            color INTEGER NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT
          )
        ''');

        // ================= ITINERARIES =================
        await db.execute('''
          CREATE TABLE IF NOT EXISTS itineraries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER UNIQUE NOT NULL,
            data TEXT NOT NULL
          )
        ''');
      }, // <-- Properly closed onCreate
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

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE travel_documents(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER,
              file_name TEXT,
              file_type TEXT,
              encrypted_file_path TEXT,
              original_name TEXT,
              uploaded_at TEXT
            )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE trips ADD COLUMN budget REAL DEFAULT 0',
          );

          await db.execute(
            'ALTER TABLE trips ADD COLUMN days INTEGER DEFAULT 1',
          );

          await db.execute('''
            CREATE TABLE expenses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER,
              title TEXT,
              amount REAL,
              category TEXT,
              date TEXT
            )
          ''');
        }

        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              color INTEGER NOT NULL,
              is_pinned INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute(
            "ALTER TABLE trips ADD COLUMN cover_image TEXT",
          );
        }

        if (oldVersion < 7) {
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final exists = columns.any((column) => column['name'] == 'reminder_time');

          if (!exists) {
            await db.execute(
              'ALTER TABLE notes ADD COLUMN reminder_time TEXT',
            );
          }
        }

        // VERSION 8: Add persistence support for itineraries safely
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS itineraries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER UNIQUE NOT NULL,
              data TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // =========================================================
  // TRIPS
  // =========================================================

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

  Future<Map<String, dynamic>?> getTrip(int id) async {
    final db = await database;

    final result = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
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

  Future<void> updateTripBudget(
      int tripId,
      double budget,
      int days,
      ) async {
    final db = await database;

    await db.update(
      'trips',
      {
        'budget': budget,
        'days': days,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<int> deleteTrip(int id) async {
    final db = await database;

    await db.delete(
      'packing_items',
      where: 'trip_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'travel_documents',
      where: 'trip_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'expenses',
      where: 'trip_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'notes',
      where: 'trip_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'itineraries',
      where: 'trip_id = ?',
      whereArgs: [id],
    );

    return await db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================================================
  // ITINERARY PERSISTENCE
  // =========================================================

  Future<void> saveItinerary(int tripId, String jsonData) async {
    final db = await database;

    await db.insert(
      'itineraries',
      {
        'trip_id': tripId,
        'data': jsonData,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getItinerary(int tripId) async {
    final db = await database;

    final result = await db.query(
      'itineraries',
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );

    if (result.isNotEmpty) {
      return result.first['data'] as String?;
    }

    return null;
  }

  Future<int> deleteItinerary(int tripId) async {
    final db = await database;

    return await db.delete(
      'itineraries',
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
  }

  // =========================================================
  // PACKING ITEMS
  // =========================================================

  Future<int> insertPackingItem(
      int tripId,
      String name,
      ) async {
    final db = await database;

    return await db.insert(
      'packing_items',
      {
        'trip_id': tripId,
        'name': name,
        'done': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPackingItems(
      int tripId,
      ) async {
    final db = await database;

    return await db.query(
      'packing_items',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'id ASC',
    );
  }

  Future<int> updatePackingItem(
      int id,
      bool done,
      ) async {
    final db = await database;

    return await db.update(
      'packing_items',
      {
        'done': done ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePackingItem(int id) async {
    final db = await database;

    return await db.delete(
      'packing_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePackingItemsByTrip(
      int tripId,
      ) async {
    final db = await database;

    await db.delete(
      'packing_items',
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
  }

  // =========================================================
  // TRAVEL DOCUMENTS
  // =========================================================

  Future<int> insertDocument(
      TravelDocument doc,
      ) async {
    final db = await database;

    return await db.insert(
      'travel_documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TravelDocument>> getDocuments(
      int tripId,
      ) async {
    final db = await database;

    final maps = await db.query(
      'travel_documents',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'uploaded_at DESC',
    );

    return maps.map((e) => TravelDocument.fromMap(e)).toList();
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;

    return await db.delete(
      'travel_documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================================================
  // NOTES
  // =========================================================

  Future<int> insertNote(Note note) async {
    final db = await database;

    return await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotesByTrip(int tripId) async {
    final db = await database;

    final result = await db.query(
      'notes',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'is_pinned DESC, id DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await database;

    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;

    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleNotePin(Note note) async {
    final db = await database;

    await db.update(
      'notes',
      {
        'is_pinned': note.isPinned ? 0 : 1,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // =========================================================
  // EXPENSES
  // =========================================================

  Future<void> addExpense(
      int tripId,
      String title,
      double amount,
      String category,
      String date,
      ) async {
    final db = await database;

    await db.insert(
      'expenses',
      {
        'trip_id': tripId,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getExpenses(
      int tripId,
      ) async {
    final db = await database;

    return await db.query(
      'expenses',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'id DESC',
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;

    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}