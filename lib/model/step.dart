

class Step {
  int? id;
  int? total;
  int? last;
  int? plus;
  int? timestamp;

  Map<String, Object?> toMap() {
    var map = <String, Object?> {
      "total": total,
      "last": last,
      "plus": plus,
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
    total = int.parse("${map["total"] ?? 0}");
    last = int.parse("${map["last"] ?? 0}");
    plus = int.parse("${map["plus"] ?? 0}");
    timestamp = int.parse("${map["timestamp"] ?? 0}");
  }
}
