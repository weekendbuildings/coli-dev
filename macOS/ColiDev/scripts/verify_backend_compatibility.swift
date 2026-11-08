import Foundation

@main
struct VerifyBackendCompatibility {
    static func main() {
        let compatibleStatus = Data(
            #"{"product_id":"colidev","api_version":1,"api_compatibility":{"minimum_client_version":1,"maximum_client_version":1},"build_id":"ci-abc123"}"#.utf8
        )
        precondition(
            BackendCompatibility.evaluate(compatibleStatus) == .compatible(apiVersion: 1, buildID: "ci-abc123"),
            "a matching ColiDev API status must be accepted"
        )

        let oldBackendStatus = Data(
            #"{"service":"coli-dev Orchestrator v4.0","version":"4.0.0"}"#.utf8
        )
        if case .compatible = BackendCompatibility.evaluate(oldBackendStatus) {
            fatalError("an old unversioned backend must be rejected")
        }

        let otherProductStatus = Data(
            #"{"product_id":"another-app","api_version":1,"api_compatibility":{"minimum_client_version":1,"maximum_client_version":1},"build_id":"ci-abc123"}"#.utf8
        )
        if case .compatible = BackendCompatibility.evaluate(otherProductStatus) {
            fatalError("a different product must be rejected")
        }

        let unsupportedVersionStatus = Data(
            #"{"product_id":"colidev","api_version":2,"api_compatibility":{"minimum_client_version":2,"maximum_client_version":3},"build_id":"ci-abc123"}"#.utf8
        )
        if case .compatible = BackendCompatibility.evaluate(unsupportedVersionStatus) {
            fatalError("a backend that excludes this client version must be rejected")
        }

        let missingBuildStatus = Data(
            #"{"product_id":"colidev","api_version":1,"api_compatibility":{"minimum_client_version":1,"maximum_client_version":1},"build_id":"  "}"#.utf8
        )
        if case .compatible = BackendCompatibility.evaluate(missingBuildStatus) {
            fatalError("a backend without a build identifier must be rejected")
        }

        precondition(BackendEndpointRegistry.defaultPort == 8000)

        // A live backend that is rebuilding its index after an update must not be stopped early (it took over 80 s).
        // Живой backend, который после обновления пересобирает индекс, нельзя останавливать раньше времени.
        precondition(BackendStartupPolicy.shouldKeepWaiting(elapsed: 15, processIsRunning: true),
                     "a starting backend must not be given up after 15 seconds")
        precondition(BackendStartupPolicy.shouldKeepWaiting(elapsed: 90, processIsRunning: true),
                     "a cold start of about 80 seconds must fit in the wait")
        precondition(!BackendStartupPolicy.shouldKeepWaiting(elapsed: 1, processIsRunning: false),
                     "a backend that exited must not be waited for")
        precondition(!BackendStartupPolicy.shouldKeepWaiting(
            elapsed: BackendStartupPolicy.readinessTimeout, processIsRunning: true
        ), "the wait must end")
        print("Backend compatibility contract verified.")
    }
}
