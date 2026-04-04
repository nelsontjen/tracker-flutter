# Flutter Expense Tracker - Build Troubleshooting Guide

## Issue: Gradle Build Fails with "Connection reset" from dl.google.com

### Root Cause
The Android Gradle build process attempts to download SDK metadata and native libraries from Google's CDN (`dl.google.com:443`). Transient network issues or ISP blocking causes repeated `java.net.SocketException: Connection reset` errors during the `mergeReleaseNativeLibs` task.

### Fixes Applied

#### 1. **Increased Network Timeouts** (android/gradle.properties)
```properties
systemProp.org.gradle.internal.http.socketTimeout=180000        # 3 minutes (was 120s)
systemProp.org.gradle.internal.http.connectionTimeout=180000    # 3 minutes (was 120s)
systemProp.http.keepAlive=true                                  # Enable connection reuse
systemProp.http.maxRetries=5                                    # Retry up to 5 times
```

#### 2. **Aliyun Maven Mirrors** (android/build.gradle.kts)
Pre-configured to use Aliyun mirrors for Google and public repositories, reducing reliance on Google's CDN.

#### 3. **Disabled Problematic Gradle Tasks** (android/app/build.gradle.kts)
Disables tasks that fetch SDK metadata from `dl.google.com`:
- `SdkDependencyData` tasks
- `VersionControlInfo` tasks
- Play Services metadata tasks

These tasks are optional and not required for app functionality.

#### 4. **Repository Configuration** (android/settings.gradle.kts)
Added `dependencyResolutionManagement` to enforce consistent repository usage and skip problematic metadata files.

### How to Build

#### Option 1: Normal Release Build (Recommended)
```bash
cd android
./gradlew assembleRelease --no-daemon
```

#### Option 2: Skip Problematic Tasks
```bash
cd android
./gradlew assembleRelease -x mergeReleaseNativeLibs --no-daemon
```

#### Option 3: Use Init Script
```bash
cd android
./gradlew assembleRelease -I init.gradle --no-daemon
```

#### Option 4: Offline Mode (if dependencies are cached)
```bash
cd android
./gradlew assembleRelease --offline --no-daemon
```

### If Build Still Fails

1. **Stop all Gradle daemons:**
   ```bash
   ./gradlew --stop
   ```

2. **Clean and rebuild:**
   ```bash
   ./gradlew clean assembleRelease --refresh-dependencies --no-daemon
   ```

3. **Check network connectivity:**
   ```powershell
   Invoke-WebRequest -Uri https://dl.google.com -UseBasicParsing
   ```

4. **Check for ISP blocking / Corporate proxy:**
   - If behind a corporate proxy, add to `~/.gradle/gradle.properties`:
     ```properties
     systemProp.http.proxyHost=YOUR_PROXY
     systemProp.http.proxyPort=8080
     systemProp.https.proxyHost=YOUR_PROXY
     systemProp.https.proxyPort=8080
     ```

5. **Try Flutter's built-in build (uses different settings):**
   ```bash
   flutter build apk --release
   ```

### Key Files Modified
- `android/gradle.properties` — Network timeout configuration
- `android/build.gradle.kts` — Repository and task configuration
- `android/app/build.gradle.kts` — Disabled problematic tasks
- `android/settings.gradle.kts` — Dependency resolution strategy
- `android/init.gradle` — Init script for task disabling
- `.gradle/gradle.properties` — Root Gradle configuration

### Notes
- The app does not require Google Play metadata to build and run correctly.
- Aliyun mirrors provide faster downloads for users in CN and nearby regions.
- Network timeouts are set to 180 seconds to allow slow/unstable connections time to complete.

### For More Help
- Check `build_error.txt` for detailed error logs
- Run with `--stacktrace` for full exception details: `./gradlew assembleRelease --stacktrace --no-daemon`
