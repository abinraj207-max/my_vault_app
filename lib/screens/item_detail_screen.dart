import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/vault_models.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';
import 'edit_item_screen.dart';
import 'file_viewer_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final VaultState vaultState;
  final VaultItem item;

  const ItemDetailScreen({
    super.key,
    required this.vaultState,
    required this.item,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _revealPassword = false;
  bool _revealApiKey = false;
  bool _revealSecretKey = false;
  late VaultItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  void _copyToClipboard(String label, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.surfaceVariant,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: const Text('Are you sure you want to permanently delete this item from your vault?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.vaultState.deleteItem(_currentItem);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
      }
    }
  }

  void _editItem() async {
    final result = await Navigator.push<VaultItem>(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(
          vaultState: widget.vaultState,
          type: _currentItem.type,
          itemToEdit: _currentItem,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentItem = result;
      });
    }
  }

  void _shareItemDetails() {
    final sb = StringBuffer();
    sb.writeln('MyVault - Shared Details');
    sb.writeln('Title: ${_currentItem.title}');
    sb.writeln('Category: ${_currentItem.type.name.toUpperCase()}');

    if (_currentItem.username != null && _currentItem.username!.isNotEmpty) {
      sb.writeln('Username: ${_currentItem.username}');
    }
    if (_currentItem.email != null && _currentItem.email!.isNotEmpty) {
      sb.writeln('Email: ${_currentItem.email}');
    }
    if (_currentItem.website != null && _currentItem.website!.isNotEmpty) {
      sb.writeln('Website: ${_currentItem.website}');
    }
    if (_currentItem.notes != null && _currentItem.notes!.isNotEmpty) {
      sb.writeln('Notes: ${_currentItem.notes}');
    }

    Share.share(sb.toString(), subject: _currentItem.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Item Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header ring layout with Icon
            _buildVisualHeader(),
            const SizedBox(height: 32),

            // Detail Cards based on VaultType
            _buildDetailSection(),
            const SizedBox(height: 16),

            // Tag List Chip Layout
            if (_currentItem.tags.isNotEmpty) ...[
              _buildTagsCard(),
              const SizedBox(height: 16),
            ],

            // Date details
            _buildMetadataCard(),
            const SizedBox(height: 32),

            // Action Buttons
            _buildActionRow(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualHeader() {
    IconData icon;
    switch (_currentItem.type) {
      case VaultType.password:
        icon = Icons.vpn_key_rounded;
        break;
      case VaultType.apiKey:
        icon = Icons.code_rounded;
        break;
      case VaultType.email:
        icon = Icons.alternate_email_rounded;
        break;
      case VaultType.note:
        icon = Icons.sticky_note_2_rounded;
        break;
      case VaultType.image:
        icon = Icons.image_rounded;
        break;
      case VaultType.card:
        icon = Icons.credit_card_rounded;
        break;
      case VaultType.document:
        icon = Icons.description_rounded;
        break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 104,
                    width: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1.5),
                    ),
                  ),
                  Container(
                    height: 84,
                    width: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: AppColors.highlight, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.highlight.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: AppColors.highlight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentItem.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.highlight.withOpacity(0.4), width: 1),
              ),
              child: Text(
                _currentItem.type.name.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.highlight, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool obscure = false, bool isRevealed = false, VoidCallback? onRevealToggle, VoidCallback? onWebsiteTap}) {
    if (value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  obscure && !isRevealed ? '••••••••••••••••' : value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: obscure && !isRevealed ? FontWeight.bold : FontWeight.normal,
                    fontFamily: obscure ? 'monospace' : null,
                  ),
                ),
              ),
              if (obscure && onRevealToggle != null)
                IconButton(
                  icon: Icon(isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  onPressed: onRevealToggle,
                  color: AppColors.highlight,
                  visualDensity: VisualDensity.compact,
                ),
              if (onWebsiteTap != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  onPressed: onWebsiteTap,
                  color: AppColors.highlight,
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => _copyToClipboard(label, value),
                color: AppColors.highlight,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection() {
    final list = <Widget>[];

    void addGroupCard(List<Widget> rows) {
      list.add(
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ),
      );
    }

    switch (_currentItem.type) {
      case VaultType.password:
        final rows = <Widget>[];
        if (_currentItem.username != null) rows.add(_buildDetailRow('Username', _currentItem.username!));
        if (_currentItem.email != null) rows.add(_buildDetailRow('Email Address', _currentItem.email!));
        if (_currentItem.password != null) {
          rows.add(_buildDetailRow(
            'Password',
            _currentItem.password!,
            obscure: true,
            isRevealed: _revealPassword,
            onRevealToggle: () => setState(() => _revealPassword = !_revealPassword),
          ));
        }
        if (_currentItem.website != null) rows.add(_buildDetailRow('Website URL', _currentItem.website!));
        if (rows.isNotEmpty) addGroupCard(rows);
        break;

      case VaultType.apiKey:
        final rows = <Widget>[];
        if (_currentItem.service != null) rows.add(_buildDetailRow('Service/Provider', _currentItem.service!));
        if (_currentItem.apiKey != null) {
          rows.add(_buildDetailRow(
            'API Key',
            _currentItem.apiKey!,
            obscure: true,
            isRevealed: _revealApiKey,
            onRevealToggle: () => setState(() => _revealApiKey = !_revealApiKey),
          ));
        }
        if (_currentItem.secretKey != null) {
          rows.add(_buildDetailRow(
            'Secret Key',
            _currentItem.secretKey!,
            obscure: true,
            isRevealed: _revealSecretKey,
            onRevealToggle: () => setState(() => _revealSecretKey = !_revealSecretKey),
          ));
        }
        if (_currentItem.environment != null) rows.add(_buildDetailRow('Environment', _currentItem.environment!));
        if (rows.isNotEmpty) addGroupCard(rows);
        break;

      case VaultType.email:
        final rows = <Widget>[];
        if (_currentItem.email != null) rows.add(_buildDetailRow('Email Address', _currentItem.email!));
        if (_currentItem.username != null) rows.add(_buildDetailRow('Username', _currentItem.username!));
        if (_currentItem.password != null && _currentItem.password!.isNotEmpty) {
          rows.add(_buildDetailRow(
            'Password',
            _currentItem.password!,
            obscure: true,
            isRevealed: _revealPassword,
            onRevealToggle: () => setState(() => _revealPassword = !_revealPassword),
          ));
        }
        if (rows.isNotEmpty) addGroupCard(rows);
        break;

      case VaultType.note:
        if (_currentItem.content != null && _currentItem.content!.isNotEmpty) {
          list.add(
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Secure Note Content', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      _currentItem.content!,
                      style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard('Secure Note Content', _currentItem.content!),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Content'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        break;

      case VaultType.image:
      case VaultType.document:
        if (_currentItem.fileVaultPath != null) {
          final sizeKb = _currentItem.fileSize != null ? (_currentItem.fileSize! / 1024).toStringAsFixed(1) : '0';
          list.add(
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Encrypted File Attachment', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          foregroundColor: AppColors.highlight,
                          child: Icon(_currentItem.type == VaultType.image ? Icons.image_rounded : Icons.description_rounded),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentItem.originalFileName ?? 'Attachment',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Size: $sizeKb KB • Type: ${_currentItem.mimeType ?? "unknown"}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileViewerScreen(
                              vaultState: widget.vaultState,
                              vaultRelativePath: _currentItem.fileVaultPath!,
                              originalName: _currentItem.originalFileName ?? 'decrypted_file',
                              mimeType: _currentItem.mimeType,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_open_rounded, color: Colors.black),
                      label: const Text('Decrypt & View Attachment'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        break;

      case VaultType.card:
        final rows = <Widget>[];
        if (_currentItem.cardHolderName != null) rows.add(_buildDetailRow('Card Holder Name', _currentItem.cardHolderName!));
        if (_currentItem.company != null) rows.add(_buildDetailRow('Company', _currentItem.company!));
        if (_currentItem.phone != null) rows.add(_buildDetailRow('Phone Number', _currentItem.phone!));
        if (_currentItem.email != null) rows.add(_buildDetailRow('Email Address', _currentItem.email!));
        if (_currentItem.website != null) rows.add(_buildDetailRow('Website', _currentItem.website!));
        if (rows.isNotEmpty) addGroupCard(rows);

        // Attachment card too if exists
        if (_currentItem.fileVaultPath != null) {
          list.add(const SizedBox(height: 12));
          list.add(
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Card Photographic Copy', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileViewerScreen(
                              vaultState: widget.vaultState,
                              vaultRelativePath: _currentItem.fileVaultPath!,
                              originalName: _currentItem.originalFileName ?? 'card_photo.jpg',
                              mimeType: _currentItem.mimeType,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_rounded, color: Colors.black),
                      label: const Text('View Card Image'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        break;
    }

    if (_currentItem.notes != null && _currentItem.notes!.isNotEmpty && _currentItem.type != VaultType.note) {
      list.add(const SizedBox(height: 12));
      list.add(
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Additional Notes', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _currentItem.notes!,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: list);
  }

  Widget _buildTagsCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tags', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentItem.tags.map((tag) {
                return Chip(
                  backgroundColor: AppColors.highlight.withOpacity(0.12),
                  labelStyle: const TextStyle(color: AppColors.highlight, fontWeight: FontWeight.bold, fontSize: 11),
                  side: const BorderSide(color: AppColors.border),
                  label: Text(tag),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Created:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                Text(dateFormat.format(_currentItem.createdAt), style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Updated:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                Text(dateFormat.format(_currentItem.updatedAt), style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _editItem,
            icon: const Icon(Icons.edit_rounded, color: Colors.black),
            label: const Text('Edit Item'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _shareItemDetails,
          icon: const Icon(Icons.share_rounded, color: AppColors.highlight),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          tooltip: 'Share Item Details',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _deleteItem,
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
          tooltip: 'Delete Item',
        ),
      ],
    );
  }
}
