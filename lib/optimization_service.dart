import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lead_model.dart';
import 'auth_service.dart';

/// 🚀 Firestore Optimization Service
///
/// This service provides optimized versions of database operations
/// to reduce Firestore reads/writes and improve performance.
///
/// Usage: Replace DatabaseService calls with OptimizationService calls
/// Example: OptimizationService.getOptimizedLeads() instead of DatabaseService.getLeads()
class OptimizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static CollectionReference get _leadsCollection => _firestore.collection('leads');
  static CollectionReference get _remarksCollection => _firestore.collection('remarks');
  static CollectionReference get _followUpsCollection => _firestore.collection('followUps');
  static CollectionReference get _summaryCollection => _firestore.collection('summary');

  // Caching and pagination
  static final Map<String, List<Lead>> _cachedLeads = {};
  static final Map<String, DocumentSnapshot?> _lastDocuments = {};
  static final Map<String, bool> _hasMoreData = {};
  static const int _pageSize = 20;

  // Debounce timers
  static final Map<String, Timer> _debounceTimers = {};

  // Last fetch times for selective refresh
  static DateTime? _lastLeadsFetch;
  static DateTime? _lastFollowUpsFetch;

  /// 🔥 OPTIMIZATION 1: Enable Firestore Local Caching
  /// Call this once in main.dart after Firebase initialization
  static Future<void> enableFirestoreCache() async {
    try {
      await _firestore.enablePersistence();
      print('✅ Firestore persistence enabled - offline-first reads activated');
    } catch (e) {
      print('⚠️ Firestore persistence already enabled or not supported: $e');
    }
  }

  /// 🔥 OPTIMIZATION 2: Paginated Lead Loading (20 per page)
  ///
  /// Usage: Replace your existing getLeads() calls
  /// Returns stream of paginated leads with load-more capability
  static Stream<PaginatedLeadsResult> getPaginatedLeads({
    String? statusFilter,
    List<String>? projectFilters,
    List<String>? sourceFilters,
    DateTimeRange? dateRange,
    bool loadMore = false,
  }) {
    final cacheKey = _buildCacheKey(statusFilter, projectFilters, sourceFilters, dateRange);

    return _getPaginatedLeadsStream(
      statusFilter: statusFilter,
      projectFilters: projectFilters,
      sourceFilters: sourceFilters,
      dateRange: dateRange,
      cacheKey: cacheKey,
      loadMore: loadMore,
    );
  }

  static Stream<PaginatedLeadsResult> _getPaginatedLeadsStream({
    String? statusFilter,
    List<String>? projectFilters,
    List<String>? sourceFilters,
    DateTimeRange? dateRange,
    required String cacheKey,
    bool loadMore = false,
  }) async* {
    try {
      // Initialize cache if needed
      if (!_cachedLeads.containsKey(cacheKey) || !loadMore) {
        _cachedLeads[cacheKey] = [];
        _lastDocuments[cacheKey] = null;
        _hasMoreData[cacheKey] = true;
      }

      // Build query
      Query query = _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId);

      // Apply filters
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }
      if (projectFilters != null && projectFilters.isNotEmpty) {
        query = query.where('projects', arrayContainsAny: projectFilters);
      }
      if (sourceFilters != null && sourceFilters.isNotEmpty) {
        query = query.where('sources', arrayContainsAny: sourceFilters);
      }
      if (dateRange != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('createdAt', isLessThan: Timestamp.fromDate(dateRange.end));
      }

      // Apply pagination
      query = query.orderBy('updatedAt', descending: true).limit(_pageSize);

      if (loadMore && _lastDocuments[cacheKey] != null) {
        query = query.startAfterDocument(_lastDocuments[cacheKey]!);
      }

      // Execute query
      final snapshot = await query.get();

      // Process results
      final newLeads = snapshot.docs.map((doc) {
        return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Update cache
      if (loadMore) {
        _cachedLeads[cacheKey]!.addAll(newLeads);
      } else {
        _cachedLeads[cacheKey] = newLeads;
      }

      // Update pagination state
      _hasMoreData[cacheKey] = newLeads.length == _pageSize;
      if (snapshot.docs.isNotEmpty) {
        _lastDocuments[cacheKey] = snapshot.docs.last;
      }

      // Return result
      yield PaginatedLeadsResult(
        leads: List.from(_cachedLeads[cacheKey]!),
        hasMore: _hasMoreData[cacheKey]!,
        isLoading: false,
      );

    } catch (e) {
      print('Error in paginated leads: $e');
      yield PaginatedLeadsResult(
        leads: _cachedLeads[cacheKey] ?? [],
        hasMore: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 🔥 OPTIMIZATION 3: Denormalized Lead Creation
  ///
  /// Creates lead with embedded summary data to reduce future reads
  static Future<String> createOptimizedLead(Lead lead, String? initialRemark) async {
    final batch = _firestore.batch();

    try {
      // Create lead with denormalized fields
      final leadRef = _leadsCollection.doc();
      final optimizedLead = lead.copyWith().toMap();

      // Add denormalized fields
      optimizedLead['lastActivity'] = FieldValue.serverTimestamp();
      optimizedLead['followUpCount'] = 0;
      optimizedLead['remarkCount'] = initialRemark?.isNotEmpty == true ? 1 : 0;
      optimizedLead['lastFollowUp'] = null;
      optimizedLead['lastRemark'] = initialRemark;
      optimizedLead['isHot'] = false; // For quick filtering

      batch.set(leadRef, optimizedLead);

      // Add initial remark if provided
      if (initialRemark?.isNotEmpty == true) {
        final remarkRef = _remarksCollection.doc();
        final remark = Remark(
          id: remarkRef.id,
          leadId: leadRef.id,
          content: initialRemark!,
          type: RemarkType.note,
          createdAt: DateTime.now(),
          userId: AuthService.currentUserId!,
        );
        batch.set(remarkRef, remark.toMap());
      }

      // Update summary statistics
      await _updateSummaryStats(batch, leadCount: 1);

      await batch.commit();

      // Clear relevant caches
      _clearLeadCaches();

      return leadRef.id;
    } catch (e) {
      print('Error creating optimized lead: $e');
      rethrow;
    }
  }

  /// 🔥 OPTIMIZATION 4: Summary Collection for Dashboard Stats
  ///
  /// Get dashboard statistics from pre-calculated summary instead of counting documents
  static Future<DashboardSummary> getOptimizedDashboardStats() async {
    try {
      final summaryDoc = await _summaryCollection
          .doc('${AuthService.currentUserId}_stats')
          .get();

      if (summaryDoc.exists) {
        final data = summaryDoc.data() as Map<String, dynamic>;
        return DashboardSummary.fromMap(data);
      } else {
        // Fallback: calculate and store summary
        return await _calculateAndStoreSummary();
      }
    } catch (e) {
      print('Error getting optimized stats: $e');
      // Fallback to live calculation
      return await _calculateAndStoreSummary();
    }
  }

  /// 🔥 OPTIMIZATION 5: Debounced Search with Caching
  ///
  /// Delays search execution until user stops typing (300ms)
  static Stream<List<Lead>> getDebouncedSearchResults(
      String searchQuery, {
        Duration debounceTime = const Duration(milliseconds: 300),
      }) {
    final controller = StreamController<List<Lead>>();
    final searchKey = 'search_$searchQuery';

    // Cancel previous timer
    _debounceTimers[searchKey]?.cancel();

    // Set new timer
    _debounceTimers[searchKey] = Timer(debounceTime, () async {
      try {
        // Check cache first
        if (_cachedLeads.containsKey(searchKey)) {
          controller.add(_cachedLeads[searchKey]!);
          return;
        }

        // Execute search
        final query = _leadsCollection
            .where('userId', isEqualTo: AuthService.currentUserId)
            .orderBy('name')
            .startAt([searchQuery])
            .endAt([searchQuery + '\uf8ff'])
            .limit(50);

        final snapshot = await query.get();
        final results = snapshot.docs.map((doc) {
          return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        // Cache results
        _cachedLeads[searchKey] = results;
        controller.add(results);
      } catch (e) {
        controller.addError(e);
      }
    });

    return controller.stream;
  }

  /// 🔥 OPTIMIZATION 6: Selective Refresh - Only New Data
  ///
  /// Fetches only leads updated since last fetch
  static Stream<List<Lead>> getSelectivelyRefreshedLeads() async* {
    try {
      final now = DateTime.now();

      // If no previous fetch, get recent data
      final since = _lastLeadsFetch ?? now.subtract(const Duration(days: 7));

      final query = _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('updatedAt', descending: true)
          .limit(100);

      final snapshot = await query.get();
      final newLeads = snapshot.docs.map((doc) {
        return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      _lastLeadsFetch = now;
      yield newLeads;

    } catch (e) {
      print('Error in selective refresh: $e');
      yield [];
    }
  }

  /// 🔥 OPTIMIZATION: Enhanced Follow-up Creation with Denormalization
  static Future<String> createOptimizedFollowUp(FollowUp followUp) async {
    final batch = _firestore.batch();

    try {
      // Create follow-up
      final followUpRef = _followUpsCollection.doc();
      batch.set(followUpRef, followUp.toMap());

      // Update lead with denormalized follow-up data
      final leadRef = _leadsCollection.doc(followUp.leadId);
      batch.update(leadRef, {
        'lastFollowUp': {
          'id': followUpRef.id,
          'scheduledAt': Timestamp.fromDate(followUp.scheduledAt),
          'title': followUp.title,
          'status': followUp.status.toString(),
        },
        'followUpCount': FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
        'isHot': followUp.scheduledAt.isBefore(DateTime.now().add(const Duration(hours: 24))),
      });

      // Update summary
      await _updateSummaryStats(batch, followUpCount: 1);

      await batch.commit();

      // Clear caches
      _clearFollowUpCaches();

      return followUpRef.id;
    } catch (e) {
      print('Error creating optimized follow-up: $e');
      rethrow;
    }
  }

  /// 🔥 UTILITY: Update Summary Statistics
  static Future<void> _updateSummaryStats(
      WriteBatch batch, {
        int leadCount = 0,
        int followUpCount = 0,
        int remarkCount = 0,
      }) async {
    final summaryRef = _summaryCollection.doc('${AuthService.currentUserId}_stats');

    final updateData = <String, dynamic>{};
    if (leadCount != 0) updateData['totalLeads'] = FieldValue.increment(leadCount);
    if (followUpCount != 0) updateData['totalFollowUps'] = FieldValue.increment(followUpCount);
    if (remarkCount != 0) updateData['totalRemarks'] = FieldValue.increment(remarkCount);
    updateData['lastUpdated'] = FieldValue.serverTimestamp();

    batch.set(summaryRef, updateData, SetOptions(merge: true));
  }

  /// 🔥 UTILITY: Calculate and Store Summary (Fallback)
  static Future<DashboardSummary> _calculateAndStoreSummary() async {
    try {
      // Get actual counts (expensive operation - only as fallback)
      final leadsQuery = await _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .get();

      final followUpsQuery = await _followUpsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .where('status', isEqualTo: FollowUpStatus.pending.toString())
          .get();

      final summary = DashboardSummary(
        totalLeads: leadsQuery.docs.length,
        totalFollowUps: followUpsQuery.docs.length,
        totalRemarks: 0, // Can be calculated separately if needed
        lastUpdated: DateTime.now(),
      );

      // Store for future use
      await _summaryCollection
          .doc('${AuthService.currentUserId}_stats')
          .set(summary.toMap());

      return summary;
    } catch (e) {
      print('Error calculating summary: $e');
      return DashboardSummary.empty();
    }
  }

  /// 🔥 UTILITY: Cache Management
  static String _buildCacheKey(
      String? statusFilter,
      List<String>? projectFilters,
      List<String>? sourceFilters,
      DateTimeRange? dateRange,
      ) {
    return [
      statusFilter ?? 'all',
      projectFilters?.join(',') ?? 'all',
      sourceFilters?.join(',') ?? 'all',
      dateRange?.start.millisecondsSinceEpoch.toString() ?? 'all',
      dateRange?.end.millisecondsSinceEpoch.toString() ?? 'all',
    ].join('_');
  }

  static void _clearLeadCaches() {
    _cachedLeads.clear();
    _lastDocuments.clear();
    _hasMoreData.clear();
  }

  static void _clearFollowUpCaches() {
    // Clear follow-up related caches
    _lastFollowUpsFetch = null;
  }

  /// 🔥 UTILITY: Get Cached Lead Count (for quick stats)
  static int getCachedLeadCount(String cacheKey) {
    return _cachedLeads[cacheKey]?.length ?? 0;
  }

  /// 🔥 UTILITY: Preload Critical Data
  static Future<void> preloadCriticalData() async {
    try {
      // Preload dashboard stats
      await getOptimizedDashboardStats();

      // Preload recent leads
      await getPaginatedLeads().first;

      print('✅ Critical data preloaded');
    } catch (e) {
      print('⚠️ Error preloading data: $e');
    }
  }

  /// 🔥 CLEANUP: Dispose resources
  static void dispose() {
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Clear caches
    _cachedLeads.clear();
    _lastDocuments.clear();
    _hasMoreData.clear();
  }
}

/// 📊 Data Models for Optimized Operations

class PaginatedLeadsResult {
  final List<Lead> leads;
  final bool hasMore;
  final bool isLoading;
  final String? error;

  PaginatedLeadsResult({
    required this.leads,
    required this.hasMore,
    required this.isLoading,
    this.error,
  });
}

class DashboardSummary {
  final int totalLeads;
  final int totalFollowUps;
  final int totalRemarks;
  final DateTime lastUpdated;

  DashboardSummary({
    required this.totalLeads,
    required this.totalFollowUps,
    required this.totalRemarks,
    required this.lastUpdated,
  });

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalLeads: map['totalLeads'] ?? 0,
      totalFollowUps: map['totalFollowUps'] ?? 0,
      totalRemarks: map['totalRemarks'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalLeads': totalLeads,
      'totalFollowUps': totalFollowUps,
      'totalRemarks': totalRemarks,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory DashboardSummary.empty() {
    return DashboardSummary(
      totalLeads: 0,
      totalFollowUps: 0,
      totalRemarks: 0,
      lastUpdated: DateTime.now(),
    );
  }
}

/// 🚀 INTEGRATION EXAMPLES:
///
/// 1. Enable caching in main.dart:
///    ```dart
///    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
///    await OptimizationService.enableFirestoreCache();
///    ```
///
/// 2. Replace getLeads() calls:
///    ```dart
///    // OLD: DatabaseService.getLeads()
///    // NEW: OptimizationService.getPaginatedLeads()
///    ```
///
/// 3. Replace dashboard stats:
///    ```dart
///    // OLD: Count documents manually
///    // NEW: OptimizationService.getOptimizedDashboardStats()
///    ```
///
/// 4. Add load more functionality:
///    ```dart
///    onLoadMore: () {
///      OptimizationService.getPaginatedLeads(loadMore: true);
///    }
///    ```
///
/// 5. Use debounced search:
///    ```dart
///    OptimizationService.getDebouncedSearchResults(searchQuery)
///    ```