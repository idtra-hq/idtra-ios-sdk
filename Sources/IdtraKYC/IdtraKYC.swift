import UIKit

public struct IdtraResponse {
    public let isMatch: Bool
    public let confidence: Double
    public let message: String
    public let rawJson: [String: Any]
}

public final class IdtraKYC {

    public static var defaultBaseUrl: String = "https://idtra.com"

    /// Launch Biometric Verification modal screen
    public static func startVerification(
        from presenter: UIViewController,
        apiKey: String,
        serviceType: String = "NIN",
        number: String,
        baseUrl: String = defaultBaseUrl,
        completion: @escaping (Result<IdtraResponse, Error>) -> Void
    ) {
        let vc = IdtraCameraViewController(
            apiKey: apiKey,
            serviceType: serviceType,
            number: number,
            baseUrl: baseUrl,
            completion: completion
        )
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        presenter.present(navController, animated: true)
    }
}
