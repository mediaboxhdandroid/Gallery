import UIKit
import AVFoundation
import CoreLocation
import MapKit

protocol CameraViewDelegate: class {
  func cameraView(_ cameraView: CameraView, didTouch point: CGPoint)
}

class CameraView: UIView, UIGestureRecognizerDelegate {

  lazy var closeButton: UIButton = self.makeCloseButton()
  lazy var flashButton: TripleButton = self.makeFlashButton()
  lazy var rotateButton: UIButton = self.makeRotateButton()
  fileprivate lazy var bottomContainer: UIView = self.makeBottomContainer()
  lazy var bottomView: UIView = self.makeBottomView()
  lazy var stackView: StackView = self.makeStackView()
  lazy var shutterButton: ShutterButton = self.makeShutterButton()
  lazy var doneButton: UIButton = self.makeDoneButton()
  lazy var focusImageView: UIImageView = self.makeFocusImageView()
  lazy var tapGR: UITapGestureRecognizer = self.makeTapGR()
  lazy var rotateOverlayView: UIView = self.makeRotateOverlayView()
  lazy var shutterOverlayView: UIView = self.makeShutterOverlayView()
  lazy var blurView: UIVisualEffectView = self.makeBlurView()
      
    var infoSwitch: UISwitch = UISwitch()
    var imgOverlay: UIImageView = UIImageView()
    var infOverlay: UIView = UIView()
    var labelOverlay: UILabel = UILabel()
    var pinImage = MKPinAnnotationView(annotation: nil, reuseIdentifier: nil).image ?? UIImage()
    var preGeocoder : CLGeocoder?
    var preMapSnapshotter : MKMapSnapshotter?
    
