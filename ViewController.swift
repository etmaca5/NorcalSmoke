//
//  ViewController.swift
//  NorcalSmoke
//
//  Created by etienne on 8/20/21.
//

import UIKit
import LinkPresentation
import Vision

class ViewController: UIViewController {
    
    var region = "norcal" // norcal, socal, oregon, washington
        
    var norcalData1: [Data?] = []
    var norcalData2: [Data?] = []
    var norcalImageDownloaded1: [Bool?] = []
    var norcalImageDownloaded2: [Bool?] = []
    
    var socalData1: [Data?] = []
    var socalData2: [Data?] = []
    var socalImageDownloaded1: [Bool?] = []
    var socalImageDownloaded2: [Bool?] = []
    
    var oregonData1: [Data?] = []
    var oregonData2: [Data?] = []
    var oregonImageDownloaded1: [Bool?] = []
    var oregonImageDownloaded2: [Bool?] = []
    
    var washingtonData1: [Data?] = []
    var washingtonData2: [Data?] = []
    var washingtonImageDownloaded1: [Bool?] = []
    var washingtonImageDownloaded2: [Bool?] = []

    var prepend: String = "smokes"
    var reportTypeNb: Int = 0
    var indexNumber: Int = 0
    var lastRefreshed = Date().timeIntervalSince1970
    
    var firstDate: Date = Date()
    var firstDateInitialized: Bool = false
    var currentHour : Int = 0
    var currentDate : Date = Date ()

    var isMorningData : Bool = true

    @IBOutlet var appTitle: UINavigationBar!
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        currentHour = getCurrentHour()
        currentDate = Date()
        
