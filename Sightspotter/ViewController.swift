import ARKit
import CoreLocation
import UIKit
import SpriteKit
import SwiftyJSON

class ViewController: UIViewController,
        ARSKViewDelegate, CLLocationManagerDelegate {
  @IBOutlet var sceneView: ARSKView!

  let locationManager = CLLocationManager()
  var userLocation = CLLocation()

  var userHeading = 0.0
  // Keep track of how many heading
  // updates we receive from the locationManager.
  var headingCount = 0

  // Store the JSON object we get
  // from the Wikipedia's API.
  var sightsJSON: JSON!

  // Link the anchors to the corresponding
  // Wikipedia page title. Use the UUID of
  // the anchor as key and the page title
  // as value.
  var pages = [UUID: String]()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Set the view's delegate
    sceneView.delegate = self

    // Load the SKScene from 'Scene.sks'
    if let scene = SKScene(fileNamed: "Scene") {
      sceneView.presentScene(scene)
    }

    locationManager.delegate = self
    // We need the best possible
    // accuracy for the user location.
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.requestWhenInUseAuthorization()
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
    // Title label.
    let labelNode = SKLabelNode(text: pages[anchor.identifier])
    labelNode.horizontalAlignmentMode = .center
    labelNode.verticalAlignmentMode = .center
    labelNode.fontSize = 70

    // Scale the label.
    let size = labelNode.frame.size.applying(
            CGAffineTransform(scaleX: 1.1, y: 1.4))

    // Create a background node
    // and round the corners.
    let backgroundNode = SKShapeNode(rectOf: size, cornerRadius: 10)
    // Fill it with a random color.
    backgroundNode.fillColor = UIColor(
            hue: CGFloat.random(in: 0...1),
            saturation: 0.5,
            brightness: 0.4,
            alpha: 0.9)

    // Draw a border around the
    // background node.
    backgroundNode.strokeColor = backgroundNode.fillColor.withAlphaComponent(1)
    backgroundNode.lineWidth = 2

    // Add the label to the background.
    backgroundNode.addChild(labelNode)

    return backgroundNode
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
                    https://en.wikipedia.org/w/api.php?\
                    ggscoord=\(userLocation.coordinate.latitude)\
                    %7C\(userLocation.coordinate.longitude)\
                    &action=query&prop=coordinates%7Cpageimages\
                    %7Cpageterms&colimit=50&piprop=thumbnail&pithumbsize=500\
                    &pilimit=50&wbptterms=description&generator=geosearch\
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

  /// Creates the anchors for each of the
  /// sightings we get from the Wikipedia API.
  func createSights() {
    // Loop over the Wikipedia pages.
    for page in sightsJSON["query"]["pages"].dictionaryValue.values {
      // Make a location from the
      // coordinates in the page.
      let latitude = page["coordinates"][0]["lat"].doubleValue
      let longitude = page["coordinates"][0]["lon"].doubleValue
      let location = CLLocation(latitude: latitude, longitude: longitude)

      // Calculate the distance from
      // the user to the location.
      let distance = Float(userLocation.distance(from: location))
      // Calculate the azimuth (direction).
      let azimuth = direction(from: userLocation, to: location)
      // Calculate the angle from the
      // user's location to that direction.
      let angle = deg2rad(azimuth - userHeading)

      // Create the rotation matrices.
      let rotationHorizontal = simd_float4x4(SCNMatrix4MakeRotation(
              Float(angle), 1, 0, 0))
      let rotationVertical = simd_float4x4(SCNMatrix4MakeRotation(
              -0.2 + Float(distance / 6000), 0, 1, 0))
      // Combine the horizontal and vertical
      // matrices to get the rotation.
      let rotation = simd_mul(rotationHorizontal, rotationVertical)

      guard let frame = sceneView.session.currentFrame else {
        return
      }

      // Combine the rotation with
      // the camera transform.
      let cameraRotation = simd_mul(frame.camera.transform, rotation)

      // Create a matrix to position
      // the anchor into the screen.
      var translation = matrix_identity_float4x4
      translation.columns.3.z = -(distance / 200)
      let transform = simd_mul(cameraRotation, translation)

      // Create a new anchor and add
      // it to the pages dictionary.
      let anchor = ARAnchor(transform: transform)
      sceneView.session.add(anchor: anchor)
      pages[anchor.identifier] = page["title"].string ?? "Unknown"
    }
  }
}
