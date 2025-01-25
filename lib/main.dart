import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_test/your_task_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_background_test/service_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

int trackingId = 0;
String token = "";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(MyApp());
}

Future<void> fetchLocationAndSendToAPI(int driverId) async {
  PermissionStatus permission = await Permission.locationAlways.request();

  if (permission.isGranted) {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String loc = "${position.latitude},${position.longitude}";
      String dateTime = DateTime.now().toUtc().toIso8601String();

      List<Map<String, dynamic>> body = [
        {
          "trackingId": driverId,
          "loc": loc,
          "dateTime": dateTime,
        }
      ];

      final url = Uri.parse('https://api.mutasportal.com/TrackingLog/Insert');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print("Location sent successfully: $loc");
      } else {
        print("Failed to send location");
      }
    } catch (e) {
      print("Error fetching location or sending to API: $e");
    }
  } else if (permission.isDenied || permission.isPermanentlyDenied) {
    print("Location permission denied. Please enable it from app settings.");
    if (permission.isPermanentlyDenied) {
      openAppSettings();
    }
  } else {
    print("Location permission is in an unknown state.");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = "";

  Future<void> _login() async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Username and Password are required";
      });
      return;
    }

    final Map<String, String> body = {
      "username": username,
      "password": password,
    };

    final url = Uri.parse('https://api.mutasportal.com/Driver/Login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final data = responseData['data'];
          token = data['item2'];
          trackingId = data['item1']['id'];

          // Navigate to the TrackingPage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingPage(),
            ),
          );
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Login failed!';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Something went wrong, please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: Colors.blueGrey[50],
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: 'Username'),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Password'),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class TrackingPage extends StatefulWidget {
  @override
  _TrackingPageState createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  bool _isReady = false;
  String _errorMessage = "";
  dynamic activeTrackingData;

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final dynamic timestampMillis = data["timestampMillis"];
      if (timestampMillis != null) {
        final DateTime timestamp =
        DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
        print('timestamp: ${timestamp.toString()}');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Add a callback to receive data sent from the TaskHandler.
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissions();
      initService();
    });
  }

  @override
  void dispose() {
    // Remove a callback to receive data sent from the TaskHandler.
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  Future<void> _startTracking() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();

    final url = Uri.parse(
        'https://api.mutasportal.com/Tracking/GetActiveTracking?driverId=$trackingId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          activeTrackingData = responseData['data'];

          // fetchLocationAndSendToAPI(trackingData['id']);
          log('startServiceRequest');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('trackingId', activeTrackingData['id'].toString());
          await prefs.setString('token', token);

          FlutterForegroundTask.startService(
            serviceId: 256,
            notificationTitle: 'Foreground Service is running',
            notificationText: 'Tap to return to the app',
            notificationIcon: null,
            notificationButtons: [
              const NotificationButton(id: 'btn_hello', text: 'cancel'),
            ],
            notificationInitialRoute: '/',
            callback: startCallback,
          );
          // FlutterForegroundTask.sendDataToTask({'token': token});

          setState(() {
            _isReady = true;
          });
        } else {
          setState(() {
            _errorMessage =
                responseData['message'] ?? 'No active tracking found.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch active tracking data.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Page'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: InkWell(
                onLongPress: () {
                  FlutterForegroundTask.stopService();
                },
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  onPressed: _isReady ? null : _startTracking,
                  child: Text(
                    'Start Tracking',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            activeTrackingData == null
                ? SizedBox()
                : Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: Colors.blueGrey[50],
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${activeTrackingData["id"]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Title: ${activeTrackingData["title"]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Description: ${activeTrackingData["description"]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start Date: ${activeTrackingData["startDate"]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Finish Date: ${activeTrackingData["finishDate"]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
