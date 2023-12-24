// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'package:pedometer_db/provider/step_provider.dart';

import 'pedometer_db_platform_interface.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sqflite/sqflite.dart';

class PedometerDb {
  StepProvider? stepProvider;


  initPlatformState() async {
    stepProvider = StepProvider();
    await stepProvider?.initDatabase();
    await stepProvider?.initStepCountStream();
  }

  Future<int> queryPedometerData(int startTime, int endTime) async {
    return await stepProvider?.queryPedometerData(startTime, endTime) ?? 0;
  }
}
