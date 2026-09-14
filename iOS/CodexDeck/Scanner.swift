import SwiftUI
import AVFoundation

struct PairingScanner: UIViewControllerRepresentable {
    var found: (String) -> Void
    var failed: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let controller=ScannerController();controller.found=found;controller.failed=failed;return controller
    }
    func updateUIViewController(_ controller: ScannerController,context:Context) {}
    static func dismantleUIViewController(_ controller:ScannerController,coordinator:()) {controller.stop()}
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var found: ((String)->Void)?
    var failed: ((String)->Void)?
    private let session=AVCaptureSession()
    private let queue=DispatchQueue(label:"dev.codexdeck.camera")
    private var preview:AVCaptureVideoPreviewLayer?
    private var delivered=false
    private var stopped=false
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized:setup()
        case .notDetermined:AVCaptureDevice.requestAccess(for:.video) { [weak self] granted in DispatchQueue.main.async {if granted {self?.setup()}else{self?.failed?("请在设置中允许相机访问，或使用粘贴链接连接。")}}}
        default:failed?("请在设置中允许相机访问，或使用粘贴链接连接。")
        }
    }
    private func setup() {
        guard !stopped,isViewLoaded,let camera=AVCaptureDevice.default(for:.video),let input=try? AVCaptureDeviceInput(device:camera),session.canAddInput(input) else {failed?("相机暂不可用，请使用粘贴链接连接。");return}
        session.addInput(input)
        let output=AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else{failed?("无法打开扫描器");return}
        session.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main);output.metadataObjectTypes=[.qr]
        let layer=AVCaptureVideoPreviewLayer(session:session);layer.videoGravity = .resizeAspectFill;view.layer.addSublayer(layer);preview=layer
        queue.async { [session] in session.startRunning() }
    }
    override func viewDidLayoutSubviews() {super.viewDidLayoutSubviews();preview?.frame=view.bounds}
    func stop() {stopped=true;queue.async { [session] in if session.isRunning {session.stopRunning()} }}
    func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput objects:[AVMetadataObject],from connection:AVCaptureConnection) {
        guard !delivered,let text=(objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else{return}
        guard (try? Pairing(text)) != nil else{return}
        delivered=true;stop();found?(text)
    }
}
