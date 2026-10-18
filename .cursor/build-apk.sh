#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export PATH="/usr/local/bin:${ANDROID_HOME}/platform-tools:${PATH}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLEW="$(find "$ROOT/project" -type f -name gradlew 2>/dev/null | head -1)"
if [[ -z "$GRADLEW" ]]; then
  echo "Run .cursor/install.sh first (project not extracted)." >&2
  exit 1
fi

PROJECT_DIR="$(dirname "$GRADLEW")"
CI_INIT="$(mktemp)"
cat > "$CI_INIT" <<'EOF'
import org.gradle.api.tasks.compile.JavaCompile

allprojects {
  tasks.withType(JavaCompile).configureEach {
    sourceCompatibility = "1.8"
    targetCompatibility = "1.8"
  }

  tasks.configureEach { task ->
    if (task.class.name.contains("KotlinCompile") && task.hasProperty("kotlinOptions")) {
      task.kotlinOptions.jvmTarget = "1.8"
    }
  }
}
EOF

cd "$PROJECT_DIR"
chmod +x ./gradlew
./gradlew --no-daemon -I "$CI_INIT" assembleDebug
rm -f "$CI_INIT"

find "$PROJECT_DIR" -path '*/build/outputs/apk/debug/*.apk' -print
