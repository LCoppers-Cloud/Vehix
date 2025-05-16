import SwiftUI
import UIKit

// Shared Camera view for taking photos
struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Shared Image Picker for photo library
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Shared Receipt Capture View
struct ReceiptCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    
    let onCapture: (UIImage) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = capturedImage {
                    // Show captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    
                    Button("Use This Receipt") {
                        onCapture(image)
                        dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                } else {
                    // Show capture options
                    VStack(spacing: 30) {
                        Image(systemName: "receipt")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                        
                        Text("Add Receipt")
                            .font(.title2)
                            .bold()
                        
                        Text("Take a photo of the receipt or choose from your photo library")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Camera button
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Take Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Photo library button
                        Button(action: {
                            showingPhotoLibrary = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose from Library")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(capturedImage: $capturedImage)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(selectedImage: $capturedImage, sourceType: .photoLibrary)
            }
        }
    }
} 