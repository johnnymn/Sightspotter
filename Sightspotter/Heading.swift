import CoreLocation

/// Calculates the direction (expressed as an angle)
/// from one point to another.
///
/// - Parameters:
///   - pointA: The starting location.
///   - pointB: The target location.
/// - Returns: The angle between the 2 points in degrees.
func direction(from pointA: CLLocation, to pointB: CLLocation) -> Double {
  let latA = deg2rad(pointA.coordinate.latitude)
  let longA = deg2rad(pointA.coordinate.longitude)
  let latB = deg2rad(pointB.coordinate.latitude)
  let lonB = deg2rad(pointB.coordinate.longitude)

  let lonDelta = lonB - longA
  let pointY = sin(lonDelta) * cos(lonB)
  let pointX = cos(latA) * sin(latB) - sin(latA) * cos(latB) * cos(lonDelta)

  return rad2deg(atan2(pointY, pointX))
}
