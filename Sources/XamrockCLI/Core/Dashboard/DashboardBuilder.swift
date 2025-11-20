import Foundation

/// Handles building the XamrockDashboard using Docker and SwiftWasm
public class DashboardBuilder {

    // MARK: - Properties

    private let dashboardPath: URL
    private let outputPath: URL
    private let production: Bool
    private let verbose: Bool

    // MARK: - Initialization

    public init(
        dashboardPath: URL,
        outputPath: URL,
        production: Bool = false,
        verbose: Bool = false
    ) {
        self.dashboardPath = dashboardPath
        self.outputPath = outputPath
        self.production = production
        self.verbose = verbose
    }

    // MARK: - Build Operations

    /// Clean previous build artifacts
    public func clean() throws {
        if FileManager.default.fileExists(atPath: outputPath.path) {
            try FileManager.default.removeItem(at: outputPath)
        }
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
    }

    /// Build WASM using Docker
    public func buildWASM() async throws {
        // Check Docker is running
        try validateDockerRunning()

        // Execute docker-compose build
        let buildProcess = Process()
        buildProcess.currentDirectoryURL = dashboardPath
        buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        buildProcess.arguments = ["docker-compose", "up", "swiftwasm-builder"]

        if verbose {
            buildProcess.standardOutput = FileHandle.standardOutput
            buildProcess.standardError = FileHandle.standardError
        } else {
            buildProcess.standardOutput = nil
            buildProcess.standardError = nil
        }

        try buildProcess.run()
        buildProcess.waitUntilExit()

        guard buildProcess.terminationStatus == 0 else {
            throw DashboardError.buildFailed("Docker build failed with exit code \(buildProcess.terminationStatus)")
        }
    }

    /// Optimize WASM for production
    public func optimizeWASM() async throws {
        // For now, the docker-compose already handles optimization
        // Future: Add wasm-opt integration here
    }

    /// Copy static assets to output directory
    public func copyAssets() throws {
        // Copy built WASM files
        let buildOutputPath = dashboardPath
            .appendingPathComponent(".build")
            .appendingPathComponent("wasm32-unknown-wasi")
            .appendingPathComponent(production ? "release" : "debug")

        // Find .wasm file
        let wasmFiles = try FileManager.default.contentsOfDirectory(at: buildOutputPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wasm" }

        guard let wasmFile = wasmFiles.first else {
            throw DashboardError.buildFailed("No WASM file found in build output")
        }

        // Copy WASM file (replace if exists)
        let destWasm = outputPath.appendingPathComponent(wasmFile.lastPathComponent)
        if FileManager.default.fileExists(atPath: destWasm.path) {
            try FileManager.default.removeItem(at: destWasm)
        }
        try FileManager.default.copyItem(at: wasmFile, to: destWasm)

        // Copy JavaScript runtime files from Public directory
        let publicPath = dashboardPath.appendingPathComponent("Public")

        // Only copy if output is different from Public (avoid copying to itself)
        guard outputPath.path != publicPath.path else {
            return
        }

        let jsFiles = try FileManager.default.contentsOfDirectory(at: publicPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "js" || $0.pathExtension == "html" }

        for jsFile in jsFiles {
            let dest = outputPath.appendingPathComponent(jsFile.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: jsFile, to: dest)
        }
    }

    /// Get bundle size information
    public func getBundleSize() throws -> BundleSize {
        var wasmSize = 0
        var jsSize = 0

        let files = try FileManager.default.contentsOfDirectory(at: outputPath, includingPropertiesForKeys: [.fileSizeKey])

        for file in files {
            let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = attrs[.size] as? Int ?? 0

            if file.pathExtension == "wasm" {
                wasmSize += size
            } else if file.pathExtension == "js" {
                jsSize += size
            }
        }

        return BundleSize(wasm: wasmSize, js: jsSize, total: wasmSize + jsSize)
    }

    /// Analyze bundle size (optional detailed analysis)
    public func analyzeBundleSize() throws {
        let bundleSize = try getBundleSize()
        print("Bundle Analysis:")
        print("  WASM: \(formatBytes(bundleSize.wasm))")
        print("  JS:   \(formatBytes(bundleSize.js))")
        print("  Total: \(formatBytes(bundleSize.total))")
    }

    // MARK: - Validation

    private func validateDockerRunning() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "ps"]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw DashboardError.dockerNotRunning
            }
        } catch {
            throw DashboardError.dockerNotRunning
        }
    }

    // MARK: - Utilities

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}

// MARK: - Bundle Size

public struct BundleSize {
    public let wasm: Int
    public let js: Int
    public let total: Int
}
