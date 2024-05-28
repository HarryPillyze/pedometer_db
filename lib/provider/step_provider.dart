import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/model/step.dart';
import 'package:sqflite/sqflite.dart';

final String tableName = 'steps';

class StepProvider {
  Database? db;

  // Stream<StepCount>? _stepCountStream;

  Future initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = "$databasesPath/pedometer_db.db";
    db = await openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) => {},
      onCreate: (Database db, int version) => _createDatabase(db, version),
      onUpgrade: (Database db, int oldVersion, int newVersion) => {},
    );
  }

  Future _createDatabase(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS steps (
      id INTEGER PRIMARY KEY, 
      total INTEGER NOT NULL,
      last INTEGER NOT NULL,
      plus INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

    //create index
    await db.execute('''
    CREATE INDEX idx_timestamp ON steps (timestamp ASC)
    ''');
  }

  Future<int?> insertData(StepCount event) async {
    Step? lastStep = await getLastStep();

    int last = event.steps;
    int plus = lastStep?.plus ?? 0;
    int total = event.steps;
    int timestamp = event.timeStamp.millisecondsSinceEpoch;

    //어플 처음 실행이 아닐 경우
    if (lastStep != null) {
      //재부팅이 되었을 경우, 재부팅 시점의 걸음값을 정확히 모르는 상태에서 초기화 해야함
      if ((lastStep.last ?? 0) > event.steps) {
        // delta_steps = event.steps;
        // steps = (lastStep.steps ?? 0) + event.steps;
        // 0부터 시작
        total = lastStep.total ?? 0;
        plus = lastStep.total ?? 0; //더해야 할 값 재조정
      } else {
        //재부팅이 되지 않고 계속 쌓일 경우
        total = event.steps + plus;
      }
    }

    debugPrint("** insertData last: ${last}, plus: ${plus}, total: ${total}, steps: ${event.steps}, timestamp: ${timestamp}");

    return await db?.insert(
      tableName, // table name
      {
        'total': total,
        'last': last,
        'timestamp': timestamp,
        'plus': plus,
      }, // new post row data
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> queryPedometerData(int startTime, int endTime) async {
    List<Map<String, Object?>>? firstMaps = await db?.rawQuery('SELECT * from $tableName where timestamp >= $startTime limit 1');
    List<Map<String, Object?>>? lastMaps = await db?.rawQuery('SELECT * from $tableName where timestamp < $endTime ORDER BY id desc limit 1');

    Step? firstStep;
    Step? lastStep;
    if (firstMaps != null && firstMaps.isNotEmpty) {
      firstStep = Step.fromMap(firstMaps.first);
    }
    if (lastMaps != null && lastMaps.isNotEmpty) {
      lastStep = Step.fromMap(lastMaps.first);
    }

    if ((firstStep?.total ?? 0) == 0 || (lastStep?.total ?? 0) == 0) {
      return 0;
    } else {
      int realDataStep = (lastStep?.total ?? 0) - (firstStep?.total ?? 0);
      if (realDataStep < 0) {
        return 0;
      }
      return realDataStep < 0 ? 0 : realDataStep; //실제값 리턴
    }
  }

  Future<Step?> getLastStep() async {
    List<Map<String, Object?>>? maps = await db?.rawQuery('SELECT * from $tableName ORDER BY id DESC limit 1');
    if (maps == null) return null;
    if (maps.isEmpty) return null;
    return Step.fromMap(maps.first);
  }

  Future<int?> delete(int id) async {
    return await db?.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> update(Step step) async {
    return await db?.update(tableName, step.toMap(), where: 'id = ?', whereArgs: [step.id]);
  }

  Future close() async => db?.close();
}
