import UIKit
import AVFoundation
import Alamofire
import SwiftyJSON
import Vision
import MLKit

class DetectionController: UIViewController, AVCapturePhotoCaptureDelegate {
    // UI
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var navigationBar: UINavigationItem!
    @IBOutlet weak var positionChangeButton: UIBarButtonItem!
    
    // 카메라
    var captureSesssion : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    var cameraPosition = "back"
    
    var idCardImage: UIImage!
    var faceImage: UIImage!
    var resultJson: JSON!
    
    private var finish = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        
        // 프리뷰 위치 지정
        previewView.frame = CGRect(x: 0 , y: (self.navigationController?.navigationBar.frame.maxY)!, width: self.view.frame.width, height: self.view.frame.width * (4032 / 3024))
        
        // 카메라
        captureSesssion = AVCaptureSession()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.photo
        
        cameraOutput = AVCapturePhotoOutput()
        
        var device: AVCaptureDevice!
        if cameraPosition == "back" {
            device = AVCaptureDevice.default(for: .video)
        }
        else {
            device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if (captureSesssion.canAddInput(input)) {
                captureSesssion.addInput(input)
                if (captureSesssion.canAddOutput(cameraOutput)) {
                    captureSesssion.addOutput(cameraOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    previewLayer.frame = previewView.bounds
                    previewView.layer.addSublayer(previewLayer)
                    captureSesssion.startRunning()
                }
            } else {
                print("에러 발생 : 20")
            }
        } else {
            print("에러 발생 : 21")
        }
    }
    
