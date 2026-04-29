import AVFoundation
import SwiftUI

struct ScanIDView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = CameraPreviewModel()

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
                    // Progress (same as previous step).
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                    }

                    // Step header.
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("1")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)

                            Text("Scan your ID")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("To continue, please scan your Emirates ID for quick and secure identity verification.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Camera viewfinder with sample ID.
                    cameraFrame
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                // Caption.
                Text("Position the front of your Emirates ID in\nthe frame")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Spacer()

                // Bottom controls — capture circle, OR review buttons after capture.
                Group {
                    if hasCaptured {
                        HStack(spacing: 16) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hasCaptured = false
                                }
                            } label: {
                                Text("Retake")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 100, minHeight: 48)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onCapture()
                            } label: {
                                Text("Scan the back face")
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
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    @ViewBuilder
    private var cameraFrame: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            switch camera.authorizationStatus {
            case .authorized:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.accent.opacity(0.65), lineWidth: 2)
                    .padding(12)

            case .denied, .restricted:
                permissionOverlay(
                    title: "Camera access required",
                    message: "Allow camera access in Settings to scan the front of your Emirates ID."
                )

            case .notDetermined:
                permissionOverlay(
                    title: "Requesting camera access",
                    message: "We need camera permission before showing the Emirates ID preview frame."
                )

            @unknown default:
                permissionOverlay(
                    title: "Camera unavailable",
                    message: "The camera preview could not be started on this device."
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func permissionOverlay(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.45))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class CameraPreviewModel: ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let sessionQueue = DispatchQueue(label: "com.ahoymoney.camera-preview")
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

            defer {
                session.commitConfiguration()
            }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                return
            }

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
