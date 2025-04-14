import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/incident.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path;
    
    // Handle web platform differently
    if (kIsWeb) {
      // For web, we'll use a temporary in-memory database
      // This won't persist across page refreshes but works for the current session
      path = ':memory:';
    } else {
      // For mobile platforms, use the application documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'urban_incidents.db');
    }
    
    return await openDatabase(
      path,
      version: 2, // Increased version number for migration
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Add migration handler
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE incidents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      local_id TEXT,
      incident_type TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      photo TEXT,
      audio_file TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      address TEXT,
      created_at TEXT,
      updated_at TEXT,
      status TEXT NOT NULL,
      is_voice_description INTEGER NOT NULL,
      user_username TEXT,
      is_synced INTEGER NOT NULL
    )
    ''');
  }

  // Incident operations
  Future<int> insertIncident(Incident incident) async {
    try {
      final db = await database;
      return await db.insert(
        'incidents',
        incident.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting incident: $e');
      // Return -1 to indicate failure
      return -1;
    }
  }

  Future<List<Incident>> getIncidents() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('incidents');
      return List.generate(maps.length, (i) => Incident.fromMap(maps[i]));
    } catch (e) {
      print('Error getting incidents: $e');
      // Return an empty list in case of error
      return [];
    }
  }

  Future<List<Incident>> getUnsyncedIncidents() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'incidents',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      return List.generate(maps.length, (i) => Incident.fromMap(maps[i]));
    } catch (e) {
      print('Error getting unsynced incidents: $e');
      return [];
    }
  }

  Future<void> updateIncidentSyncStatus(String localId) async {
    try {
      final db = await database;
      await db.update(
        'incidents',
        {'is_synced': 1},
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      print('Error updating incident sync status: $e');
    }
  }

  Future<void> deleteIncident(int id) async {
    try {
      final db = await database;
      await db.delete(
        'incidents',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting incident: $e');
    }
  }
  
  Future<void> deleteIncidentById(int id) async {
    try {
      final db = await database;
      await db.delete(
        'incidents',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting incident by ID: $e');
    }
  }
  
  Future<Incident?> getIncidentByLocalId(String localId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'incidents',
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return Incident.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting incident by local ID: $e');
      return null;
    }
  }
  
  Future<void> clearAllIncidents() async {
    try {
      final db = await database;
      await db.delete('incidents');
    } catch (e) {
      print('Error clearing incidents: $e');
    }
  }
  
  // Handle database migrations
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2: add audio_file column
      try {
        await db.execute('ALTER TABLE incidents ADD COLUMN audio_file TEXT');
        print('Database migration successful: added audio_file column');
      } catch (e) {
        print('Error during database migration: $e');
        // If migration fails, recreate the table (this will lose data, but it's a fallback)
        try {
          await db.execute('DROP TABLE IF EXISTS incidents_old');
          await db.execute('ALTER TABLE incidents RENAME TO incidents_old');
          await _createDB(db, newVersion);
          
          // Copy data from old table to new table
          await db.execute('''
          INSERT INTO incidents 
          (id, local_id, incident_type, title, description, photo, latitude, longitude, 
          address, created_at, updated_at, status, is_voice_description, user_username, is_synced)
          SELECT id, local_id, incident_type, title, description, photo, latitude, longitude, 
          address, created_at, updated_at, status, is_voice_description, user_username, is_synced
          FROM incidents_old
          ''');
          
          await db.execute('DROP TABLE incidents_old');
          print('Database recreation successful after migration failure');
        } catch (recreateError) {
          print('Error recreating database: $recreateError');
        }
      }
    }
  }
}