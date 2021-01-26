import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
  var locationManager = CLLocationManager()
  var latestLocation: CLLocation?
    var controller: CameraController?
    
    init(_ cameraController: CameraController? ) {
    super.init()
        self.controller = cameraController
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10
    locationManager.requestWhenInUseAuthorization()
  }

  func start() {
    locationManager.startUpdatingLocation()
  }

  func stop() {
    locationManager.stopUpdatingLocation()
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Pick the location with best (= smallest value) horizontal accuracy
    latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
    if let location = latestLocation {
        self.controller?.didUpdateLocation(location)
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      locationManager.startUpdatingLocation()
    } else {
      locationManager.stopUpdatingLocation()
    }
  }
}
