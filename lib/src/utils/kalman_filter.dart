
class KalmanFilter {
  final double _q; // Process noise
  final double _r; // Measurement noise
  double _x = 0; // Estimated value
  double _p = 1; // Estimation error covariance
  double _k = 0; // Kalman gain

  KalmanFilter({double q = 0.001, double r = 0.01}) : _q = q, _r = r;

  // 🟢 Fixed: Renamed from 'process' to 'filter' to match your Notifier
  double filter(double measurement) {
    _p = _p + _q;
    _k = _p / (_p + _r);
    _x = _x + _k * (measurement - _x);
    _p = (1 - _k) * _p;
    return _x;
  }

  // 🟢 Fixed: Standardized method name
  void reset(double value) {
    _x = value;
    _p = 1.0;
  }
}
