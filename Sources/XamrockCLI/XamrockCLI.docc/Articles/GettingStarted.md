# Getting Started

Start exploring your iOS app with AI-powered testing in minutes.

## Overview

Xamrock CLI helps you automatically test your iOS applications by generating intelligent test suites. This guide will walk you through your first exploration session.

## Prerequisites

Before you begin, make sure you have:

- macOS 26.0 or later
- Xcode installed
- iOS 26.0+ simulator or device
- Swift 6.0 or later

## Quick Start

### Step 1: Install Xamrock CLI

Install via Homebrew:

```bash
brew tap xamrock/tap
brew install xamrock
```

Or build from source:

```bash
git clone https://github.com/Xamrock/CLI.git
cd CLI
make install
```

### Step 2: Generate Your First Test

Run the explore command with your app's bundle identifier:

```bash
xamrock explore --app com.example.YourApp
```

This creates a test file at `scout-results/ScoutCLIExploration.swift` configured for your app.

### Step 3: Add Test to Your Xcode Project

Copy the generated test to your UITests target:

```bash
cp scout-results/ScoutCLIExploration.swift YourAppUITests/
```

Then add it to your project in Xcode:
1. Open your Xcode project
2. File → Add Files to "YourApp"...
3. Select `ScoutCLIExploration.swift`
4. Make sure it's added to your UITests target

### Step 4: Run the Exploration

Press `⌘U` in Xcode to run your tests, or use xcodebuild:

```bash
xcodebuild test -project YourApp.xcodeproj -scheme YourApp
```

The AI will automatically:
- Explore your app for approximately 20 interactions
- Take screenshots of each screen
- Test user flows intelligently
- Generate comprehensive reports

### Step 5: Review Results

After the test completes, check the results:

```bash
# View the interactive dashboard
open scout-results/*/dashboard.html

# Read the failure report
cat scout-results/*/FailureReport.md

# Review generated tests
cat scout-results/*/GeneratedTests.swift
```

## What You Get

Each exploration run generates:

- **ScoutCLIExploration.swift**: The test file to add to your project (one-time setup)
- **GeneratedTests.swift**: A complete test suite with 8+ specific tests
- **dashboard.html**: Interactive visual report with screenshots and navigation maps
- **FailureReport.md**: Issues and accessibility problems found during exploration
- **manifest.json**: Metadata for CI/CD integration

## Next Steps

- Learn about <doc:Installation> options
- Explore <doc:Configuration-article> settings
- Set up <doc:CI-Integration> for automated testing
- Troubleshoot common issues in <doc:Troubleshooting>

## Example: Custom Exploration

You can customize the exploration with additional options:

```bash
xamrock explore \
  --app com.example.ShoppingApp \
  --steps 30 \
  --goal "Test the checkout flow and payment screens" \
  --output ./test-results \
  --verbose
```

This will generate a test that:
- Performs 30 exploration steps (instead of default 20)
- Focuses on checkout and payment functionality
- Saves results to `./test-results`
- Shows detailed output during generation
