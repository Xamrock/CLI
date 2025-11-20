# Dashboard Integration Plan for Xamrock CLI

## Executive Summary

This document outlines the plan to integrate XamrockDashboard development workflow into the Xamrock CLI, following established coding standards and architectural patterns from the existing CLI codebase.

## Current State Analysis

### Existing CLI Architecture

The Xamrock CLI follows a well-structured, modular architecture:

#### **Command Structure**
- Uses `ArgumentParser` framework for CLI parsing
- Commands are organized hierarchically with parent/subcommand relationships
- Each command is a separate `ParsableCommand` struct with clear responsibilities

**Pattern Example:**
```swift
// Parent command (command group)
struct FixtureCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fixture",
        abstract: "...",
        subcommands: [
            FixtureInitCommand.self,
            FixtureValidateCommand.self,
            FixtureAnalyzeCommand.self
        ]
    )
}

// Leaf command (actual implementation)
struct FixtureInitCommand: ParsableCommand {
    @Option var name: String?
    @Flag var verbose: Bool = false

    func run() throws {
        // Implementation here
    }
}
```

#### **Core Module Organization**

Located in `Sources/XamrockCLI/Core/`:
- **Artifacts** - Manifest generation and artifact handling
- **Backend** - Backend API client and session management
- **Config** - Configuration management and environment handling
- **Execution** - xcodebuild runner and test execution
- **Fixtures** - Test data fixture management
- **Formatting** - Console output formatting with colors
- **Platform** - Platform-specific orchestrators (iOS, Android)

#### **Key Coding Standards Identified**

1. **MARK Comments**: Clear section organization
   ```swift
   // MARK: - Command Execution
   // MARK: - Configuration Building
   // MARK: - Backend Upload
   ```

2. **Console Formatting**: Consistent use of `ConsoleFormatter`
   - Colored output (green for success, red for errors, cyan for info)
   - Progress indicators: `⏳` for in-progress, `✅` for complete
   - Emoji icons for different file types and states
   - Formatted banners and tables

3. **Error Handling**: Rich error messages with suggestions
   ```swift
   ❌ ERROR: Build failed

   💡 Suggestion:
     Build compilation failed.

     Try:
       1. Open your project in Xcode and fix compilation errors
       2. Build the project manually: Cmd+B
       3. Ensure all dependencies are resolved
   ```

4. **Async/Await**: Modern Swift concurrency throughout
   - `AsyncParsableCommand` for async commands
   - Proper error propagation with `throws`

5. **Documentation**: Extensive inline comments and help text
   - Each option has clear `help:` text
   - Commands include `discussion:` with examples
   - Usage examples in multiline strings

6. **Testing**: Comprehensive unit tests for all core functionality

## Proposed Dashboard Command Structure

### Command Hierarchy

```
xamrock
├── explore              (existing)
├── fixture              (existing)
│   ├── init
│   ├── validate
│   └── analyze
├── organization         (existing)
└── dashboard            (NEW)
    ├── dev              (NEW - start dev server with HMR)
    ├── build            (NEW - build for production)
    ├── deploy           (NEW - deploy to hosting)
    └── new              (NEW - scaffold new dashboard)
```

### Implementation Plan

#### Phase 1: Core Dashboard Commands (Must-Have)

**Files to Create:**
```
Sources/XamrockCLI/
├── Commands/
│   ├── DashboardCommand.swift              # Parent command
│   ├── DashboardDevCommand.swift           # Dev server with HMR
│   ├── DashboardBuildCommand.swift         # Production build
│   └── DashboardDeployCommand.swift        # Deployment
└── Core/
    ├── Dashboard/
    │   ├── DashboardBuilder.swift          # Build orchestration
    │   ├── DashboardDevServer.swift        # Dev server with file watching
    │   ├── SwiftWASMToolchain.swift        # WASM toolchain management
    │   └── HotReloadManager.swift          # Hot module replacement
    └── Formatting/
        └── DashboardFormatter.swift         # Dashboard-specific formatting
```

### 1. DashboardCommand.swift

```swift
import Foundation
import ArgumentParser

/// Dashboard management commands
public struct DashboardCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "dashboard",
        abstract: "Manage XamrockDashboard development and deployment",
        discussion: """
        Dashboard commands help you develop, build, and deploy the XamrockDashboard web application.

        Common workflows:
          1. Start dev server: xamrock dashboard dev
          2. Build for production: xamrock dashboard build --production
          3. Deploy: xamrock dashboard deploy
          4. Create new dashboard: xamrock dashboard new MyDashboard

        The dashboard is built with Swift + WebAssembly using Gossamer framework.
        """,
        subcommands: [
            DashboardDevCommand.self,
            DashboardBuildCommand.self,
            DashboardDeployCommand.self,
            DashboardNewCommand.self
        ]
    )

    public init() {}
}
```

