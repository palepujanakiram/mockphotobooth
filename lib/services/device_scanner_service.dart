import 'dart:io';
import 'dart:async';
import 'package:printing/printing.dart';
import '../model/camera_device.dart';
import '../model/printer_device.dart';

class DeviceScannerService {
  
  // ============ CAMERA SCANNING ============
  
  /// Scan network for TP-Link Tapo C520WS camera
  Stream<CameraDevice> scanForCameras() async* {
    print('🔍 Starting camera scan for TP-Link Tapo C520WS...');
    
    String? networkPrefix = await _getNetworkPrefix();
    if (networkPrefix == null) {
      print('❌ Cannot determine network');
      return;
    }
    
    print('📡 Scanning network: $networkPrefix.x on port 554 (RTSP)');
    
    // Scan all IPs from 1 to 254 in batches
    const int BATCH_SIZE = 20;
    
    for (int start = 1; start < 255; start += BATCH_SIZE) {
      List<Future<CameraDevice?>> batch = [];
      
      for (int i = start; i < start + BATCH_SIZE && i < 255; i++) {
        if (i == 1) continue; // Skip router IP
        
        String ip = '$networkPrefix.$i';
        batch.add(_checkForCamera(ip));
      }
      
      List<CameraDevice?> results = await Future.wait(batch);
      
      for (var camera in results) {
        if (camera != null) {
          print('✅ Camera found: ${camera.ip}');
          yield camera;
        }
      }
    }
    
    print('✓ Camera scan complete');
  }
  
  /// Check if IP has RTSP camera (port 554)
  Future<CameraDevice?> _checkForCamera(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        554, // RTSP port for TP-Link Tapo
        timeout: Duration(milliseconds: 200),
      );
      socket.destroy();
      
      // Found camera on port 554
      return CameraDevice(
        ip: ip,
        name: 'Tapo Camera at $ip',
        manufacturer: 'TP-Link',
        model: 'Tapo C520WS',
      );
      
    } catch (_) {
      return null;
    }
  }
  
  // ============ PRINTER SCANNING ============
  
  /// Scan network for printers
  Future<List<PrinterDevice>> scanForPrinters() async {
    print('🔍 Starting printer scan...');
    
    List<PrinterDevice> devices = [];
    
    try {
      // NOTE:
      // `Printing.listPrinters()` is only implemented on desktop platforms
      // (macOS/Windows/Linux). On Android/iOS it returns "not implemented",
      // which surfaces as a MissingPluginException on the Dart side.
      //
      // On mobile, we use `Printing.layoutPdf()` at print time to let the OS
      // show the system print UI (and choose a printer).
      if (Platform.isAndroid || Platform.isIOS) {
        print('ℹ️ Printer listing not supported on mobile; will use system print dialog.');
        return [];
      }

      // Desktop printer discovery
      List<Printer> printers = await Printing.listPrinters();
      
      int order = 0;
      for (var printer in printers) {
        devices.add(PrinterDevice(
          name: printer.name,
          url: printer.url,
          model: printer.model,
          printer: printer,
          order: order++,
        ));
        
        print('✅ Printer found: ${printer.name}');
      }
      
    } catch (e) {
      print('❌ Printer scan error: $e');
    }
    
    print('✓ Printer scan complete (${devices.length} found)');
    return devices;
  }
  
  // ============ NETWORK UTILITIES ============
  
  Future<String?> _getNetworkPrefix() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            String ip = addr.address;
            return ip.substring(0, ip.lastIndexOf('.'));
          }
        }
      }
    } catch (e) {
      print('Network error: $e');
    }
    return null;
  }
}