part of 'dashboard.dart';

// Part 5: Profile Screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.picker});
  final ImagePicker? picker;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  String? _phoneError, _idError;
  bool _clearId = false;
  late final ImagePicker _picker;
  String? _selectedGender;
  Uint8List? _profileImageBytes;
  bool _pickingPhoto = false;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    // Pre-fill fields from saved global state
    _nameController.text = AppState.getUserName();
    _emailController.text = AppState.getUserEmail();
    _phone.text = AppState.getPhoneNumber();
    final gender = AppState.getUserGender();
    if (gender.isNotEmpty && profileGenders.contains(gender)) {
      _selectedGender = gender;
    }
    _profileImageBytes = AppState.getUserProfileImageBytes();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_pickingPhoto || _saving) return;
    setState(() => _pickingPhoto = true);
    try {
      if (kIsWeb && source == ImageSource.camera) {
        final bytes = await captureCamera(context);
        if (bytes != null && mounted)
          setState(() => _profileImageBytes = bytes);
        return;
      }
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _profileImageBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Photo selected. Press Done to save.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not choose a photo. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_red_eye_outlined),
                title: const AppText('View Picture'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_profileImageBytes != null)
                            Image.memory(_profileImageBytes!, height: 300)
                          else
                            Image.asset(
                              'Pics & Icons/Pic_Icon.png',
                              height: 300,
                            ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const AppText('Close'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const AppText('Upload a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const AppText('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const AppText(
                  'Delete Picture',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _profileImageBytes != null
                    ? () {
                        Navigator.pop(context);
                        setState(() {
                          _profileImageBytes = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: AppText(
                              'Picture removed (will be deleted on save)',
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phone.dispose();
    _nationalId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _pickingPhoto) return;
    final nameError = validateProfileName(_nameController.text);
    String? phoneError;
    String phone = '';
    try {
      if (_phone.text.trim().isNotEmpty) phone = normalizePhone(_phone.text);
    } on FormatException catch (e) {
      phoneError = e.message;
    }
    final idError = nationalIdError(_nationalId.text);
    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      _idError = idError;
    });
    if (nameError != null || phoneError != null || idError != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      if (Marketplace.enabled)
        await Marketplace.shared.saveProfile(
          name: _nameController.text.trim(),
          phone: phone,
          gender: _selectedGender ?? '',
          photo: _profileImageBytes,
          replacePhoto: true,
          nationalId:
              Marketplace.shared.isWorker &&
                  (_clearId || _nationalId.text.isNotEmpty)
              ? normalizeNationalId(_nationalId.text)
              : null,
        );
      await AccountService.saveProfile(
        name: _nameController.text,
        gender: _selectedGender ?? '',
      );
      AppState.setUserName(_nameController.text.trim());
      AppState.setUserGender(_selectedGender ?? '');
      AppState.setPhoneNumber(phone);
      AppState.setUserProfileImageBytes(_profileImageBytes);
      await LocalAccountStore.flush();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Profile saved')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              e is FormatException
                  ? e.message
                  : 'Profile could not be saved. Please retry.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editServices() async {
    final chosen = Set<String>.from(
      Marketplace.shared.account?['skills'] as List? ?? [],
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, change) => AlertDialog(
          title: const AppText('Services I provide'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final j in jobCatalog)
                    CheckboxListTile(
                      title: AppText(j.name),
                      value: chosen.contains(j.id),
                      onChanged: (v) => change(
                        () =>
                            v == true ? chosen.add(j.id) : chosen.remove(j.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Marketplace.shared.saveProfile(
        name: AppState.getUserName(),
        skills: chosen.toList(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Could not sync your account. Check your connection and retry.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final worker = Marketplace.shared.isWorker;
    final savedId =
        Marketplace.shared.account?['national_id_last4'] as String? ?? '';
    final hasId =
        (!_clearId && savedId.isNotEmpty) ||
        (_nationalId.text.isNotEmpty &&
            nationalIdError(_nationalId.text) == null);
    final progress = profileCompletion(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phone.text,
      gender: _selectedGender ?? '',
      hasPhoto: _profileImageBytes != null,
      worker: worker,
      hasId: hasId,
    );
    final busy = _saving || _pickingPhoto;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: SanadUi.canvas(context),
        appBar: AppBar(
          title: const AppText('My profile'),
          backgroundColor: SanadUi.surface(context),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            key: const Key('profile-back'),
            tooltip: tr('Back'),
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const ReferenceIcon('back', mirror: true),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: busy ? null : _showPhotoOptions,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFFEDF0E5),
                            backgroundImage: _profileImageBytes == null
                                ? null
                                : MemoryImage(_profileImageBytes!),
                            child: _profileImageBytes == null
                                ? const Icon(Icons.person_outline, size: 48)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFd7ff00),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(child: AppText('Profile photo')),
                  if (worker) ...[
                    const SizedBox(height: 8),
                    Text(
                      _nameController.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (Marketplace.shared.account?['skills'] as List? ?? [])
                          .map(
                            (id) => tr(
                              jobCatalog
                                      .where((j) => j.id == id)
                                      .firstOrNull
                                      ?.name ??
                                  '',
                            ),
                          )
                          .join(' • '),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SanadUi.muted(context)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  progress == 100
                                      ? 'Profile complete'
                                      : 'Complete your profile',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (progress == 100)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              Text(
                                '$progress%',
                                key: const Key('profile-completion'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: progress / 100,
                            color: progress == 100
                                ? Colors.green
                                : SanadUi.lime,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 10),
                          const AppText(
                            'Add your details to complete your profile.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    enabled: !busy,
                    onChanged: (_) => setState(() => _nameError = null),
                    decoration: InputDecoration(
                      labelText: tr('Name'),
                      filled: true,
                      fillColor: SanadUi.surface(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: trNullable(_nameError),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: tr('Email'),
                      filled: true,
                      fillColor: SanadUi.surface(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('profile-phone'),
                    controller: _phone,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() => _phoneError = null),
                    decoration: InputDecoration(
                      labelText: tr('Mobile number'),
                      hintText: '01012345678',
                      filled: true,
                      fillColor: SanadUi.surface(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: trNullable(_phoneError),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: tr('Gender'),
                      filled: true,
                      fillColor: SanadUi.surface(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: profileGenders
                        .where((g) => g.isNotEmpty)
                        .map(
                          (g) => DropdownMenuItem(value: g, child: AppText(g)),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _selectedGender = v),
                  ),
                  if (worker) ...[
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('profile-national-id'),
                      controller: _nationalId,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      onChanged: (_) => setState(() {
                        _idError = null;
                        _clearId = false;
                      }),
                      decoration: InputDecoration(
                        labelText: tr('National ID (optional)'),
                        hintText: savedId.isNotEmpty && !_clearId
                            ? '••••••••••$savedId'
                            : null,
                        filled: true,
                        fillColor: SanadUi.surface(context),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: trNullable(_idError),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppText(
                      'Only the last 4 digits are saved. Format checked; identity not verified.',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (savedId.isNotEmpty && !_clearId)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                _clearId = true;
                                _nationalId.clear();
                              }),
                        child: const AppText('Remove saved ID'),
                      ),
                  ],
                  if (worker) ...[
                    const SizedBox(height: 24),
                    SanadPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: AppText(
                                  'My services',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: busy ? null : _editServices,
                                child: const AppText('Edit'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final j in jobCatalog.where(
                                (j) =>
                                    (Marketplace.shared.account?['skills']
                                                as List? ??
                                            [])
                                        .contains(j.id),
                              ))
                                Chip(
                                  avatar: Image.asset(
                                    j.imagePath!,
                                    width: 28,
                                    height: 28,
                                  ),
                                  label: AppText(j.name),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Done'),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  TextButton.icon(
                    key: const Key('profile-delete-account'),
                    onPressed: busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeleteAccountScreen(),
                            ),
                          ),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const AppText(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
