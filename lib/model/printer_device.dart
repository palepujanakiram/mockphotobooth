import 'package:printing/printing.dart';

class PrinterDevice {
  final String name;
  final String? url;
  final String? model;
  final Printer printer;
  final DateTime discoveredAt;
  int order;
  
  PrinterDevice({
    required this.name,
    this.url,
    this.model,
    required this.printer,
    DateTime? discoveredAt,
    this.order = 0,
  }) : discoveredAt = discoveredAt ?? DateTime.now();
  
  String get displayName => model ?? name;
  
  String get ipAddress {
    if (url == null) return 'Unknown';
    try {
      Uri uri = Uri.parse(url!);
      return uri.host;
    } catch (_) {
      return 'Unknown';
    }
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'model': model,
    'order': order,
    'discoveredAt': discoveredAt.toIso8601String(),
  };
  
  factory PrinterDevice.fromJson(Map<String, dynamic> json, Printer printer) => PrinterDevice(
    name: json['name'],
    url: json['url'],
    model: json['model'],
    printer: printer,
    order: json['order'] ?? 0,
    discoveredAt: DateTime.parse(json['discoveredAt']),
  );
}