# Idtra iOS SDK (Swift Package)

Official iOS SDK for embedding **Idtra Biometric Face Verification** and **Active Liveness Detection** into native Swift iOS applications.

---

## 1. Installation via Swift Package Manager (SPM)

In Xcode:
1. File > Add Packages...
2. Enter the repository URL:
   ```
   https://github.com/idtra/idtra-ios-sdk.git
   ```
3. Select version `1.0.0` and click **Add Package**.

---

## 2. Permissions (`Info.plist`)

Add the camera permission to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Idtra requires camera access to perform facial liveness verification.</string>
```

---

## 3. Usage Example

```swift
import UIKit
import IdtraKYC

class ViewController: UIViewController {

    @IBAction func didTapVerifyButton(_ sender: UIButton) {
        IdtraKYC.startVerification(
            from: self,
            apiKey: "sk_live_...",
            serviceType: "NIN", // or "BVN"
            number: "12345678901"
        ) { result in
            switch result {
            case .success(let response):
                if response.isMatch {
                    print("Face Match Confirmed! Confidence: \(response.confidence)")
                } else {
                    print("Mismatch: \(response.message)")
                }
            case .failure(let error):
                print("Verification Error: \(error.localizedDescription)")
            }
        }
    }
}
```

---

## License

MIT © [Idtra Technologies Ltd](https://idtra.com)
