/// Egyptian local mobile numbers or international E.164 numbers.
String normalizePhone(String input) {
  var phone = input.trim();
  for (var i = 0; i < 10; i++) {
    phone = phone
        .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
        .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  phone = phone.replaceAll(RegExp(r'[\s()\-]'), '');
  if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
  if (RegExp(r'^01[0125]\d{8}$').hasMatch(phone))
    phone = '+20${phone.substring(1)}';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
    throw const FormatException(
      'Enter a mobile number with country code, e.g. +201012345678.',
    );
  }
  return phone;
}
