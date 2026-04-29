import AVFoundation
import SwiftUI

struct SelfieCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = SelfieCameraModel()

    @State private var hasCaptured: Bool = false

    var onCapture: () -> Void = {}

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Setup Wallet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.white)

                        Spacer()

                        Button {
                            onCapture()
                        } label: {
                            Text("Next")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 3/255, green: 1/255, blue: 38/255))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Theme.accent, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    // Progress: first 2 white (steps 1 & 2 active), last 3 cyan.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                    }

                    // Step header.
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("2")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)

                            Text("Let's Take a Selfie")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Before you take your selfie, please remove your glasses, hat, face mask or any other accessories. These make it harder to identify you.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                // Circular live camera preview.
                selfieCircle
                    .padding(.top, 28)

                // Caption.
                if !hasCaptured {
                    Text("Turn your head to the left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 28)
                }

                Spacer()

                // Bottom controls.
                Group {
                    if hasCaptured {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hasCaptured = false
                                }
                            } label: {
                                Text("Retake")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 28)
                                    .frame(minHeight: 48)
                                    .background(Color.white, in: .capsule)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onCapture()
                            } label: {
                                Text("Looks Good")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Theme.accent, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 22)
                        .transition(.opacity)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasCaptured = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.black, lineWidth: 4)
                                    .background(
                                        Circle().fill(Color.white)
                                    )
                                    .frame(width: 64, height: 64)

                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 50, height: 50)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var selfieCircle: some View {
        ZStack {
            switch camera.authorizationStatus {
            case .authorized:
                SelfieCameraPreview(session: camera.session)
            case .denied, .restricted:
                permissionOverlay(
                    title: "Camera access required",
                    message: "Allow camera access in Settings to take your selfie."
                )
            case .notDetermined:
                permissionOverlay(
                    title: "Requesting camera access",
                    message: "We need camera permission to capture your selfie."
                )
            @unknown default:
                permissionOverlay(
                    title: "Camera unavailable",
                    message: "The camera could not be started on this device."
                )
            }
        }
        .frame(width: 280, height: 280)
        .background(Color.white)
        .clipShape(Circle())
    }

    private func permissionOverlay(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.4))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

private struct SelfieCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> SelfieCameraPreviewUIView {
        let view = SelfieCameraPreviewUIView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: SelfieCameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class SelfieCameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .white
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class SelfieCameraModel: ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let sessionQueue = DispatchQueue(label: "com.ahoymoney.camera-preview-selfie")
    private var isConfigured = false

    func start() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            configureIfNeeded()
            startSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self.configureIfNeeded()
                        self.startSession()
                    }
                }
            }

        case .denied, .restricted:
            stop()

        @unknown default:
            stop()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        sessionQueue.async { [session] in
            session.beginConfiguration()
            session.sessionPreset = .photo

            defer { session.commitConfiguration() }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return }

            session.addInput(input)
        }
    }

    private func startSession() {
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }
}
