import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pedometer_db_method_channel.dart';

abstract class PedometerDbPlatform extends PlatformInterface {
  /// Constructs a PedometerDbPlatform.
  PedometerDbPlatform() : super(token: _token);

  static final Object _token = Object();

  static PedometerDbPlatform _instance = MethodChannelPedometerDb();

  /// The default instance of [PedometerDbPlatform] to use.
  ///
  /// Defaults to [MethodChannelPedometerDb].
  static PedometerDbPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PedometerDbPlatform] when
  /// they register themselves.
  static set instance(PedometerDbPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int?> queryPedometerDataFromOS(int startTime, int endTime) {
    throw UnimplementedError('queryPedometerDataFromOS() has not been implemented.');
  }

}
