const profileGenders = ['', 'Male', 'Female', 'Other'];

String? validateProfileName(String? value) {
  final length = value?.trim().length ?? 0;
  return length < 2 || length > 80 ? 'Enter 2–80 characters.' : null;
}

void validateProfile({required String name, required String gender}) {
  final error = validateProfileName(name);
  if (error != null) throw FormatException(error);
  if (!profileGenders.contains(gender)) {
    throw const FormatException('Choose a valid gender.');
  }
}
