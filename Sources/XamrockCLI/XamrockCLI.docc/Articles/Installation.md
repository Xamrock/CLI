# Installation

Multiple ways to install Xamrock CLI on your system.

## Overview

Xamrock CLI can be installed via Homebrew (recommended) or built from source. This guide covers all installation methods and how to verify your installation.

## Homebrew Installation (Recommended)

The easiest way to install Xamrock CLI is through Homebrew:

```bash
# Add the Xamrock tap
brew tap xamrock/tap

# Install the CLI
brew install xamrock

# Verify installation
xamrock --version
```

### Updating via Homebrew

To update to the latest version:

```bash
brew update
brew upgrade xamrock
```

### Troubleshooting Homebrew Installation

**Command not found after installation:**

If `xamrock` is not found after installing, link the binary:

```bash
brew link xamrock
```

Then verify:

```bash
which xamrock  # Should output: /opt/homebrew/bin/xamrock
```

**Build fails with "Command Line Tools are too outdated":**

Update your Xcode Command Line Tools:

```bash
xcode-select --install
```

Or update via System Settings → General → Software Update.

## Building from Source

For development or if you prefer to build from source:

### Prerequisites

- macOS 26.0+
- Xcode with Swift 6.0+
- Command Line Tools installed

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/Xamrock/CLI.git
cd CLI

# Build and install to /usr/local/bin
make install

# Or build without installing
swift build -c release

# Run directly from build directory
.build/release/XamrockCLI explore --app com.example.YourApp
```

### Build Targets

The Makefile provides several targets:

```bash
make build       # Build in release mode
make install     # Build and install to /usr/local/bin
make test        # Run test suite
make clean       # Clean build artifacts
```

## Installation Verification

After installation, verify everything is working:

```bash
# Check version
xamrock --version

# View help
xamrock --help

# Test with explore command
xamrock explore --help
```

Expected output:
```
OVERVIEW: AI-powered mobile app testing from your terminal

USAGE: xamrock explore [options]

OPTIONS:
  -a, --app <bundle-id>     Bundle ID of your iOS app (required)
  -s, --steps <count>       Number of exploration steps (default: 20)
  ...
```

## System Requirements

- **Operating System**: macOS 26.0 or later
- **Xcode**: Latest version with Swift 6.0+
- **Storage**: ~50MB for CLI, additional space for documentation archives
- **Memory**: Minimal overhead; test execution uses standard XCUITest resources

## Uninstallation

### Homebrew

```bash
brew uninstall xamrock
brew untap xamrock/tap
```

### Manual Build

```bash
# If installed via make install
sudo rm /usr/local/bin/xamrock

# Remove build artifacts
cd CLI
make clean
```

## What's Installed

When you install Xamrock CLI, you get:

- **xamrock** binary: The main command-line tool
- **Man pages**: Documentation accessible via `man xamrock`
- **Shell completions**: Auto-completion for bash/zsh (if configured)

## Next Steps

- Follow the <doc:GettingStarted> guide to run your first exploration
- Learn about <doc:Configuration-article> options
- Set up <doc:CI-Integration> for automated testing
