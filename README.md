# IndoorLocation

IndoorLocation is an iOS App to perform indoor location tracking. The system consists of an iOS device running the IndoorLocation App, an Arduino TIAN running the Pozyx2iPhone sketch, a Pozyx tag mounted on the Arduino and at least one Pozyx anchor.

The app implements options for filtering the measurement data. The position can be determined by a linear least squares algorithm, an extended Kalman filter or a particle filter. The filters' parameters can be optimised manually.
