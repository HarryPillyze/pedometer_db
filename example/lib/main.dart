import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pedometer_db/pedometer_db.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // String _platformVersion = 'Unknown';
  final _pedometerDB = PedometerDb();
  int _stepCount = 0;
  // int _lastTime = DateTime.now().microsecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationAlways,
      Permission.activityRecognition
    ].request();

    _pedometerDB.initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_stepCount\n'),
        ),
        floatingActionButton: FloatingActionButton(

          onPressed: () async {
            DateTime now = DateTime.now();

            // Set the time to midnight (start of the day)
            DateTime startOfDay = DateTime(now.year, now.month, now.day);

            // Set the time to the last moment of the day
            DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);


            // int endTime = DateTime.now().microsecondsSinceEpoch;
            _stepCount = await _pedometerDB.queryPedometerData(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch);
            // _lastTime = endTime;
            setState(() {

            });
          },
          child: Icon(Icons.edit),
        ),
      ),
    );
  }
}
