// lib/utils/xlsx_writer.dart
//
// A small Excel (.xlsx) writer: styled cells, column widths, merged title
// rows, frozen header rows and an autofilter — enough for well-formatted
// reports (e.g. the Google vs. weather-station comparison). Writes plain
// Office Open XML zipped with `archive` (already used by the app), so it
// works the same on web and phones, with no extra licence.
//
//   final x = XlsxWorkbook();
//   final s = x.sheet('Summary', widths: [24, 14]);
//   s.row([XCell('Title', XStyle.title)]);
//   s.row([XCell('Temp', XStyle.header), XCell(21.4, XStyle.number)]);
//   final bytes = x.encode();

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The styles available to cells (index = cellXfs id in styles.xml).
enum XStyle {
  plain,
  title,
  subtitle,
  header,
  headerGoogle,
  headerStation,
  headerDiff,
  text,
  number,
  diff,
  textAlt,
  numberAlt,
  diffAlt,
  label,
  note,
  sectionGoogle,
  sectionStation,
  sectionDiff,
}

class XCell {
  final Object? value; // String, num or null
  final XStyle style;
  const XCell(this.value, [this.style = XStyle.plain]);
}

class XlsxSheet {
  final String name;
  final List<double> widths;
  final List<List<XCell>> rows = [];
  final List<String> merges = [];

  /// Rows above this (1-based row index) stay visible when scrolling.
  int? freezeRows;

  /// e.g. "A5:K29" — filter buttons on a header row.
  String? autoFilter;

  XlsxSheet(this.name, this.widths);

  /// Adds a row; returns its 1-based index.
  int row(List<XCell> cells) {
    rows.add(cells);
    return rows.length;
  }

  void blank() => rows.add(const []);

  /// Merges columns [fromCol]..[toCol] (0-based) of row [row] (1-based).
  void merge(int row, int fromCol, int toCol) =>
      merges.add('${colName(fromCol)}$row:${colName(toCol)}$row');
}

