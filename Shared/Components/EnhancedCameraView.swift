import SwiftUI
import AVFoundation
import UIKit

struct EnhancedCameraView: UIViewControllerRepresentable {
    let poNumber: String
    let jobAddress: String?
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> EnhancedCameraViewController {
        let controller = EnhancedCameraViewController(
            poNumber: poNumber,
            jobAddress: jobAddress,
            onCapture: onCapture,
            onDismiss: onDismiss
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: EnhancedCameraViewController, context: Context) {
        // Update if needed
    }
}

class EnhancedCameraViewController: UIViewController {
    private let poNumber: String
    private let jobAddress: String?
    private let onCapture: (UIImage) -> Void
    private let onDismiss: () -> Void
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    
    private var overlayView: UIView!
    private var poNumberLabel: UILabel!
    private var addressLabel: UILabel!
    private var instructionsView: UIView!
    private var captureButton: UIButton!
    private var dismissButton: UIButton!
    
    init(poNumber: String, jobAddress: String?, onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
        self.poNumber = poNumber
        self.jobAddress = jobAddress
        self.onCapture = onCapture
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access back camera!")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            photoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                
                setupPreview()
            }
        } catch {
            print("Error Unable to initialize back camera: \(error.localizedDescription)")
        }
    }
    
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        if #available(iOS 17.0, *) {
            previewLayer.connection?.videoRotationAngle = 0
        } else {
            previewLayer.connection?.videoOrientation = .portrait
        }
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Overlay container
        overlayView = UIView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        
        // PO Number Label
        poNumberLabel = UILabel()
        poNumberLabel.text = "PO: \(poNumber)"
        poNumberLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        poNumberLabel.textColor = .white
        poNumberLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        poNumberLabel.textAlignment = .center
        poNumberLabel.layer.cornerRadius = 8
        poNumberLabel.layer.masksToBounds = true
        poNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 0.8
        pulseAnimation.toValue = 1.0
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        poNumberLabel.layer.add(pulseAnimation, forKey: "pulse")
        
        overlayView.addSubview(poNumberLabel)
        
        // Address Label (if available)
        if let address = jobAddress {
            addressLabel = UILabel()
            addressLabel.text = address
            addressLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            addressLabel.textColor = .white
            addressLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            addressLabel.textAlignment = .center
            addressLabel.numberOfLines = 2
            addressLabel.layer.cornerRadius = 6
            addressLabel.layer.masksToBounds = true
            addressLabel.translatesAutoresizingMaskIntoConstraints = false
            overlayView.addSubview(addressLabel)
        }
        
        // Instructions View
        setupInstructionsView()
        
        // Capture Button
        captureButton = UIButton(type: .system)
        captureButton.setTitle("📸 Capture Receipt", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        captureButton.backgroundColor = UIColor.systemGreen
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        overlayView.addSubview(captureButton)
        
        // Dismiss Button
        dismissButton = UIButton(type: .system)
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        dismissButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.layer.cornerRadius = 20
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissCamera), for: .touchUpInside)
        overlayView.addSubview(dismissButton)
        
        // Tap to capture gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(capturePhoto))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupInstructionsView() {
        instructionsView = UIView()
        instructionsView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        instructionsView.layer.cornerRadius = 12
        instructionsView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(instructionsView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        instructionsView.addSubview(stackView)
        
        let titleLabel = UILabel()
        titleLabel.text = "📸 Receipt Scanning"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        let instructions = [
            "• Keep receipt flat and well-lit",
            "• Ensure all text is clearly visible",
            "• Tap anywhere to capture photo",
            "• Multiple receipts are supported"
        ]
        
        let instructionLabel = UILabel()
        instructionLabel.text = instructions.joined(separator: "\n")
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        instructionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        instructionLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: instructionsView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: instructionsView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: instructionsView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: instructionsView.bottomAnchor, constant: -16)
        ])
        
        // Auto-hide instructions after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            UIView.animate(withDuration: 0.5) {
                self.instructionsView.alpha = 0
            } completion: { _ in
                self.instructionsView.isHidden = true
            }
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Overlay View
            overlayView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // PO Number Label
            poNumberLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 20),
            poNumberLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -20),
            poNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            poNumberLabel.heightAnchor.constraint(equalToConstant: 44),
            
            // Dismiss Button
            dismissButton.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 20),
            dismissButton.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Capture Button
            captureButton.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Instructions View
            instructionsView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),
            instructionsView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 20),
            instructionsView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -20)
        ])
        
        // Address Label constraints (if exists)
        if let addressLabel = addressLabel {
            NSLayoutConstraint.activate([
                addressLabel.topAnchor.constraint(equalTo: poNumberLabel.bottomAnchor, constant: 8),
                addressLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -20),
                addressLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
                addressLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
            ])
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Visual feedback
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        view.addSubview(flashView)
        
        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                flashView.alpha = 0
            } completion: { _ in
                flashView.removeFromSuperview()
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func dismissCamera() {
        onDismiss()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension EnhancedCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error converting photo to image")
            return
        }
        
        // Add PO number watermark to image
        let watermarkedImage = addWatermark(to: image)
        onCapture(watermarkedImage)
    }
    
    private func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)
            
            // Prepare watermark text
            let watermarkText = "PO: \(poNumber)\n\(Date().formatted(date: .abbreviated, time: .shortened))"
            
            // Text attributes
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: min(image.size.width, image.size.height) * 0.03, weight: .bold),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.black.withAlphaComponent(0.7)
            ]
            
            // Calculate text size and position
            let attributedString = NSAttributedString(string: watermarkText, attributes: attributes)
            let textSize = attributedString.size()
            
            let margin: CGFloat = 20
            let textRect = CGRect(
                x: image.size.width - textSize.width - margin,
                y: margin,
                width: textSize.width + 10,
                height: textSize.height + 10
            )
            
            // Draw background
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            context.cgContext.fill(textRect)
            
            // Draw text
            attributedString.draw(in: textRect.insetBy(dx: 5, dy: 5))
        }
    }
}

#if DEBUG
struct EnhancedCameraView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedCameraView(
            poNumber: "JOB123-20240115-001",
            jobAddress: "123 Main St, Anytown USA",
            onCapture: { image in
                print("Captured image: \(image)")
            },
            onDismiss: {
                print("Camera dismissed")
            }
        )
    }
}
#endif 