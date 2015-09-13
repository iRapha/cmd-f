//
//  ViewController.swift
//  Cmd-F
//
//  Created by Spruce Bondera on 9/11/15.
//  Copyright © 2015 MHackers. All rights reserved.
//

import UIKit
let HISTORY_KEY = "history key"
class ViewController: UIViewController, G8TesseractDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var overlayView: UIView!
    @IBOutlet weak var textQuery: UISearchBar!
    
    var tesseract: G8Tesseract?
    var picker: UIImagePickerController?
    
    @IBOutlet var cameraButton: UIButton!
    @IBAction func cameraButtonAction(sender: UIButton) {
        picker?.takePicture()
    }
    
    func swipeDown() {
        performSegueWithIdentifier("historySegue", sender: self)
        print("test")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let tap = UITapGestureRecognizer(target: self, action: "presentCamera")
        self.view.addGestureRecognizer(tap)
        print("init")
        
        // Intialize tesseract.
        tesseract = G8Tesseract(language:"eng")
        tesseract!.delegate = self
    }
    
    override func viewDidAppear(animated: Bool) {
        picker = createCamera()
        print("view loaded")
    }
    
    func initializeOverlay(picker: UIImagePickerController) {
        NSBundle.mainBundle().loadNibNamed("OverlayView", owner: self, options: nil)
        let tap = UITapGestureRecognizer(target: self, action: "closeKeyboard")
        overlayView.addGestureRecognizer(tap)
        let swipe = UISwipeGestureRecognizer(target: self, action: "swipeDown")
        swipe.direction = .Down
        overlayView.addGestureRecognizer(swipe)
        cameraButton.layer.cornerRadius = cameraButton.bounds.size.width / 2
        cameraButton.backgroundColor = UIColor.whiteColor()
        
        overlayView.frame = picker.cameraOverlayView!.frame
        overlayView.opaque = false
        overlayView.backgroundColor = UIColor.clearColor()
    }
    
    func createCamera() -> UIImagePickerController? {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            print("Woo")
            picker.delegate = self as protocol<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
            picker.sourceType = UIImagePickerControllerSourceType.Camera
            picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureMode.Photo
            picker.cameraDevice = UIImagePickerControllerCameraDevice.Rear
            picker.showsCameraControls = false
            picker.navigationBarHidden = true
            picker.toolbarHidden = true
            initializeOverlay(picker)
            picker.cameraOverlayView = overlayView
            
            let screenSize = UIScreen.mainScreen().bounds.size
            let cameraAspectRatio = 4.0 / 3.0
            let imageWidth = floor(Double(screenSize.width) * cameraAspectRatio)
            let scale = CGFloat(ceil((Double(screenSize.height) / imageWidth) * 10.0) / 10.0)
            let translationX = CGFloat(0.0)
            let translationY = CGFloat(1 * textQuery.bounds.height)
            
            picker.cameraViewTransform = CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale)
                , CGAffineTransformMakeTranslation(translationX, translationY))
            
            return picker
        } else {
            return nil
        }
    }
    
    func presentCamera() {
        print("tapp")
        if picker != nil {
            presentViewController(picker!, animated: true, completion: nil)

        } else {
            print("fail")
        }
    }
    
    func closeKeyboard() {
        print("tap recognized!")
        overlayView.endEditing(false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func shouldCancelImageRecognitionForTesseract(tesseract: G8Tesseract!) -> Bool {
        return false; // return true if you need to interrupt tesseract before it finishes
    }
    func saveDataToDisk(image: UIImage) -> NSURL? {
        let manager = NSFileManager.defaultManager()
        
        let documents = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first!, isDirectory: true)
        let images = documents.URLByAppendingPathComponent("Images", isDirectory: true)
        if manager.fileExistsAtPath(images.filePathURL!.absoluteString) {
            let name = NSProcessInfo().globallyUniqueString + ".png"
            let imageUrl = images.URLByAppendingPathComponent(name, isDirectory: false)
            UIImagePNGRepresentation(image)?.writeToURL(imageUrl, atomically: true)
            return imageUrl
        } else {
            return nil
        }
    }
    
    // DONE modify to save query and image
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        // Do anything that requires the captured image here
        print("Starting tesseract")
        
        // Find ranges in recognizedText where seachQuery matches. Remove all new lines and spaces from both strings (so that the blocks array correspond one-to-one).
        let searchQuery = textQuery.text
        let imageNSURL = saveDataToDisk(image)
        var NewHistoryObject: HistoryObject
        if imageNSURL != nil && searchQuery != nil {
            NewHistoryObject = HistoryObject(text: searchQuery!, url: imageNSURL!)
            let defaults = NSUserDefaults.standardUserDefaults()
            var historyArray = defaults.objectForKey(HISTORY_KEY) as? [HistoryObject]
            if historyArray == nil {
                let arr = [NewHistoryObject]
                defaults.setObject(arr, forKey: HISTORY_KEY)
            }
            else {
                historyArray!.append(NewHistoryObject)
                defaults.setObject(historyArray, forKey: HISTORY_KEY)
            }
            defaults.synchronize()
        }
        
        dismissViewControllerAnimated(true, completion:
            {if searchQuery != nil {
                self.tesseract(searchQuery!, image: image)
                }})
    }
    
    func errorAlert(title: String, message: String) {
        if #available(iOS 8.0, *) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        } else {
            UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func tesseract(searchQuery: String, image: UIImage!) {
        print("Starting tesseract")
        
        // Give tesseract a preprocessed UIImage.
        tesseract!.image = image.g8_grayScale().g8_blackAndWhite()
        
        // Recognize characters.
        tesseract!.recognize()
        let recognizedText = tesseract!.recognizedText
        let formattedRecognizedText = recognizedText.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "").stringByReplacingOccurrencesOfString("\n", withString: "")
        let formattedSearchQuery = searchQuery.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "").stringByReplacingOccurrencesOfString("\n", withString: "")
        
        // Get match start and end index.
        if formattedSearchQuery.characters.count > 0 {
            if let rangeOfMatch = formattedRecognizedText.rangeOfString(formattedSearchQuery) {
                let matchStartIndex = formattedRecognizedText.startIndex.distanceTo(rangeOfMatch.startIndex)
                let matchEndIndex = formattedRecognizedText.startIndex.distanceTo(rangeOfMatch.endIndex)
                var blocks = tesseract!.recognizedBlocksByIteratorLevel(G8PageIteratorLevel.Symbol) as! [G8RecognizedBlock]
                // Only use blocks that match searchQuery.
                let filteredBlocks = Array(blocks[matchStartIndex..<matchEndIndex])
                
                // Make tesseract display the image with the highlighted blocks.
                imageView.image = tesseract!.imageWithBlocks(filteredBlocks, drawText: true, thresholded: false)
                
                // Request information from google books.
                //            let remote = GoogleBooksRemote()
                //            let query = ("/books/v1/volumes?q=" + recognizedText!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())! + "&key=AIzaSyDhY74nCaymN5Slm-doWyoweJrAbLYWJVM")
                //            NSLog("%@", query)
                //            remote.connect(query)
            } else {
                errorAlert("Unknown query", message: "Could not be completed")
            }
        } else {
            errorAlert("Unknown query", message: "Could not be completed")
        }
    }
}