/// 0 → A, 25 → Z, 26 → AA.
String colName(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // XML 1.0 can't carry most control characters.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

class XlsxWorkbook {
  final List<XlsxSheet> sheets = [];
  String title;
  String author;

  XlsxWorkbook({this.title = '', this.author = 'Kilimo Mkononi'});

  XlsxSheet sheet(String name, {List<double> widths = const []}) {
    // Sheet names: max 31 chars, no []:*?/\
    final clean = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final s = XlsxSheet(clean.length > 31 ? clean.substring(0, 31) : clean, widths);
    sheets.add(s);
    return s;
  }

  Uint8List encode() {
    final a = Archive();
    void add(String path, String xml) {
      final bytes = utf8.encode(xml);
      a.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', _rootRels);
    add('docProps/core.xml', _core());
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels());
    add('xl/styles.xml', _styles);
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  String _contentTypes() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '${[for (var i = 1; i <= sheets.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>';

  static const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';

  String _core() {
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_esc(title)}</dc:title><dc:creator>${_esc(author)}</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created>'
        '</cp:coreProperties>';
  }

  String _workbook() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets>'
      '${_definedNames()}'
      '</workbook>';

  // Autofilters need a hidden _FilterDatabase name to show in Excel.
  String _definedNames() {
    final names = <String>[];
    for (var i = 0; i < sheets.length; i++) {
      final f = sheets[i].autoFilter;
      if (f == null) continue;
      final parts = f.split(':');
      String abs(String ref) => ref.replaceAllMapped(RegExp(r'([A-Z]+)(\d+)'), (m) => '\$${m[1]}\$${m[2]}');
      names.add('<definedName name="_xlnm._FilterDatabase" localSheetId="$i" hidden="1">'
          "'${_esc(sheets[i].name).replaceAll("'", "''")}'!${abs(parts[0])}:${abs(parts[1])}</definedName>");
    }
    return names.isEmpty ? '' : '<definedNames>${names.join()}</definedNames>';
  }

  String _workbookRels() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 1; i <= sheets.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  String _sheetXml(XlsxSheet s) {
    final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    final f = s.freezeRows;
    if (f != null && f > 0) {
      b.write('<sheetViews><sheetView workbookViewId="0">'
          '<pane ySplit="$f" topLeftCell="A${f + 1}" activePane="bottomLeft" state="frozen"/>'
          '</sheetView></sheetViews>');
    } else {
      b.write('<sheetViews><sheetView workbookViewId="0"/></sheetViews>');
    }
    b.write('<sheetFormatPr defaultRowHeight="16"/>');
    if (s.widths.isNotEmpty) {
      b.write('<cols>');
      for (var i = 0; i < s.widths.length; i++) {
        b.write('<col min="${i + 1}" max="${i + 1}" width="${s.widths[i]}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < s.rows.length; r++) {
      final cells = s.rows[r];
      final rowNo = r + 1;
      final tall = cells.any((c) => c.style == XStyle.title) ? ' ht="26" customHeight="1"' : '';
      final header = cells.any((c) => c.style.name.startsWith('header')) ? ' ht="32" customHeight="1"' : '';
      b.write('<row r="$rowNo"${tall.isNotEmpty ? tall : header}>');
      for (var c = 0; c < cells.length; c++) {
        final cell = cells[c];
        final ref = '${colName(c)}$rowNo';
        final st = ' s="${cell.style.index}"';
        final v = cell.value;
        if (v == null || (v is String && v.isEmpty)) {
          b.write('<c r="$ref"$st/>');
        } else if (v is num) {
          final n = v.isFinite ? v : 0;
          b.write('<c r="$ref"$st><v>$n</v></c>');
        } else {
          b.write('<c r="$ref"$st t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (s.autoFilter != null) b.write('<autoFilter ref="${s.autoFilter}"/>');
    if (s.merges.isNotEmpty) {
      b.write('<mergeCells count="${s.merges.length}">${s.merges.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>');
    }
    b.write('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
        '<pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>');
    b.write('</worksheet>');
    return b.toString();
  }

  // Fonts: 0 normal, 1 title, 2 subtitle (grey italic), 3 bold white,
  //        4 bold, 5 note (grey), 6 diff (dark orange)
  // Fills: 0 none, 1 gray125 (required), 2 dark green, 3 Google blue,
  //        4 station green, 5 orange, 6 zebra, 7 light blue, 8 light green, 9 light orange
  // Borders: 0 none, 1 thin grey
  // NumFmts: 164 "0.0", 165 "+0.0;-0.0;0.0"
  static const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="0.0"/><numFmt numFmtId="165" formatCode="+0.0;-0.0;0.0"/></numFmts>'
      '<fonts count="7">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="16"/><color rgb="FF1B5E20"/><name val="Calibri"/></font>'
      '<font><i/><sz val="10"/><color rgb="FF5F6B5F"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><sz val="10"/><color rgb="FF5F6B5F"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFB45309"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="10">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF1B5E20"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF1A73E8"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF2E7D32"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE65100"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFF3F6F3"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE8F0FE"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE8F5E9"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFFF3E0"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FFD0D7D0"/></left><right style="thin"><color rgb="FFD0D7D0"/></right>'
      '<top style="thin"><color rgb="FFD0D7D0"/></top><bottom style="thin"><color rgb="FFD0D7D0"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="18">'
      // 0 plain
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      // 1 title
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"><alignment vertical="center"/></xf>'
      // 2 subtitle
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      // 3 header (dark green)
      '<xf numFmtId="0" fontId="3" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      // 4 header Google (blue)
      '<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      // 5 header station (green)
      '<xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      // 6 header difference (orange)
      '<xf numFmtId="0" fontId="3" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      // 7 text
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      // 8 number 0.0
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 9 difference +0.0
      '<xf numFmtId="165" fontId="6" fillId="9" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 10 text (zebra)
      '<xf numFmtId="0" fontId="0" fillId="6" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      // 11 number (zebra)
      '<xf numFmtId="164" fontId="0" fillId="6" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 12 difference (zebra — same light orange so the column reads as one)
      '<xf numFmtId="165" fontId="6" fillId="9" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 13 label (bold, bordered)
      '<xf numFmtId="0" fontId="4" fillId="6" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      // 14 note (grey, wrapped)
      '<xf numFmtId="0" fontId="5" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>'
      // 15 section Google (light blue band)
      '<xf numFmtId="0" fontId="4" fillId="7" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 16 section station (light green band)
      '<xf numFmtId="0" fontId="4" fillId="8" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      // 17 section difference (light orange band)
      '<xf numFmtId="0" fontId="4" fillId="9" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
