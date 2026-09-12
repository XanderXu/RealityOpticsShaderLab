#if os(iOS)
import SwiftUI
import ARKit
import AVFoundation

@MainActor @Observable
final class MobilePreviewState {
    private(set) var isAR = false
    private(set) var requestingAR = false
    var message = ""
    var resetRevision = 0
    private var requestRevision = 0

    func useVirtual() {
        requestRevision += 1
        requestingAR = false
        isAR = false
        message = ""
    }

    func useAR() async {
        guard !isAR, !requestingAR else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            message = "AR 预览需要支持 ARKit 的真机，模拟器请使用 3D 预览。"
            return
        }
        requestRevision += 1
        let revision = requestRevision
        requestingAR = true
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard revision == requestRevision else { return }
        requestingAR = false
        guard granted else {
            message = "相机权限未开启，请在系统设置中允许 Optics Lab 使用相机。"
            return
        }
        message = "正在启动 AR…"
        isAR = true
    }

}
#endif
