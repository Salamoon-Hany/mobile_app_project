String normalizeNationalId(String value) {
  var v = value.trim();
  for (var i = 0; i < 10; i++) {
    v = v.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i').replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  return v;
}

String? nationalIdError(String value) {
  final id = normalizeNationalId(value);
  if (id.isEmpty) return null;
  const error = 'Enter a valid 14-digit Egyptian national ID.';
  if (!RegExp(r'^[23]\d{13}$').hasMatch(id)) return error;
  final year = (id[0] == '2' ? 1900 : 2000) + int.parse(id.substring(1, 3)),
      month = int.parse(id.substring(3, 5)),
      day = int.parse(id.substring(5, 7));
  final date = DateTime.utc(year, month, day);
  return date.year != year ||
          date.month != month ||
          date.day != day ||
          date.isAfter(DateTime.now())
      ? error
      : null;
}

int profileCompletion({
  required String name,
  required String email,
  required String phone,
  required String gender,
  required bool hasPhoto,
  bool worker = false,
  bool hasId = false,
}) {
  final fields = [
    name.trim().length >= 2,
    email.contains('@'),
    phone.trim().isNotEmpty,
    gender.isNotEmpty,
    hasPhoto,
    if (worker) hasId,
  ];
  return (fields.where((v) => v).length * 100 / fields.length).round();
}
