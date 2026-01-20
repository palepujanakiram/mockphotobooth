class CameraDevice {
  final String ip;
  final String name;
  final String? manufacturer;
  final String? model;
  String username;
  String password;
  final DateTime discoveredAt;
  
  CameraDevice({
    required this.ip,
    required this.name,
    this.manufacturer,
    this.model,
    this.username = 'admin',
    this.password = '',
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();
  
  String get displayName => model ?? manufacturer ?? 'Camera at $ip';
  
  // TP-Link Tapo C520WS RTSP URLs
  String get rtspUrl => Uri(
        scheme: 'rtsp',
        userInfo: '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}',
        host: ip,
        port: 554,
        path: '/stream1',
      ).toString();
  
  // Alternative lower quality stream
  String get rtspUrlLowQuality => Uri(
        scheme: 'rtsp',
        userInfo: '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}',
        host: ip,
        port: 554,
        path: '/stream2',
      ).toString();
  
  // ONVIF Snapshot URL for TP-Link Tapo cameras
  String get snapshotUrl => 'http://$ip/onvif/snapshot';
  
  Map<String, dynamic> toJson() => {
    'ip': ip,
    'name': name,
    'manufacturer': manufacturer,
    'model': model,
    'username': username,
    'password': password,
    'discoveredAt': discoveredAt.toIso8601String(),
  };
  
  factory CameraDevice.fromJson(Map<String, dynamic> json) => CameraDevice(
    ip: json['ip'],
    name: json['name'],
    manufacturer: json['manufacturer'],
    model: json['model'],
    username: json['username'] ?? 'admin',
    password: json['password'] ?? '',
    discoveredAt: DateTime.parse(json['discoveredAt']),
  );
  
  CameraDevice copyWith({
    String? ip,
    String? name,
    String? manufacturer,
    String? model,
    String? username,
    String? password,
  }) {
    return CameraDevice(
      ip: ip ?? this.ip,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      username: username ?? this.username,
      password: password ?? this.password,
      discoveredAt: discoveredAt,
    );
  }
}