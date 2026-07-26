import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nama;
  final String idPengguna; // No. Matrik / Staff ID
  final String emel;
  final String peranan; // pelajar, kakitangan, pegawai_keselamatan, admin
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.nama,
    required this.idPengguna,
    required this.emel,
    required this.peranan,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nama: data['nama'] ?? '',
      idPengguna: data['idPengguna'] ?? '',
      emel: data['emel'] ?? '',
      peranan: data['peranan'] ?? 'pelajar',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'nama': nama,
      'idPengguna': idPengguna,
      'emel': emel,
      'peranan': peranan,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  bool get isPelajar => peranan == 'pelajar';
  bool get isKakitangan => peranan == 'kakitangan';
  bool get isPegawaiKeselamatan => peranan == 'pegawai_keselamatan';
  bool get isAdmin => peranan == 'admin';
}
