import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../model/printer_device.dart';
import '../model/print_config.dart';
import '../services/storage_service.dart';
import 'print_config_screen.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final Uint8List photoBytes;
  final List<PrinterDevice> printers;
  
  PhotoPreviewScreen({
    required this.photoBytes,
    required this.printers,
  });
  
  @override
  _PhotoPreviewScreenState createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  final StorageService _storage = StorageService();
  bool _isPrinting = false;
  PrintConfig? _printConfig;
  
  @override
  void initState() {
    super.initState();
    _loadPrintConfig();
  }
  
  Future<void> _loadPrintConfig() async {
    _printConfig = await _storage.loadPrintConfig();
    setState(() {});
  }
  
  Future<void> _openPrintSettings() async {
    if (_printConfig == null) return;
    
    final updatedConfig = await Navigator.push<PrintConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => PrintConfigScreen(initialConfig: _printConfig!),
      ),
    );
    
    if (updatedConfig != null) {
      setState(() => _printConfig = updatedConfig);
    }
  }
  
  Future<void> _printPhoto() async {
    if (_printConfig == null) {
      _showError('Print configuration not loaded');
      return;
    }
    
    setState(() => _isPrinting = true);
    
    try {
      final pdfBytes = await _buildPdfBytes();

      // Mobile: show system print UI (select printer via OS)
      if (Platform.isAndroid || Platform.isIOS) {
        print('🖨️ Sending print job via system print dialog (${_printConfig!.copies} page(s))');
        await Printing.layoutPdf(
          name: 'Photo Booth',
          onLayout: (_) async => pdfBytes,
        );
      } else {
        // Desktop: print silently to the first configured printer
        PrinterDevice? printer = await _storage.getFirstPrinter(widget.printers);
        if (printer == null) {
          _showError('No printer configured');
          setState(() => _isPrinting = false);
          return;
        }

        print('🖨️ Printing ${_printConfig!.copies} page(s) to ${printer.name}');
        await Printing.directPrintPdf(
          printer: printer.printer,
          onLayout: (_) async => pdfBytes,
          usePrinterSettings: false,
        );
      }
      
      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Print job sent',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      await Future.delayed(Duration(seconds: 2));
      Navigator.pop(context);
      
    } catch (e) {
      _showError('Print failed: $e');
      print('❌ Print error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }
  
  Future<Uint8List> _buildPdfBytes() async {
    final config = _printConfig!;

    // Process image for optimal print quality
    final processedImage = await _processImageForPrint(widget.photoBytes);

    // Create PDF with custom configuration
    final pdf = pw.Document();
    final pageFormat = config.getPageFormat();

    // Determine fit mode
    final pw.BoxFit boxFit = switch (config.fitMode) {
      FitMode.fill => pw.BoxFit.cover,
      FitMode.fit => pw.BoxFit.contain,
      FitMode.stretch => pw.BoxFit.fill,
    };

    // Model copies as multiple identical pages (works across platforms)
    final pages = config.copies.clamp(1, 10);
    for (int i = 0; i < pages; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(processedImage),
              fit: boxFit,
            ),
          ),
        ),
      );
    }

    return pdf.save();
  }
  
  Future<Uint8List> _processImageForPrint(Uint8List imageBytes) async {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    
    if (image == null) {
      return imageBytes; // Return original if decode fails
    }
    
    // Crop to 4x6 ratio if needed (2:3 aspect ratio)
    if (_printConfig!.paperSize == PaperSize.photo4x6) {
      int targetWidth = image.width;
      int targetHeight = (image.width * 1.5).round(); // 2:3 ratio
      
      if (image.height > targetHeight) {
        // Crop height
        int offsetY = (image.height - targetHeight) ~/ 2;
        image = img.copyCrop(
          image,
          x: 0,
          y: offsetY,
          width: targetWidth,
          height: targetHeight,
        );
      }
    }
    
    // Enhance image quality
    // Optional: adjust brightness, contrast, sharpness here
    
    // Encode back to JPEG with high quality
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Photo Preview'),
        backgroundColor: Colors.black87,
        actions: [
          if (_printConfig != null)
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: _openPrintSettings,
              tooltip: 'Print Settings',
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo preview
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha((0.1 * 255).round()),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.memory(
                    widget.photoBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
          
          // Image info
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Tapo C520WS • 2K Quality',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Print info
          if (_printConfig != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_printConfig!.paperSizeName} • ${_printConfig!.qualityName} • ${_printConfig!.copies} ${_printConfig!.copies == 1 ? 'copy' : 'copies'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: _openPrintSettings,
                    child: Text('Change'),
                  ),
                ],
              ),
            ),
          
          // Buttons
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.black,
            child: Row(
              children: [
                // Back button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPrinting ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back),
                    label: Text('Retake', style: TextStyle(fontSize: 18)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                
                SizedBox(width: 20),
                
                // Print button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _printPhoto,
                    icon: _isPrinting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.print, size: 24),
                    label: Text(
                      _isPrinting ? 'Printing...' : 'Print',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}