import 'dart:io';
import 'dart:isolate';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/pedometer_db.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart';

import 'my_app.dart';

void _initForegroundTask() {
  if (!Platform.isAndroid) {
    return;
  }
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service Notification',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: true,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}


void _startForegroundService() {
  _initForegroundTask();
  FlutterForegroundTask.isRunningService.then((value) {
    if(value == true) {
      FlutterForegroundTask.restartService();
    } else {
      FlutterForegroundTask.startService(
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  });


}


Future<void> _requestPermissionForAndroid() async {
  if (!Platform.isAndroid) {
    return;
  }
  // Android 13 and higher, you need to allow notification permission to expose foreground service notification.
  final NotificationPermission notificationPermissionStatus =
  await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermissionStatus != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //workmanager 초기화
  await Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode: false // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  //15분마다 alarm manager 깨우기
  Workmanager().registerPeriodicTask(
    "task-identifier",
    "simpleTask",
    frequency: const Duration(minutes: 15),
  );

  //alarm manager 초기화
  await AndroidAlarmManager.initialize();
  //local notification 초기화
  const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_launcher'), //android project의 main/res/drawable 안에 있음
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  runApp(const MyApp());

  //alarm manager로 1분마다 forground task 실행
  AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
  await _requestPermissionForAndroid();
}

int alarmTaskId = 10; //나중에 cancel 에 사용될 수 있음

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("** Workmanager executeTask");
    AndroidAlarmManager.initialize().then((value) {
      // AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, readStepSensor);
      AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
      // AndroidAlarmManager.cancel(alarmTaskId).then((value) {
      //   AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, localNotificationEveryMinute);
      // });
    });
    return Future.value(true);
  });
}


// forground task 로 실행되는 로직 - 센서값을 얻어오려면 forground task 이거나 화면이 보여야 함
void insertDataWithNotification(StepCount event) {
  print("** read steps count by sensor : ${event.steps}");
  final _pedometerDB = PedometerDb();
  _pedometerDB.initialize().then((value) {
    _pedometerDB.insertPedometerData(event).then((value) {
      print("** insertPedometerData : ${value}");
      //데이터를 db에 넣었으면 notification 하자
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
      _pedometerDB.queryPedometerData(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch).then((steps) {
        showAndroidNotification(steps);
        FlutterForegroundTask.stopService();
      });
    });
  });
}

int id = 0;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
void showAndroidNotification(int? steps) {
  print("** showAndroidNotification : $steps");

  const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'galaxia_steps_id',  //channel id
      'galaxia_steps_name', //channel name
      channelDescription: 'steps count for android');
  const NotificationDetails notificationDetails =
  NotificationDetails(android: androidNotificationDetails);
  flutterLocalNotificationsPlugin.show(
    id,
    '걸음수보다 더 크게 코인 쌓이는 앱테크',
    '오늘의 걸음수 : ${NumberFormat.decimalPattern().format(steps ?? 100)}',
    notificationDetails,
  );
}


// 등록된 forground task가 시작되는 부분
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SensorReadTaskHandler());
}


class SensorReadTaskHandler extends TaskHandler {
  // Called when the task is started.
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    Pedometer.stepCountStream.listen(insertDataWithNotification);
  }

  // Called every [interval] milliseconds in [ForegroundTaskOptions].
  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
  }

  // Called when the notification button on the Android platform is pressed.
  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {
  }

  // Called when the notification button on the Android platform is pressed.
  @override
  void onNotificationButtonPressed(String id) {
  }

  @override
  void onNotificationPressed() {
  }
}
