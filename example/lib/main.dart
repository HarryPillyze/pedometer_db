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
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service Notification',
      channelDescription: 'This notification appears when the foreground service is running.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
      buttons: [
        const NotificationButton(id: 'sendButton', text: 'Send'),
        const NotificationButton(id: 'testButton', text: 'Test'),
      ],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}


ReceivePort? _receivePort;
bool _registerReceivePort(ReceivePort? newReceivePort) {
  if (newReceivePort == null) {
    return false;
  }

  _closeReceivePort();

  _receivePort = newReceivePort;
  _receivePort?.listen((data) {
    if (data is int) {
      print('eventCount: $data');
    } else if (data is String) {
      // if (data == 'onNotificationPressed') {
      //   Navigator.of(context).pushNamed('/resume-route');
      // }
    } else if (data is DateTime) {
      print('timestamp: ${data.toString()}');
    }
  });

  return _receivePort != null;
}

void _closeReceivePort() {
  _receivePort?.close();
  _receivePort = null;
}

void _startForegroundService() {
  _initForegroundTask();
  print("** _startForegroundService");

  // Register the receivePort before starting the service.
  final ReceivePort? receivePort = FlutterForegroundTask.receivePort;
  final bool isRegistered = _registerReceivePort(receivePort);
  if (!isRegistered) {
    print('Failed to register receivePort!');
    return  ;
  }

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

  await Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode: false // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  //15분마다 alarm manager 깨우기
  // Workmanager().registerPeriodicTask(
  //   "task-identifier",
  //   "simpleTask",
  //   frequency: const Duration(minutes: 15),
  // );
  Workmanager().registerOneOffTask(
    "task-identifier",
    "simpleTask",
  );

  await AndroidAlarmManager.initialize();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_launcher'), //android project의 main/res/drawable 안에 있음
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  runApp(const MyApp());
  // AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, readStepSensor);
  AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
  await _requestPermissionForAndroid();
}

int alarmTaskId = 10; //나중에 cancel 에 사용될 수 있음

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    AndroidAlarmManager.initialize().then((value) {
      _startForegroundService();
      // AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, readStepSensor);
      AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, _startForegroundService);
      // AndroidAlarmManager.cancel(alarmTaskId).then((value) {
      //   AndroidAlarmManager.periodic(const Duration(minutes: 1), alarmTaskId, localNotificationEveryMinute);
      // });
    });
    return Future.value(true);
  });
}


//참고1: https://pub.dev/packages/android_alarm_manager_plus
@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void readStepSensor() {
  Pedometer.stepCountStream.listen(insertDataWithNotification);

}

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

  // FlutterForegroundTask.updateService(
  //   notificationTitle: '걸음수보다 더 크게 코인 쌓이는 앱테크',
  //   notificationText: '오늘의 걸음수 : ${NumberFormat.decimalPattern().format(steps ?? 0)}',
  // );
}


// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() {
  print("** startCallback");
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}


class FirstTaskHandler extends TaskHandler {
  SendPort? _sendPort;

  // Called when the task is started.
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;


    // You can use the getData function to get the stored data.
    final customData =
    await FlutterForegroundTask.getData<String>(key: 'customData');
    print('** FirstTaskHandler customData: $customData');

    Pedometer.stepCountStream.listen(insertDataWithNotification);
  }

  // Called every [interval] milliseconds in [ForegroundTaskOptions].
  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Send data to the main isolate.
    // sendPort?.send(timestamp);
  }

  // Called when the notification button on the Android platform is pressed.
  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {

  }

  // Called when the notification button on the Android platform is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed >> $id');
  }

  // Called when the notification itself on the Android platform is pressed.
  //
  // "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted for
  // this function to be called.
  @override
  void onNotificationPressed() {
    // Note that the app will only route to "/resume-route" when it is exited so
    // it will usually be necessary to send a message through the send port to
    // signal it to restore state when the app is already started.
    // FlutterForegroundTask.launchApp("/resume-route");
    // _sendPort?.send('onNotificationPressed');
  }
}
