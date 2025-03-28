import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/model/step.dart';
import 'package:sqflite/sqflite.dart';

final String tableName = 'steps';
final String tableNameAcc = 'Accelerometers';

class StepProvider {
  Database? db;
  Database? dbAcc;

  // Stream<StepCount>? _stepCountStream;

  Future initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = "$databasesPath/pedometer_db.db";
    String pathAcc = "$databasesPath/pedometer_dbAcc.db";
    db = await openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) => {},
      onCreate: (Database db, int version) => _createDatabase(db, version),
      onUpgrade: (Database db, int oldVersion, int newVersion) => {},
    );
    dbAcc = await openDatabase(
      pathAcc,
      version: 1,
      onConfigure: (Database db) => {},
      onCreate: (Database db, int version) => _createAccDatabase(db, version),
      onUpgrade: (Database db, int oldVersion, int newVersion) => {},
    );
  }

  Future _createDatabase(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableName (
      id INTEGER PRIMARY KEY, 
      total INTEGER NOT NULL,
      last INTEGER NOT NULL,
      plus INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

    //create index
    await db.execute('''
    CREATE INDEX idx_timestamp ON $tableName (timestamp ASC)
    ''');
  }

  Future _createAccDatabase(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableNameAcc (
      id INTEGER PRIMARY KEY, 
      total INTEGER NOT NULL,
      last INTEGER NOT NULL,
      plus INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

    //create index
    await db.execute('''
    CREATE INDEX idx_timestamp ON $tableNameAcc (timestamp ASC)
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


  Future<void> insertAccData(DateTime timeStamp) async {
    Step? lastAccStep = await getLastAccStep();
    int total = (lastAccStep?.total ?? 0) + 1;
    debugPrint("** insertData total: $total, timestamp: ${timeStamp.millisecondsSinceEpoch}");
    await dbAcc?.insert(
      tableNameAcc, // table name
      {
        'total': total,
        'last': 0,
        'timestamp': timeStamp.millisecondsSinceEpoch,
        'plus': 0,
      }, // new post row data
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> queryPedometerData(int startTime, int endTime) async {
    int stepCount = 0;
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
      stepCount = 0;
    } else {
      int realDataStep = (lastStep?.total ?? 0) - (firstStep?.total ?? 0);
      stepCount = realDataStep < 0 ? 0 : realDataStep;
    }


    //accCount
    int stepAccCount = 0;
    List<Map<String, Object?>>? firstAccMaps = await dbAcc?.rawQuery('SELECT * from $tableNameAcc where timestamp >= $startTime limit 1');
    List<Map<String, Object?>>? lastAccMaps = await dbAcc?.rawQuery('SELECT * from $tableNameAcc where timestamp < $endTime ORDER BY id desc limit 1');

    Step? firstAccStep;
    Step? lastAccStep;
    if (firstAccMaps != null && firstAccMaps.isNotEmpty) {
      firstAccStep = Step.fromMap(firstAccMaps.first);
    }
    if (lastAccMaps != null && lastAccMaps.isNotEmpty) {
      lastAccStep = Step.fromMap(lastAccMaps.first);
    }

    if ((firstAccStep?.total ?? 0) == 0 || (lastAccStep?.total ?? 0) == 0) {
      stepAccCount = 0;
    } else {
      int realDataStep = (lastAccStep?.total ?? 0) - (firstAccStep?.total ?? 0);
      stepAccCount = realDataStep < 0 ? 0 : realDataStep;
    }
    debugPrint("** stepCount total: $stepCount, stepAccCount: $stepAccCount");
    return stepCount + stepAccCount;
  }

  Future<Step?> getLastStep() async {
    List<Map<String, Object?>>? maps = await db?.rawQuery('SELECT * from $tableName ORDER BY id DESC limit 1');
    if (maps == null) return null;
    if (maps.isEmpty) return null;
    return Step.fromMap(maps.first);
  }

  Future<Step?> getLastAccStep() async {
    List<Map<String, Object?>>? maps = await dbAcc?.rawQuery('SELECT * from $tableNameAcc ORDER BY id DESC limit 1');
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
