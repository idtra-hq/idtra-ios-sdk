import Foundation
import SafariServices
import UIKit

/// Outcome of a hosted verification session (state only: no personal data on the device).
/// status: completed, failed, expired, or cancelled. Read the full result on your server
/// (GET /api/biometrics/session/{id}/result with your API key) or receive it on your webhook.
public struct IdtraSessionResult {
    public let sessionId: String
    public let status: String
    public let isMatch: Bool?
    public let confidence: Double?
    public let message: String?
    public let rawJson: [String: Any]

    public var isVerified: Bool { status == "completed" && isMatch == true }
}

/// v2 (recommended): your SERVER creates the session with your secret key
/// (POST https://idtra.com/api/biometrics/session/create) and passes only the returned verification_url to the app.
/// This presents Idtra's hosted live check in SFSafariViewController (camera works natively) and calls `completion`
/// on the main thread when the session finishes, or when the user closes the page (status "cancelled" if unfinished).
public final class IdtraSession: NSObject, SFSafariViewControllerDelegate {
    private static var active: IdtraSession?
    private static let finalStates: Set<String> = ["completed", "failed", "expired"]

    private let sessionId: String
    private let statusURL: URL
    private let completion: (IdtraSessionResult) -> Void
    private weak var safari: SFSafariViewController?
    private var timer: Timer?
    private var last: [String: Any] = ["status": "in_progress"]
    private var finished = false

    public static func start(from presenter: UIViewController, verificationUrl: String,
                             completion: @escaping (IdtraSessionResult) -> Void) throws {
        guard let url = URL(string: verificationUrl),
              let range = url.path.range(of: #"/verify/s/([A-Za-z0-9_]+)"#, options: .regularExpression) else {
            throw NSError(domain: "IdtraKYC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an Idtra verification link"])
        }
        let sessionId = String(url.path[range].dropFirst("/verify/s/".count))
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.path = "/api/biometrics/session/\(sessionId)/status"
        comps.query = nil
        let session = IdtraSession(sessionId: sessionId, statusURL: comps.url!, completion: completion)
        active = session
        let vc = SFSafariViewController(url: url)
        vc.delegate = session
        session.safari = vc
        presenter.present(vc, animated: true)
        session.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak session] _ in session?.check() }
    }

    private init(sessionId: String, statusURL: URL, completion: @escaping (IdtraSessionResult) -> Void) {
        self.sessionId = sessionId
        self.statusURL = statusURL
        self.completion = completion
    }

    private func check(closing: Bool = false) {
        var req = URLRequest(url: statusURL)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let data = data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                self.last = json
            }
            let status = self.last["status"] as? String ?? ""
            if IdtraSession.finalStates.contains(status) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.finish(status) }
            } else if closing {
                DispatchQueue.main.async { self.finish("cancelled") }
            }
        }.resume()
    }

    private func finish(_ status: String) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        safari?.dismiss(animated: true)
        let result = IdtraSessionResult(
            sessionId: sessionId,
            status: status,
            isMatch: last["is_match"] as? Bool,
            confidence: (last["confidence"] as? NSNumber)?.doubleValue,
            message: (last["match_message"] as? String) ?? (last["error_message"] as? String),
            rawJson: last
        )
        completion(result)
        IdtraSession.active = nil
    }

    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        check(closing: true)   // the user closed the page: report the final state, or "cancelled"
    }
}
