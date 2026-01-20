import 'package:flutter/material.dart';
import '../model/print_config.dart';

class QuickPrintSettings extends StatelessWidget {
  final PrintConfig config;
  final Function(PrintConfig) onChanged;
  
  QuickPrintSettings({
    required this.config,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          
          // Paper size dropdown
          DropdownButtonFormField<PaperSize>(
            initialValue: config.paperSize,
            decoration: InputDecoration(
              labelText: 'Paper Size',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.photo_size_select_actual),
            ),
            items: PaperSize.values.map((size) {
              final temp = PrintConfig(paperSize: size);
              return DropdownMenuItem(
                value: size,
                child: Text(temp.paperSizeName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(paperSize: value));
              }
            },
          ),
          
          SizedBox(height: 12),
          
          // Copies counter
          Row(
            children: [
              Text('Copies: ', style: TextStyle(fontSize: 16)),
              Spacer(),
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: config.copies > 1
                    ? () => onChanged(config.copyWith(copies: config.copies - 1))
                    : null,
              ),
              Text(
                '${config.copies}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: config.copies < 10
                    ? () => onChanged(config.copyWith(copies: config.copies + 1))
                    : null,
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Quality selector
          DropdownButtonFormField<PrintQuality>(
            initialValue: config.quality,
            decoration: InputDecoration(
              labelText: 'Quality',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.high_quality),
            ),
            items: PrintQuality.values.map((quality) {
              final temp = PrintConfig(quality: quality);
              return DropdownMenuItem(
                value: quality,
                child: Text(temp.qualityName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(quality: value));
              }
            },
          ),
        ],
      ),
    );
  }
}