### 2. DashboardDevCommand.swift

```swift
import Foundation
import ArgumentParser

/// Start dashboard development server with hot reload
public struct DashboardDevCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "dev",
        abstract: "Start development server with hot reload",
        discussion: """
        Starts a local development server for XamrockDashboard with:
          - File watching for Swift sources
          - Hot module replacement (HMR)
          - Automatic browser refresh
          - Fast incremental builds

        Examples:
          xamrock dashboard dev
          xamrock dashboard dev --port 3000
          xamrock dashboard dev --open
        """
    )

    // MARK: - Server Options

    @Option(name: [.short, .customLong("port")], help: "Dev server port (default: 8000)")
    public var port: Int = 8000

    @Option(name: .customLong("host"), help: "Dev server host (default: localhost)")
    public var host: String = "localhost"

    @Flag(name: .customLong("open"), help: "Open browser automatically")
    public var openBrowser: Bool = false

    // MARK: - Build Options

    @Flag(name: .customLong("skip-initial-build"), help: "Skip initial build and use existing artifacts")
    public var skipInitialBuild: Bool = false

    @Option(name: .customLong("dashboard-path"), help: "Path to XamrockDashboard directory")
    public var dashboardPath: String?

    @Flag(name: [.short, .customLong("verbose")], help: "Verbose output")
    public var verbose: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() async throws {
        let formatter = ConsoleFormatter(verbose: verbose)

        // Print start banner
        print("")
        print(formatter.formatColored("╔═══════════════════════════════════════════════════════════════╗", color: .cyan))
        print(formatter.formatColored("║           🌐 XamrockDashboard Dev Server                    ║", color: .cyan))
        print(formatter.formatColored("╚═══════════════════════════════════════════════════════════════╝", color: .cyan))
        print("")

        // Resolve dashboard path
        let dashboardURL = try resolveDashboardPath()
        print("  " + formatter.formatColored("Dashboard:", color: .bold) + " \(dashboardURL.path)")
        print("  " + formatter.formatColored("Server:", color: .bold) + " http://\(host):\(port)")
        print("")

        // Initialize dev server
        let devServer = DashboardDevServer(
            dashboardPath: dashboardURL,
            host: host,
            port: port,
            verbose: verbose
        )

        // Perform initial build unless skipped
        if !skipInitialBuild {
            print(formatter.formatProgress(step: "Building dashboard", isDone: false))
            try await devServer.performInitialBuild()
            print(formatter.formatProgress(step: "Building dashboard", isDone: true))
        }

        // Start dev server
        print(formatter.formatProgress(step: "Starting dev server", isDone: false))
        try await devServer.start()
        print(formatter.formatProgress(step: "Starting dev server", isDone: true))
        print("")
        print(formatter.formatSuccess("Dev server running at:"))
        print(formatter.formatLink("http://\(host):\(port)"))
        print("")
        print(formatter.formatInfo("Watching for file changes... Press Ctrl+C to stop"))
        print("")

        // Open browser if requested
        if openBrowser {
            try openInBrowser(url: "http://\(host):\(port)")
        }

        // Keep running until interrupted
        try await devServer.keepAlive()
    }

    // MARK: - Internal Methods

    func resolveDashboardPath() throws -> URL {
        if let path = dashboardPath {
            return URL(fileURLWithPath: path)
        }

        // Auto-detect: look for XamrockDashboard in parent directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Try ../XamrockDashboard
        let parentDashboard = currentDir
            .deletingLastPathComponent()
            .appendingPathComponent("XamrockDashboard")

        if FileManager.default.fileExists(atPath: parentDashboard.path) {
            return parentDashboard
        }

        // Try ./XamrockDashboard
        let localDashboard = currentDir.appendingPathComponent("XamrockDashboard")
        if FileManager.default.fileExists(atPath: localDashboard.path) {
            return localDashboard
        }

        throw DashboardError.dashboardNotFound(
            "Could not find XamrockDashboard directory. Use --dashboard-path to specify location."
        )
    }

    func openInBrowser(url: String) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try process.run()
        #endif
    }
}
```

### 3. DashboardBuildCommand.swift