        super.viewDidLoad()
        initDataArrays()
        initInterface()
        downloadImage()
    }
    
    @objc func applicationDidBecomeActive(notification: NSNotification) {
        // Application is back in the foreground
        
        let now = Date().timeIntervalSince1970
        let timeDiff = now - lastRefreshed
        print ("Time since last restart \(timeDiff)");
        
        if (timeDiff > 7200.0) {
            lastRefreshed = Date().timeIntervalSince1970
            purgeCache()
        } else {
            currentHour = getCurrentHour()
            currentDate = Date()
            
            if (currentHour >= 18 || currentHour < 6) {
                if (isMorningData == true) {
                    // reload
                    isMorningData = false
                    purgeCache()
                    
                }
            } else {
                if (isMorningData == false) {
                    // reload
                    isMorningData = true
                    purgeCache()
                }
            }
        }
    }
    
    func getCurrentHour () -> Int {
        return Calendar.current.component(.hour, from: Date());
    }
    
    func getCurrentDate () -> Date {
        return Date()
    }
    
    func purgeCache () {
        region = "norcal"
        firstDateInitialized = false
        indexNumber = 0
        sliderOutlet.value = 0.0
        initDataArrays()
        initInterface()
        downloadImage()
    }
    

        
    func getHours (_ index: Int) -> Int {
        return index - startingIndex
    }
        
    @IBOutlet var aqiImage: UIImageView!
    
    @IBAction func reportType(_ sender: UISegmentedControl) {
        if (sender.selectedSegmentIndex == 0) {
            prepend = "smokes"
        } else if (sender.selectedSegmentIndex == 1) {
            prepend = "smokec"
        }
        reportTypeNb = sender.selectedSegmentIndex
        downloadImage()
    }
    
    @IBOutlet var miniImage: UIImageView!
    var startingIndex: Int = 0
    
    func imageUrl(_ index: Int) -> URL {
        var urlString: String = ""
        switch region {
            case "norcal":
                urlString = "https://airquality.weather.gov/images/northcalifornia/\(prepend)\(index+1)_northcalifornia.png"
                break
            case "socal":
                urlString = "https://airquality.weather.gov/images/southcalifornia/\(prepend)\(index+1)_southcalifornia.png"
                break
            case "oregon":
                urlString = "https://airquality.weather.gov/images/oregon/\(prepend)\(index+1)_oregon.png"
                break
            case "washington":
                urlString = "https://airquality.weather.gov/images/washington/\(prepend)\(index+1)_washington.png"
                break
            default:
                urlString = "https://airquality.weather.gov/images/northcalifornia/\(prepend)\(index+1)_northcalifornia.png"
                break
        }
        return URL(string:urlString)!;
        
    }
    
    @IBOutlet var sliderOutlet: UISlider!
    
    @IBAction func selection(_ sender: UISlider) {
        currentHour = getCurrentHour()
        currentDate = Date()
        indexNumber = Int(sender.value);
//        print ("sent by slider indexNumber \(indexNumber)")
        downloadImage()
    }
    
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    
    func analyzeNooaWeatherImage(image: UIImage, rect: CGRect) -> UIImage {
        // TODO what do do if image is nil
        let cgImage = image.cgImage!
        if let croppedCGImage = cgImage.cropping(to: rect) {
            let croppedImage = UIImage(cgImage: croppedCGImage)
            
            let requestHandler = VNImageRequestHandler(cgImage: croppedCGImage)
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                let finalString = self.recognizeText(from: request)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE MMM dd yyyy ha z"
                    
                if let date = dateFormatter.date(from: finalString ?? "") {
                    let dateFormatterNew = DateFormatter()
                    dateFormatterNew.dateFormat = "EEE ha z"
                    print("Started @ Pacific \(dateFormatterNew.string(from: date))")
                    self.firstDate = date
                } else {
                    print ("Date not recognized!")
                }
            
            }
            if (firstDateInitialized == false) {
                firstDateInitialized = true;
                do {
                    try requestHandler.perform([request])
                } catch {
                    print("Unable to perform the requests: \(error).")
                }
            }
            
            return croppedImage
        } else {
            return UIImage()
        }
    }
    
    func displayProperTimeStamp (theIndex: Int, theFirstDate: Date) {
        // DATE
        let dateFormatter2 = DateFormatter()
        dateFormatter2.dateFormat = "EEEE ha z"
        
        let dateFormatterHour = DateFormatter()
        dateFormatterHour.dateFormat = "h"
                
        let diffComponents = Calendar.current.dateComponents([.hour, .minute], from: theFirstDate.adding(hours: theIndex), to: currentDate)
        let minutes = diffComponents.minute ?? -99999
        let hours = diffComponents.hour ?? -99999
        
        
 if (minutes == -99999) {
    appTitle.topItem?.title =  "\(dateFormatter2.string(from: theFirstDate.adding(hours: theIndex)))";
        } else {
            if (hours > 0) {
                appTitle.topItem?.title =  "\(dateFormatter2.string(from: theFirstDate.adding(hours: theIndex))) (\(abs(hours))H ago)";
            } else {
                if (minutes < 0) {
                    appTitle.topItem?.title = "\(dateFormatter2.string(from: theFirstDate.adding(hours: theIndex))) (in \(abs(hours) + 1)H)"
                } else {
                    appTitle.topItem?.title = "\(dateFormatter2.string(from: theFirstDate.adding(hours: theIndex))) (now)"
                }
            }
        }
        
    }
    
    
    func downloadImage() {
        
        let url = imageUrl(indexNumber);
                
        var structure : [Data?]
        var structureDownloaded : [Bool?]
        
        let cropImage : Bool = (region == "norcal")
        let localIndexNb = self.indexNumber
        let localRegion = self.region
        let localReportTypeNb = self.reportTypeNb

        if (localReportTypeNb == 1) {
            
            switch localRegion {
                case "socal":
                    structure = self.socalData2
                    structureDownloaded = self.socalImageDownloaded2
                    break
                case "oregon":
                    structure = self.oregonData2
                    structureDownloaded = self.oregonImageDownloaded2
                    break
                case "washington":
                    structure = self.washingtonData2
                    structureDownloaded = self.washingtonImageDownloaded2
                    break
                default:
                    structure = self.norcalData2
                    structureDownloaded = self.norcalImageDownloaded2
                    break
            }
    
        } else {
            switch localRegion {
                case "socal":
                    structure = self.socalData1
                    structureDownloaded = self.socalImageDownloaded1
                    break
                case "oregon":
                    structure = self.oregonData1
                    structureDownloaded = self.oregonImageDownloaded1
                    break
                case "washington":
                    structure = self.washingtonData1
                    structureDownloaded = self.washingtonImageDownloaded1
                    break
                default:
                    structure = self.norcalData1
                    structureDownloaded = self.norcalImageDownloaded1
                    break
            }
        }
        
        if (structureDownloaded[localIndexNb] == false && structure[localIndexNb] == nil) {
            // print("proceed with download")
            getData(from: url) { data, response, error in
                guard let data = data, error == nil else { return }
                if (localReportTypeNb == 1) {
                    switch localRegion {
                        case "norcal":
                            self.norcalData2[localIndexNb] = data
                            break
                        case "socal":
                            self.socalData2[localIndexNb] = data
                            break
                        case "oregon":
                            self.oregonData2[localIndexNb] = data
                            break
                        case "washington":
                            self.washingtonData2[localIndexNb] = data
                            break
                        default:
                            self.norcalData2[localIndexNb] = data
                    }
                } else {
                    switch localRegion {
                        case "norcal":
                            self.norcalData1[localIndexNb] = data
                            break
                        case "socal":
                            self.socalData1[localIndexNb] = data
                            break
                        case "oregon":
                            self.oregonData1[localIndexNb] = data
                            break
                        case "washington":
                            self.washingtonData1[localIndexNb] = data
                            break
                        default:
                            self.norcalData1[localIndexNb] = data
                    }
                }
                // print ("Downloaded index \(localIndexNb)");
                // always update the UI from the main thread
                DispatchQueue.main.async() { [weak self] in
                    // print ("Displaying index \(localIndexNb)");
                    self?.aqiImage.image = UIImage(data: data)
                    
                    if (cropImage == true) {
                        if let theImage = UIImage(data: data) {
                            self?.miniImage.image = self!.analyzeNooaWeatherImage(image: theImage, rect: CGRect(x: 310, y: 684, width: 200, height: 20));
                        }
                        self?.displayProperTimeStamp(theIndex:localIndexNb, theFirstDate: self?.firstDate ?? Date())
                    
                    } else {
                        self?.displayProperTimeStamp(theIndex:localIndexNb, theFirstDate: self?.firstDate ?? Date())
            
                        self?.miniImage.isHidden = true
                    }
                }
            }
        } else {
            DispatchQueue.main.async() { [weak self] in
                if (structure[localIndexNb] != nil) {
                    self?.aqiImage.image = UIImage(data: structure[localIndexNb] ?? Data())
                    // print ("localIndexNb \(localIndexNb)")
                    self?.displayProperTimeStamp(theIndex: localIndexNb, theFirstDate: self?.firstDate ?? Date())
                                        
                }
            }
        }
    }
    
}

