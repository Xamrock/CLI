# Xamrock CLI

> AI-powered mobile app testing from your terminal

Xamrock CLI brings intelligent UI exploration to your iOS apps with a simple command-line interface. Point it at your app, and watch as AI automatically discovers screens, tests user flows, and generates comprehensive reports.

## Quick Start

### Prerequisites

- macOS 26.0+ with Xcode installed
- iOS 26.0+ simulator or device
- Swift 6.0+

### Installation

```bash
# Clone the repository
git clone https://github.com/Xamrock/CLI.git
cd Xamrock/CLI

# Build the CLI
swift build

# Run your first exploration
.build/debug/XamrockCLI explore --app com.example.YourApp --platform ios
```

That's it! The CLI will:
1. ✅ Validate your environment
2. 🤖 Launch AI-powered exploration
3. 📊 Generate test files, reports, and dashboards
4. 📦 Package everything in `./scout-results/`

## Usage

### Basic Exploration

The simplest way to explore your iOS app:

```bash
xamrock explore --app com.yourcompany.YourApp
```

This will:
- Auto-detect your Xcode project
- Run 20 exploration steps
- Generate a comprehensive test suite
- Create an HTML dashboard of results

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
├── GeneratedTests.swift      # Runnable XCUITest suite
├── FailureReport.md          # Issues found during exploration
├── dashboard.html            # Interactive visual report
├── exploration.json          # Full exploration data
└── manifest.json             # Metadata for CI/CD
```

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

1. **Run exploration during development:**
   ```bash
   xamrock explore --app com.example.App --steps 10 --verbose
   ```

2. **Review the dashboard:**
   ```bash
   open scout-results/dashboard.html
   ```

3. **Add generated tests to your project:**
   - Copy `scout-results/GeneratedTests.swift` to your test target
   - Run tests with `⌘U` in Xcode or `xcodebuild test`

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
          git clone https://github.com/Xamrock/CLI.git
          cd Xamrock/CLI
          swift build -c release
          echo "$PWD/.build/release" >> $GITHUB_PATH

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

Xamrock CLI is a wrapper around [AITestScout](../AITestScout), orchestrating the entire exploration workflow:

1. **Validation**: Checks for Xcode, validates bundle ID, confirms project structure
2. **Test Generation**: Creates a temporary XCUITest file configured for your app
3. **Execution**: Runs `xcodebuild test` with the generated test
4. **Collection**: Gathers all artifacts (tests, reports, dashboards)
5. **Packaging**: Creates a manifest.json for CI/CD integration

The CLI doesn't directly interact with your app - instead it generates and executes XCUITests that use AITestScout to perform intelligent exploration.

## Roadmap

- [ ] Android support (via Swift for Android & Espresso)
- [ ] Cloud results dashboard
- [ ] Custom exploration strategies
- [ ] Regression detection

## License

MIT License - see [LICENSE](LICENSE) for details.

## Questions?

- Email: context@xamrock.com
- Discussions: [Discord](https://discord.gg/Pvmbamg2ny)
- Issues: [GitHub Issues](https://github.com/xamrock/cli/issues)