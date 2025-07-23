import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:universal_html/html.dart' as html;
import 'package:kilimomkononi/home.dart';

// Define a model class for manuals
class Manual {
  final String title;
  final String filename;

  const Manual({required this.title, required this.filename});
}

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  String? _selectedPdfPath; // For mobile
// For web
  bool _isLoading = false;

  // Use a const list with a proper model
  static const List<Manual> _manuals = [
    Manual(title: 'Carrots Farming', filename: 'Carrots_Farming.pdf'),
    Manual(title: 'Beans Manual', filename: 'Beans_Manual.pdf'),
    Manual(title: 'Green Pepper', filename: 'Green_Pepper.pdf'),
    Manual(title: 'Courgette Farming in Kenya', filename: 'Courgette_farming_in_Kenya.pdf'),
    Manual(title: 'Onion Growing Manual', filename: 'Onion_Growing_Manual.pdf'),
    Manual(title: 'Tomato Production', filename: 'Tomato_Production.pdf'),
  ];

  @override
  void dispose() {
    _cleanupTemporaryFile();
    super.dispose();
  }

  void _cleanupTemporaryFile() {
    if (_selectedPdfPath != null) {
      File(_selectedPdfPath!).deleteSync();
      _selectedPdfPath = null;
    }
  }

  Future<void> _loadPdf(Manual manual) async {
    const String assetBasePath = 'manuals/';
    final String assetPath = '$assetBasePath${manual.filename}';

    setState(() => _isLoading = true);
    _cleanupTemporaryFile();

    try {
      final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();

      if (!mounted) return;

      if (Platform.isAndroid || Platform.isIOS) {
        await _handleMobileLoad(manual.filename, bytes);
      } else {
        _handleWebLoad(bytes);
      }
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      if (mounted) {
        _showErrorSnackBar();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleMobileLoad(String filename, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    
    if (!file.existsSync()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    
    setState(() => _selectedPdfPath = file.path);
  }

  void _handleWebLoad(Uint8List bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to load manual'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: const Text(
          'Farming Manuals',
          style: TextStyle(color: Colors.white), // Added for consistency
        ),
        backgroundColor: Colors.green[700],
        elevation: 2,
      ),
      body: Stack(
        children: [
          _buildContent(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            flex: _selectedPdfPath == null ? 1 : 2,
            child: _buildManualsList(),
          ),
          if (_selectedPdfPath != null && (Platform.isAndroid || Platform.isIOS))
            Expanded(
              flex: 3,
              child: _buildPdfViewer(),
            ),
        ],
      ),
    );
  }

  Widget _buildManualsList() {
    return Card(
      elevation: 2,
      child: ListView.builder(
        itemCount: _manuals.length,
        itemBuilder: (context, index) {
          final manual = _manuals[index];
          return ListTile(
            leading: Icon(Icons.book, color: Colors.green[700]),
            title: Text(manual.title),
            onTap: () => _loadPdf(manual),
            hoverColor: Colors.green[50],
          );
        },
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Card(
      elevation: 2,
      child: PDFView(
        filePath: _selectedPdfPath!,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: false,
        onError: (error) => _showErrorSnackBar(),
        onPageError: (page, error) => _showErrorSnackBar(),
      ),
    );
  }
}