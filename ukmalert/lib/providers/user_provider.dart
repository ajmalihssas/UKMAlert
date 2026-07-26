import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // Convenience getters — treat empty strings same as null so fallbacks work
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get idPengguna {
    final v = _currentUser?.idPengguna ?? '';
    return v.isNotEmpty ? v : uid;
  }
  String get nama {
    final v = _currentUser?.nama ?? '';
    return v.isNotEmpty ? v : (FirebaseAuth.instance.currentUser?.displayName ?? '');
  }
  String get emel {
    final v = _currentUser?.emel ?? '';
    return v.isNotEmpty ? v : (FirebaseAuth.instance.currentUser?.email ?? '');
  }
  String get peranan => _currentUser?.peranan ?? 'pelajar';

  bool get isPelajar => peranan == 'pelajar';
  bool get isKakitangan => peranan == 'kakitangan';
  bool get isPegawaiKeselamatan => peranan == 'pegawai_keselamatan';
  bool get isAdmin => peranan == 'admin';
  bool get isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

  /// Load current user data from Firestore. Call after login.
  Future<void> loadUser() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.isAnonymous) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('UserProvider.loadUser error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Listen to real-time updates on the user document.
  void startListening() {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.isAnonymous) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
        notifyListeners();
      }
    });
  }

  void clear() {
    _currentUser = null;
    notifyListeners();
  }
}
