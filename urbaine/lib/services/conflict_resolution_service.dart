// conflict_resolution_service.dart

import '../models/incident.dart';

enum ConflictResolutionStrategy {
  // Take the server version and discard local changes
  serverWins,
  
  // Keep local version and overwrite server
  clientWins,
  
  // Use the most recently updated version
  mostRecent,
  
  // Merge both versions (when possible)
  merge,
  
  // Ask user to decide
  manual
}

class ConflictResolutionService {
  // Default strategy
  ConflictResolutionStrategy _defaultStrategy = ConflictResolutionStrategy.mostRecent;
  
  // Singleton pattern
  static final ConflictResolutionService _instance = ConflictResolutionService._internal();
  factory ConflictResolutionService() => _instance;
  ConflictResolutionService._internal();
  
  // Set default strategy
  void setDefaultStrategy(ConflictResolutionStrategy strategy) {
    _defaultStrategy = strategy;
  }
  
  // Resolve conflict between local and server incident
  Future<Incident> resolveIncidentConflict(
    Incident localIncident, 
    Incident serverIncident,
    {ConflictResolutionStrategy? strategy}
  ) async {
    final resolveStrategy = strategy ?? _defaultStrategy;
    
    switch (resolveStrategy) {
      case ConflictResolutionStrategy.serverWins:
        return _resolveServerWins(localIncident, serverIncident);
        
      case ConflictResolutionStrategy.clientWins:
        return _resolveClientWins(localIncident, serverIncident);
        
      case ConflictResolutionStrategy.mostRecent:
        return _resolveMostRecent(localIncident, serverIncident);
        
      case ConflictResolutionStrategy.merge:
        return _resolveMerge(localIncident, serverIncident);
        
      case ConflictResolutionStrategy.manual:
        // In a real implementation, this would show UI to user
        // For now, default to most recent as fallback
        print('Manual conflict resolution requested but not implemented');
        return _resolveMostRecent(localIncident, serverIncident);
    }
  }
  
  // Server version takes precedence
  Incident _resolveServerWins(Incident localIncident, Incident serverIncident) {
    // Keep server version but preserve local ID for reference
    return serverIncident.copyWith(
      localId: localIncident.localId,
      isSynced: true
    );
  }
  
  // Local version takes precedence
  Incident _resolveClientWins(Incident localIncident, Incident serverIncident) {
    // Keep local version but use server ID
    return localIncident.copyWith(
      id: serverIncident.id,
      isSynced: true
    );
  }
  
  // Most recently updated version wins
  Incident _resolveMostRecent(Incident localIncident, Incident serverIncident) {
    final localTime = localIncident.updatedAt ?? localIncident.createdAt;
    final serverTime = serverIncident.updatedAt ?? serverIncident.createdAt;
    
    if (localTime == null || serverTime == null) {
      // If we can't determine time, server wins
      return _resolveServerWins(localIncident, serverIncident);
    }
    
    if (localTime.isAfter(serverTime)) {
      return _resolveClientWins(localIncident, serverIncident);
    } else {
      return _resolveServerWins(localIncident, serverIncident);
    }
  }
  
  // Merge both versions
  Incident _resolveMerge(Incident localIncident, Incident serverIncident) {
    // Start with server version as base
    Incident mergedIncident = serverIncident;
    
    // Check each field to determine which to keep
    // For text fields, prefer non-empty values
    final mergedTitle = localIncident.title.isNotEmpty ? 
        localIncident.title : serverIncident.title;
        
    final mergedDescription = localIncident.description.isNotEmpty ? 
        localIncident.description : serverIncident.description;
    
    // For photos, keep both if different (in a real app, you might want to handle this differently)
    final String? mergedPhoto = serverIncident.photo;
    
    // For location data, prefer more precise coordinates if available
    // For simplicity, we'll just use server coordinates
    
    return mergedIncident.copyWith(
      localId: localIncident.localId,
      title: mergedTitle,
      description: mergedDescription,
      photo: mergedPhoto,
      isSynced: true
    );
  }
  
  // Detect if there's a conflict between local and server versions
  bool hasConflict(Incident localIncident, Incident serverIncident) {
    // If updatedAt times are the same, no conflict
    if (localIncident.updatedAt != null && 
        serverIncident.updatedAt != null &&
        localIncident.updatedAt!.isAtSameMomentAs(serverIncident.updatedAt!)) {
      return false;
    }
    
    // Check for differences in key fields
    if (localIncident.title != serverIncident.title ||
        localIncident.description != serverIncident.description ||
        localIncident.incidentType != serverIncident.incidentType ||
        localIncident.status != serverIncident.status) {
      return true;
    }
    
    // No conflict detected
    return false;
  }
}
