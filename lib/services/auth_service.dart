// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return _fetchUser(cred.user!.uid);
  }

  Future<AppUser?> register(
      String name, String email, String password) async {
    debugPrint('[AuthService] Starting registration for $email');
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    debugPrint('[AuthService] Auth user created: ${cred.user!.uid}. Updating display name...');
    await cred.user!.updateDisplayName(name);
    
    final user = AppUser(
      uid: cred.user!.uid,
      name: name,
      email: email,
      preferences: UserPreferences(),
    );
    
    debugPrint('[AuthService] Saving user profile to Firestore...');
    await _db.collection('users').doc(user.uid).set(user.toMap());
    
    debugPrint('[AuthService] Registration complete!');
    return user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser?> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  Future<AppUser?> getCurrentAppUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _fetchUser(u.uid);
  }

  Future<void> updatePreferences(
      String uid, UserPreferences prefs) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'preferences': prefs.toMap()});
  }

  Future<void> updateProfile(String uid, {String? name}) async {
    if (name != null) {
      await _auth.currentUser?.updateDisplayName(name);
      await _db.collection('users').doc(uid).update({'name': name});
    }
  }

  Future<void> updateContacts(String uid, List<String> contacts) async {
    await _db.collection('users').doc(uid).update({'trustedContacts': contacts});
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
