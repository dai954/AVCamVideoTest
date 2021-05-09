//
//  ViewController.swift
//  AVCamVideoTest
//
//  Created by 石川大輔 on 2021/04/30.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Localized String Test!!!!!")
        
        let localStr = NSLocalizedString("hello", comment: "")
        print(localStr)
        
        
        
        // Set up the video preview view.
        previewView.session = session
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            self.sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {
                granted in
                if !granted {
                    self.setupResult = .notAuthorized
                } else {
                    self.sessionQueue.resume()
                }
            })
        default:
            setupResult = .notAuthorized
        }
        
        sessionQueue.async {
            self.configureSession()
        }
        
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
//                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCamVideoTest doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCamVideoTest", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:],
                                                  completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                    
                }
    
            case .configurationFailed:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message about session capture configuration")
                    let alertController = UIAlertController(title: "AVCamVideoTest", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
                
            }
        }
        
    }
    
    
    
    
    // MARK: Session Management
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!

    
    @IBOutlet weak var previewView: PreviewView!
    
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
//       Because default is high, I don't need to set high. But I may use midium for sharing over wifi
//        session.sessionPreset = .medium
        session.sessionPreset = .high
        
//        Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input！！！: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
//        Add an audio device input
        
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input")
            }
            
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
//        Add the Movie output
        
        sessionQueue.async {
            let movieFileOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(movieFileOutput) {
                self.session.addOutput(movieFileOutput)
            }
            
            self.movieFileOutput = movieFileOutput
            
        }
        
        self.session.commitConfiguration()
        
    }
    
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    
    
    
    //MARK: - KVO and Notifications
//    private var keyValueObservations = [NSKeyValueObservation]()
//
//    private func addObservers() {
//        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { (_, change) in
//            guard let systemPressureState = change.newValue else { return }
//            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
//        }
//        keyValueObservations.append(systemPressureStateObservation)
//
//        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
//
//    }
//
//
//
//
//    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
//        let pressureLevel = systemPressureState.level
//        if pressureLevel == .shutdown {
//            print("Session stopped running due to shutdown system pressure level.")
//        }
//    }
//
//
//    @objc func sessionRuntimeError(notification: NSNotification) {
//        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
//
//        print("Capture session runtime error: \(error)")
//
//        // If media services were reset, and the last start succeeded, restart the session.
//        if error.code == .mediaServicesWereReset {
//            sessionQueue.async {
//                if self.isSessionRunning {
//                    self.session.startRunning()
//                    self.isSessionRunning = self.session.isRunning
//                }
//            }
//
//    }
//
//
//}
}

