import Foundation
import AVFoundation
import PhotosUI
import Photos

protocol CameraManDelegate: class {
  func cameraManNotAvailable(_ cameraMan: CameraMan)
  func cameraManDidStart(_ cameraMan: CameraMan)
  func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput)
}

class CameraMan {
  weak var delegate: CameraManDelegate?

  let session = AVCaptureSession()
  let queue = DispatchQueue(label: "no.hyper.Gallery.Camera.SessionQueue", qos: .background)
  let savingQueue = DispatchQueue(label: "no.hyper.Gallery.Camera.SavingQueue", qos: .background)
  let orientationMan = OrientationMan()

  var backCamera: AVCaptureDeviceInput?
  var frontCamera: AVCaptureDeviceInput?
  var stillImageOutput: AVCaptureStillImageOutput?

  deinit {
    stop()
  }

  // MARK: - Setup

  func setup() {
    if Permission.Camera.status == .authorized {
      self.start()
    } else {
      self.delegate?.cameraManNotAvailable(self)
    }
  }

  func setupDevices() {
    // Input
    AVCaptureDevice
      .devices()
      .filter {
        return $0.hasMediaType(.video)
      }.forEach {
        switch $0.position {
        case .front:
          self.frontCamera = try? AVCaptureDeviceInput(device: $0)
        case .back:
          self.backCamera = try? AVCaptureDeviceInput(device: $0)
        default:
          break
        }
    }

    // Output
    stillImageOutput = AVCaptureStillImageOutput()
    stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
  }

  func addInput(_ input: AVCaptureDeviceInput) {
    configurePreset(input)

    if session.canAddInput(input) {
      session.addInput(input)

      DispatchQueue.main.async {
        self.delegate?.cameraMan(self, didChangeInput: input)
      }
    }
  }

  // MARK: - Session

  var currentInput: AVCaptureDeviceInput? {
    return session.inputs.first as? AVCaptureDeviceInput
  }

  fileprivate func start() {
    // Devices
    setupDevices()

    guard let input = backCamera, let output = stillImageOutput else { return }

    addInput(input)

    if session.canAddOutput(output) {
      session.addOutput(output)
    }

    queue.async {
      self.session.startRunning()

      DispatchQueue.main.async {
        self.delegate?.cameraManDidStart(self)
      }
    }
  }

  func stop() {
    self.session.stopRunning()
  }

  func switchCamera(_ completion: (() -> Void)? = nil) {
    guard let currentInput = currentInput
      else {
        completion?()
        return
    }

    queue.async {
      guard let input = (currentInput == self.backCamera) ? self.frontCamera : self.backCamera
        else {
          DispatchQueue.main.async {
            completion?()
          }
          return
      }

      self.configure {
        self.session.removeInput(currentInput)
        self.addInput(input)
      }

      DispatchQueue.main.async {
        completion?()
      }
    }
  }

  func takePhoto(_ previewLayer: AVCaptureVideoPreviewLayer, location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    guard let connection = stillImageOutput?.connection(with: .video) else { return }

    connection.videoOrientation = Utils.videoOrientation()

    DispatchQueue.global(qos: .userInteractive).async {
//    queue.async {
      self.stillImageOutput?.captureStillImageAsynchronously(from: connection) {
        buffer, error in

        guard error == nil, let buffer = buffer, CMSampleBufferIsValid(buffer),
          let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer) else {
            DispatchQueue.main.async {
              completion(nil)
            }
            return
        }
        var tmpimage = UIImage(data: imageData)
        if tmpimage == nil {
            DispatchQueue.main.async {
              completion(nil)
            }
            return
        }
        if let enableDateTime = UserDefaults.standard.string(forKey: "enableDateTime"), enableDateTime == "on" {
            let controller = self.delegate as! CameraController
            
            //draw map image
            var mapImage = controller.cameraView.imgOverlay.image
            if mapImage != nil && mapImage!.size.width > 0 {
                let size = tmpimage!.size
                let mapImageSize = size.width/3
                tmpimage = tmpimage?.with(image: mapImage?.image(alpha: 0.65)) { parentSize, newImageSize in
                    return CGRect(x: size.width - mapImageSize, y: 0, width: mapImageSize, height: mapImageSize)
                }
            }
            
            //draw datetime & address
            let text = controller.cameraView.labelOverlay.text ?? ""
            tmpimage = Utils.textToImage(drawText: text as NSString, inImage: tmpimage, targetSize: CGSize.zero)
        }
        self.savePhoto(tmpimage!, location: location, completion: completion)
      }
    }
  }
  
  func savePhoto(_ image: UIImage, location: CLLocation?, completion: @escaping ((PHAsset?) -> Void)) {
    var localIdentifier: String?

    DispatchQueue.main.async {
      do {
        try PHPhotoLibrary.shared().performChangesAndWait {
          let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
          localIdentifier = request.placeholderForCreatedAsset?.localIdentifier

          request.creationDate = Date()
          request.location = location
        }

        DispatchQueue.main.async {
          if let localIdentifier = localIdentifier {
            completion(Fetcher.fetchAsset(localIdentifier))
          } else {
            completion(nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          completion(nil)
        }
      }
    }
  }

  func flash(_ mode: AVCaptureDevice.FlashMode) {
    guard let device = currentInput?.device , device.isFlashModeSupported(mode) else { return }

    queue.async {
      self.lock {
        device.flashMode = mode
      }
    }
  }

  func focus(_ point: CGPoint) {
    guard let device = currentInput?.device , device.isFocusModeSupported(AVCaptureDevice.FocusMode.locked) else { return }

    queue.async {
      self.lock {
        device.focusPointOfInterest = point
      }
    }
  }

  // MARK: - Lock

  func lock(_ block: () -> Void) {
    if let device = currentInput?.device , (try? device.lockForConfiguration()) != nil {
      block()
      device.unlockForConfiguration()
    }
  }

  // MARK: - Configure
  func configure(_ block: () -> Void) {
    session.beginConfiguration()
    block()
    session.commitConfiguration()
  }

  // MARK: - Preset

  func configurePreset(_ input: AVCaptureDeviceInput) {
    for asset in preferredPresets() {
      if input.device.supportsSessionPreset(asset) && self.session.canSetSessionPreset(asset) {
        self.session.sessionPreset = asset
        return
      }
    }
  }

  func preferredPresets() -> [AVCaptureSession.Preset] {
    return [
      .photo,
      .high,
      .medium,
      .low
    ]
  }
}

extension UIImage {
    typealias RectCalculationClosure = (_ parentSize: CGSize, _ newImageSize: CGSize)->(CGRect)

    func with(image named: String, rectCalculation: RectCalculationClosure) -> UIImage {
        return with(image: UIImage(named: named), rectCalculation: rectCalculation)
    }

    func with(image: UIImage?, rectCalculation: RectCalculationClosure) -> UIImage {

        if let image = image {
            UIGraphicsBeginImageContext(size)

            draw(in: CGRect(origin: .zero, size: size))
            image.draw(in: rectCalculation(size, image.size))

            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage!
        }
        return self
    }

    func image(alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}
