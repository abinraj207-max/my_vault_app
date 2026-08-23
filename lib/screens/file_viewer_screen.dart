import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';

class FileViewerScreen extends StatefulWidget {
  final VaultState vaultState;
  final String vaultRelativePath;
  final String originalName;
  final String? mimeType;

  const FileViewerScreen({
    super.key,
    required this.vaultState,
    required this.vaultRelativePath,
    required this.originalName,
    this.mimeType,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isLoading = true;
  Uint8List? _decryptedBytes;
  String _errorMessage = '';
  File? _tempFile; // Reference to shredded temp files

  @override
  void initState() {
    super.initState();
    _decryptFile();
  }

  Future<void> _decryptFile() async {
    try {
      final bytes = await widget.vaultState.decryptFile(widget.vaultRelativePath);
      setState(() {
        _decryptedBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to decrypt file: $e';
        _isLoading = false;
      });
    }
  }

  bool _isImage() {
    final mime = widget.mimeType?.toLowerCase() ?? '';
    final name = widget.originalName.toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp');
  }

  Future<void> _openDocument() async {
    setState(() => _isLoading = true);
    try {
      // Decrypt to secure cache file
      final tempFile = await widget.vaultState.decryptFileToCache(
        widget.vaultRelativePath,
        widget.originalName,
      );
      _tempFile = tempFile;

      // Open in system reader
      await OpenFilex.open(tempFile.path);

      // Warning: We keep it open. Since we don't know exactly when the native app finishes reading it,
      // we will shred it when this screen is disposed or when they press "Close Document".
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open document: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareFile() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.highlight),
              SizedBox(width: 8),
              Text('Security Warning'),
            ],
          ),
          content: const Text(
            'Sharing this file will create and send a decrypted copy of it outside the MyVault secure storage area. '
            'Other applications and services will be able to access its contents.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.highlight),
              child: const Text('Proceed & Share'),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;

    setState(() => _isLoading = true);

    File? shareTemp;
    try {
      // Decrypt to cache
      shareTemp = await widget.vaultState.decryptFileToCache(
        widget.vaultRelativePath,
        widget.originalName,
      );

      // Share
      await Share.shareXFiles([XFile(shareTemp.path)], text: 'Shared from MyVault');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    } finally {
      // Shred share temp immediately after sharing is handed off
      if (shareTemp != null) {
        await widget.vaultState.clearCachedFile(shareTemp);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cleanUpTempFile() async {
    if (_tempFile != null) {
      await widget.vaultState.clearCachedFile(_tempFile!);
      _tempFile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showImage = _decryptedBytes != null && _isImage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.originalName),
        actions: [
          if (_decryptedBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _isLoading ? null : _shareFile,
              tooltip: 'Share Decrypted File',
            ),
          ],
        ],
      ),
      body: Container(
        color: Colors.black.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildMainContent(showImage),
            ),
            if (_tempFile != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.highlight, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'A decrypted copy is currently open. Tap close to secure it.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        await _cleanUpTempFile();
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Temporary decrypted files cleared.'),
                            backgroundColor: AppColors.surfaceVariant,
                          ),
                        );
                      },
                      child: const Text('Close & Secure', style: TextStyle(color: AppColors.highlight)),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool showImage) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.highlight),
            SizedBox(height: 16),
            Text('Decrypting file in memory...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
        ),
      );
    }

    if (showImage) {
      return Center(
        child: InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(
            _decryptedBytes!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // Document View Layout
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.highlight,
              child: Icon(
                widget.originalName.endsWith('.pdf')
                    ? Icons.picture_as_pdf_rounded
                    : Icons.description_rounded,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.originalName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'MIME Type: ${widget.mimeType ?? "Unknown"}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openDocument,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.black),
              label: const Text('Open Document'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanUpTempFile(); // Ensure temporary files are shredded on exit
    super.dispose();
  }
}