```swift
import Foundation
import ArgumentParser

/// Build dashboard for production
public struct DashboardBuildCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build dashboard for production deployment",
        discussion: """
        Builds the XamrockDashboard for production with optimizations:
          - Full WASM optimization
          - Minified JavaScript
          - Source maps (optional)
          - Bundle size analysis

        Examples:
          xamrock dashboard build
          xamrock dashboard build --output ./dist
          xamrock dashboard build --analyze
        """
    )

    // MARK: - Output Options

    @Option(name: [.short, .customLong("output")], help: "Output directory (default: ./dist)")
    public var outputPath: String?

    @Option(name: .customLong("dashboard-path"), help: "Path to XamrockDashboard directory")
    public var dashboardPath: String?

    // MARK: - Build Options

    @Flag(name: .customLong("production"), help: "Production build with full optimizations")
    public var production: Bool = true

    @Flag(name: .customLong("source-maps"), help: "Generate source maps for debugging")
    public var sourceMaps: Bool = false

    @Flag(name: .customLong("analyze"), help: "Analyze bundle size")
    public var analyze: Bool = false

    @Flag(name: [.short, .customLong("verbose")], help: "Verbose output")
    public var verbose: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() async throws {
        let formatter = ConsoleFormatter(verbose: verbose)

        // Print start banner
        print(formatter.formatColored("🔨 Building XamrockDashboard for production", color: .bold))
        print("")

        // Resolve paths
        let dashboardURL = try resolveDashboardPath()
        let outputURL = resolveOutputPath()

        print("  " + formatter.formatColored("Dashboard:", color: .bold) + " \(dashboardURL.path)")
        print("  " + formatter.formatColored("Output:", color: .bold) + " \(outputURL.path)")
        print("")

        // Initialize builder
        let builder = DashboardBuilder(
            dashboardPath: dashboardURL,
            outputPath: outputURL,
            production: production,
            verbose: verbose
        )

        // Clean previous build
        print(formatter.formatProgress(step: "Cleaning previous build", isDone: false))
        try builder.clean()
        print(formatter.formatProgress(step: "Cleaning previous build", isDone: true))

        // Build WASM
        print(formatter.formatProgress(step: "Building Swift → WASM", isDone: false))
        try await builder.buildWASM()
        print(formatter.formatProgress(step: "Building Swift → WASM", isDone: true))

        // Optimize (if production)
        if production {
            print(formatter.formatProgress(step: "Optimizing WASM", isDone: false))
            try await builder.optimizeWASM()
            print(formatter.formatProgress(step: "Optimizing WASM", isDone: true))
        }

        // Copy static assets
        print(formatter.formatProgress(step: "Copying static assets", isDone: false))
        try builder.copyAssets()
        print(formatter.formatProgress(step: "Copying static assets", isDone: true))

        print("")
        print(formatter.formatSuccess("Build complete!"))
        print("")

        // Show bundle info
        let bundleSize = try builder.getBundleSize()
        print("  " + formatter.formatColored("WASM Size:", color: .bold) + " \(formatFileSize(bundleSize.wasm))")
        print("  " + formatter.formatColored("JS Size:", color: .bold) + " \(formatFileSize(bundleSize.js))")
        print("  " + formatter.formatColored("Total:", color: .bold) + " \(formatFileSize(bundleSize.total))")
        print("")

        // Analyze if requested
        if analyze {
            print(formatter.formatProgress(step: "Analyzing bundle", isDone: false))
            try builder.analyzeBundleSize()
            print(formatter.formatProgress(step: "Analyzing bundle", isDone: true))
        }
    }

    // MARK: - Internal Methods

    func resolveDashboardPath() throws -> URL {
        // Same as DashboardDevCommand
        // ... (implementation)
        return URL(fileURLWithPath: "")
    }

    func resolveOutputPath() -> URL {
        if let path = outputPath {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("dist")
    }

    func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}
```

## Developer Experience Improvements

### Before (Current State)
```bash
# Manual Docker setup
docker-compose up -d

# Manual carton build
carton bundle --product XamrockDashboard --debug

# Manual file copying
cp .build/.../XamrockDashboard.wasm Public/
cp .build/.../runtime.js Public/
# ... etc

# Manual server start
python3 -m http.server 8000

# Every code change: repeat all steps above
```

### After (With CLI Integration)
```bash
# One command to start developing
xamrock dashboard dev

# Automatic:
# - Builds WASM
# - Starts dev server
# - Watches for changes
# - Hot reloads browser
# - Shows errors inline
```

### Production Build

**Before:**
```bash
# Complex Docker commands
docker run --rm -v ...

# Manual optimization
wasm-opt -Oz ...

# Manual file organization
mkdir dist
cp ...
```

**After:**
```bash
xamrock dashboard build --production
# → Optimized, minified, ready to deploy
```

## Benefits for iOS Developers

### 1. **Familiar Workflow**
- Single CLI tool (like `xcodebuild`)
- Clear error messages (like Xcode)
- Fast feedback loop (like SwiftUI previews)

