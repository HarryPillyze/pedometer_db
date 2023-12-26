import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/model/step.dart';
import 'package:sqflite/sqflite.dart';

final String tableName = 'steps';



class StepProvider {
  Database? db;
  Stream<StepCount>? _stepCountStream;

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
      delta_steps INTEGER NOT NULL,
      steps INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

    //create index
    await db.execute('''
    CREATE INDEX idx_timestamp ON steps (timestamp ASC)
    ''');
  }

  // Future<Step> insert(Step step) async {
  //   step.id = await db?.insert(tableStep, step.toMap());
  //   return step;
  // }

  // Future<Step?> getStep(int id) async {
  //   List<Map<String, Object?>>? maps = await db?.query(tableStep,
  //       columns: ['id', 'delta_steps', 'steps', 'timestamp'],
  //       where: 'id = ?',
  //       whereArgs: [id]);
  //   if (maps == null) return null;
  //   return Step.fromMap(maps.first);
  // }

  Future<int?> insertData(StepCount event) async {
    Step? lastStep = await getLastStep();

    int delta_steps = 0;
    int steps = event.steps;
    int timestamp = event.timeStamp.millisecondsSinceEpoch;



    if(lastStep != null) {
      //어플 처음 실행이 아닐 경우
      if((lastStep.steps ?? 0) > event.steps) {
        //재부팅이 되었을 경우
        delta_steps = event.steps;
        steps = (lastStep.steps ?? 0) + event.steps;
      } else {
        delta_steps = event.steps - (lastStep.steps ?? 0);
      }
    }

    print("insertData delta: ${delta_steps}, steps: ${steps}, lastStep: ${lastStep?.steps}");

    return await db?.insert(
      tableName,  // table name
      {
        'delta_steps': delta_steps,
        'steps': steps,
        'timestamp': timestamp,
      },  // new post row data
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

  }


  Future<int> queryPedometerData(int startTime, int endTime) async {
    //db 범위밖 1개씩 가져와서 데이터를 조합해야함
    List<Map<String, Object?>>? firstMaps = await db?.rawQuery('SELECT * from $tableName where timestamp < $startTime ORDER BY id desc limit 1');
    List<Map<String, Object?>>? lastMaps = await db?.rawQuery('SELECT * from $tableName where timestamp > $endTime limit 1');

    Step? firstStep;
    Step? lastStep;
    bool firstNoExist = false;
    bool lastNoExist = false;

    if(firstMaps != null && firstMaps.isEmpty) {
      //db상 첫번째 데이터를 가져온다
      firstNoExist = true;
      firstMaps = await db?.rawQuery('SELECT * from $tableName limit 1');
    }

    if(firstMaps != null && firstMaps.isNotEmpty) {
      firstStep = Step.fromMap(firstMaps.first);
    }
    if(lastMaps != null && lastMaps.isEmpty) {
      //db상 마지막 데이터를 가져온다
      lastNoExist = true;
      lastMaps = await db?.rawQuery('SELECT * from $tableName ORDER BY id desc limit 1');
    }
    if(lastMaps != null && lastMaps.isNotEmpty) {
      lastStep = Step.fromMap(lastMaps.first);
    }
    print("lastStep: ${lastStep?.steps}, fristStep: ${firstStep?.steps}");
    //값 없을때 예상값 조회 시간 보정
    if(firstNoExist) { startTime = firstStep?.timestamp ?? startTime; }
    if(lastNoExist) { endTime = lastStep?.timestamp ?? endTime; }

    int realDataStep = (lastStep?.steps ?? 0) - (firstStep?.steps ?? 0);
    int realDataTimestamp = (lastStep?.timestamp ?? 0) - (firstStep?.timestamp ?? 0);
    if(realDataTimestamp == 0) realDataTimestamp = 1; //0으로 나누지 않게 예외처리

    double percent = (endTime - startTime) / realDataTimestamp; //예상 데이터를 구하기 위한 환산된 비율
    //기록 걸음수

    print("startTime: $startTime, endTime: $endTime, diff: ${endTime - startTime}, realDataStep: ${realDataStep}, realDataTimestamp: ${realDataTimestamp}, percent: $percent");

    return (realDataStep * percent).toInt();
  }

  // Future<Step> queryPedometerData(int timestamp) async {
  //   List<Map<String, Object?>>? maps = await db?.rawQuery('SELECT * from $tableName ORDER BY id DESC limit 1');
  //
  // }


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
    return await db?.update(tableName, step.toMap(),
        where: 'id = ?', whereArgs: [step.id]);
  }

  Future close() async => db?.close();
}

extension StepPedometer on StepProvider {

  initStepCountStream() async {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(_onStepDeltaSaveToDB).onError((err) {
      print("stepCountStream error");
    });
  }


  Future<void> _onStepDeltaSaveToDB(StepCount event) async {

    int? index = await insertData(event);
    print("*** insertData : ${event.steps}, ${event.timeStamp}, $index");
  }
}