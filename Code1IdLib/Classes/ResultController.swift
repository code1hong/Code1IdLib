import UIKit
import Alamofire
import SwiftyJSON
import Foundation

class ResultController: UIViewController {
    
    var resultCapture: UIImageView!
    
    var result: IdCard!
    var originalImage: UIImage!
    var idCardImage: UIImage!
    var idAuth = false
    var success = false
    
    var labelAuth: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        
        if result.title == "주민등록증" || result.title == "주민등록증(재외국민)" || result.title == "운전면허증" {
            success = true
            // 마스킹
            idCardImage = UIUtilities.masking(image: idCardImage, rect: result.masking)
        }
        
        // 결과 이미지
        resultCapture = UIImageView(frame: CGRect(x: 0, y: (self.navigationController?.navigationBar.frame.maxY)!, width: view.frame.width, height: view.frame.width / 1.59))
        resultCapture.image = idCardImage
        self.view.addSubview(resultCapture)
        
        var lastLabelRect: CGRect!
        
        // 성공
        if success {
            if result.title == "주민등록증" || result.title == "주민등록증(재외국민)" {
                lastLabelRect = juminPrint()
            }
            else if result.title == "운전면허증" {
                lastLabelRect = driverPrint()
            }
            
            let labelAuthTitle = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: lastLabelRect.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
            labelAuth = UILabel(frame: CGRect(x: self.view.frame.width * 0.3, y: lastLabelRect.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))

            self.view.addSubview(labelAuthTitle)
            self.view.addSubview(labelAuth)

            labelAuthTitle.text = "진위 여부"
            labelAuthTitle.font = UIFont.systemFont(ofSize: 12)
            labelAuthTitle.textAlignment = .right
            
            labelAuth.font = UIFont.systemFont(ofSize: 14)
            labelAuth.textAlignment = .left
            
            // 인증
            if idAuth {
                labelAuth.text = "판별중"
                sendIdAuth(image: idCardImage)
            }
            else {
                labelAuth.text = "인증 안함"
            }

        }
        // 실패
        else {
            let label1 = UILabel(frame: CGRect(x: self.view.frame.width * 0.1 , y: self.resultCapture.frame.maxY + 30, width: self.view.frame.width * 0.8, height: self.view.frame.height * 0.05))
            
            self.view.addSubview(label1)
            label1.text = "검출 실패"
            label1.textAlignment = .center
            lastLabelRect = label1.frame
            resultCapture.image = idCardImage
            
            print("지원하지 않는 신분증입니다.")
        }
  
    }
    
    @IBAction func faceOnClick(_ sender: Any) {
//        guard let detectionController = self.storyboard?.instantiateViewController(identifier: "DetectionController") as? DetectionController else { return }
                
//        detectionController.idCardImage = idCardImage
        self.performSegue(withIdentifier: "detectionSegue", sender: self)

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is DetectionController{
            let detectionController = segue.destination as? DetectionController
            detectionController?.idCardImage = originalImage
        }
    }
    
    // 인증 서버 통신
    func sendIdAuth(image: UIImage) {
        let userName = "code1system"
        let url = "http://115.178.87.240:5090/menesdemo/predict"
        let imgData = image.jpegData(compressionQuality: 1.0)!
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imgData, withName: "file", fileName: "\(userName).jpg", mimeType: "image/jpg")
        }, to: url).responseJSON { response in
            switch response.result {
            case .success(let value):
                let authResult = JSON(value)["prediction"]["label"].rawString()!
                let authProb = String(format: "%.3f", Float(JSON(value)["prediction"]["probability"].rawString()!)!)
                self.labelAuth.text = "\(authResult) - \(authProb)"
            default:
                self.labelAuth.text = "인증 실패"
                print("인증 서버 통신 실패")
                print("에러 13")
            }
        }
    }
    
    func juminPrint() -> CGRect {
        let label1 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: self.resultCapture.frame.maxY + 10, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label2 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label1.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label3 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label2.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label4 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label3.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        
        self.view.addSubview(label1)
        self.view.addSubview(label2)
        self.view.addSubview(label3)
        self.view.addSubview(label4)
        
        label1.text = "종류"
        label2.text = "이름"
        label3.text = "주민번호"
        label4.text = "발급일자"
        
        label1.font = UIFont.systemFont(ofSize: 14)
        label2.font = UIFont.systemFont(ofSize: 14)
        label3.font = UIFont.systemFont(ofSize: 14)
        label4.font = UIFont.systemFont(ofSize: 14)
        label1.textAlignment = .right
        label2.textAlignment = .right
        label3.textAlignment = .right
        label4.textAlignment = .right
        
        let textField1 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: self.resultCapture.frame.maxY + 10, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField2 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField1.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField3 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField2.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField4 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField3.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        
        self.view.addSubview(textField1)
        self.view.addSubview(textField2)
        self.view.addSubview(textField3)
        self.view.addSubview(textField4)
        
        textField1.text = result.title
        textField2.text = result.name
        textField3.text = result.regnum
        textField4.text = result.issueDate
        
        textField1.textAlignment = .left
        textField2.textAlignment = .left
        textField3.textAlignment = .left
        textField4.textAlignment = .left
        
        textField1.textColor = .black
        textField2.textColor = .black
        textField3.textColor = .black
        textField4.textColor = .black
        
        underLine(textField: textField1)
        underLine(textField: textField2)
        underLine(textField: textField3)
        underLine(textField: textField4)
        
        return label4.frame
    }
    
    
    
    func driverPrint() -> CGRect {
        let label1 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: self.resultCapture.frame.maxY + 10, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label2 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label1.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label3 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label2.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label4 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label3.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label5 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label4.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        let label6 = UILabel(frame: CGRect(x: self.view.frame.width * 0.05, y: label5.frame.maxY, width: self.view.frame.width * 0.15, height: self.view.frame.height * 0.05))
        
        self.view.addSubview(label1)
        self.view.addSubview(label2)
        self.view.addSubview(label3)
        self.view.addSubview(label4)
        self.view.addSubview(label5)
        self.view.addSubview(label6)
        
        label1.text = "종류"
        label2.text = "면허번호"
        label3.text = "이름"
        label4.text = "주민번호"
        label5.text = "암호일련"
        label6.text = "발급일자"
        
        label1.font = UIFont.systemFont(ofSize: 14)
        label2.font = UIFont.systemFont(ofSize: 14)
        label3.font = UIFont.systemFont(ofSize: 14)
        label4.font = UIFont.systemFont(ofSize: 14)
        label5.font = UIFont.systemFont(ofSize: 14)
        label6.font = UIFont.systemFont(ofSize: 14)
        
        label1.textAlignment = .right
        label2.textAlignment = .right
        label3.textAlignment = .right
        label4.textAlignment = .right
        label5.textAlignment = .right
        label6.textAlignment = .right
        
        let textField1 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: self.resultCapture.frame.maxY + 10, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField2 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField1.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField3 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField2.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField4 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField3.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField5 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField4.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        let textField6 = UITextField(frame: CGRect(x: self.view.frame.width * 0.3, y: textField5.frame.maxY, width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.05))
        
        self.view.addSubview(textField1)
        self.view.addSubview(textField2)
        self.view.addSubview(textField3)
        self.view.addSubview(textField4)
        self.view.addSubview(textField5)
        self.view.addSubview(textField6)
        
        textField1.text = result.title
        textField2.text = result.licenseNum
        textField3.text = result.name
        textField4.text = result.regnum
        textField5.text = result.encnum
        textField6.text = result.issueDate
        
        textField1.textAlignment = .left
        textField2.textAlignment = .left
        textField3.textAlignment = .left
        textField4.textAlignment = .left
        textField5.textAlignment = .left
        textField6.textAlignment = .left
        
        textField1.textColor = .black
        textField2.textColor = .black
        textField3.textColor = .black
        textField4.textColor = .black
        textField5.textColor = .black
        textField6.textColor = .black
        
        underLine(textField: textField1)
        underLine(textField: textField2)
        underLine(textField: textField3)
        underLine(textField: textField4)
        underLine(textField: textField5)
        underLine(textField: textField6)
        
        return label6.frame
    }
    
    func underLine(textField: UITextField) {
        textField.borderStyle = .none
        let border = CALayer()
        border.frame = CGRect(x: 0, y: textField.frame.size.height-1, width: textField.frame.width, height: 1)
        border.backgroundColor = UIColor.black.cgColor
        textField.layer.addSublayer((border))
        textField.textColor = UIColor.black
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        self.view.endEditing(true)
        
    }
}

