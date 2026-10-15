const experienceCountries = <String, String>{
  'EG': 'Egypt',
  'AE': 'UAE',
  'SA': 'Saudi Arabia',
  'QA': 'Qatar',
  'KW': 'Kuwait',
  'BH': 'Bahrain',
  'OM': 'Oman',
  'PK': 'Pakistan',
  'IN': 'India',
};
int? parseExperienceYears(String input) {
  var value = input.trim();
  for (var i = 0; i < 10; i++) {
    value = value
        .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
        .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  if (!RegExp(r'^\d{1,2}$').hasMatch(value)) return null;
  final years = int.parse(value);
  return years <= 60 ? years : null;
}
