import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../model/camera_device.dart';
import '../model/printer_device.dart';
import '../services/device_scanner_service.dart';
import '../services/storage_service.dart';
import 'photo_preview_screen.dart';
import 'settings_screen.dart';
import '../widgets/rtsp_player.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.example.mockphotobooth/snapshot');
  
  final DeviceScannerService _scanner = DeviceScannerService();
  final StorageService _storage = StorageService();
  
  CameraDevice? _camera;
  List<PrinterDevice> _printers = [];
  
  bool _isCameraReady = false;
  bool _isScanning = true;
  bool _isCapturing = false;
  
  String _statusMessage = 'Initializing...';
  
  @override
  void initState() {
    super.initState();
    _initializeDevices();
  }
  
  Future<void> _initializeDevices() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for devices...';
    });
    
    // Load saved camera
    _camera = await _storage.getSelectedCamera();
    
    if (_camera != null) {
      // Camera already configured
      print('✅ Loaded saved camera: ${_camera!.ip}');
      await _scanPrinters();
      // Stop scanning before connecting, so the UI can render the VlcPlayer widget
      setState(() => _isScanning = false);
      await _connectCamera();
    } else {
      // First time - scan for cameras
      await _scanCameras();
      await _scanPrinters();
      setState(() => _isScanning = false);
    }
  }
  
  Future<void> _scanCameras() async {
    setState(() => _statusMessage = 'Scanning for TP-Link Tapo C520WS...');
    
    List<CameraDevice> cameras = [];
    
    await for (var camera in _scanner.scanForCameras()) {
      cameras.add(camera);
      
      // Found first camera - ask for credentials
      if (_camera == null) {
        setState(() => _camera = camera);
        _showCredentialsDialog(camera);
        break;
      }
    }
    
    // Save discovered cameras
    if (cameras.isNotEmpty) {
      await _storage.saveCameras(cameras);
    }
  }
  
  Future<void> _scanPrinters() async {
    setState(() => _statusMessage = 'Scanning for printers...');
    
    List<PrinterDevice> printers = await _scanner.scanForPrinters();
    
    // Apply saved order
    printers = await _storage.loadAndReorderPrinters(printers);
    
    setState(() {
      _printers = printers;
      if (printers.isEmpty) {
        _statusMessage = 'No printer found';
      }
    });
  }
  
  void _showCredentialsDialog(CameraDevice camera) {
    final userController = TextEditingController(text: camera.username);
    final passController = TextEditingController(text: camera.password);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Tapo C520WS Credentials'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera Found!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('Model: ${camera.model ?? "Tapo C520WS"}'),
              Text('IP: ${camera.ip}'),
              SizedBox(height: 20),
              Text(
                'Enter RTSP Credentials:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 10),
              TextField(
                controller: userController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'admin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter RTSP password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 10),
              Text(
                'Tip: Set this in Tapo app → Settings → Camera Account → RTSP',
                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _camera = null);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storage.updateCameraCredentials(
                camera.ip,
                userController.text,
                passController.text,
              );
              
              setState(() {
                _camera = camera.copyWith(
                  username: userController.text,
                  password: passController.text,
                );
              });
              
              Navigator.pop(context);
              await _connectCamera();
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _connectCamera() async {
    if (_camera == null) return;
    
    print('🔌 _connectCamera called. _camera: ${_camera?.ip}');
    print('📺 Native RTSP player will handle connection automatically');
    
    setState(() {
      _isCameraReady = true;
      _statusMessage = 'Ready - 2K Quality';
    });
    
    print('✅ Camera ready!');
  }

  
  Future<void> _capturePhoto() async{
    if (_camera == null || _isCapturing) return;
    
    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing 2K photo...';
    });
    
    try {
      print('📸 Requesting snapshot from LibVLC...');
      
      // Call native method to capture snapshot from RTSP stream
      final String? snapshotPath = await platform.invokeMethod('captureSnapshot');
      
      if (snapshotPath == null) {
        throw Exception('Snapshot path is null');
      }
      
      print('✅ Snapshot captured at: $snapshotPath');
      
      // Read the snapshot file
      final File snapshotFile = File(snapshotPath);
      if (!await snapshotFile.exists()) {
        throw Exception('Snapshot file not found');
      }
      
      final Uint8List photoBytes = await snapshotFile.readAsBytes();
      print('✅ Snapshot loaded! Size: ${photoBytes.length} bytes');
      
      // Show confirmation that photo was saved
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📸 Photo saved to gallery!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to preview screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              photoBytes: photoBytes,
              printers: _printers,
            ),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Capture error: $e');
      _showError('Failed to capture photo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _statusMessage = 'Ready - 2K Quality';
        });
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.photo_camera, size: 24),
            SizedBox(width: 8),
            Text('Photo Booth'),
            if (_camera != null) ...[
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '2K',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
              // Reload devices after settings
              _initializeDevices();
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    print('📱 _buildBody: _isScanning=$_isScanning, _camera=${_camera?.ip}, _isCameraReady=$_isCameraReady');
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Looking for TP-Link Tapo C520WS...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    if (_camera == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No camera found',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              'Make sure Tapo C520WS is powered on\nand connected to WiFi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _initializeDevices,
              icon: Icon(Icons.refresh),
              label: Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    if (!_isCameraReady) {
      print('📺 Camera not ready yet, showing loading...');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Connecting to camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              _camera!.ip,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        // Live video preview using native RTSP player (fills screen)
        SizedBox.expand(
          child: RtspPlayer(
            url: _camera!.rtspUrl,
          ),
        ),
        
        // Status bar
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.7 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 15),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '2K QHD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '2560×1440',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Spacer(),
                if (_printers.isNotEmpty) ...[
                  Icon(Icons.print, color: Colors.green, size: 16),
                  SizedBox(width: 5),
                  Text(
                    'Printer Ready',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Camera info
        Positioned(
          bottom: 120,
          left: 10,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.7 * 255).round()),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TP-Link Tapo C520WS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _camera!.ip,
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        
        // Capture button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isCapturing ? null : _capturePhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing ? Colors.grey : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.3 * 255).round()),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isCapturing
                    ? Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(Icons.camera_alt, size: 40, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }
}