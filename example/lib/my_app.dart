
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/models/notification_permission.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/pedometer_db.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final _pedometerDB = PedometerDb();
  // fianl temp = Pedo
  int _stepCount = 0;
  // int _lastTime = DateTime.now().microsecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pedometerDB.initialize();
      initPlatformState();
      getTodaySteps().then((value) {
        setState(() {
          _stepCount = value;
        });

      });
    });

  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    await [
      Permission.locationAlways,
      Permission.activityRecognition
    ].request();
    Pedometer.stepCountStream.listen(_onStepDeltaSaveToDB).onError((err) {
      print("stepCountStream error");
    });
    // _pedometerDB.initPlatformState();
  }


  Future<void> _onStepDeltaSaveToDB(StepCount event) async {
    await _pedometerDB.insertPedometerData(event);
  }

  Future<int> getTodaySteps() async {
    DateTime now = DateTime.now();
    // Set the time to midnight (start of the day)
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    // Set the time to the last moment of the day
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
    // int endTime = DateTime.now().microsecondsSinceEpoch;
    return await _pedometerDB.queryPedometerData(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch);
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
            _stepCount = await getTodaySteps();
            // _lastTime = endTime;
            setState(() {
              _stepCount;
            });


          },
          child: Icon(Icons.edit),
        ),
      ),
    );
  }
}