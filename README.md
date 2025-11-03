# Xamrock CLI

> AI-powered mobile app testing from your terminal

Xamrock CLI brings intelligent UI exploration to your iOS apps with a simple command-line interface. Point it at your app, and watch as AI automatically discovers screens, tests user flows, and generates comprehensive reports.

**[Quick Start](#quick-start)** | **[📚 Full Documentation](https://docs.xamrock.com)**

## Installation

### Homebrew (Recommended)

```bash
# Add the Xamrock tap
brew tap xamrock/tap

# Install the CLI
brew install xamrock

# Verify installation
xamrock --version
```

**Troubleshooting:** If `xamrock` command is not found after installation:
```bash
brew link xamrock
```

**[Other installation methods →](https://docs.xamrock.com/installation)**

## Quick Start

### Before You Start: Pre-flight Checklist

Before running your first exploration, make sure:

- ✅ **Your app builds successfully** - Open in Xcode and press ⌘B to build
- ✅ **Your app runs in simulator** - Press ⌘R and verify it launches without errors
- ✅ **Simulator is currently open** - Keep Simulator.app running in the background
- ✅ **You know your bundle ID** - Find it in Xcode: Project Settings → General → Bundle Identifier

### Run Your First Exploration

```bash
# Navigate to your Xcode project directory
cd /path/to/YourApp

# Start AI exploration (replace with your actual bundle ID)
xamrock explore --app com.example.YourApp
```

**That's it!** The CLI will:
1. ✅ Validate your environment and configuration
2. 📝 Generate a test file at `scout-results/ScoutCLIExploration.swift`
3. 🤖 Run the AI exploration in your simulator
4. 📊 Save results, screenshots, and reports to `scout-results/`

### What You Get

After exploration completes, you'll find:

```
scout-results/
├── ScoutCLIExploration.swift    # Generated test file
├── manifest.json                 # Exploration metadata
├── GeneratedTests.swift          # Full test suite
├── FailureReport.md              # Issues discovered
└── dashboard.html                # Visual report
```

**Next Steps:** [Learn how to integrate these tests into your project →](https://docs.xamrock.com/integration)

## Common Issues

The CLI provides detailed error messages with suggestions when something goes wrong. Here's how to handle the most common issues:

### "Unable to find a suitable simulator"

**Error message you'll see:**
```
Error:
  Unable to find a destination matching the provided destination specifier

💡 Suggestion:
  Unable to find a suitable simulator.

  Try:
    1. Open Simulator.app to ensure simulators are available
    2. List available simulators: xcrun simctl list devices
    3. Specify a device: xamrock explore --device "iPhone 15"
```

**Solution:** Open Simulator.app first, or explicitly specify which simulator to use:
```bash
# List available simulators
xcrun simctl list devices

# Use a specific simulator
xamrock explore --app com.example.App --device "iPhone 15 Pro"
```

### "Scheme not found" or "Build failed"

**What to check:**
1. Make sure your app builds successfully in Xcode (⌘B)
2. Verify you're running the command from your project directory containing `.xcodeproj` or `.xcworkspace`
3. Check that your scheme name matches your project name

**If project isn't in current directory:**
```bash
xamrock explore --app com.example.App --project-path /path/to/YourApp.xcodeproj
```

### Exit Code 65 Errors

When the CLI exits with code 65, it will show you:
- **The specific error** from xcodebuild output
- **Suggested fixes** based on the error type
- **Diagnostic commands** to investigate further

**Example:**
```
❌ Exploration Failed (Exit Code: 65)

Error:
  Build failed - check compilation errors

💡 Suggestion:
  Build compilation failed.

  Try:
    1. Open your project in Xcode and fix compilation errors
    2. Build the project manually: Cmd+B
    3. Ensure all dependencies are resolved
```

### Getting More Details

Use the `--verbose` flag to see detailed output including the exact xcodebuild commands being run:

```bash
xamrock explore --app com.example.App --verbose
```

### Quick Diagnostic Commands

```bash
# List available iOS simulators
xcrun simctl list devices

# Show schemes in your project
xcodebuild -list -project YourApp.xcodeproj

# Check if your app is installed on the simulator
xcrun simctl get_app_container booted com.example.YourApp
```

## Command Options

The most common options for `xamrock explore`:

| Option | Description | Example |
|--------|-------------|---------|
| `--app, -a` | Your app's bundle ID (required) | `--app com.example.MyApp` |
| `--steps, -s` | Number of exploration steps | `--steps 30` |
| `--device, -d` | Target simulator name | `--device "iPhone 15"` |
| `--verbose, -v` | Show detailed output | `--verbose` |
| `--output, -o` | Custom output directory | `--output ./my-results` |

**[See all options →](https://docs.xamrock.com/command-reference)**

## Documentation

For comprehensive documentation, visit **[docs.xamrock.com](https://docs.xamrock.com)**

**Popular topics:**
- [Installation & Setup](https://docs.xamrock.com/installation)
- [Integration Guide](https://docs.xamrock.com/integration) - Adding tests to your Xcode project
- [CI/CD Setup](https://docs.xamrock.com/ci-cd) - GitHub Actions, etc.
- [Command Reference](https://docs.xamrock.com/command-reference) - All flags and options
- [Troubleshooting](https://docs.xamrock.com/troubleshooting) - Detailed error solutions

## Need Help?

- **Email:** context@xamrock.com
- **Discord Community:** [Join here](https://discord.gg/Pvmbamg2ny)
- **GitHub Issues:** [Report a bug](https://github.com/xamrock/cli/issues)

## License

MIT License - see [LICENSE](LICENSE) for details.
