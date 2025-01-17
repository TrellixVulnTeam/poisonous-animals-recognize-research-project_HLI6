

import UIKit
import CoreML
import AVFoundation
import Vision


/**
 Controller that allows user to upload a picture of the animal,
 then provides a prediction of that animal
 */
class CNNUploadPhoto: UIViewController, UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    
    
    
    /** image of the picture uploaded */
    @IBOutlet weak var imageView: UIImageView!
    
    /** label of the result of prediction */
    @IBOutlet weak var classifier: UILabel!
    
    /**
     back to the previous controller
     - parameter sender: button going back to the prevous page
     */
    @IBAction func back(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    
    
    
    /** animal's name in the prediction result */
    var spiderName:String!
    
    /** alert telling users that information is sent to database successfully */
    var alert: UIAlertController!
    
    var model: VNCoreMLModel!
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // initiate the reference and create a child object
        
        // request to use the information of users' location
        locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        // set uo the image classifier model
        model = try? VNCoreMLModel(for: ConstantsEnum.imageClassifier)
    }
    
    /**
     Open camera and accept the photo taken
     - parameter sender: the button of taking picture
     */
    @IBAction func camera(_ sender: Any) {
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = self
        cameraPicker.sourceType = .camera
        cameraPicker.allowsEditing = false
        present(cameraPicker, animated: true)
    }
    
    /**
     Open library and accept the photo selected
     - parameter sender: the button of library
     */
    @IBAction func openLibrary(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    

}

extension CNNUploadPhoto: UIImagePickerControllerDelegate {
    /**
     Generate a reult of predition using the photo provided
     - parameter image: image select/taken by users
     */
    func prediciton(_ image: CVPixelBuffer) {
        // load our CoreML model
        // run an inference with CoreML
        let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
            
            // grab the inference results
            guard let results = finishedRequest.results as? [VNClassificationObservation] else { return }
            
            // grab the highest confidence result
            guard let Observation = results.first else { return }
            
            // create the label text components
            let predclass = "\(Observation.identifier)"
            self.spiderName = predclass
            let predconfidence = String(format: "%.02f", Observation.confidence * 100)
            let toxicity = ConstantsEnum.toxicityMapping[predclass]!
            
            // set the label text
            DispatchQueue.main.async(execute: {
                self.classifier.textColor = ConstantsEnum.colorMapping[toxicity]!
                self.classifier.text = "\(predclass) \(predconfidence)%\n" +
                                       "Level: \(toxicity)"
            })
        }
        
        
        try? VNImageRequestHandler(cvPixelBuffer: image, options: [:]).perform([request])
    }
    
    /**
     Close the picker window if the user selected cancel
     - parameter picker: controller of image picker
     */
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    /**
     Capture the picture selected and predict using model provided
     - parameter picker: controller of image picker
     - parameter didFinishPickingMediaWithInfo: an array of String indicating the information of picked media
     */
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true)
        
        // set up the label and image
        classifier.text = "Analyzing Image..."
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
            return
        }
        
        // set up the size and position of that image
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 299, height: 299), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: 299, height: 299))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // pretreat the image and buffer it
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
        
        // show the image after re-size and pretreat
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        imageView.image = newImage
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
        
        // Core ML
        // generate the rusult of prediction
        prediciton(pixelBuffer!)
        
    }
}
