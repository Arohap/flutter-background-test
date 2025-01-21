import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void startCallback() async{
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  late String trackingId;
  late String token;
  // Called when the task is started.



  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) async {
    final locationResponse = await _getLocation();
    if(locationResponse == null) return;
    final prefs = await SharedPreferences.getInstance();
    trackingId =  await prefs.getString('trackingId').toString();
    token =  await prefs.getString('token').toString();

    // create request body
    List<Map<String, dynamic>> body = [
      {
        "trackingId": trackingId,
        "loc": "${locationResponse["lat"] as double},${locationResponse["long"] as double}",
        "dateTime": locationResponse["time"] as String,
      }
    ];

    final response = await _uploadToServer(token, body);
    if(response){
      print("Successful: ${locationResponse["lat"] as double},${locationResponse["long"] as double}");
    }else{
      print("Fail: ${locationResponse["lat"] as double},${locationResponse["long"] as double}");
    }
  }

  Future<Map<String, dynamic>?> _getLocation() async {
    try {
      // check gps enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
      }

      // check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied.");
        }
      }

      // when user denied location permission forever
      if (permission == LocationPermission.deniedForever) {
        print("Location permission permanently denied.");
      }

      // receive location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        "lat": position.latitude,
        "long": position.longitude,
        "time": DateTime.now().toUtc().toIso8601String()
      };
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  Future<bool> _uploadToServer(String token,List<Map<String, dynamic>> body) async{
    try {
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
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Error fetching location or sending to API: $e");
      return false;
    }
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}
