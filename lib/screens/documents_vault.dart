import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
// 🔐 DOCUMENTS VAULT SCREEN
// ─────────────────────────────────────────────────────────────

class DocumentsVault extends StatefulWidget {
  final int tripId;
  final String tripTitle;

  const DocumentsVault({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  State<DocumentsVault> createState() => _DocumentsVaultState();
}

class _DocumentsVaultState extends State<DocumentsVault> {
  List<TravelDocument> _documents = [];
  bool _isLoading = false;
  final EncryptionService _encryption = EncryptionService();
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await _db.getDocuments(widget.tripId);
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      setState(() => _isLoading = true);

      final ext = path.extension(pickedFile.name).toLowerCase();
      final fileType = (ext == '.pdf') ? 'pdf' : 'image';

      final encryptedPath = await _encryption.encryptAndSaveFile(
        pickedFile.path!,
        widget.tripId.toString(),
      );

      final doc = TravelDocument(
        tripId: widget.tripId,
        fileName: pickedFile.name,
        fileType: fileType,
        encryptedFilePath: encryptedPath,
        originalName: pickedFile.name,
        uploadedAt: DateTime.now(),
      );

      await _db.insertDocument(doc);
      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Document uploaded & encrypted!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewDocument(TravelDocument doc) async {
    try {
      setState(() => _isLoading = true);

      final tempPath = await _encryption.decryptToTempFile(
        doc.encryptedFilePath,
        doc.originalName,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (doc.fileType == 'pdf') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(filePath: tempPath),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              filePath: tempPath,
              title: doc.originalName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Could not open: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(TravelDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Document"),
        content:
        Text("Delete '${doc.originalName}'? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
            const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final file = File(doc.encryptedFilePath);
    if (await file.exists()) await file.delete();

    await _db.deleteDocument(doc.id!);
    await _loadDocuments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Document deleted")),
      );
    }
  }

  IconData _getDocIcon(String fileType) =>
      fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image;

  Color _getDocColor(String fileType) =>
      fileType == 'pdf' ? Colors.redAccent : Colors.blueAccent;

  String _formatDate(DateTime dt) =>
      "${dt.day}/${dt.month}/${dt.year}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Documents Vault",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.tripTitle,
                style:
                const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: "Upload Document",
            onPressed: _pickAndUploadDocument,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child:
          CircularProgressIndicator(color: Colors.purpleAccent))
          : _documents.isEmpty
          ? _buildEmptyState()
          : _buildDocumentList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUploadDocument,
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.upload_file),
        label: const Text("Upload"),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            "No Documents Yet",
            style: TextStyle(
                color: Colors.white60,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Upload passports, visas, tickets\nand more. All encrypted. 🔐",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(
                  horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _pickAndUploadDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text("Upload First Document",
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16213E), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getDocColor(doc.fileType).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getDocIcon(doc.fileType),
                  color: _getDocColor(doc.fileType), size: 28),
            ),
            title: Text(
              doc.originalName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.lock,
                      size: 12, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    "AES-256 Encrypted",
                    style: TextStyle(
                        color: Colors.greenAccent.shade400,
                        fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(doc.uploadedAt),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined,
                      color: Colors.blueAccent),
                  tooltip: "View",
                  onPressed: () => _viewDocument(doc),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  tooltip: "Delete",
                  onPressed: () => _deleteDocument(doc),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 📄 PDF VIEWER SCREEN
// ─────────────────────────────────────────────────────────────

class PdfViewerScreen extends StatefulWidget {
  final String filePath;

  const PdfViewerScreen({super.key, required this.filePath});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          _isReady
              ? "Page $_currentPage / $_totalPages"
              : "Loading PDF...",
        ),
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) {
          setState(() {
            _totalPages = pages ?? 0;
            _currentPage = 1;
            _isReady = true;
          });
        },
        onPageChanged: (page, total) {
          setState(() => _currentPage = (page ?? 0) + 1);
        },
        onError: (error) => debugPrint("PDF Error: $error"),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 🖼️ IMAGE VIEWER SCREEN
// ─────────────────────────────────────────────────────────────

class ImageViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const ImageViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image,
                    color: Colors.white54, size: 80),
                SizedBox(height: 12),
                Text("Could not load image",
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}