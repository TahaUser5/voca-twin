@echo off
echo ================================
echo    FIXING GRADLE ISSUES...
echo ================================

echo.
echo 1. Cleaning Flutter project...
call flutter clean

echo.
echo 2. Clearing Gradle cache...
cd android
call gradlew clean --stop

echo.
echo 3. Clearing system Gradle cache...
rmdir /s /q %USERPROFILE%\.gradle\caches 2>nul
rmdir /s /q %USERPROFILE%\.gradle\daemon 2>nul

echo.
echo 4. Getting Flutter dependencies...
cd ..
call flutter pub get

echo.
echo 5. Rebuilding Gradle wrapper...
cd android
call gradlew wrapper --gradle-version=8.12 --distribution-type=all

echo.
echo 6. Pre-building dependencies...
call gradlew build --parallel --daemon

echo.
echo ================================
echo     GRADLE ISSUES FIXED!
echo ================================
echo.
echo You can now run: flutter run
pause 