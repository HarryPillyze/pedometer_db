import Flutter
import UIKit
import CoreMotion

public class PedometerDbPlugin: NSObject, FlutterPlugin {
  private let pedometer = CMPedometer()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pedometer_db", binaryMessenger: registrar.messenger())
    let instance = PedometerDbPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "queryPedometerDataFromOS":
        if #available(iOS 10.0, *) {
            guard
                let arguments = call.arguments as? [String: Any],
                let startTime = arguments["startTime"] as? Int64,
                let endTime = arguments["endTime"] as? Int64
            else {
                result(0)
                return
            }
//            let microSeconds: Int64 = 1000 * 1000

//            let timeNow = Date().timeIntervalSince1970
            let startTimeDate = Date(timeIntervalSince1970: Double(startTime / 1000))
            var endTimeDate = Date(timeIntervalSince1970: Double(endTime / 1000))
//            if(timeNow < Double(endTime / 1000)) {
//                endTimeDate = Date(timeIntervalSince1970: timeNow)
//            }
            
//            print("startTime: \(startTime / 1000), endTime: \(endTime / 100), \(timeNow),  \(timeNow - Double(startTime / 1000)), \(endTimeDate)")
            
            pedometer.queryPedometerData(from: startTimeDate, to: endTimeDate) {
                pedometerData, error in
                guard let pedometerData = pedometerData, error == nil else { return }
                
                
                result(pedometerData.numberOfSteps.intValue)
                
                //                DispatchQueue.main.async {
                //                    self.handleEvent(count: pedometerData.numberOfSteps.intValue)
                //                }})
            
            }
        }
    
                                         
    case "dispose":
        pedometer.stopUpdates()
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}


/// StepCounter, handles step count streaming
// public class StepCounter: NSObject {
//     private let pedometer = CMPedometer()
//     private var running = false
// //     private var eventSink: FlutterEventSink?
//
// //     private func handleEvent(count: Int) {
// //         // If no eventSink to emit events to, do nothing (wait)
// //         if (eventSink == nil) {
// //             return
// //         }
// //         // Emit step count event to Flutter
// //         eventSink!(count)
// //     }
//
//     public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
//         self.eventSink = eventSink
//         if #available(iOS 10.0, *) {
//             if (!CMPedometer.isStepCountingAvailable()) {
//                 eventSink(FlutterError(code: "3", message: "Step Count is not available", details: nil))
//             }
//             else if (!running) {
//                 let systemUptime = ProcessInfo.processInfo.systemUptime;
//                 let timeNow = Date().timeIntervalSince1970
//                 let dateOfLastReboot = Date(timeIntervalSince1970: timeNow - systemUptime)
//                 running = true
//                 pedometer.startUpdates(from: dateOfLastReboot) {
//                     pedometerData, error in
//                     guard let pedometerData = pedometerData, error == nil else { return }
//
//                     DispatchQueue.main.async {
//                         self.handleEvent(count: pedometerData.numberOfSteps.intValue)
//                     }
//                 }
//             }
//         } else {
//             eventSink(FlutterError(code: "1", message: "Requires iOS 10.0 minimum", details: nil))
//         }
//         return nil
//     }
//
//     public func onCancel(withArguments arguments: Any?) -> FlutterError? {
// //         NotificationCenter.default.removeObserver(self)
// //         eventSink = nil
//
//         if (running) {
//             pedometer.stopUpdates()
//             running = false
//         }
//         return nil
//     }
// }

