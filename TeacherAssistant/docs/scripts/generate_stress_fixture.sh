#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-docs/stress-fixture.json}"
CLASS_COUNT="${CLASS_COUNT:-24}"
STUDENTS_PER_CLASS="${STUDENTS_PER_CLASS:-32}"

python3 - <<'PY' "$OUTPUT" "$CLASS_COUNT" "$STUDENTS_PER_CLASS"
import datetime
import json
import sys

output = sys.argv[1]
class_count = int(sys.argv[2])
students_per_class = int(sys.argv[3])

classes = [
    {
        "name": f"Class {i+1}",
        "grade": str((i % 9) + 1),
        "studentCount": students_per_class,
    }
    for i in range(class_count)
]

payload = {
    "generatedAt": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "classes": classes,
    "totalStudents": class_count * students_per_class,
}

with open(output, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=True)

print(f"Generated stress fixture at {output}")
PY
