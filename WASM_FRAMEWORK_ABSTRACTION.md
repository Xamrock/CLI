# Swift WASM Framework Abstraction

## Vision

Make Xamrock CLI the **universal tool for Swift WASM development** - supporting any framework (Gossamer, Tokamak, or custom implementations).

## Current Problem

- `DashboardBuilder` and `DashboardDevServer` are tightly coupled to Gossamer's docker-compose setup
- No way to use the CLI with Tokamak or other Swift WASM frameworks
- Hard-coded assumptions about project structure

## Proposed Architecture

### Protocol-Based Design

```swift
/// Represents any Swift WASM project
public protocol WASMProject {
    /// Framework name (e.g., "Gossamer", "Tokamak", "Custom")
    var frameworkName: String { get }

    /// Project root directory
    var projectPath: URL { get }

    /// Build the WASM binary
    func build(production: Bool, verbose: Bool) async throws

    /// Location of built WASM file after build()
    func wasmArtifactPath(production: Bool) throws -> URL

    /// Static assets to serve alongside WASM (HTML, JS, CSS)
    func staticAssets() throws -> [URL]

    /// Recommended dev server settings
    var devServerDefaults: DevServerDefaults { get }
}

public struct DevServerDefaults {
    let host: String
    let port: Int
    let indexFile: String

    static let standard = DevServerDefaults(
        host: "localhost",
        port: 8000,
        indexFile: "index.html"
    )
}
```

### Framework Detection

```swift
public class WASMProjectDetector {
    /// Auto-detect framework from Package.swift dependencies
    public static func detect(at projectPath: URL) throws -> WASMProject {
        let packagePath = projectPath.appendingPathComponent("Package.swift")
        let packageContents = try String(contentsOf: packagePath)

        if packageContents.contains("Gossamer") {
            return GossamerProject(projectPath: projectPath)
        } else if packageContents.contains("Tokamak") {
            return TokamakProject(projectPath: projectPath)
        } else {
            // Fallback: generic Swift WASM project
            return GenericWASMProject(projectPath: projectPath)
        }
    }
}
```

### Framework Implementations

#### 1. Gossamer (Current)

```swift
public class GossamerProject: WASMProject {
    public let frameworkName = "Gossamer"
    public let projectPath: URL

    public init(projectPath: URL) {
        self.projectPath = projectPath
    }

    public func build(production: Bool, verbose: Bool) async throws {
        // Use docker-compose as currently implemented
        let buildProcess = Process()
        buildProcess.currentDirectoryURL = projectPath
        buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        buildProcess.arguments = ["docker-compose", "up", "swiftwasm-builder"]

        if verbose {
            buildProcess.standardOutput = FileHandle.standardOutput
            buildProcess.standardError = FileHandle.standardError
        }

        try buildProcess.run()
        buildProcess.waitUntilExit()

        guard buildProcess.terminationStatus == 0 else {
            throw WASMError.buildFailed("Docker build failed")
        }
    }

    public func wasmArtifactPath(production: Bool) throws -> URL {
        let buildMode = production ? "release" : "debug"
        return projectPath
            .appendingPathComponent(".build/wasm32-unknown-wasi/\(buildMode)")
    }

    public func staticAssets() throws -> [URL] {
        let publicPath = projectPath.appendingPathComponent("Public")
        return try FileManager.default.contentsOfDirectory(at: publicPath, includingPropertiesForKeys: nil)
            .filter { ["html", "js", "css"].contains($0.pathExtension) }
    }

    public var devServerDefaults: DevServerDefaults {
        .standard
    }
}
```

#### 2. Tokamak (New)

```swift
public class TokamakProject: WASMProject {
    public let frameworkName = "Tokamak"
    public let projectPath: URL

    public init(projectPath: URL) {
        self.projectPath = projectPath
    }

    public func build(production: Bool, verbose: Bool) async throws {
        // Tokamak typically uses carton
        let buildProcess = Process()
        buildProcess.currentDirectoryURL = projectPath
        buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = ["carton", "bundle"]
        if !production {
            args.append("--debug")
        }
        if verbose {
            args.append("--verbose")
        }

        buildProcess.arguments = args

        if verbose {
            buildProcess.standardOutput = FileHandle.standardOutput
            buildProcess.standardError = FileHandle.standardError
        }

        try buildProcess.run()
        buildProcess.waitUntilExit()

        guard buildProcess.terminationStatus == 0 else {
            throw WASMError.buildFailed("Carton build failed")
        }
    }

    public func wasmArtifactPath(production: Bool) throws -> URL {
        // Carton outputs to Bundle directory
        return projectPath.appendingPathComponent("Bundle")
    }

    public func staticAssets() throws -> [URL] {
        // Carton auto-generates index.html, no separate Public dir needed
        return []
    }

    public var devServerDefaults: DevServerDefaults {
        .standard
    }
}
```

