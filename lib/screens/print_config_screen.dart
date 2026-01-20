import 'package:flutter/material.dart';
import '../model/print_config.dart';
import '../services/storage_service.dart';

class PrintConfigScreen extends StatefulWidget {
  final PrintConfig initialConfig;
  
  PrintConfigScreen({required this.initialConfig});
  
  @override
  _PrintConfigScreenState createState() => _PrintConfigScreenState();
}

class _PrintConfigScreenState extends State<PrintConfigScreen> {
  final StorageService _storage = StorageService();
  late PrintConfig _config;
  
  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }
  
  Future<void> _saveAndExit() async {
    await _storage.savePrintConfig(_config);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Print settings saved'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
    Navigator.pop(context, _config);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveAndExit,
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Paper Size
          _buildSection(
            'Paper Size',
            Icons.photo_size_select_actual,
            _buildPaperSizeSelector(),
          ),
          
          Divider(),
          
          // Quality
          _buildSection(
            'Print Quality',
            Icons.high_quality,
            _buildQualitySelector(),
          ),
          
          Divider(),
          
          // Orientation
          _buildSection(
            'Orientation',
            Icons.screen_rotation,
            _buildOrientationSelector(),
          ),
          
          Divider(),
          
          // Fit Mode
          _buildSection(
            'Image Fit',
            Icons.fit_screen,
            _buildFitModeSelector(),
          ),
          
          Divider(),
          
          // Borders
          _buildSection(
            'Borders',
            Icons.border_outer,
            _buildBorderSelector(),
          ),
          
          Divider(),
          
          // Copies
          _buildSection(
            'Copies',
            Icons.content_copy,
            _buildCopiesSelector(),
          ),
          
          SizedBox(height: 20),
          
          // Preview info
          _buildPreviewInfo(),
          
          SizedBox(height: 20),
          
          // Save button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _saveAndExit,
              icon: Icon(Icons.save),
              label: Text('Save Settings', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, Widget content) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
  
  Widget _buildPaperSizeSelector() {
    return Column(
      children: PaperSize.values.map((size) {
        final config = PrintConfig(paperSize: size);
        return RadioListTile<PaperSize>(
          title: Text(config.paperSizeName),
          value: size,
          groupValue: _config.paperSize,
          onChanged: (value) {
            setState(() => _config = _config.copyWith(paperSize: value));
          },
          dense: true,
        );
      }).toList(),
    );
  }
  
  Widget _buildQualitySelector() {
    return Column(
      children: PrintQuality.values.map((quality) {
        final config = PrintConfig(quality: quality);
        return RadioListTile<PrintQuality>(
          title: Text(config.qualityName),
          subtitle: quality == PrintQuality.draft
              ? Text('Faster printing, lower quality')
              : quality == PrintQuality.high
                  ? Text('Slower printing, best quality (recommended for 2K photos)')
                  : null,
          value: quality,
          groupValue: _config.quality,
          onChanged: (value) {
            setState(() => _config = _config.copyWith(quality: value));
          },
          dense: true,
        );
      }).toList(),
    );
  }
  
  Widget _buildOrientationSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stay_current_portrait, size: 20),
                SizedBox(width: 8),
                Text('Portrait'),
              ],
            ),
            selected: !_config.landscape,
            onSelected: (selected) {
              if (selected) {
                setState(() => _config = _config.copyWith(landscape: false));
              }
            },
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stay_current_landscape, size: 20),
                SizedBox(width: 8),
                Text('Landscape'),
              ],
            ),
            selected: _config.landscape,
            onSelected: (selected) {
              if (selected) {
                setState(() => _config = _config.copyWith(landscape: true));
              }
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildFitModeSelector() {
    return Column(
      children: FitMode.values.map((mode) {
        final config = PrintConfig(fitMode: mode);
        return RadioListTile<FitMode>(
          title: Text(config.fitModeName),
          subtitle: mode == FitMode.fill
              ? Text('Image fills entire area, may crop edges (recommended for 2K)')
              : mode == FitMode.fit
                  ? Text('Entire image visible, may have white space')
                  : Text('Image stretched to fill area'),
          value: mode,
          groupValue: _config.fitMode,
          onChanged: (value) {
            setState(() => _config = _config.copyWith(fitMode: value));
          },
          dense: true,
        );
      }).toList(),
    );
  }
  
  Widget _buildBorderSelector() {
    return Column(
      children: BorderSize.values.map((border) {
        final config = PrintConfig(borderSize: border);
        return RadioListTile<BorderSize>(
          title: Text(config.borderSizeName),
          value: border,
          groupValue: _config.borderSize,
          onChanged: (value) {
            setState(() => _config = _config.copyWith(borderSize: value));
          },
          dense: true,
        );
      }).toList(),
    );
  }
  
  Widget _buildCopiesSelector() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.remove_circle_outline),
          iconSize: 32,
          onPressed: _config.copies > 1
              ? () {
                  setState(() => _config = _config.copyWith(copies: _config.copies - 1));
                }
              : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_config.copies} ${_config.copies == 1 ? 'copy' : 'copies'}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          iconSize: 32,
          onPressed: _config.copies < 10
              ? () {
                  setState(() => _config = _config.copyWith(copies: _config.copies + 1));
                }
              : null,
        ),
      ],
    );
  }
  
  Widget _buildPreviewInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Current Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildInfoRow('Paper', _config.paperSizeName),
          _buildInfoRow('Quality', _config.qualityName),
          _buildInfoRow('Orientation', _config.landscape ? 'Landscape' : 'Portrait'),
          _buildInfoRow('Image Fit', _config.fitModeName),
          _buildInfoRow('Borders', _config.borderSizeName),
          _buildInfoRow('Copies', '${_config.copies}'),
          Divider(height: 20),
          Row(
            children: [
              Icon(Icons.camera_alt, size: 16, color: Colors.green),
              SizedBox(width: 6),
              Text(
                'Optimized for Tapo C520WS 2K photos',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey[700])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}