#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export PATH="/usr/local/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p project
unzip -qo Shree_Pathology_Lab_Android_V7-2.zip -d project

GRADLEW="$(find project -type f -name gradlew | head -1)"
if [[ -z "$GRADLEW" ]]; then
  echo "gradlew not found after extracting Android project" >&2
  exit 1
fi

PROJECT_DIR="$(dirname "$GRADLEW")"
PROPS="$PROJECT_DIR/gradle.properties"
touch "$PROPS"
grep -q '^android.useAndroidX=true' "$PROPS" 2>/dev/null || echo 'android.useAndroidX=true' >> "$PROPS"
grep -q '^android.enableJetifier=true' "$PROPS" 2>/dev/null || echo 'android.enableJetifier=true' >> "$PROPS"
grep -q '^android.suppressUnsupportedCompileSdk=35' "$PROPS" 2>/dev/null || echo 'android.suppressUnsupportedCompileSdk=35' >> "$PROPS"

LOCAL_PROPS="$PROJECT_DIR/local.properties"
if [[ ! -f "$LOCAL_PROPS" ]] || ! grep -q "^sdk.dir=" "$LOCAL_PROPS"; then
  echo "sdk.dir=${ANDROID_HOME}" > "$LOCAL_PROPS"
fi

chmod +x "$GRADLEW"

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
./gradlew --no-daemon -I "$CI_INIT" dependencies
rm -f "$CI_INIT"

echo "Android project ready at: $PROJECT_DIR"
