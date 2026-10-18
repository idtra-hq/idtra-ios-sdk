import UIKit
import AVFoundation

public class IdtraCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    private let apiKey: String
    private let serviceType: String
    private let number: String
    private let baseUrl: String
    private let completion: (Result<IdtraResponse, Error>) -> Void

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let ovalOverlay = UIView()
    private let promptLabel = UILabel()
    private let subPromptLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    public init(apiKey: String, serviceType: String, number: String, baseUrl: String, completion: @escaping (Result<IdtraResponse, Error>) -> Void) {
        self.apiKey = apiKey
        self.serviceType = serviceType
        self.number = number
        self.baseUrl = baseUrl
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1.0)
        setupUI()
        checkCameraPermissions()
    }

    private func setupUI() {
        title = "Idtra Face KYC"
        navigationController?.navigationBar.barTintColor = .black
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissSelf)
        )

        // Oval Viewport
        ovalOverlay.translatesAutoresizingMaskIntoConstraints = false
        ovalOverlay.layer.borderColor = UIColor.systemBlue.cgColor
        ovalOverlay.layer.borderWidth = 4
        ovalOverlay.layer.cornerRadius = 135
        ovalOverlay.clipsToBounds = true
        view.addSubview(ovalOverlay)

        // Labels
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.text = "Center face in the oval"
        promptLabel.textColor = .white
        promptLabel.font = UIFont.boldSystemFont(ofSize: 18)
        promptLabel.textAlignment = .center
        view.addSubview(promptLabel)

        subPromptLabel.translatesAutoresizingMaskIntoConstraints = false
        subPromptLabel.text = "Hold your phone steady at eye level"
        subPromptLabel.textColor = .lightGray
        subPromptLabel.font = UIFont.systemFont(ofSize: 13)
        subPromptLabel.textAlignment = .center
        view.addSubview(subPromptLabel)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            ovalOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ovalOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            ovalOverlay.widthAnchor.constraint(equalToConstant: 270),
            ovalOverlay.heightAnchor.constraint(equalToConstant: 340),

            promptLabel.topAnchor.constraint(equalTo: ovalOverlay.bottomAnchor, constant: 24),
            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subPromptLabel.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 8),
            subPromptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subPromptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupCamera() } else { self?.dismissSelf() }
                }
            }
        default:
            dismissSelf()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) { session.addOutput(output) }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = ovalOverlay.bounds
        ovalOverlay.layer.insertSublayer(preview, at: 0)

        self.captureSession = session
        self.photoOutput = output
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.promptLabel.text = "Please blink your eyes"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.capturePhoto()
                }
            }
        }
    }

    private func capturePhoto() {
        promptLabel.text = "Hold steady, verifying..."
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
        let base64String = "data:image/jpeg;base64," + jpegData.base64EncodedString()
        
        submitVerification(base64Image: base64String)
    }

    private func submitVerification(base64Image: String) {
        activityIndicator.startAnimating()

        let endpoint = serviceType == "BVN" ? "\(baseUrl)/api/biometrics/bvn-verify" : "\(baseUrl)/api/biometrics/nin-verify"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            serviceType.lowercased(): number,
            "image": base64Image
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let error = error {
                    self?.completion(.failure(error))
                    self?.dismissSelf()
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.dismissSelf()
                    return
                }

                let faceMatch = json["face_match"] as? [String: Any]
                let isMatch = (faceMatch?["is_match"] as? Bool) ?? (json["status"] as? String == "success")
                let confidence = (faceMatch?["confidence"] as? Double) ?? (isMatch ? 0.95 : 0.20)
                let message = (faceMatch?["message"] as? String) ?? (json["message"] as? String ?? "")

                let res = IdtraResponse(isMatch: isMatch, confidence: confidence, message: message, rawJson: json)
                self?.completion(.success(res))
                self?.dismissSelf()
            }
        }.resume()
    }

    @objc private func dismissSelf() {
        captureSession?.stopRunning()
        dismiss(animated: true)
    }
}
