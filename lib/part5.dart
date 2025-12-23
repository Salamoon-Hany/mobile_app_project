part of 'screens/dashboard.dart';

// Part 5: Profile Screen

class ProfileScreen extends StatefulWidget {
  final String phoneNumber;
  
  const ProfileScreen({super.key, required this.phoneNumber});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  String? _selectedGender;
  String? _profileImagePath;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields from saved global state
    _nameController.text = _MyAppState.getUserName();
    _emailController.text = _MyAppState.getUserEmail();
    final gender = _MyAppState.getUserGender();
    if (gender.isNotEmpty) {
      _selectedGender = gender;
    }
    // Load saved profile image path
    final savedImagePath = _MyAppState.getUserProfileImagePath();
    if (savedImagePath.isNotEmpty) {
      _profileImagePath = savedImagePath;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded from gallery'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera capture works on mobile devices only'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured from camera'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e'), duration: const Duration(seconds: 3)),
        );
      }
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
                title: const Text('View Picture'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_profileImagePath != null && !kIsWeb)
                            Image.file(File(_profileImagePath!), height: 300)
                          else
                            Image.asset('Pics & Icons/Pic_Icon.png', height: 300),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Picture', style: TextStyle(color: Colors.red)),
                onTap: _profileImagePath != null
                    ? () {
                        Navigator.pop(context);
                        setState(() {
                          _profileImagePath = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Picture removed (will be deleted on save)'),
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

  void _showEmailOptions() {
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
                leading: const Icon(Icons.verified_outlined),
                title: const Text('Verify email'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification link sent (demo).'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Change email'),
                onTap: () {
                  Navigator.pop(context);
                  _emailFocusNode.requestFocus();
                },
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
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const SizedBox(),
        title: const Text(
          'My profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Section
              const Text(
                'Profile photo',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _profileImagePath != null && !kIsWeb
                                ? FileImage(File(_profileImagePath!))
                                : const AssetImage('Pics & Icons/Pic_Icon.png') as ImageProvider,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFd7ff00),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Name Field
              const Text(
                'Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (value) {
                  _MyAppState.setUserName(value.trim());
                  setState(() {
                    // Clear error when user starts typing
                    if (_nameError != null) {
                      _nameError = null;
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _nameError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Email Field
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                focusNode: _emailFocusNode,
                decoration: InputDecoration(
                  hintText: 'Enter_Your_Email@gmail.com',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: _showEmailOptions,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Contact Field (Read-only, from verification)
              const Text(
                'Contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.phoneNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.verified,
                      color: Colors.green[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Gender Field
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedGender,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('Select gender'),
                  items: ['Male', 'Female'].map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
              // Done button at bottom to save and exit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd7ff00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Validate name is not empty
                    if (_nameController.text.trim().isEmpty) {
                      setState(() {
                        _nameError = 'This field is required';
                      });
                      return;
                    }
                    
                    // Get previous image path for change detection
                    final previousImagePath = _MyAppState.getUserProfileImagePath();
                    
                    // Persist values to global state
                    _MyAppState.setUserName(_nameController.text.trim());
                    _MyAppState.setUserEmail(_emailController.text.trim());
                    if (_selectedGender != null) {
                      _MyAppState.setUserGender(_selectedGender!);
                    }
                    
                    // Handle profile image changes and notifications
                    if (_profileImagePath != null) {
                      // Image was uploaded or changed
                      if (previousImagePath.isEmpty) {
                        // New picture uploaded
                        _MyAppState.setUserProfileImagePath(_profileImagePath!);
                        NotificationManager.addNotification(
                          NotificationModel(
                            id: DateTime.now().toString(),
                            title: 'Profile Picture Updated',
                            description: 'Your profile picture has been uploaded successfully.',
                            createdAt: DateTime.now(),
                            icon: '📸',
                            iconColor: Colors.purple,
                          ),
                        );
                      } else if (previousImagePath != _profileImagePath) {
                        // Picture was changed
                        _MyAppState.setUserProfileImagePath(_profileImagePath!);
                        NotificationManager.addNotification(
                          NotificationModel(
                            id: DateTime.now().toString(),
                            title: 'Profile Picture Changed',
                            description: 'Your profile picture has been changed.',
                            createdAt: DateTime.now(),
                            icon: '📸',
                            iconColor: Colors.purple,
                          ),
                        );
                      }
                    } else if (previousImagePath.isNotEmpty) {
                      // Picture was deleted
                      _MyAppState.setUserProfileImagePath('');
                      NotificationManager.addNotification(
                        NotificationModel(
                          id: DateTime.now().toString(),
                          title: 'Profile Picture Deleted',
                          description: 'Your profile picture has been removed.',
                          createdAt: DateTime.now(),
                          icon: '🗑️',
                          iconColor: Colors.red,
                        ),
                      );
                    }
                    
                    // Add notification for email change if it was updated
                    if (_emailController.text.trim().isNotEmpty) {
                      NotificationManager.addNotification(
                        NotificationModel(
                          id: DateTime.now().toString(),
                          title: 'Profile Updated',
                          description: 'Your email ${_emailController.text.trim()} has been added to your profile.',
                          createdAt: DateTime.now(),
                          icon: '✏️',
                          iconColor: Colors.blue,
                        ),
                      );
                    }
                    // Feedback and close
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile saved'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    // Go to Home after saving
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MyHomePage()),
                    );
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// --- Payment Screen ---

// Global Constants for Styling
const Color _kActiveGreen = Color(0xFF8BC34A);
const Color _kGreyText = Color(0xFF757575);
const Color _kSuccessColor = Color(0xFF4CAF50);

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isPaymentDone = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Payments',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Active payment',
                style: TextStyle(
                  color: _kGreyText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              _buildActivePaymentCard(),
              const SizedBox(height: 24),

              const Text(
                'Remaining payments',
                style: TextStyle(color: _kGreyText),
              ),
              const SizedBox(height: 8),
              _buildRemainingPaymentItem(),
              const SizedBox(height: 24),

              const Text(
                'Cleared payments',
                style: TextStyle(color: _kGreyText),
              ),
              const SizedBox(height: 8),
              _buildClearedPaymentItem(
                icon: Icons.credit_card,
                iconColor: const Color(0xFF007A9A),
              ),
              const Divider(height: 1),
              _buildClearedPaymentItem(
                icon: Icons.payments,
                iconColor: const Color(0xFF9C27B0),
              ),
              const SizedBox(height: 24),

              _buildPaymentSummaryBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePaymentCard() {
    final bool isDone = _isPaymentDone;
    final Color buttonColor = isDone ? _kSuccessColor : _kActiveGreen;
    final String buttonText = isDone ? 'DONE' : 'PAY NOW';
    final VoidCallback? onPressedAction = isDone
        ? null
        : () {
      setState(() {
        _isPaymentDone = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment simulated. Status: $buttonText'),
          duration: const Duration(seconds: 3),
        ),
      );
    };

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Material payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Due Date',
                style: TextStyle(color: _kGreyText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Rs. 1500',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                '10/10/2023',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressedAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: isDone ? 0 : 2,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingPaymentItem() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Text(
          'Payment Amount',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Row(
          children: const <Widget>[
            Text(
              'Rs. 4933',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: _kGreyText),
          ],
        ),
      ],
    );
  }

  Widget _buildClearedPaymentItem({
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: [
              Container(
                width: 30,
                height: 20,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              const Text('Amount paid'),
            ],
          ),
          Row(
            children: const <Widget>[
              Text('Rs. 4933'),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: _kGreyText, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Payments summary',
          style: TextStyle(color: _kGreyText),
        ),
        const SizedBox(height: 8),
        _buildSummaryRow('Total Amount', 'Rs.3000', isBold: true),
        _buildSummaryRow('Amount paid', 'Rs.1500'),
        _buildSummaryRow('Remaining Amount', 'Rs.1500', isBold: true),
      ],
    );
  }
}