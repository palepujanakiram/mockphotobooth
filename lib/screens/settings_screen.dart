import 'package:flutter/material.dart';
import '../model/camera_device.dart';
import '../model/printer_device.dart';
import '../model/print_config.dart';
import '../services/device_scanner_service.dart';
import '../services/storage_service.dart';
import 'print_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DeviceScannerService _scanner = DeviceScannerService();
  final StorageService _storage = StorageService();
  
  List<CameraDevice> _cameras = [];
  List<PrinterDevice> _printers = [];
  PrintConfig? _printConfig;
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadPrintConfig();
  }
  
  Future<void> _loadDevices() async {
    _cameras = await _storage.loadCameras();
    
    // Load printers
    List<PrinterDevice> discoveredPrinters = await _scanner.scanForPrinters();
    _printers = await _storage.loadAndReorderPrinters(discoveredPrinters);
    
    setState(() {});
  }
  
  Future<void> _loadPrintConfig() async {
    _printConfig = await _storage.loadPrintConfig();
    setState(() {});
  }
  
  Future<void> _rescanCameras() async {
    setState(() => _isScanning = true);
    
    _cameras.clear();
    
    await for (var camera in _scanner.scanForCameras()) {
      setState(() => _cameras.add(camera));
    }
    
    if (_cameras.isNotEmpty) {
      await _storage.saveCameras(_cameras);
    }
    
    setState(() => _isScanning = false);
  }
  
  Future<void> _rescanPrinters() async {
    setState(() => _isScanning = true);
    
    _printers = await _scanner.scanForPrinters();
    _printers = await _storage.loadAndReorderPrinters(_printers);
    
    setState(() => _isScanning = false);
  }
  
  void _editCameraCredentials(CameraDevice camera) {
    final userController = TextEditingController(text: camera.username);
    final passController = TextEditingController(text: camera.password);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Camera: ${camera.ip}'),
            SizedBox(height: 15),
            TextField(
              controller: userController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storage.updateCameraCredentials(
                camera.ip,
                userController.text,
                passController.text,
              );
              Navigator.pop(context);
              await _loadDevices();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _reorderPrinters(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      
      final printer = _printers.removeAt(oldIndex);
      _printers.insert(newIndex, printer);
      
      // Update order values
      for (int i = 0; i < _printers.length; i++) {
        _printers[i].order = i;
      }
    });
    
    // Save new order
    _storage.savePrinterOrder(_printers);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Scanning for devices...'),
                ],
              ),
            )
          : ListView(
              children: [
                // Cameras section
                _buildSectionHeader('Cameras', Icons.videocam, _rescanCameras),
                
                if (_cameras.isEmpty)
                  ListTile(
                    title: Text('No cameras found'),
                    subtitle: Text('Tap refresh to scan'),
                  )
                else
                  ..._cameras.map((camera) => ListTile(
                        leading: Icon(Icons.videocam),
                        title: Text(camera.displayName),
                        subtitle: Text('${camera.ip} • User: ${camera.username}'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editCameraCredentials(camera),
                        ),
                      )),
                
                Divider(height: 40),
                
                // Printers section
                _buildSectionHeader('Printers', Icons.print, _rescanPrinters),
                
                if (_printers.isEmpty)
                  ListTile(
                    title: Text('No printers found'),
                    subtitle: Text('Tap refresh to scan'),
                  )
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    onReorder: _reorderPrinters,
                    children: _printers.map((printer) {
                      return ListTile(
                        key: ValueKey(printer.name),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle),
                            SizedBox(width: 10),
                            Icon(Icons.print),
                          ],
                        ),
                        title: Text(printer.displayName),
                        subtitle: Text('${printer.ipAddress} • Order: ${printer.order + 1}'),
                        trailing: printer.order == 0
                            ? Chip(
                                label: Text('Primary', style: TextStyle(fontSize: 12)),
                                backgroundColor: Colors.green,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                
                Divider(height: 40),
                
                // Print Settings section
                _buildSectionHeader('Print Settings', Icons.settings, () {}),
                
                if (_printConfig != null) ...[
                  ListTile(
                    leading: Icon(Icons.photo_size_select_actual),
                    title: Text('Paper Size'),
                    subtitle: Text(_printConfig!.paperSizeName),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final updated = await Navigator.push<PrintConfig>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintConfigScreen(initialConfig: _printConfig!),
                        ),
                      );
                      if (updated != null) {
                        setState(() => _printConfig = updated);
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.high_quality),
                    title: Text('Print Quality'),
                    subtitle: Text(_printConfig!.qualityName),
                  ),
                  ListTile(
                    leading: Icon(Icons.content_copy),
                    title: Text('Copies'),
                    subtitle: Text('${_printConfig!.copies} ${_printConfig!.copies == 1 ? 'copy' : 'copies'}'),
                  ),
                  ListTile(
                    title: Text('Configure All Print Settings'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: () async {
                      final updated = await Navigator.push<PrintConfig>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintConfigScreen(initialConfig: _printConfig!),
                        ),
                      );
                      if (updated != null) {
                        setState(() => _printConfig = updated);
                      }
                    },
                  ),
                ],
                
                SizedBox(height: 20),
                
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Drag printers to reorder. First printer will be used for printing.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // App info
                Divider(),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Photo Booth App',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optimized for TP-Link Tapo C520WS',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon, VoidCallback onRefresh) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}