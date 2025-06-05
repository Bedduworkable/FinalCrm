import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  static Future<UserCredential> signUp(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile with retry mechanism
      final userDoc = {
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'customFields': {
          'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
          'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
          'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
        },
      };

      // Try to create user document with retries
      int attempts = 0;
      while (attempts < 3) {
        try {
          await _firestore.collection('users').doc(credential.user!.uid).set(userDoc);
          break; // Success, exit loop
        } catch (e) {
          attempts++;
          if (attempts >= 3) rethrow; // Rethrow on final attempt
          await Future.delayed(Duration(seconds: 1)); // Wait before retry
        }
      }

      // Update display name
      await credential.user!.updateDisplayName(name);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  static Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUserId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(currentUserId).update(data);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get custom fields (statuses, projects, sources)
  static Future<Map<String, List<String>>> getCustomFields() async {
    if (currentUserId == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      final data = doc.data();

      if (data != null && data['customFields'] != null) {
        final customFields = data['customFields'] as Map<String, dynamic>;
        return {
          'statuses': List<String>.from(customFields['statuses'] ?? []),
          'projects': List<String>.from(customFields['projects'] ?? []),
          'sources': List<String>.from(customFields['sources'] ?? []),
        };
      }

      // Return default values if no custom fields found
      return {
        'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
        'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
        'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
      };
    } catch (e) {
      print('Error getting custom fields: $e');
      return {};
    }
  }

  // Update custom fields
  static Future<void> updateCustomFields(String fieldType, List<String> values) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'customFields.$fieldType': values,
      });
    } catch (e) {
      print('Error updating custom fields: $e');
      rethrow;
    }
  }

  // Add new custom field value
  static Future<void> addCustomFieldValue(String fieldType, String value) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'customFields.$fieldType': FieldValue.arrayUnion([value]),
      });
    } catch (e) {
      print('Error adding custom field value: $e');
      rethrow;
    }
  }
}