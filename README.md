# Xamrock CLI

> AI-powered mobile app testing from your terminal

Xamrock CLI brings intelligent UI exploration to your iOS apps with a simple command-line interface. Point it at your app, and watch as AI automatically discovers screens, tests user flows, and generates comprehensive reports.

**[📚 Full Documentation](https://docs.xamrock.com)** | [Quick Start](#quick-start) | [Installation](#installation)

## Quick Start

### Prerequisites

- macOS 26.0+ with Xcode installed
- iOS 26.0+ simulator or device
- Swift 6.0+

### Installation

#### Homebrew (Recommended)

```bash
# Add the Xamrock tap
brew tap xamrock/tap

# Install the CLI
brew install xamrock

# Run your first exploration
xamrock explore --app com.example.YourApp

# Add the generated test to your project
cp scout-results/ScoutCLIExploration.swift YourAppUITests/

# Run the test in Xcode (⌘U) or via xcodebuild
xcodebuild test -project YourApp.xcodeproj -scheme YourApp
```

#### Building from Source

```bash
# Clone the repository
git clone https://github.com/Xamrock/CLI.git
cd CLI

# Build and install
make install

# Or build only
swift build -c release
.build/release/XamrockCLI explore --app com.example.YourApp
```

The CLI will:
1. ✅ Validate your environment
2. 📝 Generate test file configured for your app
3. 💾 Save to `scout-results/ScoutCLIExploration.swift`

Then when you run the test:
1. 🤖 AI automatically explores your app
2. 📊 Generates reports and dashboards
3. 📦 Saves everything to `scout-results/`

## Usage

### Basic Exploration

**Step 1: Generate the test**

```bash
xamrock explore --app com.yourcompany.YourApp
```

This creates `scout-results/ScoutCLIExploration.swift` configured with:
- Your app's bundle ID
- 20 exploration steps (customizable)
- Default exploration goal
- Output directory settings

**Step 2: Add to your Xcode project** (one-time setup)

```bash
# Copy to your UITests target
cp scout-results/ScoutCLIExploration.swift YourAppUITests/

# Then add it in Xcode:
# File → Add Files to "YourApp"... → Select ScoutCLIExploration.swift
# Make sure it's added to your UITests target
```

**Step 3: Run the exploration**

In Xcode: Press `⌘U` to run tests

Or via command line:
```bash
xcodebuild test -project YourApp.xcodeproj -scheme YourApp
```

The AI will automatically:
- Explore your app for ~20 interactions
- Take screenshots of each screen
- Test user flows intelligently
- Generate comprehensive reports

### With Custom Options

```bash
xamrock explore \
  --app com.example.ShoppingApp \
  --steps 30 \
  --goal "Test the checkout flow and payment screens" \
  --output ./test-results \
  --verbose
```

### CI/CD Mode

For reproducible results in continuous integration:

```bash
xamrock explore \
  --app com.example.App \
  --ci-mode \
  --fail-on-issues \
  --no-generate-dashboard
```

This enables:
- Deterministic behavior (fixed seed, low temperature)
- Exit code 1 if critical issues found
- Minimal output for CI logs
- JSON manifest for parsing

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--app, -a` | Bundle ID of your iOS app | **Required** |
| `--platform, -p` | Platform: `ios` or `android` | Auto-detect |
| `--steps, -s` | Number of exploration steps | 20 |
| `--goal, -g` | What to focus on testing | "Explore the app systematically" |
| `--output, -o` | Where to save results | `./scout-results` |
| `--ci-mode` | Enable CI-friendly mode | false |
| `--fail-on-issues` | Exit with error if issues found | false |
| `--verbose, -v` | Show detailed output | false |
| `--device, -d` | Target simulator/device | Default simulator |
| `--no-generate-dashboard` | Skip HTML dashboard | false |

## What You Get

After an exploration run, you'll find:

```
scout-results/
├── ScoutCLIExploration.swift           # Test to add to your project
├── manifest.json                        # Metadata for CI/CD
└── 2025-10-27_23-34-49_ABC123/         # Timestamped results folder
    ├── GeneratedTests.swift             # Full test suite (8+ tests)
    ├── FailureReport.md                 # Issues found during exploration
    └── dashboard.html                   # Interactive visual report (1MB+)
```

**Note:** The timestamped subfolder is created when you run the test, not by the CLI.

### Generated Test Suite

The `GeneratedTests.swift` file contains ready-to-run tests:

```swift
@available(iOS 26.0, *)
final class ScoutCLIExploration: XCTestCase {
    func testExploration() throws {
        let app = XCUIApplication()
        app.launch()

        let config = ExplorationConfig(
            steps: 30,
            goal: "Test checkout flow",
            outputDirectory: URL(fileURLWithPath: "./scout-results"),
            generateTests: true,
            generateDashboard: true,
            failOnCriticalIssues: false,
            verboseOutput: false
        )

        let result = try Scout.explore(app, config: config)
        // Validates 30 interaction steps completed successfully
    }
}
```

Add this to your project and run it like any other XCUITest!

### HTML Dashboard

Open `dashboard.html` to see:
- 📱 Screenshots of every screen discovered
- 🗺️ Visual map of your app's navigation
- ⚠️ Issues and accessibility problems found
- 📈 Coverage metrics and exploration statistics

## Development Workflow

### Local Testing

1. **Generate test file:**
   ```bash
   xamrock explore --app com.example.App --steps 10 --verbose
   ```

2. **Add to Xcode (first time only):**
   ```bash
   cp scout-results/ScoutCLIExploration.swift MyAppUITests/
   ```
   Then add the file to your UITests target in Xcode.

3. **Run exploration:**
   ```bash
   # In Xcode: Press ⌘U
   # Or via CLI:
   xcodebuild test -project MyApp.xcodeproj -scheme MyApp
   ```

4. **Review results:**
   ```bash
   open scout-results/*/dashboard.html
   cat scout-results/*/FailureReport.md
   ```

5. **Next iterations:** Just re-run step 3 - the test file stays in your project!

### CI/CD Integration

#### GitHub Actions

```yaml
name: AI-Powered UI Testing

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Xamrock CLI
        run: |
          brew tap xamrock/tap
          brew install xamrock

      - name: Run AI Exploration
        run: |
          xamrock explore \
            --app com.example.YourApp \
            --ci-mode \
            --fail-on-issues \
            --output ./test-results

      - name: Upload Results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: exploration-results
          path: ./test-results/
```

## How It Works

Xamrock CLI is a test generator that creates XCUITest files powered by [AITestScout](../AITestScout):

### What the CLI Does

1. **Validates** your environment (Xcode, bundle ID, project structure)
2. **Generates** `ScoutCLIExploration.swift` configured for your app
3. **Saves** the test file to `scout-results/`
4. **Creates** `manifest.json` with metadata

### What Happens When You Run the Test

Once you add `ScoutCLIExploration.swift` to your Xcode project and run it:

1. **Launch**: XCUITest starts your app
2. **Explore**: AITestScout AI makes intelligent decisions about which UI elements to interact with
3. **Document**: Screenshots, failures, and navigation paths are captured
4. **Generate**: A comprehensive test suite is created based on what was discovered
5. **Report**: HTML dashboard, failure report, and test files are saved

The CLI is a **test generator**, not a test runner. This gives you full control over when and how tests execute.

## Troubleshooting

### Homebrew Installation Issues

**Command not found after installation:**

If `xamrock` is not found after installing via Homebrew, run:
```bash
brew link xamrock
```

**Build fails with "Command Line Tools are too outdated":**

Update your Command Line Tools:
```bash
xcode-select --install
```

Or update via Software Update in System Settings.

**Verify installation:**
```bash
which xamrock
xamrock --version
```

## Roadmap

- [ ] Android support (via Swift for Android & Espresso)
- [ ] Cloud results dashboard
- [ ] Custom exploration strategies
- [ ] Regression detection

## Documentation

For comprehensive documentation, visit **[docs.xamrock.com](https://docs.xamrock.com)**

Topics covered:
- Getting Started guide
- Installation options
- CI/CD integration
- Configuration reference
- Troubleshooting
- Generated tests format

The documentation is built with DocC and automatically updated on every commit.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Questions?

- Email: context@xamrock.com
- Discussions: [Discord](https://discord.gg/Pvmbamg2ny)
- Issues: [GitHub Issues](https://github.com/xamrock/cli/issues)