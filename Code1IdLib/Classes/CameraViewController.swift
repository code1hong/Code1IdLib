
import SwiftyJSON
import Alamofire
import AVFoundation
import CoreVideo
import MLImage
import MLKit
import UIKit

@objc(CameraViewController)
class CameraViewController: UIViewController, UINavigationControllerDelegate {
    private var isUsingFrontCamera = false
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {
        
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    // MARK: - IBOutlets
    @IBOutlet private weak var cameraView: UIView!
    var serverMobileSwitch: UISwitch!
    var liveLabel: UILabel!
    var authSwitch: UISwitch!
    var serverMobileLabel: UILabel!
    var authLabel: UILabel!
    var captureButton: UIButton!
    
    // MARK: - Detection
    var idCard: IdCard!
    var idCardImageTemp: UIImage!
    var idCardImage: UIImage!
    var originalImage: UIImage!
    var finish = false
    
    // MARK: - Option
    private let cameraSize = CGSize(width: 1080, height: 1920)
    private var cameraRatio: CGFloat!
    private var naviY: CGFloat!
    private var previewWidth: CGFloat!
    private var previewHeight: CGFloat!
    private var previewY: CGFloat!
    private var viewFrame: CGRect!
    
    private var onDevice = true
    private var idAuth = true
    
    private var guideRect: CGRect!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        
        // 카메라 비율
        cameraRatio = cameraSize.height / cameraSize.width
        naviY = navigationController?.navigationBar.frame.maxY
        viewFrame = self.view.frame
        previewWidth = cameraView.frame.width
        previewHeight = cameraView.frame.height
        previewY = cameraView.frame.minY
        // 프리뷰 위치 지정
        cameraView.frame = CGRect(x: 0 , y: 0, width: self.view.frame.width, height: self.view.frame.width * cameraRatio)
        self.setUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        idCardImageTemp = UIImage()
        idCardImage = UIImage()
        self.finish = false
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.frame
    }
    
