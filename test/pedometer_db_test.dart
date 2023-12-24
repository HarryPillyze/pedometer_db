// import 'package:flutter_test/flutter_test.dart';
// import 'package:pedometer_db/pedometer_db.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockPedometerDbPlatform
//     with MockPlatformInterfaceMixin
//     implements PedometerDbPlatform {
//
//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }
//
// void main() {
//   final PedometerDbPlatform initialPlatform = PedometerDbPlatform.instance;
//
//   test('$MethodChannelPedometerDb is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelPedometerDb>());
//   });
//
//   test('getPlatformVersion', () async {
//     PedometerDb pedometerDbPlugin = PedometerDb();
//     MockPedometerDbPlatform fakePlatform = MockPedometerDbPlatform();
//     PedometerDbPlatform.instance = fakePlatform;
//
//     expect(await pedometerDbPlugin.getPlatformVersion(), '42');
//   });
// }
