# IndoorLocation

IndoorLocation is an iOS application which is used to perform indoor location tracking. The system consists of an iOS-device running the IndoorLocation App, an Arduino TIAN running the Pozyx2iPhone sketch, a pozyx tag mounted on the Arduino and at least one pozyx anchor with a known position.

The app implements options for filtering the measured data, which is the distances to all anchors and the acceleration of the tag to be located. The position can be determined by a linear least squares algorithm, an Extended Kalman filter or a particle filter. The filters' parameters can be optimised manually.
