import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'lead_model.dart';

/// Firestore optimization utilities.
///
/// These helper methods provide optional features to reduce reads and writes
/// without altering the existing database structure.
class FirestoreOptimization {
  FirestoreOptimization._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enables offline persistence so that reads can be served from cache.
  static Future<void> enableOfflinePersistence() async {
    try {
      await _firestore.enablePersistence();
    } catch (_) {
      // ignore if persistence already enabled or not supported
    }
  }

  // Pagination state
  static const int _pageSize = 20;
  static DocumentSnapshot? _lastLeadDoc;
  static bool _hasMoreLeads = true;

  /// Returns the next page of leads. Call with [loadMore] = false for the first
  /// page and true for subsequent pages.
  static Future<List<Lead>> fetchLeadsPage({bool loadMore = false}) async {
    Query query = _firestore
        .collection('leads')
        .where('userId', isEqualTo: AuthService.currentUserId)
        .orderBy('updatedAt', descending: true)
        .limit(_pageSize);

    if (loadMore && _lastLeadDoc != null) {
      query = query.startAfterDocument(_lastLeadDoc!);
    }

    final snap = await query.get();
    if (snap.docs.isNotEmpty) {
      _lastLeadDoc = snap.docs.last;
    }
    if (snap.docs.length < _pageSize) {
      _hasMoreLeads = false;
    }
    return snap.docs
        .map((d) => Lead.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Whether more lead pages are available.
  static bool get hasMoreLeads => _hasMoreLeads;

  /// Creates a lead with denormalized summary fields and updates statistics.
  static Future<void> createLeadWithSummary(
    Lead lead, {
    String? initialRemark,
  }) async {
    final batch = _firestore.batch();

    final leadRef = _firestore.collection('leads').doc();
    final leadData = lead.toMap()
      ..['remarkCount'] = initialRemark != null ? 1 : 0
      ..['followUpCount'] = 0
      ..['latestRemark'] = initialRemark
      ..['latestFollowUp'] = null;
    batch.set(leadRef, leadData);

    if (initialRemark != null) {
      final remarkRef = _firestore.collection('remarks').doc();
      final remark = Remark(
        id: remarkRef.id,
        leadId: leadRef.id,
        content: initialRemark,
        type: RemarkType.note,
        createdAt: DateTime.now(),
        userId: AuthService.currentUserId!,
        metadata: null,
      );
      batch.set(remarkRef, remark.toMap());
    }

    _updateSummary(batch, leadDelta: 1);

    await batch.commit();
    _resetPagination();
  }

  /// Adds a follow-up and stores a short reference inside the lead document.
  static Future<void> createFollowUpWithSummary(FollowUp followUp) async {
    final batch = _firestore.batch();

    final fuRef = _firestore.collection('followUps').doc();
    batch.set(fuRef, followUp.toMap());

    final leadRef = _firestore.collection('leads').doc(followUp.leadId);
    batch.update(leadRef, {
      'latestFollowUp': {
        'id': fuRef.id,
        'title': followUp.title,
        'scheduledAt': Timestamp.fromDate(followUp.scheduledAt),
        'status': followUp.status.toString(),
      },
      'followUpCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _updateSummary(batch, followUpDelta: 1);

    await batch.commit();
    _resetPagination();
  }

  /// Debounced search. Results are emitted after the user stops typing.
  static Timer? _debounceTimer;
  static Stream<List<Lead>> searchLeads(String query,
      {Duration debounce = const Duration(milliseconds: 300)}) {
    final controller = StreamController<List<Lead>>();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      try {
        final snap = await _firestore
            .collection('leads')
            .where('userId', isEqualTo: AuthService.currentUserId)
            .orderBy('name')
            .startAt([query])
            .endAt([query + '\uf8ff'])
            .limit(20)
            .get();
        final results = snap.docs
            .map((d) => Lead.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        controller.add(results);
      } catch (e) {
        controller.addError(e);
      }
    });
    return controller.stream;
  }

  static DateTime? _lastFetchTime;

  /// Returns leads updated since the last fetch time to avoid full reload.
  static Future<List<Lead>> fetchNewLeads() async {
    final since = _lastFetchTime ?? DateTime.now().subtract(const Duration(days: 7));
    final snap = await _firestore
        .collection('leads')
        .where('userId', isEqualTo: AuthService.currentUserId)
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .get();
    _lastFetchTime = DateTime.now();
    return snap.docs
        .map((d) => Lead.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Updates summary statistics document.
  static void _updateSummary(WriteBatch batch,
      {int leadDelta = 0, int followUpDelta = 0}) {
    final summaryRef =
        _firestore.collection('summary').doc(AuthService.currentUserId);
    final data = <String, dynamic>{
      if (leadDelta != 0) 'totalLeads': FieldValue.increment(leadDelta),
      if (followUpDelta != 0)
        'totalFollowUps': FieldValue.increment(followUpDelta),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    batch.set(summaryRef, data, SetOptions(merge: true));
  }

  static void _resetPagination() {
    _lastLeadDoc = null;
    _hasMoreLeads = true;
  }
}


