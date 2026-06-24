import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurantwaiter/domain/models/table_qr_token.dart';

class TableQrPdfService {
  Future<void> printBranchQrPdf({
    required String branchName,
    required List<TableQrToken> tokens,
  }) async {
    final doc = pw.Document();
    final sorted = [...tokens]
      ..sort((a, b) {
        final floor = a.floor.compareTo(b.floor);
        if (floor != 0) return floor;
        return a.tableNumber.compareTo(b.tableNumber);
      });

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            branchName.isEmpty ? 'Codigos QR de mesas' : branchName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Escanea el codigo QR para unirte al pedido de la mesa.'),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 14,
            runSpacing: 14,
            children: sorted.map(_tableCard).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'mesas_qr.pdf',
      onLayout: (_) => doc.save(),
    );
  }

  pw.Widget _tableCard(TableQrToken token) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Mesa ${token.tableNumber}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Piso ${token.floor}'),
          pw.SizedBox(height: 8),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: token.qrToken,
            width: 120,
            height: 120,
          ),
        ],
      ),
    );
  }
}
