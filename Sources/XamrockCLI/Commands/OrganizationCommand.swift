import Foundation
import ArgumentParser

/// Example command demonstrating the new error handling
struct OrganizationCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "org",
        abstract: "Manage Xamrock organizations",
        subcommands: [Create.self, Get.self, List.self]
    )
}

extension OrganizationCommand {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new organization"
        )

        @Option(name: .shortAndLong, help: "Organization name")
        var name: String

        @Option(name: .shortAndLong, help: "Subscription tier")
        var tier: String = "free"

        @Option(help: "Backend URL")
        var backendURL: String = "http://localhost:8080"

        func run() async throws {
            let client = BackendClient(baseURL: backendURL)

            print("Creating organization '\(name)'...")

            do {
                // Attempt to create the organization
                let orgId = try await createOrganization(client: client)
                print("✅ Organization created successfully!")
                print("   ID: \(orgId)")
                print("   Name: \(name)")
                print("   Tier: \(tier)")
            } catch {
                // Use the new error handler
                ErrorHandler.handle(error)

                // Check for specific error types to provide additional context
                if ErrorHandler.isDuplicateResource(error) {
                    print("\n💡 Tip: Use 'xamrock org list' to see existing organizations")
                }

                throw ExitCode.failure
            }
        }

        private func createOrganization(client: BackendClient) async throws -> UUID {
            // Direct API call - let errors propagate up
            guard let url = URL(string: "\(client.baseURL)/api/v1/organizations") else {
                throw BackendError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = [
                "name": name,
                "subscriptionTier": tier
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }

            guard httpResponse.statusCode == 201 else {
                throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let idString = json?["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                throw BackendError.invalidJSON
            }

            return id
        }
    }

    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get organization details"
        )

        @Argument(help: "Organization ID")
        var id: String

        @Option(help: "Backend URL")
        var backendURL: String = "http://localhost:8080"

        func run() async throws {
            let client = BackendClient(baseURL: backendURL)

            // Validate UUID format
            guard let orgId = UUID(uuidString: id) else {
                print("❌ Invalid UUID format: \(id)")
                print("💡 Use format: 00000000-0000-0000-0000-000000000000")
                throw ExitCode.failure
            }

            print("Fetching organization \(orgId)...")

            do {
                let organization = try await getOrganization(client: client, id: orgId)
                print("✅ Organization found:")
                print("   ID: \(organization["id"] ?? "unknown")")
                print("   Name: \(organization["name"] ?? "unknown")")
                print("   Tier: \(organization["subscriptionTier"] ?? "unknown")")
            } catch {
                ErrorHandler.handle(error)

                if ErrorHandler.isNotFound(error) {
                    print("\n💡 Tip: Use 'xamrock org list' to see available organizations")
                }

                throw ExitCode.failure
            }
        }

        private func getOrganization(client: BackendClient, id: UUID) async throws -> [String: Any] {
            guard let url = URL(string: "\(client.baseURL)/api/v1/organizations/\(id)") else {
                throw BackendError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BackendError.invalidJSON
            }

            return json
        }
    }

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all organizations"
        )

        @Option(help: "Backend URL")
        var backendURL: String = "http://localhost:8080"

        func run() async throws {
            let client = BackendClient(baseURL: backendURL)

            print("Fetching organizations...")

            do {
                let organizations = try await listOrganizations(client: client)

                if organizations.isEmpty {
                    print("No organizations found")
                    print("💡 Use 'xamrock org create' to create your first organization")
                } else {
                    print("✅ Found \(organizations.count) organization(s):")
                    for org in organizations {
                        print("\n   ID: \(org["id"] ?? "unknown")")
                        print("   Name: \(org["name"] ?? "unknown")")
                        print("   Tier: \(org["subscriptionTier"] ?? "unknown")")
                    }
                }
            } catch {
                ErrorHandler.handle(error)
                throw ExitCode.failure
            }
        }

        private func listOrganizations(client: BackendClient) async throws -> [[String: Any]] {
            guard let url = URL(string: "\(client.baseURL)/api/v1/organizations") else {
                throw BackendError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw BackendError.invalidJSON
            }

            return json
        }
    }
}