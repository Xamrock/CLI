import XCTest
import Foundation
@testable import XamrockCLI

final class PlatformDetectorTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XamrockCLITests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - iOS Detection Tests

    func testDetectIOSFromXcodeProject() throws {
        // Given: A directory with an .xcodeproj file
        let projectPath = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should detect iOS
        XCTAssertEqual(platform, .iOS)
    }

    func testDetectIOSFromXcodeWorkspace() throws {
        // Given: A directory with an .xcworkspace file
        let workspacePath = tempDirectory.appendingPathComponent("MyApp.xcworkspace")
        try FileManager.default.createDirectory(at: workspacePath, withIntermediateDirectories: true)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should detect iOS
        XCTAssertEqual(platform, .iOS)
    }

    func testDetectIOSFromBundleIDPattern() throws {
        // Given: A bundle ID in typical iOS format
        let bundleID = "com.example.MyApp"

        // When: Detecting platform from bundle ID
        let platform = PlatformDetector.detectPlatform(fromAppIdentifier: bundleID)

        // Then: Should detect iOS (capitalized format)
        XCTAssertEqual(platform, .iOS)
    }

    // MARK: - Android Detection Tests

    func testDetectAndroidFromBuildGradle() throws {
        // Given: A directory with build.gradle file
        let gradlePath = tempDirectory.appendingPathComponent("build.gradle")
        try "android { }".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should detect Android
        XCTAssertEqual(platform, .android)
    }

    func testDetectAndroidFromBuildGradleKts() throws {
        // Given: A directory with build.gradle.kts file
        let gradlePath = tempDirectory.appendingPathComponent("build.gradle.kts")
        try "android { }".write(to: gradlePath, atomically: true, encoding: .utf8)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should detect Android
        XCTAssertEqual(platform, .android)
    }

    func testDetectAndroidFromManifest() throws {
        // Given: A directory with AndroidManifest.xml
        let manifestDir = tempDirectory.appendingPathComponent("app/src/main")
        try FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        let manifestPath = manifestDir.appendingPathComponent("AndroidManifest.xml")
        try "<manifest></manifest>".write(to: manifestPath, atomically: true, encoding: .utf8)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should detect Android
        XCTAssertEqual(platform, .android)
    }

    func testDetectAndroidFromPackageName() throws {
        // Given: A package name in typical Android format (with underscore)
        let packageName = "com.example.my_app"

        // When: Detecting platform from package name
        let platform = PlatformDetector.detectPlatform(fromAppIdentifier: packageName)

        // Then: Should detect Android (underscore format)
        XCTAssertEqual(platform, .android)
    }

    // MARK: - Ambiguous Cases

    func testReturnNilWhenNoProjectFiles() throws {
        // Given: An empty directory
        // (tempDirectory is already empty)

        // When: Detecting platform
        let platform = PlatformDetector.detectPlatform(in: tempDirectory)

        // Then: Should return nil (ambiguous)
        XCTAssertNil(platform)
    }

    func testReturnNilForAmbiguousBundleID() throws {
        // Given: A bundle ID that could be either platform
        let ambiguousID = "com.example.app"  // All lowercase, but not clearly Android

        // When: Detecting platform without context
        let platform = PlatformDetector.detectPlatform(fromAppIdentifier: ambiguousID)

        // Then: Should return nil (ambiguous)
        XCTAssertNil(platform)
    }

    // MARK: - Explicit Platform Override

    func testExplicitPlatformOverridesDetection() throws {
        // Given: iOS project files but explicit Android platform
        let projectPath = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

        // When: Using explicit platform
        let platform = PlatformDetector.resolvePlatform(
            explicit: .android,
            projectDirectory: tempDirectory
        )

        // Then: Should use explicit platform
        XCTAssertEqual(platform, .android)
    }

    func testAutoDetectWhenNoExplicitPlatform() throws {
        // Given: iOS project files and no explicit platform
        let projectPath = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

        // When: No explicit platform provided
        let platform = PlatformDetector.resolvePlatform(
            explicit: nil,
            projectDirectory: tempDirectory
        )

        // Then: Should auto-detect iOS
        XCTAssertEqual(platform, .iOS)
    }
}
