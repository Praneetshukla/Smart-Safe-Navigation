// lib/services/pdf_export_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfExportService {
  /// Generates a Journey Report PDF and prompts user to save it.
  Future<void> exportJourneyReport({
    required List<Journey> journeys,
    required Map<String, dynamic> stats,
    required BuildContext context,
  }) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();

    // ── Fonts ──────────────────────────────────────────────────────────────
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 22,
        style: PdfFontStyle.bold);
    final headingFont = PdfStandardFont(PdfFontFamily.helvetica, 14,
        style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    // ── Colors ─────────────────────────────────────────────────────────────
    final primaryColor = PdfColor(10, 22, 40);
    final accentColor = PdfColor(0, 212, 170);
    final textColor = PdfColor(50, 50, 80);
    final lightGray = PdfColor(240, 242, 245);

    // ── Header Banner ──────────────────────────────────────────────────────
    graphics.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, 0, bounds.width, 80),
    );
    graphics.drawString(
      'SafeRoute — Journey Report',
      titleFont,
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(20, 20, bounds.width - 40, 40),
    );
    graphics.drawString(
      'Generated: ${DateFormat('MMMM d, y  h:mm a').format(DateTime.now())}',
      smallFont,
      brush: PdfSolidBrush(PdfColor(180, 200, 220)),
      bounds: Rect.fromLTWH(20, 56, bounds.width - 40, 20),
    );

    double y = 100;

    // ── Summary Statistics ─────────────────────────────────────────────────
    graphics.drawString('Summary', headingFont,
        brush: PdfSolidBrush(textColor),
        bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20));
    y += 24;

    graphics.drawRectangle(
      brush: PdfSolidBrush(lightGray),
      bounds: Rect.fromLTWH(20, y, bounds.width - 40, 60),
    );

    final summaryLines = [
      'Total Journeys: ${stats['total']}',
      'Journeys This Week: ${stats['thisWeek']}',
      'Average Safety Rating: ${(stats['avgRating'] as double).toStringAsFixed(1)} / 5.0',
    ];
    double sx = 30;
    for (final line in summaryLines) {
      graphics.drawString(line, bodyFont,
          brush: PdfSolidBrush(textColor),
          bounds: Rect.fromLTWH(sx, y + 10, 160, 40));
      sx += 170;
    }
    y += 76;

    // ── Route Preference Breakdown ─────────────────────────────────────────
    final routeTypes = stats['routeTypes'] as Map<String, int>? ?? {};
    if (routeTypes.isNotEmpty) {
      graphics.drawString('Route Preferences', headingFont,
          brush: PdfSolidBrush(textColor),
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20));
      y += 24;
      for (final entry in routeTypes.entries) {
        graphics.drawString(
          '  ${entry.key[0].toUpperCase()}${entry.key.substring(1)}: ${entry.value} journeys',
          bodyFont,
          brush: PdfSolidBrush(textColor),
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 16),
        );
        y += 18;
      }
      y += 8;
    }

    // ── Journey Table ──────────────────────────────────────────────────────
    if (journeys.isNotEmpty) {
      graphics.drawString('Journey Log', headingFont,
          brush: PdfSolidBrush(textColor),
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20));
      y += 24;

      // Table header
      final colWidths = [120.0, 120.0, 80.0, 60.0, 50.0];
      final headers = ['From', 'To', 'Date', 'Route', 'Rating'];
      double hx = 20;
      graphics.drawRectangle(
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20),
      );
      for (int i = 0; i < headers.length; i++) {
        graphics.drawString(
          headers[i],
          PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          bounds: Rect.fromLTWH(hx + 4, y + 4, colWidths[i] - 8, 14),
        );
        hx += colWidths[i];
      }
      y += 20;

      // Table rows
      bool alternate = false;
      for (final j in journeys) {
        // New page if needed
        if (y > bounds.height - 40) {
          document.pages.add();
          y = 20;
        }
        if (alternate) {
          graphics.drawRectangle(
            brush: PdfSolidBrush(lightGray),
            bounds: Rect.fromLTWH(20, y, bounds.width - 40, 18),
          );
        }
        final cells = [
          _truncate(j.startAddress, 20),
          _truncate(j.endAddress, 20),
          DateFormat('MMM d, yyyy').format(j.startTime),
          j.routeType,
          j.rating?.toStringAsFixed(1) ?? '—',
        ];
        double cx = 20;
        for (int i = 0; i < cells.length; i++) {
          graphics.drawString(
            cells[i],
            bodyFont,
            brush: PdfSolidBrush(textColor),
            bounds: Rect.fromLTWH(cx + 4, y + 3, colWidths[i] - 8, 14),
          );
          cx += colWidths[i];
        }
        y += 18;
        alternate = !alternate;
      }
    }

    // ── Footer ─────────────────────────────────────────────────────────────
    graphics.drawString(
      'SafeRoute App  •  Stay Safe, Navigate Smart',
      smallFont,
      brush: PdfSolidBrush(PdfColor(160, 170, 190)),
      bounds: Rect.fromLTWH(20, bounds.height - 20, bounds.width - 40, 16),
    );

    // ── Save File ──────────────────────────────────────────────────────────
    final bytes = await document.save();
    document.dispose();

    final fileName =
        'saferoute_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Journey Report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to $outputPath'),
            backgroundColor: const Color(0xFF00D4AA),
          ),
        );
      }
    }
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
