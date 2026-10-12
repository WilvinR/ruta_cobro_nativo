class Client {
  final String id;
  String name;
  String phone;
  String ref;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    this.ref = '',
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        phone: m['phone']?.toString() ?? '',
        ref: m['ref']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'ref': ref,
      };

  Client copyWith({String? name, String? phone, String? ref}) => Client(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        ref: ref ?? this.ref,
      );
}
