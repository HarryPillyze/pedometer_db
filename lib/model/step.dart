

class Step {
  int? id;
  int? delta_steps;
  int? steps;
  int? timestamp;

  Map<String, Object?> toMap() {
    var map = <String, Object?> {
      "delta_steps": delta_steps,
      "steps": steps,
      "timestamp": timestamp,
    };
    if (id != null) {
      map["id"] = id;
    }
    return map;
  }

  Step();

  Step.fromMap(Map<String, Object?> map) {
    id = int.parse("${map["id"] ?? 0}");
    delta_steps = int.parse("${map["delta_steps"] ?? 0}");
    steps = int.parse("${map["steps"] ?? 0}");
    timestamp = int.parse("${map["timestamp"] ?? 0}");
  }
}