  var timer: Timer?
  var previewLayer: AVCaptureVideoPreviewLayer?
  weak var delegate: CameraViewDelegate?

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)

    backgroundColor = UIColor.black
    setup()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

    @objc func showInfo(_ sender: UISwitch? = nil) {
        infOverlay.isHidden = !(infoSwitch.isOn)
        if sender != nil {
            UserDefaults.standard.set(infoSwitch.isOn ? "on" : "off" , forKey: "enableDateTime")
            if (infOverlay.isHidden == false) {
                let controller = self.delegate as! CameraController
                self.updateLocation(controller.locationManager?.latestLocation)
            }
        }
    }
    
  func setup() {
    addGestureRecognizer(tapGR)

    [closeButton, flashButton, rotateButton, bottomContainer].forEach {
      addSubview($0)
    }

    [bottomView, shutterButton].forEach {
      bottomContainer.addSubview($0)
    }

    [stackView, doneButton].forEach {
      bottomView.addSubview($0)
    }

    [closeButton, flashButton, rotateButton].forEach {
      $0.g_addShadow()
    }

    rotateOverlayView.addSubview(blurView)
    insertSubview(rotateOverlayView, belowSubview: rotateButton)
    insertSubview(focusImageView, belowSubview: bottomContainer)
    insertSubview(shutterOverlayView, belowSubview: bottomContainer)

    closeButton.g_pin(on: .left)
    closeButton.g_pin(size: CGSize(width: 44, height: 44))

    flashButton.g_pin(on: .centerY, view: closeButton)
    flashButton.g_pin(on: .centerX)
    flashButton.g_pin(size: CGSize(width: 60, height: 44))

    rotateButton.g_pin(on: .right)
    rotateButton.g_pin(size: CGSize(width: 44, height: 44))

    if #available(iOS 11, *) {
      Constraint.on(
        closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
        rotateButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
      )
    } else {
      Constraint.on(
        closeButton.topAnchor.constraint(equalTo: topAnchor),
        rotateButton.topAnchor.constraint(equalTo: topAnchor)
      )
    }

    bottomContainer.g_pinDownward()
    bottomContainer.g_pin(height: 80)
    bottomView.g_pinEdges()

    stackView.g_pin(on: .centerY, constant: -4)
    stackView.g_pin(on: .left, constant: 38)
    stackView.g_pin(size: CGSize(width: 56, height: 56))

    shutterButton.g_pinCenter()
    shutterButton.g_pin(size: CGSize(width: 60, height: 60))
    
    doneButton.g_pin(on: .centerY)
    doneButton.g_pin(on: .right, constant: -38)

    rotateOverlayView.g_pinEdges()
    blurView.g_pinEdges()
    shutterOverlayView.g_pinEdges()
    
    if let enableDateTime = UserDefaults.standard.string(forKey: "enableDateTime"), enableDateTime.count > 0 {
        insertSubview(infOverlay, at: 0)
        infOverlay.frame = self.frame
        infOverlay.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        infOverlay.backgroundColor = .clear
        
        infOverlay.addSubview(imgOverlay)
        imgOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imgOverlay.topAnchor.constraint(equalTo: infOverlay.topAnchor),
            imgOverlay.trailingAnchor.constraint(equalTo: infOverlay.trailingAnchor),
            imgOverlay.widthAnchor.constraint(equalTo: infOverlay.widthAnchor, multiplier: 1/3),
            imgOverlay.heightAnchor.constraint(equalTo: infOverlay.widthAnchor, multiplier: 1/3),
        ])
        imgOverlay.alpha = 0.65
        
        infOverlay.addSubview(labelOverlay)
        labelOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelOverlay.topAnchor.constraint(equalTo: infOverlay.topAnchor),
            labelOverlay.leadingAnchor.constraint(equalTo: infOverlay.leadingAnchor),
            labelOverlay.widthAnchor.constraint(equalTo: infOverlay.widthAnchor, multiplier: 0.7),
        ])
        labelOverlay.numberOfLines = 0
        labelOverlay.textAlignment = .left
        
        self.addSubview(self.infoSwitch)
        infoSwitch.isOn = enableDateTime == "on"
        infoSwitch.g_pin(size: CGSize(width: 51, height: 31))
        infoSwitch.addTarget(self, action: #selector(self.showInfo(_:)), for: UIControl.Event.valueChanged)
        if #available(iOS 11.0, *) {
            Constraint.on(
                infoSwitch.topAnchor.constraint(equalTo: rotateButton.bottomAnchor, constant: 10),
                infoSwitch.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor, constant: -10)
            )
        } else {
            Constraint.on(
                infoSwitch.topAnchor.constraint(equalTo: rotateButton.bottomAnchor, constant: 10),
                infoSwitch.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -10)
            )
        }

        self.showInfo()
    }

  }

    func updateLocation(_ location : CLLocation?) {
        if let enableDateTime = UserDefaults.standard.string(forKey: "enableDateTime"), enableDateTime == "on" {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = DateFormatter.Style.short //Set time style
            dateFormatter.dateStyle = DateFormatter.Style.short //Set date style
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.locale = Locale(identifier: "vi")
            let text = dateFormatter.string(from: date)
            print("updateLocation \(location)")
            if let location = location {
                //get address
                if preGeocoder == nil {
                    preGeocoder = CLGeocoder()
                }
                preGeocoder?.cancelGeocode()
                preGeocoder?.reverseGeocodeLocation(location) { [weak self] (clPlacemark: [CLPlacemark]?, error: Error?) in
                    guard let `self` = self else { return }
                    if error != nil {
                        print("reverseGeocodeLocation \(error)")
                        return
                    }
                    if let place = clPlacemark?.first {
                        print("reverseGeocodeLocation completionHandler")
                        let name = place.name ?? ""
                        self.labelOverlay.attributedText = NSAttributedString(string: "\(text)\n\(name)", attributes: Utils.textFontAttributes(self.infOverlay.frame.width))
                    } else {
                        print("reverseGeocodeLocation empty")
                        self.labelOverlay.attributedText = NSAttributedString(string: text, attributes: Utils.textFontAttributes(self.infOverlay.frame.width))
                    }
                }

                //get map image
                preMapSnapshotter?.cancel()
                let distanceInMeters: Double = 250
                let options = MKMapSnapshotter.Options()
                options.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: distanceInMeters, longitudinalMeters: distanceInMeters)
                options.mapType = .standard
                options.size = CGSize.init(width: 640, height: 640)
                let bgQueue = DispatchQueue.global(qos: .background)
                preMapSnapshotter = MKMapSnapshotter(options: options)
                preMapSnapshotter?.start(with: bgQueue, completionHandler: { [weak self] (snapshot, error) in
                    guard let `self` = self else { return }
                    self.preMapSnapshotter = nil
                    guard error == nil else {
                        return
                    }
                    print("MKMapSnapshotter completionHandler")
                    if let snapShotImage = snapshot?.image, let coordinatePoint = snapshot?.point(for: location.coordinate) {
                        UIGraphicsBeginImageContextWithOptions(snapShotImage.size, true, snapShotImage.scale)
                        snapShotImage.draw(at: CGPoint.zero)
                        let fixedPinPoint = CGPoint(x: coordinatePoint.x - self.pinImage.size.width / 2, y: coordinatePoint.y - self.pinImage.size.height)
                        self.pinImage.draw(at: fixedPinPoint)
                        let mapImage = UIGraphicsGetImageFromCurrentImageContext()
                        DispatchQueue.main.async {
                            self.imgOverlay.image = mapImage
                        }
                        UIGraphicsEndImageContext()
                    }
                })
            } else {
                labelOverlay.attributedText = NSAttributedString(string: text, attributes: Utils.textFontAttributes(infOverlay.frame.width))
            }
        }
    }
    
  func setupPreviewLayer(_ session: AVCaptureSession) {
    guard previewLayer == nil else { return }

    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.autoreverses = true
    layer.videoGravity = .resizeAspectFill
    layer.connection?.videoOrientation = Utils.videoOrientation()
    
    self.layer.insertSublayer(layer, at: 0)
    layer.frame = self.layer.bounds
    if let enableDateTime = UserDefaults.standard.string(forKey: "enableDateTime"), enableDateTime == "on" {
        let controller = self.delegate as! CameraController
        self.updateLocation(controller.locationManager?.latestLocation)
    }
    previewLayer = layer
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    previewLayer?.frame = self.layer.bounds
  }

  // MARK: - Action

  @objc func viewTapped(_ gr: UITapGestureRecognizer) {
    let point = gr.location(in: self)

    focusImageView.transform = CGAffineTransform.identity
    timer?.invalidate()
    delegate?.cameraView(self, didTouch: point)

    focusImageView.center = point

    UIView.animate(withDuration: 0.5, animations: {
      self.focusImageView.alpha = 1
      self.focusImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    }, completion: { _ in
      self.timer = Timer.scheduledTimer(timeInterval: 1, target: self,
        selector: #selector(CameraView.timerFired(_:)), userInfo: nil, repeats: false)
    })
  }

  // MARK: - Timer

  @objc func timerFired(_ timer: Timer) {
    UIView.animate(withDuration: 0.3, animations: {
      self.focusImageView.alpha = 0
    }, completion: { _ in
      self.focusImageView.transform = CGAffineTransform.identity
    })
  }

  // MARK: - UIGestureRecognizerDelegate
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    let point = gestureRecognizer.location(in: self)

    return point.y > closeButton.frame.maxY
      && point.y < bottomContainer.frame.origin.y
  }

  // MARK: - Controls

  func makeCloseButton() -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(GalleryBundle.image("gallery_close"), for: UIControl.State())

    return button
  }

  func makeFlashButton() -> TripleButton {
    let states: [TripleButton.ButtonState] = [
      TripleButton.ButtonState(title: "Gallery.Camera.Flash.Off".g_localize(fallback: "OFF"), image: GalleryBundle.image("gallery_camera_flash_off")!),
      TripleButton.ButtonState(title: "Gallery.Camera.Flash.On".g_localize(fallback: "ON"), image: GalleryBundle.image("gallery_camera_flash_on")!),
      TripleButton.ButtonState(title: "Gallery.Camera.Flash.Auto".g_localize(fallback: "AUTO"), image: GalleryBundle.image("gallery_camera_flash_auto")!)
    ]

    let button = TripleButton(states: states)

    return button
  }

  func makeRotateButton() -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(GalleryBundle.image("gallery_camera_rotate"), for: UIControl.State())

    return button
  }

  func makeBottomContainer() -> UIView {
    let view = UIView()

    return view
  }

  func makeBottomView() -> UIView {
    let view = UIView()
    view.backgroundColor = Config.Camera.BottomContainer.backgroundColor
    view.alpha = 0

    return view
  }

  func makeStackView() -> StackView {
    let view = StackView()

    return view
  }

  func makeShutterButton() -> ShutterButton {
    let button = ShutterButton()
    button.g_addShadow()

    return button
  }

  func makeDoneButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setTitleColor(UIColor.white, for: UIControl.State())
    button.setTitleColor(UIColor.lightGray, for: .disabled)
    button.titleLabel?.font = Config.Font.Text.regular.withSize(16)
    button.setTitle("Gallery.Done".g_localize(fallback: "Done"), for: UIControl.State())

    return button
  }

  func makeFocusImageView() -> UIImageView {
    let view = UIImageView()
    view.frame.size = CGSize(width: 110, height: 110)
    view.image = GalleryBundle.image("gallery_camera_focus")
    view.backgroundColor = .clear
    view.alpha = 0

    return view
  }

  func makeTapGR() -> UITapGestureRecognizer {
    let gr = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
    gr.delegate = self

    return gr
  }

  func makeRotateOverlayView() -> UIView {
    let view = UIView()
    view.alpha = 0

    return view
  }

  func makeShutterOverlayView() -> UIView {
    let view = UIView()
    view.alpha = 0
    view.backgroundColor = UIColor.black

    return view
  }

  func makeBlurView() -> UIVisualEffectView {
    let effect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: effect)

    return blurView
  }

}