#### 3. Generic Swift WASM (Fallback)

```swift
public class GenericWASMProject: WASMProject {
    public let frameworkName = "Generic Swift WASM"
    public let projectPath: URL

    public init(projectPath: URL) {
        self.projectPath = projectPath
    }

    public func build(production: Bool, verbose: Bool) async throws {
        // Use standard Swift Package Manager with WASM target
        let buildProcess = Process()
        buildProcess.currentDirectoryURL = projectPath
        buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = [
            "swift", "build",
            "--triple", "wasm32-unknown-wasi"
        ]

        if production {
            args.append("-c")
            args.append("release")
        }

        buildProcess.arguments = args

        if verbose {
            buildProcess.standardOutput = FileHandle.standardOutput
            buildProcess.standardError = FileHandle.standardError
        }

        try buildProcess.run()
        buildProcess.waitUntilExit()

        guard buildProcess.terminationStatus == 0 else {
            throw WASMError.buildFailed("Swift build failed")
        }
    }

    public func wasmArtifactPath(production: Bool) throws -> URL {
        let buildMode = production ? "release" : "debug"
        return projectPath
            .appendingPathComponent(".build/wasm32-unknown-wasi/\(buildMode)")
    }

    public func staticAssets() throws -> [URL] {
        // Check for common static asset directories
        for dirname in ["Public", "static", "www"] {
            let dirPath = projectPath.appendingPathComponent(dirname)
            if FileManager.default.fileExists(atPath: dirPath.path) {
                return try FileManager.default.contentsOfDirectory(at: dirPath, includingPropertiesForKeys: nil)
                    .filter { ["html", "js", "css"].contains($0.pathExtension) }
            }
        }
        return []
    }

    public var devServerDefaults: DevServerDefaults {
        .standard
    }
}
```

### Updated Builder

```swift
/// Universal WASM builder - works with any framework
public class WASMBuilder {
    private let project: WASMProject
    private let outputPath: URL
    private let production: Bool
    private let verbose: Bool

    public init(
        project: WASMProject,
        outputPath: URL,
        production: Bool = false,
        verbose: Bool = false
    ) {
        self.project = project
        self.outputPath = outputPath
        self.production = production
        self.verbose = verbose
    }

    public func build() async throws {
        if verbose {
            print("Building \(project.frameworkName) project...")
        }

        try await project.build(production: production, verbose: verbose)
    }

    public func copyAssets() throws {
        // Copy WASM artifact
        let wasmSourcePath = try project.wasmArtifactPath(production: production)
        let wasmFiles = try FileManager.default.contentsOfDirectory(at: wasmSourcePath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wasm" }

        guard let wasmFile = wasmFiles.first else {
            throw WASMError.buildFailed("No WASM file found")
        }

        let destWasm = outputPath.appendingPathComponent(wasmFile.lastPathComponent)
        if FileManager.default.fileExists(atPath: destWasm.path) {
            try FileManager.default.removeItem(at: destWasm)
        }
        try FileManager.default.copyItem(at: wasmFile, to: destWasm)

        // Copy static assets
        let assets = try project.staticAssets()
        for asset in assets {
            let dest = outputPath.appendingPathComponent(asset.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: asset, to: dest)
        }
    }
}
```

### Updated Commands

The `DashboardDevCommand` and `DashboardBuildCommand` would be renamed to `WASMDevCommand` and `WASMBuildCommand`:

```swift
// Old: xamrock dashboard dev
// New: xamrock wasm dev  (or keep "dashboard" for backward compat)

public struct WASMDevCommand: AsyncParsableCommand {
    // ... same options as before ...

    public func run() async throws {
        let projectPath = try resolveProjectPath()

        // Auto-detect framework
        let project = try WASMProjectDetector.detect(at: projectPath)

        print("Detected \(project.frameworkName) project")

        // Use universal builder
        let builder = WASMBuilder(
            project: project,
            outputPath: projectPath.appendingPathComponent("Public"),
            production: true,
            verbose: verbose
        )

        if !skipInitialBuild {
            try await builder.build()
            try builder.copyAssets()
        }

        // Start dev server (framework-agnostic)
        let devServer = WASMDevServer(
            projectPath: projectPath,
            host: host,
            port: port,
            verbose: verbose
        )

        try await devServer.start()
        try await devServer.keepAlive()
    }
}
```

