import UIKit

public struct IdtraResponse {
    public let isMatch: Bool
    public let confidence: Double
    public let message: String
    public let rawJson: [String: Any]
}

public final class IdtraKYC {

    public static var defaultBaseUrl: String = "https://idtra.com"

    /// Recommended (v2): present the hosted verification page created by YOUR SERVER (verification_url from
    /// POST /api/biometrics/session/create). No API key in the app. See `IdtraSession`.
    public static func startSession(from presenter: UIViewController, verificationUrl: String,
                                    completion: @escaping (IdtraSessionResult) -> Void) throws {
        try IdtraSession.start(from: presenter, verificationUrl: verificationUrl, completion: completion)
    }

    /// Launch Biometric Verification modal screen
    @available(*, deprecated, message: "Ships your secret API key inside the app. Use startSession(from:verificationUrl:completion:).")
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
