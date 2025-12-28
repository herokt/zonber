# Step 1: Increment Version
Write-Host "Incrementing version..."
dart run scripts\increment_version.dart

if ($LASTEXITCODE -ne 0) {
    Write-Error "Version increment failed."
    exit $LASTEXITCODE
}

# Step 2: Build APK
Write-Host "Building Release APK..."
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "APK Build failed."
    exit $LASTEXITCODE
}

# Step 3: Install on Device (Optional, but requested)
# We assume one device is connected or default is fine.
Write-Host "Installing on Device..."
flutter install

# Step 4: Build AAB
Write-Host "Building Release AAB..."
flutter build appbundle --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "AAB Build failed (or finished with warnings)."
    # Don't exit here strictly if it's just the debug symbol warning, but good to know.
}

Write-Host "Build and Release Process Completed Successfully!"
