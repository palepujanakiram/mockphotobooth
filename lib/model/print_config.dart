import 'package:pdf/pdf.dart';

enum PaperSize {
  photo4x6,
  photo5x7,
  photo6x8,
  photo8x10,
  a4,
  letter,
}

enum PrintQuality {
  draft,
  normal,
  high,
}

enum FitMode {
  fill,    // Cover entire area, may crop
  fit,     // Fit within area, may have borders
  stretch, // Stretch to fill, may distort
}

enum BorderSize {
  none,
  small,
  medium,
  large,
}

class PrintConfig {
  PaperSize paperSize;
  PrintQuality quality;
  bool landscape;
  int copies;
  FitMode fitMode;
  BorderSize borderSize;
  
  PrintConfig({
    this.paperSize = PaperSize.photo4x6,
    this.quality = PrintQuality.high,
    this.landscape = false,
    this.copies = 1,
    this.fitMode = FitMode.fill,
    this.borderSize = BorderSize.none,
  });
  
  PdfPageFormat getPageFormat() {
    double width, height;
    
    switch (paperSize) {
      case PaperSize.photo4x6:
        width = 4 * PdfPageFormat.inch;
        height = 6 * PdfPageFormat.inch;
        break;
      case PaperSize.photo5x7:
        width = 5 * PdfPageFormat.inch;
        height = 7 * PdfPageFormat.inch;
        break;
      case PaperSize.photo6x8:
        width = 6 * PdfPageFormat.inch;
        height = 8 * PdfPageFormat.inch;
        break;
      case PaperSize.photo8x10:
        width = 8 * PdfPageFormat.inch;
        height = 10 * PdfPageFormat.inch;
        break;
      case PaperSize.a4:
        final m = _getMargin();
        return PdfPageFormat.a4.copyWith(
          marginTop: m,
          marginBottom: m,
          marginLeft: m,
          marginRight: m,
        );
      case PaperSize.letter:
        final m = _getMargin();
        return PdfPageFormat.letter.copyWith(
          marginTop: m,
          marginBottom: m,
          marginLeft: m,
          marginRight: m,
        );
    }
    
    if (landscape) {
      return PdfPageFormat(height, width, marginAll: _getMargin());
    } else {
      return PdfPageFormat(width, height, marginAll: _getMargin());
    }
  }
  
  double _getMargin() {
    switch (borderSize) {
      case BorderSize.none:
        return 0;
      case BorderSize.small:
        return 0.1 * PdfPageFormat.inch;
      case BorderSize.medium:
        return 0.25 * PdfPageFormat.inch;
      case BorderSize.large:
        return 0.5 * PdfPageFormat.inch;
    }
  }
  
  String get paperSizeName {
    switch (paperSize) {
      case PaperSize.photo4x6:
        return '4x6 inch (Postcard)';
      case PaperSize.photo5x7:
        return '5x7 inch';
      case PaperSize.photo6x8:
        return '6x8 inch';
      case PaperSize.photo8x10:
        return '8x10 inch';
      case PaperSize.a4:
        return 'A4 (210 × 297 mm)';
      case PaperSize.letter:
        return 'Letter (8.5 × 11 inch)';
    }
  }
  
  String get qualityName {
    switch (quality) {
      case PrintQuality.draft:
        return 'Draft (Fast)';
      case PrintQuality.normal:
        return 'Normal';
      case PrintQuality.high:
        return 'High Quality';
    }
  }
  
  String get fitModeName {
    switch (fitMode) {
      case FitMode.fill:
        return 'Fill (May crop)';
      case FitMode.fit:
        return 'Fit (No crop)';
      case FitMode.stretch:
        return 'Stretch to fill';
    }
  }
  
  String get borderSizeName {
    switch (borderSize) {
      case BorderSize.none:
        return 'No borders';
      case BorderSize.small:
        return 'Small border';
      case BorderSize.medium:
        return 'Medium border';
      case BorderSize.large:
        return 'Large border';
    }
  }
  
  Map<String, dynamic> toJson() => {
    'paperSize': paperSize.index,
    'quality': quality.index,
    'landscape': landscape,
    'copies': copies,
    'fitMode': fitMode.index,
    'borderSize': borderSize.index,
  };
  
  factory PrintConfig.fromJson(Map<String, dynamic> json) => PrintConfig(
    paperSize: PaperSize.values[json['paperSize'] ?? 0],
    quality: PrintQuality.values[json['quality'] ?? 2],
    landscape: json['landscape'] ?? false,
    copies: json['copies'] ?? 1,
    fitMode: FitMode.values[json['fitMode'] ?? 0],
    borderSize: BorderSize.values[json['borderSize'] ?? 0],
  );
  
  PrintConfig copyWith({
    PaperSize? paperSize,
    PrintQuality? quality,
    bool? landscape,
    int? copies,
    FitMode? fitMode,
    BorderSize? borderSize,
  }) {
    return PrintConfig(
      paperSize: paperSize ?? this.paperSize,
      quality: quality ?? this.quality,
      landscape: landscape ?? this.landscape,
      copies: copies ?? this.copies,
      fitMode: fitMode ?? this.fitMode,
      borderSize: borderSize ?? this.borderSize,
    );
  }
}