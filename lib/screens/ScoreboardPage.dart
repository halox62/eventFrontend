import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
import 'package:social_flutter_giorgio/screens/profile.dart';
//import 'package:shared_preferences/shared_preferences.dart';

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({Key? key}) : super(key: key);

  @override
  _ScoreboardPageState createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  List<dynamic> _scoreboard = [];
  String? userEmail;
  bool _isLoading = true;
  bool _hasError = false;
  //String host = "127.0.0.1:5000";
  //String host = "10.0.2.2:5000";
  //String host = "event-production.up.railway.app";
  final String host = "www.event-fit.it";
  String? token;

  Map<String, dynamic>? _currentUserData;
  int? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _fetchScoreboard();
    //_fetchUserRanking();
  }

  Future<void> _checkTokenValidity(int statusCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (statusCode == 401) {
      try {
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          String? idToken = await user.getIdToken(true);
          prefs.setString('jwtToken', idToken!);
          _fetchScoreboard();
        } else {
          await Auth().signOut();
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.clear();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        }
      } catch (e) {
        await Auth().signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    }
  }

  Future<void> _fetchScoreboard() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwtToken');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(Uri.parse('https://$host/get_scoreboard'),
          headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _scoreboard = data['scoreboard'];
          _currentUserData = data['currentUser'];
          _currentUserPosition =
              _currentUserData != null ? _currentUserData!['position'] : null;
          _isLoading = false;
        });
      } else {
        _checkTokenValidity(response.statusCode);
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /*Future<void> _fetchUserRanking() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userEmail = prefs.getString('userEmail');
      final response = await http.get(
        Uri.parse(
            'http://127.0.0.1:5000/get_user_ranking?email=${userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userRanking = data['ranking'];
          _isLoadingUserRanking = false;
        });
      } else {
        setState(() {
          _hasErrorUserRanking = true;
          _isLoadingUserRanking = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasErrorUserRanking = true;
        _isLoadingUserRanking = false;
      });
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Scoreboard',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading && _scoreboard.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load scoreboard',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _scoreboard.length + (_currentUserData != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // If current user exists, show them at the top
                      if (_currentUserData != null && index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Your Position',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            _buildUserItem(_currentUserData!,
                                _currentUserPosition! - 1, true),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Divider(
                                  color: Colors.grey[300], thickness: 1.5),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Leaderboard',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }

                      // Adjust the index for the remaining scoreboard items
                      final adjustedIndex =
                          _currentUserData != null ? index - 1 : index;
                      final user = _scoreboard[adjustedIndex];
                      final position = user['position'] != null
                          ? user['position'] -
                              1 // Use position from API if available
                          : adjustedIndex; // Fallback to index

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildUserItem(user, position, false),
                      );
                    },
                  ),
                ),
    );
  }

// Helper method to build user item
  Widget _buildUserItem(
      Map<String, dynamic> user, int position, bool isCurrentUser) {
    final isTopThree = position < 3;
    final displayPosition = user['position'] ?? (position + 1);

    return GestureDetector(
      onTap: () {
        if (!isCurrentUser) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                email: user['emailUser'],
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isCurrentUser
              ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(user['profileImageUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['userName'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser ? Colors.blue[800] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user['point']} points',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isCurrentUser ? Colors.blue[600] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.blue
                      : (isTopThree
                          ? _getRankColor(position)
                          : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$displayPosition',
                    style: TextStyle(
                      color: isCurrentUser || isTopThree
                          ? Colors.white
                          : Colors.grey[600],
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

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold for 1st place
      case 1:
        return Color(0xFFC0C0C0); // Silver for 2nd place
      case 2:
        return Color(0xFFCD7F32); // Bronze for 3rd place
      default:
        return Colors.grey.shade400;
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await _fetchScoreboard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