## File Structure

```
CLI/Sources/XamrockCLI/
├── Commands/
│   ├── WASMCommand.swift          # Parent command (was DashboardCommand)
│   ├── WASMDevCommand.swift       # Dev server (was DashboardDevCommand)
│   └── WASMBuildCommand.swift     # Production build (was DashboardBuildCommand)
├── Core/
│   └── WASM/
│       ├── WASMProject.swift      # Protocol
│       ├── WASMProjectDetector.swift
│       ├── WASMBuilder.swift      # Universal builder
│       ├── WASMDevServer.swift    # Universal dev server
│       ├── WASMError.swift        # Error types
│       └── Frameworks/
│           ├── GossamerProject.swift
│           ├── TokamakProject.swift
│           └── GenericWASMProject.swift
└── Tests/
    └── WASMTests/
        ├── WASMProjectDetectorTests.swift
        ├── GossamerProjectTests.swift
        └── TokamakProjectTests.swift
```

## Backward Compatibility

To avoid breaking existing users:

```swift
// Keep "dashboard" as an alias to "wasm"
@main
struct Xamrock: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xamrock",
        subcommands: [
            ExploreCommand.self,
            FixtureCommand.self,
            OrganizationCommand.self,
            WASMCommand.self,        // New name
            DashboardCommand.self    // Deprecated alias → WASMCommand
        ]
    )
}
```

## Benefits

1. **Universal Tool**: Works with Gossamer, Tokamak, or any Swift WASM framework
2. **Auto-Detection**: No need to specify framework, CLI figures it out
3. **Extensible**: Easy to add new frameworks by implementing `WASMProject`
4. **Backward Compatible**: Existing users can keep using `xamrock dashboard`
5. **Community Growth**: Attracts broader iOS developer audience

## Migration Path

### Phase 1: Extract Abstractions (Week 1)
- Create `WASMProject` protocol
- Create `WASMProjectDetector`
- Implement `GossamerProject` using existing `DashboardBuilder` logic

### Phase 2: Add Tokamak Support (Week 2)
- Implement `TokamakProject` with carton integration
- Implement `GenericWASMProject` fallback
- Test with real Tokamak projects

### Phase 3: Rename Commands (Week 3)
- Rename `DashboardCommand` → `WASMCommand`
- Keep `dashboard` as deprecated alias
- Update documentation

### Phase 4: Community Feedback (Week 4+)
- Ship to early adopters
- Gather feedback on Tokamak workflow
- Add more framework-specific optimizations

## Example User Experience

```bash
# Works with Gossamer project
cd MyGossamerApp
xamrock wasm dev
# ✓ Detected Gossamer project
# ✓ Building with docker-compose...
# ✓ Server running at http://localhost:8000

# Works with Tokamak project
cd MyTokamakApp
xamrock wasm dev
# ✓ Detected Tokamak project
# ✓ Building with carton...
# ✓ Server running at http://localhost:8000

# Works with custom Swift WASM project
cd MyCustomWASM
xamrock wasm dev
# ✓ Detected Generic Swift WASM project
# ✓ Building with swift build...
# ✓ Server running at http://localhost:8000
```

## Success Metrics

- [ ] CLI works with Gossamer (maintain existing functionality)
- [ ] CLI works with Tokamak projects (new capability)
- [ ] CLI works with generic Swift WASM projects (fallback)
- [ ] Auto-detection is 100% accurate
- [ ] Dev server startup < 5 seconds for all frameworks
- [ ] Community adoption increases (track GitHub stars, issues, discussions)

## Open Questions

1. **Should we support carton auto-install?** If user doesn't have carton, should CLI install it?
2. **Should we provide project templates?** `xamrock wasm new --template gossamer`
3. **Should we support hot reload?** Watch for file changes and auto-rebuild
4. **Should we support multiple frameworks in one project?** Edge case, probably not needed

## Recommendation

**Implement this abstraction** - it positions Xamrock CLI as the definitive tool for Swift WASM development, not just for Xamrock/Gossamer. This will:

- Attract more iOS developers
- Encourage Swift WASM ecosystem growth
- Establish Xamrock as community leader
- Create network effects (more users → more contributors → better tooling)

The abstraction is clean, testable, and extends naturally to future frameworks.
