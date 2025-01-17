

// import necessary packages
import UIKit
import AVFoundation
import Vision

/**
 Controller that allows user to scan a animal,
 then provides a prediction of that animal in real time
 */
class CNNScan: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /**
     back to the previous controller
     - parameter sender: button going back to the prevous page
     */
    @IBAction func back(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // create a label to hold the animal name and confidence
    let label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Label"
        label.font = label.font.withSize(15)
        label.numberOfLines = 0
        return label
    }()
    
    /**
     set up the label which shows the result of prediction
     - constrain the label in the center
     - constrain the the label to 50 pixels from the bottom
     */
    func setupLabel() {
        // constrain the label in the center
        label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        // constrain the the label to 50 pixels from the bottom
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
    }
    
    override func viewDidLoad() {
        // call the parent function
        super.viewDidLoad()
        
        // establish the capture session and add the label
        setupCaptureSession()
        view.addSubview(label)
        setupLabel()
        
    }

    override func didReceiveMemoryWarning() {
        // call the parent function
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }
    
    /**
     capture the video and buffer it
     */
    func setupCaptureSession() {
        // create a new capture session
        let captureSession = AVCaptureSession()
        
        // find the available cameras
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        
        do {
            // select a camera
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            // print an error if the camera is not available
            print(error.localizedDescription)
        }
        
        // setup the video output to the screen and add output to our capture session
        let captureOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(captureOutput)
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        // buffer the video and start the capture session
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.startRunning()
    }
    
    /**
     Use the captured video, and generate a prediction using model provided
     - parameter output: video output
     - parameter sampleBuffer: buffer that stores the sample
     - parameter connection: connection to the capture session
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // load our CoreML model
        guard let model = try? VNCoreMLModel(for: ConstantsEnum.imageClassifier) else { return }
        
        // run an inference with CoreML
        let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
            
            // grab the inference results
            guard let results = finishedRequest.results as? [VNClassificationObservation] else { return }
            
            // grab the highest confidence result
            guard let Observation = results.first else { return }
            
            // create the label text components
            let predclass = "\(Observation.identifier)"
            let predconfidence = String(format: "%.02f", Observation.confidence * 100)
            let toxicity = ConstantsEnum.toxicityMapping[predclass]!
            
            // set the label text
            DispatchQueue.main.async(execute: {
                self.label.textColor = ConstantsEnum.colorMapping[toxicity]!
                self.label.text = "\(predclass) \(predconfidence)%\n" +
                                  "Level: \(toxicity)"
            })
        }
        
        // create a Core Video pixel buffer which is an image buffer that holds pixels in main memory
        // Applications generating frames, compressing or decompressing video, or using Core Image
        // can all make use of Core Video pixel buffers
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // execute the request
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
}
