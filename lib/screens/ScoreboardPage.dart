import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_flutter_giorgio/auth.dart';
import 'package:social_flutter_giorgio/screens/AuthPage.dart';
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
  String host = "127.0.0.1:5000";
  String? token;
  /*List<dynamic> _userRanking = [];
  bool _isLoadingTop100 = true;
  bool _isLoadingUserRanking = true;
  bool _hasErrorTop100 = false;
  bool _hasErrorUserRanking = false;*/

  @override
  void initState() {
    super.initState();
    _fetchScoreboard();
    //_fetchUserRanking();
  }

  Future<void> _checkTokenValidity(String message) async {
    message.toLowerCase();
    if (message.contains("token")) {
      await Auth().signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  Future<void> _fetchScoreboard() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      userEmail = prefs.getString('userEmail');
      token = prefs.getString('jwtToken');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.get(
          Uri.parse('http://' + host + '/get_scoreboard'),
          headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _scoreboard = data['scoreboard'];
          _isLoading = false;
        });
      } else {
        var errorData = jsonDecode(response.body);
        _checkTokenValidity(errorData['msg']);
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
      appBar: AppBar(
        title: const Text('Scoreboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Error loading scoreboard'))
              : ListView.builder(
                  itemCount: _scoreboard.length,
                  itemBuilder: (context, index) {
                    final user = _scoreboard[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['profileImageUrl']),
                      ),
                      title: Text(user['userName']),
                      subtitle: Text('Points: ${user['point']}'),
                      trailing: Text('#${index + 1}'),
                    );
                  },
                ),
    );
  }
}
