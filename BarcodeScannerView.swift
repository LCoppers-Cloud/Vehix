import SwiftUI
import AVFoundation

// View Controller to manage AVCaptureSession
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var didFindCode: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }

    func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { 
            failed(reason: "No video capture device available.")
            return
        }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            failed(reason: "Could not create video input: \(error.localizedDescription)")
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed(reason: "Could not add video input to session.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // Specify barcode types (QR, EAN, UPC, Code128 etc.)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .code128, .upce, .code39, .code93, .aztec, .dataMatrix]
        } else {
            failed(reason: "Could not add metadata output to session.")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .background).async { [weak self] in
             self?.captureSession.startRunning()
        }
    }

    func failed(reason: String) {
        print("Scanner setup failed: \(reason)")
        // Optionally show an alert to the user
        captureSession = nil
        // Potentially dismiss the view or show an error message
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
             DispatchQueue.global(qos: .background).async { [weak self] in
                 self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    // Delegate method for handling found metadata (barcodes)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
    }

    func found(code: String) {
        // Stop running the session to prevent multiple scans
        captureSession.stopRunning()
        // Call the completion handler
        didFindCode?(code)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

// SwiftUI View to wrap the ScannerViewController
struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.didFindCode = { code in
            self.scannedCode = code
            dismiss()
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    // Add Coordinator if needed for more complex delegate patterns, but simple closure callback is used here.
} 