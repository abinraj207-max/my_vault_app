import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../models/vault_models.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';

class EditItemScreen extends StatefulWidget {
  final VaultState vaultState;
  final VaultType type;
  final VaultItem? itemToEdit; // Null if creating new

  const EditItemScreen({
    super.key,
    required this.vaultState,
    required this.type,
    this.itemToEdit,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;

  // Form Controllers
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final _notesController = TextEditingController();

  // Passwords / Emails / Cards
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();

  // API Keys
  final _serviceController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _environmentController = TextEditingController();

  // Secure Notes
  final _contentController = TextEditingController();

  // Visiting Cards specific
  final _cardHolderController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();

  // Selected File references
  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFileMime;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.itemToEdit != null;

    if (_isEditing) {
      final item = widget.itemToEdit!;
      _titleController.text = item.title;
      _tagsController.text = item.tags.join(', ');
      _notesController.text = item.notes ?? '';

      _usernameController.text = item.username ?? '';
      _emailController.text = item.email ?? '';
      _passwordController.text = item.password ?? '';
      _websiteController.text = item.website ?? '';

      _serviceController.text = item.service ?? '';
      _apiKeyController.text = item.apiKey ?? '';
      _secretKeyController.text = item.secretKey ?? '';
      _environmentController.text = item.environment ?? '';

      _contentController.text = item.content ?? '';

      _cardHolderController.text = item.cardHolderName ?? '';
      _companyController.text = item.company ?? '';
      _phoneController.text = item.phone ?? '';

      if (item.fileVaultPath != null) {
        _selectedFileName = item.originalFileName;
        _selectedFileSize = item.fileSize;
        _selectedFileMime = item.mimeType;
      }
    }
  }

  /// Generate a proper UUID v4 string (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)
  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _serviceController.dispose();
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _environmentController.dispose();
    _contentController.dispose();
    _cardHolderController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedFile = File(picked.path);
          _selectedFileName = p.basename(picked.path);
          _selectedFileSize = _selectedFile!.lengthSync();
          _selectedFileMime = 'image/${p.extension(picked.path).replaceAll('.', '')}';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
          _selectedFileSize = result.files.single.size;
          _selectedFileMime = result.files.single.extension != null
              ? 'application/${result.files.single.extension}'
              : 'application/octet-stream';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if attachment is required and not present
    final isAttachmentType = widget.type == VaultType.image || widget.type == VaultType.document;
    if (isAttachmentType && !_isEditing && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to encrypt')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? fileVaultPath = widget.itemToEdit?.fileVaultPath;
      String? originalFileName = widget.itemToEdit?.originalFileName;
      String? mimeType = widget.itemToEdit?.mimeType;
      int? fileSize = widget.itemToEdit?.fileSize;

      // Process new file attachment if selected
      if (_selectedFile != null) {
        // Encrypt and add file to vault directory
        fileVaultPath = await widget.vaultState.addFileToVault(
          _selectedFile!,
          widget.type,
          _selectedFileName!,
        );
        originalFileName = _selectedFileName;
        fileSize = _selectedFileSize;
        mimeType = _selectedFileMime;
      }

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final now = DateTime.now();

      final item = VaultItem(
        id: widget.itemToEdit?.id ?? _generateUuidV4(),
        type: widget.type,
        title: _titleController.text.trim(),
        tags: tags,
        createdAt: widget.itemToEdit?.createdAt ?? now,
        updatedAt: now,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        website: _websiteController.text.trim(),
        service: _serviceController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        secretKey: _secretKeyController.text,
        environment: _environmentController.text.trim(),
        content: _contentController.text.trim(),
        fileVaultPath: fileVaultPath,
        originalFileName: originalFileName,
        mimeType: mimeType,
        fileSize: fileSize,
        cardHolderName: _cardHolderController.text.trim(),
        company: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (_isEditing) {
        await widget.vaultState.updateItem(item);
      } else {
        await widget.vaultState.addItem(item);
      }

      if (mounted) {
        Navigator.pop(context, item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Item updated successfully!' : 'Item added securely!'),
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit ${_currentItemLabel()}' : 'Add ${_currentItemLabel()}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _isLoading ? null : _save,
            tooltip: 'Save Item',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.highlight),
                  SizedBox(height: 16),
                  Text('Encrypting and securing item...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Title / Label',
                        prefixIcon: Icon(Icons.bookmark_border_rounded, color: AppColors.highlight),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Custom fields based on category type
                    ..._buildTypeSpecificFields(),

                    // Tags field
                    TextFormField(
                      controller: _tagsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        prefixIcon: Icon(Icons.local_offer_outlined, color: AppColors.highlight),
                        hintText: 'work, personal, finance',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Common Notes field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        prefixIcon: Icon(Icons.notes_rounded, color: AppColors.highlight),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(_isEditing ? 'Save Changes' : 'Secure Item'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String _currentItemLabel() {
    switch (widget.type) {
      case VaultType.password:
        return 'Password';
      case VaultType.apiKey:
        return 'API Key';
      case VaultType.email:
        return 'Email Account';
      case VaultType.note:
        return 'Secure Note';
      case VaultType.image:
        return 'Encrypted Image';
      case VaultType.card:
        return 'Visiting Card';
      case VaultType.document:
        return 'Document';
    }
  }

  List<Widget> _buildTypeSpecificFields() {
    final fields = <Widget>[];

    switch (widget.type) {
      case VaultType.password:
        fields.addAll([
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_open_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Website URL',
              prefixIcon: Icon(Icons.web_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
        ]);
        break;

      case VaultType.apiKey:
        fields.addAll([
          TextFormField(
            controller: _serviceController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Service/Platform',
              prefixIcon: Icon(Icons.dns_rounded, color: AppColors.highlight),
              hintText: 'AWS, Firebase, Stripe',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apiKeyController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'API Key',
              prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _secretKeyController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Secret Key',
              prefixIcon: Icon(Icons.key_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _environmentController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Environment (Dev / Prod)',
              prefixIcon: Icon(Icons.toggle_on_outlined, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
        ]);
        break;

      case VaultType.email:
        fields.addAll([
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.highlight),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username/Alias (Optional)',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email Password',
              prefixIcon: Icon(Icons.lock_open_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
        ]);
        break;

      case VaultType.note:
        fields.addAll([
          TextFormField(
            controller: _contentController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Secure Content',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined, color: AppColors.highlight),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter secure note content';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ]);
        break;

      case VaultType.image:
        fields.add(_buildFileSelectorCard(
          icon: Icons.image_rounded,
          selectLabel: 'Select Image',
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (context) {
                return SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library_rounded, color: AppColors.highlight),
                        title: const Text('Choose from Gallery'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.camera_alt_rounded, color: AppColors.highlight),
                        title: const Text('Take a Photo'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ));
        fields.add(const SizedBox(height: 16));
        break;

      case VaultType.document:
        fields.add(_buildFileSelectorCard(
          icon: Icons.description_rounded,
          selectLabel: 'Select Document',
          onTap: _pickFile,
        ));
        fields.add(const SizedBox(height: 16));
        break;

      case VaultType.card:
        fields.addAll([
          TextFormField(
            controller: _cardHolderController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Card Holder Name',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Company / Business',
              prefixIcon: Icon(Icons.business_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Website',
              prefixIcon: Icon(Icons.web_rounded, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 16),
          _buildFileSelectorCard(
            icon: Icons.camera_rounded,
            selectLabel: 'Attach Card Image',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ]);
        break;
    }

    return fields;
  }

  Widget _buildFileSelectorCard({
    required IconData icon,
    required String selectLabel,
    required VoidCallback onTap,
  }) {
    final hasFile = _selectedFileName != null;
    final sizeKb = _selectedFileSize != null ? (_selectedFileSize! / 1024).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          if (hasFile) ...[
            Row(
              children: [
                Icon(icon, color: AppColors.highlight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFileName!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: $sizeKb KB • Type: ${_selectedFileMime ?? "unknown"}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.highlight),
                  onPressed: onTap,
                )
              ],
            )
          ] else ...[
            TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: AppColors.highlight),
              label: Text(selectLabel, style: const TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
