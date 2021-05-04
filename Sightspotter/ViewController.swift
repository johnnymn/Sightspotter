import ARKit
import CoreLocation
import UIKit
import SpriteKit
import SwiftyJSON

class ViewController: UIViewController,
        ARSKViewDelegate, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()
  var userLocation = CLLocation()

  var userHeading = 0.0
  // Keep track of how many heading
  // updates we receive from the locationManager.
  var headingCount = 0

  // Store the JSON object we get
  // from the Wikipedia's API.
  var sightsJSON: JSON!

  @IBOutlet var sceneView: ARSKView!

  override func viewDidLoad() {
    super.viewDidLoad()

    // Set the view's delegate
    sceneView.delegate = self

    // Show statistics such as fps and node count
    sceneView.showsFPS = true
    sceneView.showsNodeCount = true

    // Load the SKScene from 'Scene.sks'
    if let scene = SKScene(fileNamed: "Scene") {
      sceneView.presentScene(scene)
    }

    locationManager.delegate = self
    // We need the best possible
    // accuracy for the user location.
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Create a session configuration
    let configuration = AROrientationTrackingConfiguration()

    // Run the view's session
    sceneView.session.run(configuration)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Pause the view's session
    sceneView.session.pause()
  }

  func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
    nil
  }

  /// Request location if authorized.
  func locationManager(
          _ manager: CLLocationManager,
          didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedWhenInUse {
      locationManager.requestLocation()
    }
  }

  /// Handle errors while getting location.
  func locationManager(
          _ manager: CLLocationManager,
          didFailWithError error: Error) {
    print(error.localizedDescription)
  }

  // Update user location variable and
  // trigger the fetchSights routine.
  func locationManager(
          _ manager: CLLocationManager,
          didUpdateLocations locations: [CLLocation]) {
    // Get the last location of the user.
    guard let location = locations.last else {
      return
    }

    userLocation = location

    // Fetch the sights on a background thread.
    DispatchQueue.global().async {
      self.fetchSights()
    }
  }

  // This method gets called when the user's
  // heading is updated by the location manager.
  func locationManager(
          _ manager: CLLocationManager,
          didUpdateHeading newHeading: CLHeading) {

    // Do all this work on the main thread.
    DispatchQueue.main.async {
      self.headingCount += 1

      // We want to only take the second reading
      // of the heading reported by the location
      // manager so that we get better accuracy.
      guard self.headingCount == 2 else {
        return
      }

      // Update the user heading.
      self.userHeading = newHeading.magneticHeading

      // Prevent the locationManager from
      // sending us more heading updates.
      self.locationManager.stopUpdatingHeading()

      self.createSights()
    }
  }

  /// Fetch the sights from the Wikipedia API,
  /// store them as a JSON string, and start
  /// observing the user's heading.
  func fetchSights() {
    let urlString = """
                    https://en.wikipedia.org/w/api.php?
                    ggscoord=\(userLocation.coordinate.latitude)
                    %7C\(userLocation.coordinate.longitude)
                    &action=query&prop=coordinates%7Cpageimages
                    %7Cpageterms&colimit=50&piprop=thumbnail&pithumbsize=500
                    &pilimit=50&wbptterms=description&generator=geosearch
                    &ggsradius=10000&ggslimit=50&format=json
                    """
    guard let url = URL(string: urlString) else {
      return
    }

    // Data(contentsOf: URL) throws
    // so we wrap it with a try?
    if let data = try? Data(contentsOf: url) {
      sightsJSON = JSON(data)
      locationManager.startUpdatingHeading()
    }
  }

  func createSights() {

  }
}