    // 이미지 촬영
    @IBAction func didPressTakePhoto(_ sender: UIButton) {
        self.captureButton.isEnabled = false
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        settings.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    
    // Output 콜백
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        captureSesssion.stopRunning()
        
        if error != nil {
            print("에러 발생 : 15")
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let original_image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)
            
            faceImage = original_image
            
            faceImage = self.rotate(image: faceImage, degree: 360)!
            sendFaceServer(image: faceImage)
        } else {
            print("에러 발생 : 16")
        }
    }
    
    
    func rotate(image: UIImage, degree: Int) -> UIImage? {
        
        let radians = Float(degree) / (180.0 / Float.pi)
        
        var newSize = CGRect(origin: CGPoint.zero, size: image.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        image.draw(in: CGRect(x: -image.size.width/2, y: -image.size.height/2, width: image.size.width, height: image.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    
    // 검출 서버 통신
    func sendFaceServer(image: UIImage) {
        // 얼굴 인증
        let options = FaceDetectorOptions()
        options.performanceMode = .accurate
        options.landmarkMode = .all
        options.classificationMode = .all
        
        idCardImage = self.rotate(image: idCardImage, degree: 360)!
        let faceDetectionImage1 = VisionImage(image: image)
        faceDetectionImage1.orientation = image.imageOrientation
        let faceDetectionImage2 = VisionImage(image: idCardImage)
        faceDetectionImage2.orientation = idCardImage.imageOrientation
        
        let faceDetector1 = FaceDetector.faceDetector(options: options)
        let faceDetector2 = FaceDetector.faceDetector(options: options)
        
        weak var weakSelf = self
        faceDetector1.process(faceDetectionImage1) { faces, error in
            var image1Rect: CGRect!
            var image2Rect: CGRect!
            
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            guard error == nil, let faces = faces, !faces.isEmpty else {
                self.performSegue(withIdentifier: "faceSegue", sender: self)
                return
            }
            
            // Faces detected
            for face in faces {
                let frame = face.frame
                if image1Rect == nil {
                image1Rect = frame
                }
            }
            
            weak var weakSelf2 = self
            faceDetector2.process(faceDetectionImage2) { faces2, error2 in
                guard let strongSelf2 = weakSelf2 else {
                    print("Self is nil!")
                    return
                }
                guard error2 == nil, let faces2 = faces2, !faces2.isEmpty else {
                    self.performSegue(withIdentifier: "faceSegue", sender: self)
                    return
                }

                image2Rect = faces2[0].frame
                // Faces detected
//                for face2 in faces2 {
//                    let frame2 = face2.frame
//                    image2Rect = frame2
//                    print(frame2)
//                }
                
                let cropRect1 = CGRect(x: image1Rect.minX, y: image1Rect.minY, width: image1Rect.width, height: image1Rect.height)
                
                let imageRef1 = image.cgImage!.cropping(to: cropRect1)
                let face1 = UIImage(cgImage: imageRef1!, scale: image.scale, orientation: UIImage.Orientation.right)
                
                self.faceImage = face1
                
                let cropRect2 = CGRect(x: image2Rect.minX, y: image2Rect.minY, width: image2Rect.width, height: image2Rect.height)
                
                let imageRef2 = self.idCardImage.cgImage!.cropping(to: cropRect2)
                let face2 = UIImage(cgImage: imageRef2!, scale: self.idCardImage.scale, orientation: UIImage.Orientation.right)
                
                self.idCardImage = face2
        //
        //        // resize
        //        let cropImageRatio = cropImage.size.width / cropImage.size.height
        //        let scaledImage = cropImage.scaledImage(with: CGSize(width: 480, height: 480 / cropImageRatio))!
        ////        let scaledImage = cropImage
        //        let scaleSize = cropImage.size.width / scaledImage.size.width
        //
                
                let userName = "code1system"
                let url = "http://192.168.219.100:3333/face"
                
                let imgData = face1.jpegData(compressionQuality: 1.0)!
                let idCardImgData = face2.jpegData(compressionQuality: 1.0)!
                
                let parameters = [
                    "userName" : userName
                ]
                
                AF.upload(multipartFormData: { multipartFormData in
                    
                    for (key, value) in parameters {
                        
                        multipartFormData.append("\(value)".data(using: .utf8)!, withName: key, mimeType: "text/plain")
                        
                    }
                    
                    multipartFormData.append(imgData, withName: "faceImage", fileName: "\(userName).jpg", mimeType: "image/jpg")
                    multipartFormData.append(idCardImgData, withName: "idCardImage", fileName: "\(userName).jpg", mimeType: "image/jpg")
                    
                    
                }, to: url).responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        self.resultJson = JSON(value)
                        self.performSegue(withIdentifier: "faceSegue", sender: self)
                        
                    default:
                        print("Json 파싱 실패")
                        print("에러 23")
                        self.performSegue(withIdentifier: "faceSegue", sender: self)
                    }
                }
  
            }
            
        }
      
    }
    
    @IBAction func positionChange(_ sender: Any) {
        previewView.frame = CGRect(x: 0 , y: (self.navigationController?.navigationBar.frame.maxY)!, width: self.view.frame.width, height: self.view.frame.width * (4032 / 3024))
        
        let device: AVCaptureDevice!
        if cameraPosition == "back" {
            cameraPosition = "front"
            device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: .front)
        }
        else {
            cameraPosition = "back"
            device = AVCaptureDevice.default(for: .video)
        }

        captureSesssion.stopRunning()
        
        captureSesssion = AVCaptureSession()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.photo
        
        cameraOutput = AVCapturePhotoOutput()
        
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if (captureSesssion.canAddInput(input)) {
                captureSesssion.addInput(input)
                if (captureSesssion.canAddOutput(cameraOutput)) {
                    captureSesssion.addOutput(cameraOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    previewLayer.frame = previewView.bounds
                    previewView.layer.addSublayer(previewLayer)
                    captureSesssion.startRunning()
                }
            } else {
                print("에러 발생 : 20")
            }
        } else {
            print("에러 발생 : 21")
        }

    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is FaceResultController{
            let faceResultController = segue.destination as? FaceResultController
            faceResultController?.resultJson = self.resultJson
            faceResultController?.faceImage = self.faceImage
            faceResultController?.idCardImage = self.idCardImage
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.captureButton.isEnabled = true
        self.finish = false
        captureSesssion.startRunning()
    }
}
