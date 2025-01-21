import 'package:flutter/material.dart';
import 'package:flutter_background_test/service_config.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
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
      // Request permissions and initialize the service.
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MaterialButton(
            onPressed: () {
              const trackingId = "3";
              const sampleToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjEiLCJOYW1lU3VybmFtZSI6IkjDnFNFWUlOIMOWWkRFTcSwUiIsIlVzZXJuYW1lIjoidGVzdCIsIkVtYWlsIjoicG9ydGFsQG11dGFzcG9ydGFsLmNvbSIsIlBob25lTnVtYmVyIjoiNTQ0NDkwODA4OCIsIlN5c3RlbVJvbGUiOiIyIiwiZXhwIjoxNzM3NTMyNTk2fQ.hbDxwnTcVwEMCDG4XMMzpgnXqyUHSaa39c8E8_qPJy0";
              startService(trackingId, sampleToken);
            },
            child: const Text("Start service"),
          ),
        ),
      ),
    );
  }
}
