
import Foundation
import MLKit

struct IdCard {
    var title = ""
    var name = ""
    var regnum = ""
    var issueDate = ""
    var licenseNum = ""
    var encnum = ""
    var masking: CGRect!
}

class Ocr {
    var idCard = IdCard()

    public func idOcr(recognizedText: Text, scale: CGFloat) -> IdCard! {
        var boundCheckSum = false
        let allText = recognizedText.text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
        
        print("debug - \(allText)")
        
        // MARK: 분류 and 운전면허 번호
        let licenseNumPattern: String = "([가-힣]{2}|\\d{2}-)\\d{2}-\\d{6}-\\d{2}"
        let licenseRange = allText.range(of: licenseNumPattern, options: .regularExpression)
        if licenseRange != nil {
            idCard.title = "운전면허증"
            idCard.licenseNum = String(allText[licenseRange!])
        }
        else {
            idCard.title = "주민등록증"
        }
        
        // MARK: Type 1 - 주민등록증
        if idCard.title == "주민등록증" {

            // 이름
            let allNamePattern: String = "주민[등,동,둥][록,륵,룩][종,증,중][가-힣]{2,}\\(\\S*\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])-[1-4]\\d{6}"
            let expatriatePattern: String = "주민[등,동,둥][록,륵,룩][종,증,중]\\(재외국민\\)[가-힣]{2,}\\(\\S*\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])-[1-4]\\d{6}"
            let allNameRange = allText.range(of: allNamePattern, options: .regularExpression)
            let expatriateRange = allText.range(of: expatriatePattern, options: .regularExpression)
            if allNameRange != nil {
                var allName = String(allText[allNameRange!])
                allName = String(allName[allName.index(allName.startIndex, offsetBy: 5)...allName.index(before: allName.endIndex)])
                idCard.name = allName.components(separatedBy: "(")[0]
            }
            if expatriateRange != nil {
                var allName = String(allText[expatriateRange!])
                allName = String(allName[allName.index(allName.startIndex, offsetBy: 11)...allName.index(before: allName.endIndex)])
                idCard.title += "(재외국민)"
                idCard.name = allName.components(separatedBy: "(")[0]
            }

            // 발급일자
            let issuePattern: String = "\\d{4}[\\.,\\,]\\d{1,2}[\\.,\\,]\\d{1,2}"
            let issueRange = allText.range(of: issuePattern, options: .regularExpression)
            if issueRange != nil {
                let issueTemp = String(allText[issueRange!]).replacingOccurrences(of: ",", with: ".")
                let nowDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy"
                if Int(issueTemp.components(separatedBy: ".")[0])! <= Int(dateFormatter.string(from: nowDate))! {
                    if Int(issueTemp.components(separatedBy: ".")[1])! <= 12 && Int(issueTemp.components(separatedBy: ".")[1])! >= 1 && Int(issueTemp.components(separatedBy: ".")[2])! >= 1 && Int(issueTemp.components(separatedBy: ".")[2])! <= 31 {
                        idCard.issueDate = issueTemp
                    }
                }
            }
            
            // 주민번호
            let regnumPattern: String = "\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])-[1-4]\\d{6}"
            let regnumRange = allText.range(of: regnumPattern, options: .regularExpression)
            if regnumRange != nil {
                idCard.regnum = String(allText[regnumRange!])
            }
          
            // 크롭 영역 검증
            for block in recognizedText.blocks {
                for line in block.lines {
                    let lineText = line.text.replacingOccurrences(of: " ", with: "")
                    // 주민번호 영역
                    let regnumPattern: String = "\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])-[1-4]\\d{6}"
                    let regnumRange = lineText.range(of: regnumPattern, options: .regularExpression)
                    if regnumRange != nil {
                        idCard.masking = CGRect(x: (line.frame.minX + line.frame.width / 2) * scale, y: line.frame.minY * scale, width: line.frame.width / 2 * scale, height: line.frame.height * scale)
                        if line.frame.minY > 122 && line.frame.maxY < 167 {
                            if line.frame.minX > 40 && line.frame.maxX < 255 {
                                boundCheckSum = true
                            }
                        }
                    }
                }
            }
        }
        // MARK: Type 2 - 운전면허증
        else if idCard.title == "운전면허증" {
            // 2014년 이전 면허증 (2024년 이후 제거)
            var oldDriverLicense = false

            // 이름
            let allNamePattern: String = "([가-힣]{2}|\\d{2}-)\\d{2}-\\d{6}-\\d{2}[가-힣:]{2,}\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])[-,+][1-4]\\d{6}"
            let allNameRange = allText.range(of: allNamePattern, options: .regularExpression)
            if allNameRange != nil {
                var allName = String(allText[allNameRange!])
                /// 앞에 지역명이 검출 될 가능성 제거
                allName = String(allName[allName.index(allName.startIndex, offsetBy: 2)...allName.index(before: allName.endIndex)])
                let namePattern: String = "[가-힣:]{2,}"
                let nameRange = allName.range(of: namePattern, options: .regularExpression)
                if nameRange != nil {
                    var name = String(allName[nameRange!])
                    
                    if name.contains(":") {
                        name = name.components(separatedBy: ":").last!
                        oldDriverLicense = true
                    }
                    
                    /// 이름 2번 중복 검출 제거
                    if name.count >= 4 && name.count % 2 == 0 {
                        var charComparisonCount = 0
                        let nameSplit1 = String(name[name.index(name.startIndex, offsetBy: 0)...name.index(name.startIndex, offsetBy: name.count / 2 - 1)])
                        let nameSplit2 = String(name[name.index(name.startIndex, offsetBy: name.count / 2)...name.index(before: name.endIndex)])

                        for i in 0...nameSplit1.count - 1 {
                            if String(nameSplit1[nameSplit1.index(nameSplit1.startIndex, offsetBy: i)]) == String(nameSplit2[nameSplit2.index(nameSplit2.startIndex, offsetBy: i)]) {
                                charComparisonCount += 1
                            }
                        }
                        if charComparisonCount >= 2 {
                            name = nameSplit1
                        }
                    }
                    idCard.name = name
                }
            }
            // 주민번호
            let regnumPattern: String = "\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])[-,+][1-4]\\d{6}"
            let regnumRange = allText.range(of: regnumPattern, options: .regularExpression)
            if regnumRange != nil {
                idCard.regnum = String(allText[regnumRange!]).replacingOccurrences(of: "+", with: "-")
            }
            
            for block in recognizedText.blocks {
                for line in block.lines {
                    let lineText = line.text.replacingOccurrences(of: " ", with: "")
               
                    // 운전 발급 일자
                    /// 숫자 확인
                    var issuDig = ""
                    let digitSet = CharacterSet.decimalDigits
                    for (_, ch) in lineText.unicodeScalars.enumerated() {
                        if digitSet.contains(ch) {
                            issuDig += String(ch)
                        }
                    }
                    if issuDig.count == 8 {
                        let year = String(issuDig[issuDig.index(issuDig.startIndex, offsetBy: 0)...issuDig.index(issuDig.startIndex, offsetBy: 3)])
                        let month = String(issuDig[issuDig.index(issuDig.startIndex, offsetBy: 4)...issuDig.index(issuDig.startIndex, offsetBy: 5)])
                        let date = String(issuDig[issuDig.index(issuDig.startIndex, offsetBy: 6)...issuDig.index(before: issuDig.endIndex)])
                        
                        let nowDate = Date()
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy"
                        if Int(year)! <= Int(dateFormatter.string(from: nowDate))! {
                            if Int(month)! <= 12 && Int(month)! >= 1 && Int(date)! >= 1 && Int(date)! <= 31 {
                                idCard.issueDate = year + "." + month + "." + date
                            }
                        }
                    }
                    
                    // 암호일련번호
                    if lineText.count == 6 {
                        let encnumPattern: String = "[A-Z0-9]{6}"
                        let encnumRange = lineText.range(of: encnumPattern, options: .regularExpression)
                        if encnumRange != nil {
                            idCard.encnum = String(lineText[encnumRange!])
                        }
                    }
                    
                    // 주민번호 영역
                    let regnumPattern: String = "\\d{2}([0]\\d|[1][0-2])([0][1-9]|[1-2]\\d|[3][0-1])[-,+][1-4]\\d{6}"
                    let regnumRange = lineText.range(of: regnumPattern, options: .regularExpression)
                    if regnumRange != nil {
                        idCard.masking = CGRect(x: (line.frame.minX + line.frame.width / 2) * scale, y: line.frame.minY * scale, width: line.frame.width / 2 * scale, height: line.frame.height * scale)
//                        print("debug - 위치 : (\(line.frame.minY), \(line.frame.maxY))")
//                        print("debug - 위치 : (\(line.frame.minX))")
                        if oldDriverLicense {
                            if line.frame.minY > 105 && line.frame.maxY < 145 && line.frame.minX > 245 && line.frame.minX < 275 {
                                boundCheckSum = true
                            }
                        }
                        else {
                            if line.frame.minY > 107 && line.frame.maxY < 148 && line.frame.minX > 165 && line.frame.minX < 210 {
                                boundCheckSum = true
                            }
                        }
                    }
                }
            }
        }

//        print(idCard)
//        print(boundCheckSum)
        
        if (idCard.title == "주민등록증" || idCard.title == "주민등록증(재외국민)")
            && idCard.regnum.count != 0
            && idCard.issueDate.count != 0
            && idCard.name.count != 0
            && boundCheckSum { return idCard }
        else if idCard.title == "운전면허증"
                    && idCard.licenseNum.count != 0
                    && idCard.regnum.count != 0
                    && idCard.issueDate.count != 0
                    && idCard.name.count != 0
                    && idCard.encnum.count != 0
                    && boundCheckSum { return idCard }
        return nil
    }
}


