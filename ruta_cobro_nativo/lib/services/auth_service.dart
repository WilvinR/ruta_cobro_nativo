import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user!);
    return result;
  }

  Future<void> _ensureUserDoc(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final name = u.displayName ?? (u.email ?? '').split('@').first;
      final code = await _newCode(name);
      await ref.set({
        'name': name,
        'email': u.email ?? '',
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> _newCode(String name) async {
    final initials = _initials(name);
    for (var i = 0; i < 15; i++) {
      final code = 'RC-$initials${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
      final ref = _db.collection('codes').doc(code);
      final exists = (await ref.get()).exists;
      if (!exists) {
        await ref.set({'t': 1});
        return code;
      }
    }
    return 'RC-XX${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  String _initials(String n) {
    final w = n
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (w.isEmpty) return 'XX';
    if (w.length > 1) {
      return (w[0][0] + w[1][0]).toUpperCase();
    }
    return w[0].substring(0, w[0].length >= 2 ? 2 : 1).toUpperCase().padRight(2, 'X');
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final u = currentUser;
    if (u == null) return null;
    final snap = await _db.collection('users').doc(u.uid).get();
    return snap.data();
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
