import 'dart:io';
import 'dart:isolate';

// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/pedometer_db.dart';
// import 'package:permission_handler/permission_handler.dart';
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
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}


Future<void> _startForegroundService() async {
  bool isRunning = await FlutterForegroundTask.isRunningService;
  if(isRunning) {
    await FlutterForegroundTask.restartService();
    return;
  } else {
    await FlutterForegroundTask.startService(
      // notificationTitle: 'Foreground Service is running',
      // notificationText: 'Tap to return to the app',
      notificationTitle: '걸음수보다 더 크게 쌓이는 행복',
      notificationText: '오늘도 행복한 하루 되세요',
      callback: foregroundStartCallback,
    );
    //처음일 경우 바로 모니터링 시작
    Pedometer.stepCountStream.listen(insertDataWithNotification);
  }
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

/*** 기존 로직
 Android의 경우
 startTime, endTime 조회시 db에서 예상값을 읽어옴
 - db값 갱신 로직
 1. work manager가 alram manager를 15분마다 실행시킴 (앱이 중단된 상태여도 깨워서 동작시킴)
 2. alarm manager가 1분마다 forground task를 실행시킴
 3. forground task 에서 센서값을 읽어서 db에 갱신함.
 4. 그리고 local notification 으로 사용자에게 알림. 그리고 forground task 종료시킴 (3번이 정상동작하면 4번은 굳이 안해도 될 듯)

 ios의 경우
 startTime, endTime 조회시 os에서 값을 읽어옴
***/

/*** 바뀐 로직
    Android의 경우
    startTime, endTime 조회시 db에서 예상값을 읽어옴
    - db값 갱신 로직
    1. work manager가 forground task를 15분마다 실행시킴 (앱이 중단된 상태여도 깨워서 동작시킴)
    2. forground task 에서 센서값을 읽어서 db에 갱신함.

    ios의 경우
    startTime, endTime 조회시 os에서 값을 읽어옴
 ***/


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
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
    // await AndroidAlarmManager.initialize();
    //local notification 초기화
    // const InitializationSettings initializationSettings = InitializationSettings(
    //   android: AndroidInitializationSettings('ic_launcher'), //android project의 main/res/drawable 안에 있음
    // );
    // await flutterLocalNotificationsPlugin.initialize(
    //   initializationSettings,
    // );
  }


  runApp(const MyApp());

  if (Platform.isAndroid) {
    //alarm manager로 1분마다 forground task 실행
    // AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
    _initForegroundTask();
    await _requestPermissionForAndroid();
    await _startForegroundService();
    // FlutterForegroundTask.setTaskHandler(SensorReadTaskHandler());
  }
}


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("** Workmanager executeTask");
    // AndroidAlarmManager.initialize().then((value) {
    //   AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
    // });
    _initForegroundTask();
    _startForegroundService();
    return Future.value(true);
  });
}


// forground task 로 실행되는 로직 - 센서값을 얻어오려면 forground task 이거나 화면이 보여야 함
void insertDataWithNotification(StepCount event) {
  debugPrint("** read steps count by sensor : ${event.steps}");
  final _pedometerDB = PedometerDb();
  _pedometerDB.initialize().then((value) {
    _pedometerDB.insertPedometerData(event).then((value) {
      //데이터를 db에 넣었으면 notification 하자
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
      _pedometerDB.queryPedometerData(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch).then((steps) {
        showAndroidNotification(steps).then((value) {
          // FlutterForegroundTask.stopService();
        });
      });
    });
  });
}

// int id = 0;
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
Future<bool> showAndroidNotification(int? steps) async {
  debugPrint("** showAndroidNotification : $steps");

  // const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
  //     'example_steps_id',  //channel id
  //     'example_steps_name', //channel name
  //     channelDescription: 'steps count for android');
  // const NotificationDetails notificationDetails =
  // NotificationDetails(android: androidNotificationDetails);
  // flutterLocalNotificationsPlugin.show(
  //   id,
  //   '걸음수보다 더 크게 쌓이는 행복',
  //   '오늘의 걸음수 : ${NumberFormat.decimalPattern().format(steps ?? 100)}',
  //   notificationDetails,
  // );

  return FlutterForegroundTask.updateService(
    notificationTitle: '걸음수보다 더 크게 쌓이는 행복',
    notificationText: '오늘의 걸음수 : ${NumberFormat.decimalPattern().format(steps ?? 0)}',
  );
}


// 등록된 forground task가 시작되는 부분
@pragma('vm:entry-point')
void foregroundStartCallback() {
  print("** foregroundStartCallback");
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
