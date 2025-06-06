import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'lead_model.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static CollectionReference get _leadsCollection =>
      _firestore.collection('leads');
  static CollectionReference get _remarksCollection =>
      _firestore.collection('remarks');
  static CollectionReference get _followUpsCollection =>
      _firestore.collection('followUps');

  // LEAD OPERATIONS

  // Check if lead exists with the same mobile number
  static Future<bool> checkLeadExists(String mobile) async {
    try {
      final query = await _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking lead existence: $e');
      return false;
    }
  }

  static Future<String> createLead(Lead lead) async {
    try {
      final docRef = await _leadsCollection.add(lead.toMap());

      // Add system remark for lead creation
      await addRemark(
        leadId: docRef.id,
        content: 'Lead created in ${lead.status} status',
        type: RemarkType.leadCreated,
      );

      return docRef.id;
    } catch (e) {
      print('Error creating lead: $e');
      rethrow;
    }
  }

  static Future<void> updateLead(Lead lead) async {
    try {
      await _leadsCollection.doc(lead.id).update(lead.toMap());
    } catch (e) {
      print('Error updating lead: $e');
      rethrow;
    }
  }

  static Future<void> deleteLead(String leadId) async {
    try {
      // Delete lead
      await _leadsCollection.doc(leadId).delete();

      // Delete associated remarks
      final remarksQuery = await _remarksCollection
          .where('leadId', isEqualTo: leadId)
          .get();

      final batch = _firestore.batch();
      for (final doc in remarksQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete associated follow-ups
      final followUpsQuery = await _followUpsCollection
          .where('leadId', isEqualTo: leadId)
          .get();

      for (final doc in followUpsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting lead: $e');
      rethrow;
    }
  }

  static Stream<List<Lead>> getLeads({
    String? statusFilter,
    List<String>? projectFilters,
    List<String>? sourceFilters,
  }) {
    try {
      Query query = _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .orderBy('updatedAt', descending: true);

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      if (projectFilters != null && projectFilters.isNotEmpty) {
        query = query.where('projects', arrayContainsAny: projectFilters);
      }

      if (sourceFilters != null && sourceFilters.isNotEmpty) {
        query = query.where('sources', arrayContainsAny: sourceFilters);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting leads: $e');
      return const Stream.empty();
    }
  }

  // New method with date filtering
  static Stream<List<Lead>> getLeadsWithDateFilter({
    String? statusFilter,
    List<String>? projectFilters,
    List<String>? sourceFilters,
    DateTimeRange? dateRange,
  }) {
    try {
      Query query = _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId);

      // Apply date filter first if provided
      if (dateRange != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('createdAt', isLessThan: Timestamp.fromDate(dateRange.end));
      }

      // Order by createdAt when using date filter, otherwise by updatedAt
      if (dateRange != null) {
        query = query.orderBy('createdAt', descending: true);
      } else {
        query = query.orderBy('updatedAt', descending: true);
      }

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      if (projectFilters != null && projectFilters.isNotEmpty) {
        query = query.where('projects', arrayContainsAny: projectFilters);
      }

      if (sourceFilters != null && sourceFilters.isNotEmpty) {
        query = query.where('sources', arrayContainsAny: sourceFilters);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting leads with date filter: $e');
      return const Stream.empty();
    }
  }

  static Future<Lead?> getLead(String leadId) async {
    try {
      final doc = await _leadsCollection.doc(leadId).get();
      if (doc.exists) {
        return Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting lead: $e');
      return null;
    }
  }

  static Future<void> updateLeadStatus(String leadId, String newStatus, String oldStatus) async {
    try {
      await _leadsCollection.doc(leadId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add system remark for status change
      await addRemark(
        leadId: leadId,
        content: 'Status changed from $oldStatus to $newStatus',
        type: RemarkType.statusChanged,
      );
    } catch (e) {
      print('Error updating lead status: $e');
      rethrow;
    }
  }

  // REMARK OPERATIONS

  static Future<String> addRemark({
    required String leadId,
    required String content,
    required RemarkType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final remark = Remark(
        id: '',
        leadId: leadId,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        userId: AuthService.currentUserId!,
        metadata: metadata,
      );

      final docRef = await _remarksCollection.add(remark.toMap());

      // Update lead's updatedAt timestamp
      await _leadsCollection.doc(leadId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error adding remark: $e');
      rethrow;
    }
  }

  static Stream<List<Remark>> getRemarks(String leadId) {
    try {
      return _remarksCollection
          .where('leadId', isEqualTo: leadId)
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return Remark.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting remarks: $e');
      return Stream.value([]); // Return empty stream instead of const Stream.empty()
    }
  }

  // FOLLOW-UP OPERATIONS

  static Future<String> createFollowUp(FollowUp followUp) async {
    try {
      print('Starting createFollowUp for leadId: ${followUp.leadId}');

      // First, check if there's already a pending follow-up for this lead
      final existingFollowUps = await _followUpsCollection
          .where('leadId', isEqualTo: followUp.leadId)
          .where('status', isEqualTo: FollowUpStatus.pending.toString())
          .get();

      print('Found ${existingFollowUps.docs.length} existing follow-ups');

      // Cancel any existing pending follow-ups
      if (existingFollowUps.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in existingFollowUps.docs) {
          batch.update(doc.reference, {
            'status': FollowUpStatus.cancelled.toString(),
          });
        }
        await batch.commit();
        print('Cancelled ${existingFollowUps.docs.length} existing follow-ups');

        // Add remark for cancelled follow-ups
        await addRemark(
          leadId: followUp.leadId,
          content: 'Previous follow-up cancelled - New follow-up scheduled',
          type: RemarkType.followUpSet,
        );
      }

      // Create new follow-up
      print('Creating new follow-up with data: ${followUp.toMap()}');
      final docRef = await _followUpsCollection.add(followUp.toMap());
      print('Follow-up created with ID: ${docRef.id}');

      // Add system remark for follow-up creation
      final remarkContent = 'Follow-up scheduled for ${_formatDateTime(followUp.scheduledAt)} - ${followUp.title}';
      print('Adding remark: $remarkContent');

      await addRemark(
        leadId: followUp.leadId,
        content: remarkContent,
        type: RemarkType.followUpSet,
        metadata: {
          'followUpId': docRef.id,
          'scheduledAt': followUp.scheduledAt.toIso8601String(),
        },
      );

      print('Follow-up creation completed successfully');
      return docRef.id;
    } catch (e) {
      print('Error creating follow-up: $e');
      print('Follow-up data: ${followUp.toMap()}');
      rethrow;
    }
  }

  static Future<void> updateFollowUp(FollowUp followUp) async {
    try {
      await _followUpsCollection.doc(followUp.id).update(followUp.toMap());
    } catch (e) {
      print('Error updating follow-up: $e');
      rethrow;
    }
  }

  static Future<void> snoozeFollowUp(String followUpId, DateTime newTime) async {
    try {
      final followUp = await getFollowUp(followUpId);
      if (followUp == null) return;

      await _followUpsCollection.doc(followUpId).update({
        'scheduledAt': Timestamp.fromDate(newTime),
        'status': FollowUpStatus.pending.toString(),
      });

      // Add system remark for snoozing
      await addRemark(
        leadId: followUp.leadId,
        content: 'Follow-up snoozed to ${_formatDateTime(newTime)}',
        type: RemarkType.followUpSnoozed,
        metadata: {
          'followUpId': followUpId,
          'newScheduledAt': newTime.toIso8601String(),
          'originalScheduledAt': followUp.scheduledAt.toIso8601String(),
        },
      );
    } catch (e) {
      print('Error snoozing follow-up: $e');
      rethrow;
    }
  }

  static Future<void> completeFollowUp(String followUpId, String completionNote) async {
    try {
      final followUp = await getFollowUp(followUpId);
      if (followUp == null) return;

      await _followUpsCollection.doc(followUpId).update({
        'status': FollowUpStatus.completed.toString(),
        'completedAt': FieldValue.serverTimestamp(),
        'completionNote': completionNote,
      });

      // Add system remark for completion
      await addRemark(
        leadId: followUp.leadId,
        content: 'Follow-up completed${completionNote.isNotEmpty ? ': $completionNote' : ''}',
        type: RemarkType.followUpCompleted,
        metadata: {
          'followUpId': followUpId,
          'completionNote': completionNote,
        },
      );
    } catch (e) {
      print('Error completing follow-up: $e');
      rethrow;
    }
  }

  static Future<FollowUp?> getFollowUp(String followUpId) async {
    try {
      final doc = await _followUpsCollection.doc(followUpId).get();
      if (doc.exists) {
        return FollowUp.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting follow-up: $e');
      return null;
    }
  }

  static Stream<List<FollowUp>> getFollowUps({
    String? leadId,
    FollowUpStatus? status,
    bool todayOnly = false,
  }) {
    try {
      Query query = _followUpsCollection
          .where('userId', isEqualTo: AuthService.currentUserId);

      if (leadId != null) {
        query = query.where('leadId', isEqualTo: leadId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString());
      }

      if (todayOnly) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        query = query
            .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      query = query.orderBy('scheduledAt');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return FollowUp.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting follow-ups: $e');
      return Stream.value([]); // Return empty stream
    }
  }

  static Stream<List<FollowUp>> getPendingFollowUps() {
    return getFollowUps(status: FollowUpStatus.pending);
  }

  static Stream<List<FollowUp>> getTodayFollowUps() {
    return getFollowUps(status: FollowUpStatus.pending, todayOnly: true);
  }

  // UTILITY METHODS

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Update custom fields with data migration
  static Future<void> updateCustomFieldsWithMigration(
      Map<String, List<String>> newCustomFields,
      Map<String, List<String>> oldCustomFields,
      ) async {
    if (AuthService.currentUserId == null) return;

    try {
      final batch = _firestore.batch();

      // Check for renamed fields and update all leads accordingly
      for (String fieldType in ['statuses', 'projects', 'sources']) {
        final oldValues = oldCustomFields[fieldType] ?? [];
        final newValues = newCustomFields[fieldType] ?? [];

        // Find renamed values (same position, different name)
        for (int i = 0; i < oldValues.length && i < newValues.length; i++) {
          final oldValue = oldValues[i];
          final newValue = newValues[i];

          if (oldValue != newValue) {
            // This field was renamed, update all leads using this value
            await _updateLeadsWithRenamedField(fieldType, oldValue, newValue, batch);
          }
        }
      }

      // Update the user's custom fields
      final userDocRef = _firestore.collection('users').doc(AuthService.currentUserId);
      batch.update(userDocRef, {
        'customFields': newCustomFields,
      });

      await batch.commit();
      print('Custom fields updated with data migration completed');
    } catch (e) {
      print('Error updating custom fields with migration: $e');
      rethrow;
    }
  }

  static Future<void> _updateLeadsWithRenamedField(
      String fieldType,
      String oldValue,
      String newValue,
      WriteBatch batch,
      ) async {
    try {
      Query query;

      if (fieldType == 'statuses') {
        // For status, it's a direct field
        query = _leadsCollection
            .where('userId', isEqualTo: AuthService.currentUserId)
            .where('status', isEqualTo: oldValue);
      } else {
        // For projects and sources, they are arrays
        query = _leadsCollection
            .where('userId', isEqualTo: AuthService.currentUserId)
            .where(fieldType, arrayContains: oldValue);
      }

      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (fieldType == 'statuses') {
          // Update status field directly
          batch.update(doc.reference, {
            'status': newValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update array fields (projects/sources)
          final currentArray = List<String>.from(data[fieldType] ?? []);
          final updatedArray = currentArray.map((item) =>
          item == oldValue ? newValue : item
          ).toList();

          batch.update(doc.reference, {
            fieldType: updatedArray,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      print('Updated ${snapshot.docs.length} leads for $fieldType: $oldValue -> $newValue');
    } catch (e) {
      print('Error updating leads with renamed field: $e');
    }
  }

  // STATISTICS

  static Future<Map<String, int>> getLeadStatistics() async {
    try {
      final snapshot = await _leadsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .get();

      final stats = <String, int>{};

      for (final doc in snapshot.docs) {
        final lead = Lead.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        stats[lead.status] = (stats[lead.status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting lead statistics: $e');
      return {};
    }
  }

  static Future<int> getActiveFollowUpsCount() async {
    try {
      final snapshot = await _followUpsCollection
          .where('userId', isEqualTo: AuthService.currentUserId)
          .where('status', isEqualTo: FollowUpStatus.pending.toString())
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting active follow-ups count: $e');
      return 0;
    }
  }
}