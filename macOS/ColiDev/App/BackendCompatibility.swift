import Foundation

enum BackendEndpointRegistry {
    private static let portKey = "colidev.backend.port"
    static let defaultPort = 8000

    /// The port of the backend this process started. Two copies of the app (installed and a test build) share
    /// UserDefaults, so the saved port alone could point at the other copy's older backend.
    /// Порт backend, запущенного этим процессом. Две копии приложения делят UserDefaults, поэтому сохранённый порт
    /// мог вести к старому backend другой копии.
    private static var processPort: Int?

    static var port: Int {
        if let processPort { return processPort }
        let savedPort = UserDefaults.standard.integer(forKey: portKey)
        return (1...65_535).contains(savedPort) ? savedPort : defaultPort
    }

    static var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    static func updatePort(_ port: Int) {
        guard (1...65_535).contains(port) else { return }
        processPort = port
        UserDefaults.standard.set(port, forKey: portKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: portKey)
    }
}

enum BackendCompatibility {
    static let productID = "colidev"
    static let clientAPIVersion = 1

    enum Evaluation: Equatable {
        case compatible(apiVersion: Int, buildID: String)
        case incompatible(String)
    }

    private struct Status: Decodable {
        struct CompatibilityRange: Decodable {
            let minimumClientVersion: Int
            let maximumClientVersion: Int

            enum CodingKeys: String, CodingKey {
                case minimumClientVersion = "minimum_client_version"
                case maximumClientVersion = "maximum_client_version"
            }
        }

        let productID: String
        let apiVersion: Int
        let apiCompatibility: CompatibilityRange
        let buildID: String

        enum CodingKeys: String, CodingKey {
            case productID = "product_id"
            case apiVersion = "api_version"
            case apiCompatibility = "api_compatibility"
            case buildID = "build_id"
        }
    }

    static func evaluate(_ data: Data) -> Evaluation {
        guard let status = try? JSONDecoder().decode(Status.self, from: data) else {
            return .incompatible("The backend does not provide a versioned ColiDev API status.")
        }
        guard status.productID == productID else {
            return .incompatible("The local service belongs to a different product.")
        }
        guard status.apiVersion > 0 else {
            return .incompatible("The backend reports an invalid API version.")
        }
        guard status.apiCompatibility.minimumClientVersion > 0,
              status.apiCompatibility.maximumClientVersion >= status.apiCompatibility.minimumClientVersion else {
            return .incompatible("The backend reports an invalid API compatibility range.")
        }
        guard status.apiCompatibility.minimumClientVersion <= clientAPIVersion,
              status.apiCompatibility.maximumClientVersion >= clientAPIVersion else {
            return .incompatible("The backend API version is not compatible with this app.")
        }
        let buildID = status.buildID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !buildID.isEmpty else {
            return .incompatible("The backend is missing its build identifier.")
        }
        return .compatible(apiVersion: status.apiVersion, buildID: buildID)
    }
}

/// Сколько ждать встроенный backend при запуске. / How long to wait for the bundled backend to start.
///
/// После обновления backend пересобирает индекс курса и только потом отвечает; на M1 это заняло больше 80 секунд.
/// Раньше приложение ждало 15 секунд, останавливало живой процесс и запускало новый, и «Сегодня» оставалось с нулями.
/// After an update the backend rebuilds the course index before it answers; on an M1 this took over 80 seconds.
/// The app used to wait 15 seconds, stop the live process and start another, so Today stayed at zero.
enum BackendStartupPolicy {
    static let readinessTimeout: TimeInterval = 240

    /// Ждём, пока процесс жив и время не вышло. / Keep waiting while the process is alive and time remains.
    static func shouldKeepWaiting(elapsed: TimeInterval, processIsRunning: Bool) -> Bool {
        processIsRunning && elapsed < readinessTimeout
    }
}
