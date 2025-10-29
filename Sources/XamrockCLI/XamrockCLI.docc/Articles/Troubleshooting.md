# Troubleshooting

Common issues and solutions for Xamrock CLI.

## Overview

This guide covers common problems you might encounter when using Xamrock CLI and how to resolve them.

## Installation Issues

### Command Not Found After Installation

**Problem**: Running `xamrock` returns "command not found" after Homebrew installation.

**Solution**:

```bash
# Link the binary
brew link xamrock

# Verify installation
which xamrock
xamrock --version
```

If still not found, check your PATH:

```bash
echo $PATH | grep homebrew
```

### Build Fails with Command Line Tools Error

**Problem**: Homebrew build fails with "Command Line Tools are too outdated".

**Solution**:

Update Xcode Command Line Tools:

```bash
# Install or update
xcode-select --install
```

Or update via System Settings → General → Software Update.

Verify the installation:

```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

### Swift Version Mismatch

**Problem**: Build fails with Swift version errors.

**Solution**:

Ensure you're using Swift 6.0 or later:

```bash
swift --version
```

If outdated, install the latest Xcode from the App Store.

## Exploration Issues

### Bundle ID Not Found

**Problem**: "Bundle ID not found" or "Invalid bundle identifier" error.

**Solution**:

1. Verify your app's bundle ID:
   - Open your Xcode project
   - Select your app target
   - Check the "Bundle Identifier" field in General settings

2. Ensure your app is installed in the simulator:

```bash
xcrun simctl list apps booted | grep -i "your-app"
```

3. Build and install your app first:

```bash
xcodebuild build \
  -project YourApp.xcodeproj \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Simulator Not Available

**Problem**: "No suitable simulator found" error.

**Solution**:

1. List available simulators:

```bash
xcrun simctl list devices available
```

2. Boot a simulator:

```bash
xcrun simctl boot "iPhone 15"
```

3. Specify a device explicitly:

```bash
xamrock explore \
  --app com.example.App \
  --device "iPhone 15"
```

### Test File Not Generated

**Problem**: `ScoutCLIExploration.swift` is not created.

**Solution**:

1. Check output directory permissions:

```bash
ls -la ./scout-results
```

2. Specify an absolute path:

```bash
xamrock explore \
  --app com.example.App \
  --output ~/Desktop/scout-results
```

3. Run with verbose mode to see errors:

```bash
xamrock explore \
  --app com.example.App \
  --verbose
```

## Runtime Issues

### Test Fails to Launch App

**Problem**: XCUITest fails to launch the app.

**Solution**:

1. Verify the bundle ID in the test file matches your app
2. Ensure the app is built and installed:

```bash
xcodebuild build-for-testing \
  -project YourApp.xcodeproj \
  -scheme YourApp
```

3. Check simulator status:

```bash
xcrun simctl list devices | grep Booted
```

### Exploration Times Out

**Problem**: Test runs indefinitely or times out.

**Solution**:

1. Reduce the number of steps:

```bash
xamrock explore \
  --app com.example.App \
  --steps 10
```

2. Check for modal dialogs or permissions blocking the app
3. Review the verbose output for stuck interactions

### AI Not Exploring Effectively

**Problem**: AI repeats the same actions or misses key features.

**Solution**:

1. Provide a specific goal:

```bash
xamrock explore \
  --app com.example.App \
  --goal "Test authentication, profile editing, and settings"
```

2. Increase exploration steps:

```bash
xamrock explore \
  --app com.example.App \
  --steps 40
```

3. Run multiple explorations with different goals

## Dashboard Issues

### Dashboard Won't Open

**Problem**: `dashboard.html` fails to open or display correctly.

**Solution**:

1. Ensure the test completed successfully
2. Check file permissions:

```bash
ls -la scout-results/*/dashboard.html
```

3. Open explicitly with a browser:

```bash
open -a "Google Chrome" scout-results/*/dashboard.html
```

### Missing Screenshots in Dashboard

**Problem**: Dashboard shows but screenshots are missing.

**Solution**:

1. Verify screenshot permissions for Xcode/Simulator
2. Check output directory structure:

```bash
ls -la scout-results/*/screenshots/
```

3. Ensure adequate disk space

## CI/CD Issues

### Tests Fail Only in CI

**Problem**: Tests pass locally but fail in CI environment.

**Solution**:

1. Use `--ci-mode` for deterministic behavior:

```bash
xamrock explore \
  --app com.example.App \
  --ci-mode
```

2. Verify Xcode version matches:

```yaml
- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_15.0.app
```

3. Check simulator availability in CI
4. Increase timeout values if needed

### Artifacts Not Uploaded

**Problem**: Test results aren't available in CI artifacts.

**Solution**:

1. Use `if: always()` in GitHub Actions:

```yaml
- uses: actions/upload-artifact@v4
  if: always()
  with:
    name: results
    path: test-results/
```

2. Verify output directory exists:

```bash
ls -la test-results/
```

## Performance Issues

### Slow Exploration

**Problem**: Explorations take too long to complete.

**Solution**:

1. Disable dashboard generation:

```bash
xamrock explore \
  --app com.example.App \
  --no-generate-dashboard
```

2. Reduce steps:

```bash
xamrock explore \
  --app com.example.App \
  --steps 15
```

3. Check system resources (CPU, memory)

### Large Output Files

**Problem**: Dashboard and results consume too much disk space.

**Solution**:

1. Disable dashboard for CI:

```bash
xamrock explore \
  --app com.example.App \
  --no-generate-dashboard
```

2. Clean up old results:

```bash
find scout-results -type d -mtime +7 -exec rm -rf {} +
```

## Getting Help

If you continue to experience issues:

1. **Check the logs**: Run with `--verbose` for detailed output
2. **Review manifest.json**: Contains diagnostic information
3. **Search GitHub Issues**: [Xamrock CLI Issues](https://github.com/Xamrock/CLI/issues)
4. **Create an Issue**: Include:
   - Xamrock version (`xamrock --version`)
   - macOS and Xcode versions
   - Full error message
   - Steps to reproduce
5. **Join Discord**: [Xamrock Community](https://discord.gg/Pvmbamg2ny)
6. **Email Support**: context@xamrock.com

## Debug Checklist

When troubleshooting, verify:

- [ ] Xamrock CLI is installed and in PATH
- [ ] Xcode and Command Line Tools are up to date
- [ ] Swift version is 6.0 or later
- [ ] App bundle ID is correct
- [ ] Simulator is available and booted
- [ ] Output directory has write permissions
- [ ] Xcode project structure is correct
- [ ] UITest target exists and includes the test file

## Next Steps

- Return to <doc:GettingStarted> for basics
- Review <doc:Configuration-article> for options
- Check <doc:CI-Integration> for automation
