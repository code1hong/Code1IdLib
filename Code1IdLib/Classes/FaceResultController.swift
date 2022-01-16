import UIKit
import Alamofire
import SwiftyJSON
import Foundation

class FaceResultController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var idCardView: UIImageView!
    @IBOutlet weak var faceView: UIImageView!
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var confLabel: UILabel!
    
    var resultJson: JSON!
    var faceImage: UIImage!
    var idCardImage: UIImage!
  
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navigationController?.isNavigationBarHidden = false
//        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.accessibilityElementsHidden = true
    
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        
        if idCardImage == nil || faceImage == nil || resultJson == nil {
            resultLabel.text = "얼굴 영역 검출 실패"
            confLabel.isHidden = true
        }
        else if resultJson["verify"].rawString() == "fail" {
            resultLabel.text = "검출 실패"
            confLabel.isHidden = true
        }
        else {
            idCardView.image = rotate(image: idCardImage, degree: 270)!
            faceView.image = rotate(image: faceImage, degree: 270)!
        
            if resultJson["verify"].rawString() == "True" {
                resultLabel.text = "일치"
            }
            else {
                resultLabel.text = "불일치"
            }
            let confString = String(format: "%.1f", Float(resultJson["conf"].rawString()!)!)
            confLabel.text = confString + "%"
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
 
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        self.view.endEditing(true)
    }
    
    @IBAction func backHome(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
}