### 2. **Zero Configuration**
- Auto-detects XamrockDashboard directory
- Downloads Swift WASM toolchain if needed
- Sets up dev environment automatically

### 3. **Integrated Experience**
```bash
# Develop dashboard while running backend
xamrock backend dev &    # Terminal 1
xamrock dashboard dev    # Terminal 2

# Or run both together
xamrock dev --all        # Future enhancement
```

### 4. **Better Error Messages**

**Before:**
```
error: module compilation failed
```

**After:**
```
❌ ERROR: Element initializer missing 'eventHandlers' parameter

💡 Suggestion:
  The Element struct was recently updated to support event handlers.

  Update your code:
    Element("div", attributes: [...])
  To:
    Element("div", attributes: [...], eventHandlers: [:])

  See docs: https://docs.xamrock.com/gossamer/events
```

### 5. **Hot Module Replacement**

Edit Swift code → Save → Browser updates in <2 seconds
(No need to refresh, no losing state)

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create `DashboardCommand` structure
- [ ] Implement `DashboardDevCommand` basic version
- [ ] Implement `DashboardBuildCommand` basic version
- [ ] Add to main CLI.swift subcommands

### Phase 2: Dev Server (Week 2)
- [ ] Implement `DashboardDevServer`
- [ ] Add file watching
- [ ] Add basic hot reload (full page refresh)
- [ ] Error overlay in browser

### Phase 3: Build Optimization (Week 3)
- [ ] Implement `DashboardBuilder`
- [ ] Add WASM optimization
- [ ] Add bundle size analysis
- [ ] Production-ready builds

### Phase 4: Advanced Features (Week 4)
- [ ] True hot module replacement (preserve state)
- [ ] Source maps for debugging
- [ ] `xamrock dashboard new` scaffolding
- [ ] `xamrock dashboard deploy` to various hosts

## Testing Strategy

Following existing CLI patterns:

```swift
// Tests/XamrockCLITests/DashboardDevCommandTests.swift
final class DashboardDevCommandTests: XCTestCase {

    func testResolveDashboardPath_AutoDetect() throws {
        // Test auto-detection of dashboard directory
    }

    func testResolveDashboardPath_ExplicitPath() throws {
        // Test explicit path override
    }

    func testDevServer_StartsSuccessfully() async throws {
        // Test dev server startup
    }
}
```

## Documentation Updates

### README.md Additions

```markdown
## Dashboard Development

### Start Development Server

```bash
xamrock dashboard dev
```

This starts a local development server with:
- ✅ Automatic rebuilds on file changes
- ✅ Hot module replacement
- ✅ Error overlay in browser
- ✅ Fast incremental builds

### Build for Production

```bash
xamrock dashboard build --production
```

Outputs optimized dashboard to `./dist/`:
- Minified WASM and JavaScript
- Gzipped assets
- Ready for deployment

### Deploy

```bash
xamrock dashboard deploy
```

Deploys to configured hosting provider.
```

## Coding Standards Compliance

### ✅ Follows Existing Patterns

1. **Command Structure**: Matches `FixtureCommand` pattern
2. **Formatting**: Uses `ConsoleFormatter` consistently
3. **Error Handling**: Rich errors with suggestions
4. **Documentation**: Extensive help text and examples
5. **Testing**: Unit tests for all core functionality
6. **Async/Await**: Modern Swift concurrency
7. **MARK Comments**: Clear code organization

### ✅ New Patterns Introduced

1. **Dev Server**: New concept for CLI, but follows patterns from web dev tools
2. **Hot Reload**: Industry standard for web development
3. **File Watching**: Common in modern dev tools

## Next Steps

1. **Review this plan** - Ensure alignment with vision
2. **Create GitHub issue** - Track implementation progress
3. **Phase 1 PR** - Implement basic command structure
4. **Iterate** - Build incrementally with testing

## Questions for Review

1. Should dashboard commands be in main `xamrock` CLI or separate `xamrock-dashboard`?
   - **Recommendation**: Main CLI (better integration, single tool)

2. Should we support multiple dashboard instances?
   - **Recommendation**: Yes, use `--dashboard-path` flag

3. Should dev server support custom middleware?
   - **Recommendation**: Later phase, keep simple initially

4. Should we integrate with existing backend dev server?
   - **Recommendation**: Yes, future `xamrock dev --all` command

## Success Metrics

After implementation, developers should be able to:

- [ ] Start developing dashboard with **single command**
- [ ] See code changes in browser within **2 seconds**
- [ ] Build production bundle with **zero configuration**
- [ ] Understand all errors with **clear suggestions**
- [ ] Never touch Docker or carton directly

**Target**: Reduce "time to first dashboard edit" from 30+ minutes to **< 2 minutes**
