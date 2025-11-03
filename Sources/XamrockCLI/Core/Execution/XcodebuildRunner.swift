import Foundation

/// Handles execution of xcodebuild test commands for iOS testing
public class XcodebuildRunner {

    public init() {}

    /// Build the xcodebuild test command
    public func buildCommand(config: CLIConfiguration, testFile: URL) -> String {
        var components: [String] = ["xcodebuild", "test"]

        // Add project or workspace
        if let projectPath = config.projectPath {
            if projectPath.path.hasSuffix(".xcworkspace") {
                components.append("-workspace")
                components.append(projectPath.path)
            } else {
                components.append("-project")
                components.append(projectPath.path)
            }
        }

        // Add scheme
        if let scheme = detectScheme(from: config) {
            components.append("-scheme")
            components.append(scheme)
        }

        // Add destination
        let destination = buildDestination(from: config)
        components.append("-destination")
        components.append(destination)

        // Add test target (only run our specific test)
        let testName = testFile.deletingPathExtension().lastPathComponent
        components.append("-only-testing:\(testName)/testExploration")

        return components.joined(separator: " ")
    }

    /// Detect the scheme name from the project/workspace
    public func detectScheme(from config: CLIConfiguration) -> String? {
        guard let projectPath = config.projectPath else { return nil }

        // Extract scheme name from project/workspace name
        let fileName = projectPath.lastPathComponent
        if fileName.hasSuffix(".xcodeproj") {
            return fileName.replacingOccurrences(of: ".xcodeproj", with: "")
        } else if fileName.hasSuffix(".xcworkspace") {
            return fileName.replacingOccurrences(of: ".xcworkspace", with: "")
        }

        return nil
    }

    /// Build the destination string for xcodebuild
    public func buildDestination(from config: CLIConfiguration) -> String {
        var parts: [String] = ["platform=iOS Simulator"]

        // Add device name if specified
        if let device = config.targetDevice {
            parts.append("name=\(device)")
        }

        // Add OS version if specified
        if let osVersion = config.osVersion {
            parts.append("OS=\(osVersion)")
        }

        return parts.joined(separator: ",")
    }

    /// Parse the xcodebuild test result
    public func parseResult(
        output: String,
        exitCode: Int,
        startTime: Date,
        config: CLIConfiguration
    ) -> TestExecutionResult {
        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)

        // Parse screens discovered from output
        var screensDiscovered = 0
        if let match = output.range(of: "Screens: (\\d+)", options: .regularExpression) {
            let screensStr = String(output[match]).replacingOccurrences(of: "Screens: ", with: "")
            screensDiscovered = Int(screensStr) ?? 0
        }

        // Parse failures from output
        var failuresFound = 0
        if exitCode != 0 {
            // If test failed, try to extract failure count
            if let match = output.range(of: "with (\\d+) failures", options: .regularExpression) {
                let failuresStr = String(output[match]).replacingOccurrences(of: "with ", with: "").replacingOccurrences(of: " failures", with: "")
                failuresFound = Int(failuresStr) ?? 0
            }
        }

        // Extract error message and suggestion if test failed
        var errorMessage: String? = nil
        var errorSuggestion: String? = nil

        if exitCode != 0 {
            errorMessage = extractErrorMessage(from: output, exitCode: exitCode)
            errorSuggestion = generateErrorSuggestion(for: exitCode, output: output, config: config)
        }

        return TestExecutionResult(
            exitCode: exitCode,
            outputDirectory: config.outputDirectory,
            duration: duration,
            screensDiscovered: screensDiscovered,
            failuresFound: failuresFound,
            errorMessage: errorMessage,
            errorSuggestion: errorSuggestion
        )
    }

    // MARK: - Error Extraction

    /// Extract meaningful error message from xcodebuild output
    private func extractErrorMessage(from output: String, exitCode: Int) -> String? {
        let lines = output.components(separatedBy: .newlines)

        // Look for common error patterns
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Match "xcodebuild: error:" lines
            if trimmed.hasPrefix("xcodebuild: error:") {
                return trimmed.replacingOccurrences(of: "xcodebuild: error:", with: "").trimmingCharacters(in: .whitespaces)
            }

            // Match general error lines
            if trimmed.hasPrefix("error:") {
                return trimmed.replacingOccurrences(of: "error:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        // Check for BUILD FAILED
        if output.contains("** BUILD FAILED **") {
            return "** BUILD FAILED ** - Check compilation errors in your project"
        }

        // Check for TEST FAILED
        if output.contains("** TEST FAILED **") {
            return "** TEST FAILED ** - Test execution failed"
        }

        return nil
    }

    /// Generate helpful suggestion based on error type
    private func generateErrorSuggestion(for exitCode: Int, output: String, config: CLIConfiguration) -> String? {
        // Exit code 65: General build/test failure
        if exitCode == 65 {
            if output.contains("destination") {
                return """
                Unable to find a suitable simulator.

                Try:
                  1. Open Simulator.app to ensure simulators are available
                  2. List available simulators: xcrun simctl list devices
                  3. Specify a device: xamrock explore --device "iPhone 15"
                """
            }

            if output.contains("Scheme") || output.contains("scheme") {
                return """
                Scheme configuration issue detected.

                Try:
                  1. Open your project in Xcode
                  2. Verify the scheme '\(config.projectPath?.deletingPathExtension().lastPathComponent ?? "YourApp")' exists
                  3. Edit Scheme → Test → ensure UI Testing is enabled
                """
            }

            if output.contains("BUILD FAILED") {
                return """
                Build compilation failed.

                Try:
                  1. Open your project in Xcode and fix compilation errors
                  2. Build the project manually: Cmd+B
                  3. Ensure all dependencies are resolved
                """
            }

            // Generic exit 65 suggestion
            return """
            Build or test configuration issue.

            Try:
              1. Ensure your project builds successfully in Xcode
              2. Verify the test target is configured properly
              3. Run with --verbose for more details
            """
        }

        // Exit code 70: Software/configuration error
        if exitCode == 70 {
            return """
            Configuration error detected.

            Try:
              1. Check your Xcode project settings
              2. Verify schemes and test targets are properly configured
              3. Ensure Xcode Command Line Tools are installed
            """
        }

        return nil
    }

    /// Run the xcodebuild test command
    public func runTest(config: CLIConfiguration, testFile: URL) throws -> TestExecutionResult {
        // Ensure output directory exists before running
        try FileManager.default.createDirectory(
            at: config.outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let command = buildCommand(config: config, testFile: testFile)
        let startTime = Date()

        // Execute xcodebuild
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sh", "-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // Collect output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var combinedOutput = ""
        if let output = String(data: outputData, encoding: .utf8) {
            combinedOutput += output
        }
        if let error = String(data: errorData, encoding: .utf8) {
            combinedOutput += error
        }

        // Parse and return result
        return parseResult(
            output: combinedOutput,
            exitCode: Int(process.terminationStatus),
            startTime: startTime,
            config: config
        )
    }
}
