import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';

class ProfilePage extends StatefulWidget {
  final String email;

  const ProfilePage({Key? key, required this.email}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  List<String> images = [];
  bool isLoading = true;
  String? token;
  String host = "event-production.up.railway.app";
  var point = "0";

  int? enlargedImageIndex;
  bool isImageEnlarged = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _checkTokenValidity(int statusCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (statusCode == 401) {
      try {
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          String? idToken = await user.getIdToken(true);
          prefs.setString('jwtToken', idToken!);
          _initializeData();
        } else {
          await Auth().signOut();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        }
      } catch (e) {
        await Auth().signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    await fetchProfileData(widget.email);
    await fetchImages(widget.email);
  }

  Future<void> fetchProfileData(String userEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('jwtToken');
    if (token == null) {
      throw Exception('Token not found');
    }
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.post(
        Uri.parse('https://$host/profileS'),
        headers: headers,
        body: jsonEncode({
          'email': userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            userName = data['userName'];
            profileImageUrl = data['profileImageUrl'];
            point = data['point'];
            isLoading = false;
          });
        }
      } else {
        _checkTokenValidity(response.statusCode);
        throw Exception('Failed to load profile data');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error fetching profile data: $error');
    }
  }

  Future<void> fetchImages(String email) async {
    final url = Uri.parse('https://$host/getImageS');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          images = List<String>.from(data['images']);
        });
      } else {
        _checkTokenValidity(response.statusCode);
      }
    } catch (error) {
      print('Errore durante la richiesta: $error');
    }
  }

  void _handleImageTap(int index) {
    setState(() {
      if (enlargedImageIndex == index) {
        // If tapping the already enlarged image, reset it
        enlargedImageIndex = null;
        isImageEnlarged = false;
      } else {
        // If tapping a new image or no image is enlarged
        enlargedImageIndex = index;
        isImageEnlarged = true;
      }
    });
  }

  void _handleImageLongPress(int index) {
    setState(() {
      enlargedImageIndex = index;
      isImageEnlarged = true;
    });
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _buildImageTile(int index) {
    return Hero(
      tag: 'image_$index',
      child: GestureDetector(
        onTap: () => _handleImageTap(index),
        onLongPress: () => _handleImageLongPress(index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images[index],
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black54,
                    strokeWidth: 2,
                  ),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: profileImageUrl != null
                                    ? NetworkImage(profileImageUrl!)
                                    : null,
                                child: profileImageUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userName ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('Posts', images.length.toString()),
                                _buildDivider(),
                                _buildStat('Points', point),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildImageTile(index);
                          },
                          childCount: images.length,
                        ),
                      ),
                    ),
                  ],
                ),
          if (isImageEnlarged && enlargedImageIndex != null)
            GestureDetector(
              onTap: () => _handleImageTap(enlargedImageIndex!),
              child: Container(
                color: Colors.black.withOpacity(0.95),
                alignment: Alignment.center,
                child: Hero(
                  tag: 'image_$enlargedImageIndex',
                  child: Image.network(
                    images[enlargedImageIndex!],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
