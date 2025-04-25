// sync_queue_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident.dart';

class SyncQueueItem {
  final String id;
  final String localId;
  final DateTime queuedAt;
  final int priority; // Higher number = higher priority
  final int retryCount;
  final DateTime? lastRetryAttempt;
  final String itemType; // 'incident', 'user_profile', etc.

  SyncQueueItem({
    required this.id,
    required this.localId,
    required this.queuedAt,
    this.priority = 1,
    this.retryCount = 0,
    this.lastRetryAttempt,
    required this.itemType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localId': localId,
      'queuedAt': queuedAt.toIso8601String(),
      'priority': priority,
      'retryCount': retryCount,
      'lastRetryAttempt': lastRetryAttempt?.toIso8601String(),
      'itemType': itemType,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'],
      localId: json['localId'],
      queuedAt: DateTime.parse(json['queuedAt']),
      priority: json['priority'] ?? 1,
      retryCount: json['retryCount'] ?? 0,
      lastRetryAttempt: json['lastRetryAttempt'] != null
          ? DateTime.parse(json['lastRetryAttempt'])
          : null,
      itemType: json['itemType'],
    );
  }

  SyncQueueItem copyWith({
    String? id,
    String? localId,
    DateTime? queuedAt,
    int? priority,
    int? retryCount,
    DateTime? lastRetryAttempt,
    String? itemType,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      queuedAt: queuedAt ?? this.queuedAt,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAttempt: lastRetryAttempt ?? this.lastRetryAttempt,
      itemType: itemType ?? this.itemType,
    );
  }
}

class SyncQueueService {
  static const String _queueKey = 'sync_queue';
  static const String _syncStatusKey = 'sync_status';
  
  List<SyncQueueItem> _queue = [];
  bool _isSyncing = false;
  String _syncStatus = '';
  int _syncProgress = 0;
  int _totalItems = 0;
  
  // Stream controller for sync status updates
  final _syncStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get syncStatusStream => _syncStatusController.stream;
  
  // Singleton pattern
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  // Getters
  bool get isSyncing => _isSyncing;
  String get syncStatus => _syncStatus;
  double get syncProgress => _totalItems > 0 ? _syncProgress / _totalItems : 0.0;
  List<SyncQueueItem> get queue => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  
  // Initialize the queue from persistent storage
  Future<void> initialize() async {
    await _loadQueue();
    await _loadSyncStatus();
  }
  
  // Add an incident to the sync queue
  Future<void> addToQueue(Incident incident, {int priority = 1}) async {
    // Don't add if already in queue
    if (_queue.any((item) => 
        item.localId == incident.localId || 
        (incident.id != null && item.id == incident.id.toString()))) {
      return;
    }
    
    final queueItem = SyncQueueItem(
      id: incident.id?.toString() ?? '',
      localId: incident.localId ?? '',
      queuedAt: DateTime.now(),
      priority: priority,
      itemType: 'incident',
    );
    
    _queue.add(queueItem);
    await _saveQueue();
    _notifySyncStatus();
  }
  
  // Remove an item from the queue
  Future<void> removeFromQueue(String localId) async {
    _queue.removeWhere((item) => item.localId == localId);
    await _saveQueue();
    _notifySyncStatus();
  }
  
  // Update an item's priority
  Future<void> updatePriority(String localId, int priority) async {
    final index = _queue.indexWhere((item) => item.localId == localId);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(priority: priority);
      await _saveQueue();
    }
  }
  
  // Mark an item as being processed
  Future<void> markSyncStarted() async {
    _isSyncing = true;
    _syncStatus = 'syncing';
    _totalItems = _queue.length;
    _syncProgress = 0;
    await _saveSyncStatus();
    _notifySyncStatus();
  }
  
  // Mark an item as successfully synced
  Future<void> markItemSynced(String localId) async {
    _queue.removeWhere((item) => item.localId == localId);
    _syncProgress++;
    await _saveQueue();
    await _saveSyncStatus();
    _notifySyncStatus();
  }
  
  // Mark an item as failed
  Future<void> markItemFailed(String localId) async {
    final index = _queue.indexWhere((item) => item.localId == localId);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        retryCount: _queue[index].retryCount + 1,
        lastRetryAttempt: DateTime.now(),
      );
      _syncProgress++;
      await _saveQueue();
    }
    _notifySyncStatus();
  }
  
  // Mark sync as completed
  Future<void> markSyncCompleted({bool success = true}) async {
    _isSyncing = false;
    _syncStatus = success ? 'success' : 'error';
    await _saveSyncStatus();
    _notifySyncStatus();
  }
  
  // Get the next batch of items to sync, ordered by priority
  List<SyncQueueItem> getNextBatch({int batchSize = 5}) {
    // Sort by priority (high to low) and then by queue time (oldest first)
    _queue.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority); // Higher priority first
      }
      return a.queuedAt.compareTo(b.queuedAt); // Older items first
    });
    
    return _queue.take(batchSize).toList();
  }
  
  // Save queue to persistent storage
  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = jsonEncode(_queue.map((item) => item.toJson()).toList());
    await prefs.setString(_queueKey, queueJson);
  }
  
  // Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null && queueJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded.map((item) => SyncQueueItem.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error loading sync queue: $e');
      _queue = [];
    }
  }
  
  // Save sync status to persistent storage
  Future<void> _saveSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusJson = jsonEncode({
      'isSyncing': _isSyncing,
      'syncStatus': _syncStatus,
      'syncProgress': _syncProgress,
      'totalItems': _totalItems,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_syncStatusKey, statusJson);
  }
  
  // Load sync status from persistent storage
  Future<void> _loadSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString(_syncStatusKey);
      
      if (statusJson != null && statusJson.isNotEmpty) {
        final Map<String, dynamic> status = jsonDecode(statusJson);
        _isSyncing = status['isSyncing'] ?? false;
        _syncStatus = status['syncStatus'] ?? '';
        _syncProgress = status['syncProgress'] ?? 0;
        _totalItems = status['totalItems'] ?? 0;
        
        // If app was closed during sync, reset the status
        if (_isSyncing) {
          _isSyncing = false;
          _syncStatus = 'interrupted';
          await _saveSyncStatus();
        }
      }
    } catch (e) {
      print('Error loading sync status: $e');
      _isSyncing = false;
      _syncStatus = '';
      _syncProgress = 0;
      _totalItems = 0;
    }
  }
  
  // Notify listeners of sync status changes
  void _notifySyncStatus() {
    _syncStatusController.add({
      'isSyncing': _isSyncing,
      'syncStatus': _syncStatus,
      'syncProgress': syncProgress,
      'queueLength': _queue.length,
    });
  }
  
  // Clean up resources
  void dispose() {
    _syncStatusController.close();
  }
}