extension Date {
    func adding(hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self)!
    }
}

extension ViewController {
    func recognizeText(from request: VNRequest) -> String? {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return nil
        }

        let recognizedStrings: [String] = observations.compactMap { (observation)  in
            guard let topCandidate = observation.topCandidates(1).first else { return nil }

            return topCandidate.string.trimmingCharacters(in: .whitespaces)
        }

        return recognizedStrings.joined(separator: "\n")
    }
}

extension ViewController {
    func initInterface () {
//        infoButton.layer.cornerRadius = 6.0
//        infoButton.layer.borderWidth = 0.8
//        infoButton.layer.borderColor = UIColor.white.cgColor
//
//        shareButton.layer.cornerRadius = 6.0
//        shareButton.layer.borderWidth = 0.8
//        shareButton.layer.borderColor = UIColor.white.cgColor
        
        sliderOutlet.minimumValue = 0.0
        startingIndex = 0
        sliderOutlet.value = 0.0
                
        miniImage.layer.masksToBounds = true
        miniImage.layer.borderWidth = 2.5
        miniImage.layer.borderColor = UIColor.black.cgColor
        miniImage.layer.backgroundColor = UIColor.white.cgColor
        
        aqiImage.isUserInteractionEnabled = true
        
        let swipeGestureDown = UISwipeGestureRecognizer(target: self, action: #selector(self.getSwipeAction(_:)))
        swipeGestureDown.direction = .down
        self.aqiImage.addGestureRecognizer(swipeGestureDown)
        
        let swipeGestureUp = UISwipeGestureRecognizer(target: self, action: #selector(self.getSwipeAction(_:)))
        swipeGestureUp.direction = .up
        self.aqiImage.addGestureRecognizer(swipeGestureUp)
    }
    
    func initDataArrays () {
        var i: Int = 1
        
        norcalData1 = []
        norcalData2 = []
        norcalImageDownloaded1 = []
        norcalImageDownloaded2 = []
        
        socalData1 = []
        socalData2 = []
        socalImageDownloaded1 = []
        socalImageDownloaded2 = []
        
        oregonData1 = []
        oregonData2 = []
        oregonImageDownloaded1 = []
        oregonImageDownloaded2 = []
        
        washingtonData1 = []
        washingtonData2 = []
        washingtonImageDownloaded1 = []
        washingtonImageDownloaded2 = []

        while i < 50 {
            
            norcalData1.append(nil)
            norcalData2.append(nil)
            norcalImageDownloaded1.append(false)
            norcalImageDownloaded2.append(false)
            
            socalData1.append(nil)
            socalData2.append(nil)
            socalImageDownloaded1.append(false)
            socalImageDownloaded2.append(false)
            
            oregonData1.append(nil)
            oregonData2.append(nil)
            oregonImageDownloaded1.append(false)
            oregonImageDownloaded2.append(false)
            
            washingtonData1.append(nil)
            washingtonData2.append(nil)
            washingtonImageDownloaded1.append(false)
            washingtonImageDownloaded2.append(false)
            i += 1
        }
    }
    
    @objc func getSwipeAction( _ recognizer : UISwipeGestureRecognizer){

        if recognizer.direction == .down{
            switch region {
                case "norcal":
                    region = "oregon"
                    break
                case "socal":
                    region = "norcal"
                    break
                case "oregon":
                    region = "washington"
                    break
                case "washington":
                    break
                default:
                    break
            }
        } else if recognizer.direction == .up {
            switch region {
                case "norcal":
                    region = "socal"
                    break
                case "socal":
                    break
                case "oregon":
                    region = "norcal"
                    break
                case "washington":
                    region = "oregon"
                    break
                default:
                    break
            }
        }
        downloadImage()
    }
}
