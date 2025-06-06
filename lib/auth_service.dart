import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  // Sign up with simplified approach
  static Future<UserCredential> signUp(String email, String password, String name) async {
    try {
      print('Starting signup process with name: $name');

      // Create user with email and password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('User created successfully: ${credential.user?.uid}');

      // Try to update display name (but don't fail if it errors)
      try {
        await credential.user!.updateDisplayName(name);
        await credential.user!.reload(); // Refresh user data
        print('Display name updated to: $name');
      } catch (e) {
        print('Warning: Could not update Firebase Auth display name: $e');
        // Continue anyway - we'll use the name from Firestore
      }

      // Create user profile document in Firestore - THIS IS THE IMPORTANT PART
      final userDoc = {
        'name': name, // Use the actual name parameter, not displayName
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'customFields': {
          'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
          'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
          'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
        },
      };

      print('Creating user document with name: $name');

      // Save to Firestore with retry mechanism
      await _createUserDocument(credential.user!.uid, userDoc);

      // Setup FCM token
      await _setupFCMToken(credential.user!.uid);

      print('Signup completed successfully with name: $name');
      return credential;

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('General Error during signup: $e');
      // If it's the PigeonUserDetails error, try a different approach
      if (e.toString().contains('PigeonUserDetails') || e.toString().contains('PigeonUserInfo')) {
        return await _handlePigeonError(email, password, name);
      }
      rethrow;
    }
  }

  // Alternative signup method for PigeonUserDetails error
  static Future<UserCredential> _handlePigeonError(String email, String password, String name) async {
    try {
      print('Handling PigeonUserDetails error with alternative method...');
      print('Using name: $name');

      // Try to create user with minimal approach
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('User created via alternative method: ${credential.user?.uid}');

      // Wait a moment for auth to settle
      await Future.delayed(const Duration(milliseconds: 500));

      // Create user document directly with the actual name
      final userDoc = {
        'name': name, // Use the actual name parameter passed to the function
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'customFields': {
          'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
          'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
          'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
        },
      };

      print('Creating user document via alternative method with name: $name');
      await _firestore.collection('users').doc(credential.user!.uid).set(userDoc);
      print('User document created via alternative method with correct name: $name');

      return credential;
    } catch (e) {
      print('Alternative signup method also failed: $e');
      rethrow;
    }
  }

  // Helper method to create user document with retry
  static Future<void> _createUserDocument(String uid, Map<String, dynamic> userDoc) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await _firestore.collection('users').doc(uid).set(userDoc);
        print('User document created successfully in Firestore');
        return;
      } catch (e) {
        retries--;
        print('Failed to create user document, retries left: $retries, error: $e');
        if (retries == 0) rethrow;
        await Future.delayed(Duration(seconds: 2 - retries));
      }
    }
  }

  // Setup FCM token
  static Future<void> _setupFCMToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
        print('FCM Token saved: $token');
      }
    } catch (e) {
      print('Error setting up FCM token: $e');
      // Don't throw error for FCM issues
    }
  }

  // Sign in
  static Future<UserCredential> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure user document exists
      await _ensureUserDocumentExists();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Ensure user document exists (for existing users)
  static Future<void> _ensureUserDocumentExists() async {
    if (currentUserId == null) return;

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();

      if (!doc.exists) {
        print('User document missing, creating...');
        // Get the actual name from Firebase Auth or prompt user
        String userName = _auth.currentUser?.displayName ?? 'User';
        String userEmail = _auth.currentUser?.email ?? '';

        print('Creating user document with name: $userName, email: $userEmail');

        final userDoc = {
          'name': userName,
          'email': userEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'customFields': {
            'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
            'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
            'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
          },
        };

        await _firestore.collection('users').doc(currentUserId).set(userDoc);
        print('Missing user document created with name: $userName');
      }
    } catch (e) {
      print('Error ensuring user document exists: $e');
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUserId == null) {
      print('No current user ID');
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();

      if (doc.exists) {
        final data = doc.data();
        print('User profile found: $data');
        return data;
      } else {
        print('User document does not exist, creating...');
        await _ensureUserDocumentExists();

        // Try again after creating
        final newDoc = await _firestore.collection('users').doc(currentUserId).get();
        final data = newDoc.data();
        print('User profile after creation: $data');
        return data;
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get custom fields
  static Future<Map<String, List<String>>> getCustomFields() async {
    try {
      final profile = await getUserProfile();

      if (profile != null && profile['customFields'] != null) {
        final customFields = profile['customFields'] as Map<String, dynamic>;
        return {
          'statuses': List<String>.from(customFields['statuses'] ?? []),
          'projects': List<String>.from(customFields['projects'] ?? []),
          'sources': List<String>.from(customFields['sources'] ?? []),
        };
      }
    } catch (e) {
      print('Error getting custom fields: $e');
    }

    // Return defaults if error or no custom fields
    return {
      'statuses': ['New', 'Contacted', 'Qualified', 'Negotiation', 'Closed Won', 'Closed Lost'],
      'projects': ['Residential', 'Commercial', 'Luxury Homes', 'Affordable Housing'],
      'sources': ['Website', 'Referral', 'Social Media', 'Cold Call', 'Walk-in', 'Advertisement'],
    };
  }

  // Update custom fields
  static Future<void> updateCustomFields(Map<String, List<String>> customFields) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'customFields': customFields,
      });
    } catch (e) {
      print('Error updating custom fields: $e');
      rethrow;
    }
  }

  // Update user profile - simplified to avoid PigeonUserInfo issues
  static Future<void> updateUserProfile({
    String? name,
    String? email,
  }) async {
    if (currentUserId == null) return;

    try {
      final updates = <String, dynamic>{};

      if (name != null) {
        updates['name'] = name;
        // Don't update Firebase Auth displayName to avoid PigeonUserInfo error
        // Just update Firestore document
      }

      if (email != null) {
        updates['email'] = email;
        // Don't update Firebase Auth email to avoid PigeonUserInfo error
        // Just update Firestore document
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(currentUserId).update(updates);
        print('User profile updated successfully: $updates');
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  // Get current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Delete user account
  static Future<void> deleteAccount() async {
    if (currentUserId == null) return;

    try {
      // Delete user document
      await _firestore.collection('users').doc(currentUserId).delete();

      // Delete user account
      await currentUser?.delete();
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Verify email
  static Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
      rethrow;
    }
  }

  // Add custom field value (helper method for backwards compatibility)
  static Future<void> addCustomFieldValue(String fieldType, String value) async {
    try {
      final currentFields = await getCustomFields();
      final fieldList = List<String>.from(currentFields[fieldType] ?? []);

      if (!fieldList.contains(value)) {
        fieldList.add(value);
        currentFields[fieldType] = fieldList;
        await updateCustomFields(currentFields);
      }
    } catch (e) {
      print('Error adding custom field value: $e');
      rethrow;
    }
  }

  // Update specific custom field (helper method for backwards compatibility)
  static Future<void> updateCustomField(String fieldType, List<String> values) async {
    try {
      final currentFields = await getCustomFields();
      currentFields[fieldType] = values;
      await updateCustomFields(currentFields);
    } catch (e) {
      print('Error updating custom field: $e');
      rethrow;
    }
  }
}