    // MARK: Detections
    // 실시간 검출
    private func recognizeText(in image: VisionImage, width: CGFloat, height: CGFloat, ori_img: UIImage, scale: CGFloat) {
        var recognizedText: Text
        do {
            let koreanOptions = KoreanTextRecognizerOptions()
            recognizedText = try TextRecognizer.textRecognizer(options: koreanOptions)
                .results(in: image)
        } catch let error {
            print("Failed to recognize text with error: \(error.localizedDescription).")
            self.updatePreviewOverlayViewWithLastFrame()
            return
        }
        self.updatePreviewOverlayViewWithLastFrame()
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            
            if onDevice {
                idCard = Ocr().idOcr(recognizedText: recognizedText, scale: scale)
                idCardImage = ori_img
                if idCard != nil {
                    if finish == false {
                        self.performSegue(withIdentifier: "showResult", sender: self)
                        finish = true
                    }
                }
            }
        }
    }
    
    // 검출 서버 통신
    func sendServer(image: UIImage) {
        let userName = "code1system"
        let url = "http://49.254.96.114:5000/id-scan"
        let imgData = image.jpegData(compressionQuality: 1.0)!
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imgData, withName: "file_param_1", fileName: "\(userName).jpg", mimeType: "image/jpg")
        }, to: url).responseJSON { response in
            switch response.result {
            case .success(let value):
                let resultJson = JSON(value)
                
                if resultJson["err_code"].rawString()! == "10" {
                    var title = resultJson["ocr_result"]["IDENTYPE"].rawString()!
                    if title == "JUMIN" {
                        title = "주민등록증"
                    }
                    else if title == "DRIVER" {
                        title = "운전면허증"
                    }
                    else {
                        print("지원하는 신분증이 아님")
                        print("에러 27")
                        self.idCard = IdCard(title: "", name: "", regnum: "", issueDate: "", licenseNum: "", encnum: "", masking: CGRect(x: 0, y: 0, width: 1, height: 1))
                        self.idCardImage = image
                        if self.finish == false {
                            self.performSegue(withIdentifier: "showResult", sender: self)
                            self.finish = true
                        }
                        return
                    }
                    let name = resultJson["ocr_result"]["NAME"].rawString()!
                    let regnum = resultJson["ocr_result"]["REGNUM"].rawString()!
                    let issueDate = resultJson["ocr_result"]["ISSUE_DATE"].rawString()!
                    let licenseNum = resultJson["ocr_result"]["LICENSE_NUM"].rawString()!
                    let encnum = resultJson["ocr_result"]["ENCNUM"].rawString()!
                    let expatriate = resultJson["ocr_result"]["EXPATRIATE"].rawString()!
                    
                    if expatriate == "true" {
                        title += "(재외국민)"
                    }
            
                    // 마스킹
                    let w = resultJson["masking"]["width"].rawValue as! CGFloat / 2.0
                    let h = resultJson["masking"]["height"].rawValue as! CGFloat
                    let x = resultJson["masking"]["x"].rawValue as! CGFloat + w
                    let y = resultJson["masking"]["y"].rawValue as! CGFloat
                    
                    let rect = CGRect(x: x, y: y, width: w, height: h)
            
                    self.idCard = IdCard(title: title, name: name, regnum: regnum, issueDate: issueDate, licenseNum: licenseNum, encnum: encnum, masking: rect)
                }
                else {
                    self.idCard = IdCard(title: "", name: "", regnum: "", issueDate: "", licenseNum: "", encnum: "", masking: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
                
                self.idCardImage = image
                
                if self.idCard != nil {
                    if self.finish == false {
                        self.performSegue(withIdentifier: "showResult", sender: self)
                        self.finish = true
                    }
                }
                
            default:
                print("Json 파싱 실패")
                print("에러 23")
                self.idCard = IdCard(title: "", name: "", regnum: "", issueDate: "", licenseNum: "", encnum: "", masking: CGRect(x: 0, y: 0, width: 1, height: 1))
                self.idCardImage = image
                if self.finish == false {
                    self.performSegue(withIdentifier: "showResult", sender: self)
                    self.finish = true
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func setUpCaptureSessionOutput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
//            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.high
//            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
            guard strongSelf.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            strongSelf.captureSession.addOutput(output)
            strongSelf.captureSession.commitConfiguration()
        }
    }
    
    private func setUpCaptureSessionInput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
            guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                strongSelf.captureSession.beginConfiguration()
                let currentInputs = strongSelf.captureSession.inputs
                for input in currentInputs {
                    strongSelf.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard strongSelf.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                strongSelf.captureSession.addInput(input)
                strongSelf.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func startSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.stopRunning()
        }
    }
    
    private func setUpPreviewOverlayView() {
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            
        ])
    }
    
    private func setUpAnnotationOverlayView() {
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            
            guard let lastFrame = lastFrame,
                  let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
            else {
                return
            }
            strongSelf.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
            strongSelf.removeDetectionAnnotations()
        }
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
//        var image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!, scale: 1080 / view.frame.maxX, orientation: orientation)

        previewOverlayView.image = image
    }
    
    // MARK: 이벤트 핸들러
    @objc func serverMobileSwitchAction(sender: UISwitch) {
        if sender.isOn {
            serverMobileLabel.text = "모바일"
            captureButton.isHidden = true
            liveLabel.isHidden = false
            onDevice = true
        }
        else {
            serverMobileLabel.text = "서버"
            captureButton.isHidden = false
            liveLabel.isHidden = true
            onDevice = false
        }
    }
    
    @objc func authSwitchAction(sender: UISwitch) {
        if sender.isOn {
            authLabel.text = "인증"
            idAuth = true
        }
        else {
            authLabel.text = "인증안함"
            idAuth = false
        }
    }
    
    @objc func sendServerOnclick() {
        stopSession()
        let rotateImage = UIUtilities.rotate(image: idCardImageTemp, degree: 360)
        sendServer(image: rotateImage!)
    }
    
    // MARK: UI
    // 가이드 세팅
    func setupIdGuide(guideRect: CGRect) {
        // 가이드 레이어 추가
        let frameColor : UIColor = UIColor.red
        let subLayer = CAShapeLayer()
        subLayer.lineWidth = 2.0
        subLayer.strokeColor = frameColor.cgColor
        subLayer.path = UIBezierPath(roundedRect: guideRect, cornerRadius: 10.0).cgPath
        subLayer.fillColor = nil
        self.view.layer.addSublayer(subLayer)
        
        //뒷배경 색깔 및 투명도
        let maskLayerColor: UIColor = UIColor.white
        let maskLayerAlpha: CGFloat = 1.0
        
        // 신분증 가이드 백그라운드 설정
        let backLayer = CALayer()
        backLayer.frame = view.bounds
        backLayer.backgroundColor = maskLayerColor.withAlphaComponent(maskLayerAlpha).cgColor
        
        // 신분증 가이드 구역 설정
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(roundedRect: self.guideRect!, cornerRadius: 10.0)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        backLayer.mask = maskLayer
        self.view.layer.addSublayer(backLayer)
    }
    
    func setUI() {
        // 신분증 타이틀
        let titleLabel = UILabel(frame: CGRect(x: self.cameraView.frame.minX, y: self.cameraView.frame.minY + naviY, width: self.view.frame.width, height: self.view.frame.height * 0.07))
        self.view.addSubview(titleLabel)
        titleLabel.text = "신분증 촬영"
        titleLabel.textAlignment = .center
        titleLabel.textColor = .black
        titleLabel.backgroundColor = .white
        titleLabel.font = .systemFont(ofSize: 20)
            
        // 상단 주의 문구
        let notice1Label = UILabel(frame: CGRect(x: titleLabel.frame.minX, y: titleLabel.frame.maxY, width: self.view.frame.width, height: self.view.frame.height * 0.1))
        self.view.addSubview(notice1Label)
        notice1Label.text = "빨강색 사각형 안에 신분증을 바르게 놓고 \n 촬영바랍니다."
        notice1Label.numberOfLines = 0
        notice1Label.textAlignment = .center
        notice1Label.textColor = .black
        
        // 촬영 가이드
        let frameWidth = self.view.frame.size.width
        let idCardRatio: CGFloat = 1.59
        let guideWidth = frameWidth * 0.9
        let guideHeight = guideWidth / idCardRatio
        let guideX = frameWidth * 0.05
        let guideY = notice1Label.frame.maxY
        guideRect = CGRect(x: guideX, y: guideY, width: guideWidth, height: guideHeight)
        self.setupIdGuide(guideRect: guideRect!)
        
        // 하단 주의 문구
        let notice2Label = UILabel(frame: CGRect(x: titleLabel.frame.minX, y: guideRect!.maxY, width: self.view.frame.width, height: self.view.frame.height * 0.2))
        self.view.addSubview(notice2Label)
        notice2Label.text = "※ 촬영 시 주의 사항 \n - 빛 반사가 생기지 않도록 기울기를 조절하여 \n 촬영하세요 \n \n - 어두운 바탕에 신분증을 놓고 촬영하세요"
        notice2Label.numberOfLines = 0
        notice2Label.textAlignment = .center
        notice2Label.textColor = .black
        
        self.view.bringSubviewToFront(titleLabel)
        self.view.bringSubviewToFront(notice1Label)
        self.view.bringSubviewToFront(notice2Label)
        
        // 버튼, 스위치
        captureButton = UIButton(frame: CGRect(x: view.frame.width / 2 - 32, y: view.frame.height - 100, width: 64, height: 64))
        liveLabel = UILabel(frame: CGRect(x: view.frame.width / 2 - 32, y: view.frame.height - 100, width: 64, height: 64))
        serverMobileLabel = UILabel(frame: CGRect(x: view.frame.width / 5, y: view.frame.height - 100, width: 50, height: 30))
        serverMobileSwitch = UISwitch(frame: CGRect(x: view.frame.width / 5, y: serverMobileLabel.frame.maxY, width: 50, height: 30))
        authLabel = UILabel(frame: CGRect(x: view.frame.width - serverMobileLabel.frame.maxX, y: view.frame.height - 100, width: 50, height: 30))
        authSwitch = UISwitch(frame: CGRect(x: view.frame.width - serverMobileSwitch.frame.maxX, y: authLabel.frame.maxY, width: 50, height: 30))

        self.view.addSubview(captureButton)
        self.view.addSubview(liveLabel)
        self.view.addSubview(serverMobileLabel)
        self.view.addSubview(authLabel)
        self.view.addSubview(serverMobileSwitch)
        self.view.addSubview(authSwitch)
        
        captureButton.setImage(#imageLiteral(resourceName: "camera_button"), for: .normal)
        captureButton.isHidden = true
        captureButton.addTarget(self, action: #selector(sendServerOnclick), for: .touchUpInside)
        liveLabel.text = "LIVE"
        liveLabel.textAlignment = .center
        liveLabel.font = .systemFont(ofSize: 14)
        serverMobileLabel.text = "모바일"
        serverMobileLabel.textAlignment = .center
        serverMobileLabel.font = .systemFont(ofSize: 12)
        authLabel.text = "인증"
        authLabel.textAlignment = .center
        authLabel.font = .systemFont(ofSize: 12)
        serverMobileSwitch.isOn = true
        serverMobileSwitch.addTarget(self, action: #selector(serverMobileSwitchAction(sender:)), for: UIControl.Event.valueChanged)
        authSwitch.isOn = true
        authSwitch.addTarget(self, action: #selector(authSwitchAction(sender:)), for: UIControl.Event.valueChanged)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is ResultController{
            let newController = segue.destination as? ResultController
            newController?.result = self.idCard
            newController?.idCardImage = self.idCardImage
            newController?.idAuth = self.idAuth
            newController?.originalImage = self.originalImage
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        lastFrame = sampleBuffer
        
        let uiImage = UIUtilities.createUIImage(from: imageBuffer, orientation: UIImage.Orientation.right)

        originalImage = uiImage
        // 크롭
        let cropRatio = uiImage!.size.width / viewFrame.width
        let cropImageW = self.guideRect!.width * cropRatio
        let cropImageH = self.guideRect!.height * cropRatio
        let cropImageX = self.guideRect!.minX * cropRatio
        // 네비 바를 어떻게 할까???????
//        let cropImageY = uiImage!.size.height - self.guideRect!.maxY * cropRatio
        
        let cropImageY = self.guideRect!.minY * cropRatio
        let cropRect = CGRect(x: cropImageY, y: cropImageX, width: cropImageH, height: cropImageW)
        
        let imageRef = uiImage?.cgImage!.cropping(to: cropRect)
        let cropImage = UIImage(cgImage: imageRef!, scale: uiImage!.scale, orientation: UIImage.Orientation.right)
        
        // resize
        let cropImageRatio = cropImage.size.width / cropImage.size.height
        let scaledImage = cropImage.scaledImage(with: CGSize(width: 480, height: 480 / cropImageRatio))!
//        let scaledImage = cropImage
        let scaleSize = cropImage.size.width / scaledImage.size.width
        
        idCardImageTemp = cropImage
        
        // ///////////////////////////////////////////////////////////
        
//                let visionImage = VisionImage(buffer: sampleBuffer)
        let visionImage = VisionImage(image: scaledImage)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
//        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
//            print("Failed to create MLImage from sample buffer.")
//            return
//        }
//        inputImage.orientation = orientation
        //        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        //        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        let imageWidth = scaledImage.size.width
        let imageHeight = scaledImage.size.height

        recognizeText(in: visionImage, width: imageWidth, height: imageHeight, ori_img: cropImage, scale: scaleSize)
    }
}

// MARK: - Constants

private enum Constant {
    static let videoDataOutputQueueLabel = "com.code1system.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.code1system.SessionQueue"
}
