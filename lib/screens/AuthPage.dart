import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/screens/ForgotPasswordPage.dart';
import 'package:social_flutter_giorgio/screens/HomePage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth.dart';
import 'package:permission_handler/permission_handler.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _userName = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isPrivacyAccepted = false;

  File? _profileImage;
  bool isLogin = true;
  bool _isPasswordVisible = false;
  //String host = "event-production.up.railway.app";
  final String host = "www.event-fit.it";
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _userName.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    var cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> search(String email) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://$host/search'),
      );
      request.fields['email'] = email;

      final response = await request.send();

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(AppLocalizations.of(context).account_not_present);
      }
    }

    return false;
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 300,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlay);

      Future.delayed(const Duration(seconds: 3), () {
        overlay.remove();
      });
    });
  }

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool response = await search(_email.text);

      if (response) {
        await Auth().signInWithEmailAndPassword(
          email: _email.text,
          password: _password.text,
        );

        User? user = FirebaseAuth.instance.currentUser;
        String? token = await user?.getIdToken();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwtToken', token!);
        await prefs.setString('email', _email.text);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage =
            e.toString().replaceFirst(RegExp(r'\[.*?\] '), '');

        _showErrorSnackbar(
            '${AppLocalizations.of(context).login_failed} $errorMessage');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://$host/register'),
      );

      String email = _email.text;
      String password = _password.text;

      request.fields['email'] = _email.text;
      request.fields['userName'] = _userName.text;

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            _profileImage!.path,
          ),
        );
      } else {
        _showErrorSnackbar(AppLocalizations.of(context).profile_image_missing);

        return;
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        await Auth().createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', _email.text);

        User? user = FirebaseAuth.instance.currentUser;
        String? token = await user?.getIdToken();
        await prefs.setString('jwtToken', token!);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        }
      } else {
        throw Exception('Registration failed');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage =
            e.toString().replaceFirst(RegExp(r'\[.*?\] '), '');
        _showErrorSnackbar(
            '${AppLocalizations.of(context).registration_failed} $errorMessage');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<bool> showDialogPermissionDenied() async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(localizations.permissions_denied_title),
        content: Text(localizations.permissions_denied_description),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false), // Return false for Cancel
            child: Text(
              localizations.cancel,
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Return true for Open Settings
              openAppSettings(); // Call the function to open settings
            },
            child: Text(
              localizations.open_settings,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showPicker(BuildContext context) async {
    // Verifica e richiedi i permessi
    bool permissionsGranted = await _requestPermissions();

    if (!permissionsGranted) {
      await showDialogPermissionDenied();
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black87),
                title: const Text('Gallery',
                    style: TextStyle(color: Colors.black87)),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black87),
                title: const Text('Camera',
                    style: TextStyle(color: Colors.black87)),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLogin
                        ? localizations.welcome_back
                        : localizations.create_account,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLogin
                        ? localizations.sign_in_to_continue
                        : localizations.create_account_start,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!isLogin) ...[
                    Center(
                      child: GestureDetector(
                        onTap: () => _showPicker(context),
                        child: Stack(
                          children: [
                            Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: _profileImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(60),
                                      child: Image.file(
                                        _profileImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline,
                                      size: 50,
                                      color: Colors.black54,
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2196F3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  _buildTextField(
                    controller: _email,
                    label: localizations.email_label,
                    icon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.email_required;
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return localizations.email_invalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(localizations),
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _userName,
                      label: localizations.username_label,
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.username_required;
                        }
                        return null;
                      },
                    ),
                  ],
                  if (isLogin) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForgotPasswordPage(),
                          ),
                        ),
                        child: Text(
                          localizations.forgot_password,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _isPrivacyAccepted,
                          onChanged: (value) {
                            setState(() {
                              _isPrivacyAccepted = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF2196F3),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              const url =
                                  'https://www.iubenda.com/privacy-policy/86697968';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url));
                              }
                            },
                            child: Text.rich(
                              TextSpan(
                                text: localizations.accept_privacy_policy,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: localizations.privacy_policy,
                                    style: const TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || (!_isPrivacyAccepted && !isLogin)
                          ? null
                          : () => isLogin ? signIn() : createUser(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isLogin
                                  ? localizations.sign_in_button
                                  : localizations.create_account_button,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text.rich(
                        TextSpan(
                          text: isLogin
                              ? localizations.no_account
                              : localizations.have_account,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: isLogin
                                  ? localizations.sign_up
                                  : localizations.sign_in,
                              style: const TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.black54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      ),
    );
  }

  Widget _buildPasswordField(AppLocalizations localizations) {
    return TextFormField(
      controller: _password,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.black),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return localizations.password_required;
        }
        if (value.length < 8) {
          return localizations.password_length;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: localizations.password_label,
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
        prefixIcon: Icon(
          Icons.lock_outline,
          color: Colors.black54,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.black54,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      ),
    );
  }
}
