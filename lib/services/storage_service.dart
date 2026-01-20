import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/camera_device.dart';
import '../model/printer_device.dart';
import '../model/print_config.dart';

class StorageService {
  static const String CAMERAS_KEY = 'discovered_cameras';
  static const String PRINTERS_KEY = 'discovered_printers';
  static const String SELECTED_CAMERA_KEY = 'selected_camera_ip';
  static const String PRINT_CONFIG_KEY = 'print_configuration';
  
  // ============ CAMERAS ============
  
  Future<void> saveCameras(List<CameraDevice> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> camerasJson = cameras.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(CAMERAS_KEY, camerasJson);
    print('💾 Saved ${cameras.length} cameras');
  }
  
  Future<List<CameraDevice>> loadCameras() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? camerasJson = prefs.getStringList(CAMERAS_KEY);
    
    if (camerasJson == null || camerasJson.isEmpty) {
      return [];
    }
    
    return camerasJson.map((json) {
      return CameraDevice.fromJson(jsonDecode(json));
    }).toList();
  }
  
  Future<void> updateCameraCredentials(String ip, String username, String password) async {
    List<CameraDevice> cameras = await loadCameras();
    
    int index = cameras.indexWhere((c) => c.ip == ip);
    if (index != -1) {
      cameras[index] = cameras[index].copyWith(
        username: username,
        password: password,
      );
      await saveCameras(cameras);
      print('💾 Updated credentials for camera at $ip');
    }
  }
  
  Future<CameraDevice?> getSelectedCamera() async {
    List<CameraDevice> cameras = await loadCameras();
    if (cameras.isEmpty) return null;
    
    final prefs = await SharedPreferences.getInstance();
    String? selectedIP = prefs.getString(SELECTED_CAMERA_KEY);
    
    if (selectedIP != null) {
      try {
        return cameras.firstWhere((c) => c.ip == selectedIP);
      } catch (_) {}
    }
    
    return cameras.first;
  }
  
  Future<void> setSelectedCamera(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SELECTED_CAMERA_KEY, ip);
  }
  
  // ============ PRINTERS ============
  
  Future<void> savePrinterOrder(List<PrinterDevice> printers) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> printersJson = printers.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(PRINTERS_KEY, printersJson);
    print('💾 Saved ${printers.length} printers');
  }
  
  Future<List<PrinterDevice>> loadAndReorderPrinters(List<PrinterDevice> discoveredPrinters) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedJson = prefs.getStringList(PRINTERS_KEY);
    
    if (savedJson == null || savedJson.isEmpty) {
      return discoveredPrinters;
    }
    
    Map<String, int> savedOrder = {};
    for (String json in savedJson) {
      var data = jsonDecode(json);
      savedOrder[data['name']] = data['order'];
    }
    
    for (var printer in discoveredPrinters) {
      if (savedOrder.containsKey(printer.name)) {
        printer.order = savedOrder[printer.name]!;
      }
    }
    
    discoveredPrinters.sort((a, b) => a.order.compareTo(b.order));
    
    return discoveredPrinters;
  }
  
  Future<PrinterDevice?> getFirstPrinter(List<PrinterDevice> printers) async {
    if (printers.isEmpty) return null;
    return printers.first;
  }
  
  // ============ PRINT CONFIG ============
  
  Future<void> savePrintConfig(PrintConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PRINT_CONFIG_KEY, jsonEncode(config.toJson()));
    print('💾 Saved print configuration');
  }
  
  Future<PrintConfig> loadPrintConfig() async {
    final prefs = await SharedPreferences.getInstance();
    String? configJson = prefs.getString(PRINT_CONFIG_KEY);
    
    if (configJson == null) {
      return PrintConfig(); // Default config
    }
    
    return PrintConfig.fromJson(jsonDecode(configJson));
  }
}