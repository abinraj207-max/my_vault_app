import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vault_models.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';
import 'edit_item_screen.dart';
import 'file_viewer_screen.dart';
import 'settings_screen.dart';
import 'team_members_screen.dart';
import 'roles_screen.dart';
import 'cloud_sync_screen.dart';

enum DesktopView {
  items,
  teamMembers,
  roles,
  cloudSync,
  settings,
}

class HomeScreenDesktop extends StatefulWidget {
  final VaultState vaultState;

  const HomeScreenDesktop({super.key, required this.vaultState});

  @override
  State<HomeScreenDesktop> createState() => _HomeScreenDesktopState();
}

class _HomeScreenDesktopState extends State<HomeScreenDesktop> {
  DesktopView _currentView = DesktopView.items;
  VaultType? _selectedCategoryType = VaultType.email; // Default to email as in mockup
  VaultItem? _selectedItem;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _revealPassword = false;
  bool _revealApiKey = false;
  bool _revealSecretKey = false;

  @override
  void initState() {
    super.initState();
    _selectDefaultItem();
    widget.vaultState.addListener(_onVaultStateChange);
  }

  @override
  void dispose() {
    widget.vaultState.removeListener(_onVaultStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onVaultStateChange() {
    if (mounted) {
      setState(() {
        if (_selectedItem != null) {
          final exists = widget.vaultState.items.any((e) => e.id == _selectedItem!.id);
          if (exists) {
            _selectedItem = widget.vaultState.items.firstWhere((e) => e.id == _selectedItem!.id);
          } else {
            _selectedItem = null;
            _selectDefaultItem();
          }
        } else {
          _selectDefaultItem();
        }
      });
    }
  }

  void _selectDefaultItem() {
    final filtered = _getItems();
    if (filtered.isNotEmpty) {
      _selectedItem = filtered.first;
    } else {
      _selectedItem = null;
    }
    _revealPassword = false;
    _revealApiKey = false;
    _revealSecretKey = false;
  }

  bool _canView(VaultType type) {
    if (!widget.vaultState.isTeamMember) return true;
    final role = widget.vaultState.currentRole;
    if (role == null) return false;

    switch (type) {
      case VaultType.password: return role.canViewPasswords;
      case VaultType.apiKey: return role.canViewApiKeys;
      case VaultType.email: return role.canViewEmails;
      case VaultType.note: return role.canViewNotes;
      case VaultType.image: return role.canViewImages;
      case VaultType.card: return role.canViewCards;
      case VaultType.document: return role.canViewDocuments;
    }
  }

  List<VaultItem> _getItems() {
    final type = _selectedCategoryType;
    final allItems = widget.vaultState.items;

    final categoryItems = type != null
        ? allItems.where((e) => e.type == type).toList()
        : allItems;

    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) {
      return categoryItems;
    }

    return categoryItems.where((item) {
      final matchesTitle = item.title.toLowerCase().contains(query);
      final matchesTags = item.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesUsername = item.username?.toLowerCase().contains(query) ?? false;
      final matchesEmail = item.email?.toLowerCase().contains(query) ?? false;
      final matchesCompany = item.company?.toLowerCase().contains(query) ?? false;
      final matchesWebsite = item.website?.toLowerCase().contains(query) ?? false;

      return matchesTitle || matchesTags || matchesUsername || matchesEmail || matchesCompany || matchesWebsite;
    }).toList();
  }

  int _getItemCount(VaultType type) {
    return widget.vaultState.items.where((e) => e.type == type).length;
  }

  String _getCategoryName(VaultType type) {
    switch (type) {
      case VaultType.password: return 'Passwords';
      case VaultType.apiKey: return 'API Keys';
      case VaultType.email: return 'Emails';
      case VaultType.note: return 'Secure Notes';
      case VaultType.image: return 'Images';
      case VaultType.card: return 'Cards';
      case VaultType.document: return 'Documents';
    }
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

  void _showAddEditDialog(VaultType type, {VaultItem? itemToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: MediaQuery.of(context).size.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
          ),
          child: EditItemScreen(
            vaultState: widget.vaultState,
            type: type,
            itemToEdit: itemToEdit,
          ),
        ),
      ),
    ).then((_) {
      _onVaultStateChange();
    });
  }

  Future<void> _deleteSelectedItem() async {
    if (_selectedItem == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );

    if (confirmed == true) {
      final itemToDelete = _selectedItem!;
      await widget.vaultState.deleteItem(itemToDelete);
      setState(() {
        _selectedItem = null;
        _selectDefaultItem();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
      }
    }
  }

  void _shareSelectedItem() {
    if (_selectedItem == null) return;
    final item = _selectedItem!;
    final sb = StringBuffer();
    sb.writeln('MyVault - Shared Details');
    sb.writeln('Title: ${item.title}');
    sb.writeln('Category: ${item.type.name.toUpperCase()}');

    if (item.username != null && item.username!.isNotEmpty) {
      sb.writeln('Username: ${item.username}');
    }
    if (item.email != null && item.email!.isNotEmpty) {
      sb.writeln('Email: ${item.email}');
    }
    if (item.website != null && item.website!.isNotEmpty) {
      sb.writeln('Website: ${item.website}');
    }
    if (item.notes != null && item.notes!.isNotEmpty) {
      sb.writeln('Notes: ${item.notes}');
    }

    Share.share(sb.toString(), subject: item.title);
  }

  void _showAddCategoryMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Add New Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key_rounded, color: Colors.blue),
                title: const Text('Password', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.password); },
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded, color: Colors.indigo),
                title: const Text('API Key', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.apiKey); },
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded, color: Colors.teal),
                title: const Text('Email', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.email); },
              ),
              ListTile(
                leading: const Icon(Icons.sticky_note_2_rounded, color: Colors.amber),
                title: const Text('Secure Note', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.note); },
              ),
              ListTile(
                leading: const Icon(Icons.image_rounded, color: Colors.green),
                title: const Text('Image', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.image); },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_rounded, color: Colors.purple),
                title: const Text('Card', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.card); },
              ),
              ListTile(
                leading: const Icon(Icons.description_rounded, color: Colors.orange),
                title: const Text('Document', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showAddEditDialog(VaultType.document); },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. Sidebar Panel (Left)
          _buildSidebarPanel(),
          const VerticalDivider(width: 1, color: AppColors.border),

          // 2. Main Content Area (Right)
          Expanded(
            child: _buildMainContentArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarPanel() {
    final showTeam = !widget.vaultState.isTeamMember || (widget.vaultState.currentRole?.canManageTeam ?? false);

    return Container(
      width: 260,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header in Card Style (Mockup top-left card)
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.highlight, size: 36),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MyVault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    SizedBox(height: 2),
                    Text('Zero-Knowledge', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                if (widget.vaultState.isSyncing)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.highlight)),
              ],
            ),
          ),

          // Scrollable navigation list
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSidebarSectionHeader('Vault Items'),
                _buildSidebarItem(
                  icon: Icons.grid_view_rounded,
                  label: 'All Items',
                  selected: _currentView == DesktopView.items && _selectedCategoryType == null,
                  onTap: () => setState(() {
                    _currentView = DesktopView.items;
                    _selectedCategoryType = null;
                    _selectDefaultItem();
                  }),
                ),
                if (_canView(VaultType.password))
                  _buildSidebarItem(
                    icon: Icons.vpn_key_rounded,
                    label: 'Passwords',
                    count: _getItemCount(VaultType.password),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.password,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.password;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.apiKey))
                  _buildSidebarItem(
                    icon: Icons.code_rounded,
                    label: 'API Keys',
                    count: _getItemCount(VaultType.apiKey),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.apiKey,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.apiKey;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.email))
                  _buildSidebarItem(
                    icon: Icons.alternate_email_rounded,
                    label: 'Emails',
                    count: _getItemCount(VaultType.email),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.email,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.email;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.note))
                  _buildSidebarItem(
                    icon: Icons.sticky_note_2_rounded,
                    label: 'Secure Notes',
                    count: _getItemCount(VaultType.note),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.note,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.note;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.image))
                  _buildSidebarItem(
                    icon: Icons.image_rounded,
                    label: 'Images',
                    count: _getItemCount(VaultType.image),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.image,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.image;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.card))
                  _buildSidebarItem(
                    icon: Icons.credit_card_rounded,
                    label: 'Cards',
                    count: _getItemCount(VaultType.card),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.card,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.card;
                      _selectDefaultItem();
                    }),
                  ),
                if (_canView(VaultType.document))
                  _buildSidebarItem(
                    icon: Icons.description_rounded,
                    label: 'Documents',
                    count: _getItemCount(VaultType.document),
                    selected: _currentView == DesktopView.items && _selectedCategoryType == VaultType.document,
                    onTap: () => setState(() {
                      _currentView = DesktopView.items;
                      _selectedCategoryType = VaultType.document;
                      _selectDefaultItem();
                    }),
                  ),

                if (showTeam) ...[
                  _buildSidebarSectionHeader('Team & Admin'),
                  _buildSidebarItem(
                    icon: Icons.group_rounded,
                    label: 'Team Members',
                    selected: _currentView == DesktopView.teamMembers,
                    onTap: () => setState(() { _currentView = DesktopView.teamMembers; }),
                  ),
                  _buildSidebarItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Roles',
                    selected: _currentView == DesktopView.roles,
                    onTap: () => setState(() { _currentView = DesktopView.roles; }),
                  ),
                ],

                _buildSidebarSectionHeader('Cloud & System'),
                _buildSidebarItem(
                  icon: Icons.cloud_queue_rounded,
                  label: 'Cloud Sync',
                  selected: _currentView == DesktopView.cloudSync,
                  onTap: () => setState(() { _currentView = DesktopView.cloudSync; }),
                ),
                _buildSidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: _currentView == DesktopView.settings,
                  onTap: () => setState(() { _currentView = DesktopView.settings; }),
                ),
              ],
            ),
          ),

          // Sidebar Footer: Red-bordered Lock Button (Mockup bottom-left)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF5350),
                side: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                widget.vaultState.lockVault();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vault locked securely.'), backgroundColor: AppColors.surfaceVariant),
                );
              },
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Lock Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.highlight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    int? count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Material(
        color: selected ? AppColors.highlight.withOpacity(0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.highlight.withOpacity(0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: selected ? AppColors.highlight : AppColors.textSecondary, size: 20),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: count != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.highlight : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? Colors.transparent : AppColors.border),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildMainContentArea() {
    switch (_currentView) {
      case DesktopView.items:
        return Row(
          children: [
            // Middle Panel: Master Items List (Width 360)
            SizedBox(
              width: 360,
              child: _buildItemListPanel(),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),

            // Right Panel: Detail View Dashboard (takes remaining screen)
            Expanded(
              child: _buildDetailPanel(),
            ),
          ],
        );

      case DesktopView.teamMembers:
        return TeamMembersScreen(
          supabaseService: widget.vaultState.supabaseService,
          vaultState: widget.vaultState,
        );

      case DesktopView.roles:
        return RolesScreen(
          supabaseService: widget.vaultState.supabaseService,
        );

      case DesktopView.cloudSync:
        return CloudSyncScreen(
          vaultState: widget.vaultState,
        );

      case DesktopView.settings:
        return SettingsScreen(
          vaultState: widget.vaultState,
        );
    }
  }

  Widget _buildItemListPanel() {
    final items = _getItems();
    final title = _selectedCategoryType != null
        ? _getCategoryName(_selectedCategoryType!)
        : 'All Items';

    final isTeamMember = widget.vaultState.isTeamMember;
    final canAdd = !isTeamMember || (widget.vaultState.currentRole?.canAddItems ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          if (canAdd && _selectedCategoryType != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.highlight),
              tooltip: 'Add new $title',
              onPressed: () => _showAddEditDialog(_selectedCategoryType!),
            ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search box inside card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search $title...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.background,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Scrollable List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await widget.vaultState.syncWithCloud();
                },
                color: AppColors.highlight,
                child: items.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'No matching items found',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = _selectedItem?.id == item.id;
                          return _buildItemTileInline(item, isSelected);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canAdd && _selectedCategoryType == null
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.highlight,
              foregroundColor: Colors.black,
              onPressed: _showAddCategoryMenu,
              tooltip: 'Add new item',
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildItemTileInline(VaultItem item, bool isSelected) {
    IconData icon;
    String subtitle = '';

    switch (item.type) {
      case VaultType.password:
        icon = Icons.vpn_key_rounded;
        subtitle = item.username ?? item.email ?? '';
        break;
      case VaultType.apiKey:
        icon = Icons.code_rounded;
        subtitle = item.service ?? '';
        break;
      case VaultType.email:
        icon = Icons.alternate_email_rounded;
        subtitle = item.email ?? '';
        break;
      case VaultType.note:
        icon = Icons.sticky_note_2_rounded;
        subtitle = item.notes ?? 'Secure Note';
        break;
      case VaultType.image:
        icon = Icons.image_rounded;
        subtitle = 'Encrypted Image';
        break;
      case VaultType.card:
        icon = Icons.credit_card_rounded;
        subtitle = item.company ?? 'Visiting Card';
        break;
      case VaultType.document:
        icon = Icons.description_rounded;
        subtitle = item.originalFileName ?? 'Document';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.highlight.withOpacity(0.12),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: Material(
        color: isSelected ? AppColors.highlight.withOpacity(0.06) : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.highlight : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isSelected ? AppColors.highlight.withOpacity(0.2) : AppColors.surfaceVariant,
            foregroundColor: isSelected ? AppColors.highlight : Colors.white,
            child: Icon(icon, size: 16),
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? AppColors.highlight : Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                )
              : null,
          onTap: () {
            setState(() {
              _selectedItem = item;
              _revealPassword = false;
              _revealApiKey = false;
              _revealSecretKey = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedItem == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 80, color: AppColors.border),
              SizedBox(height: 16),
              Text('Select an item to view details', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    final item = _selectedItem!;
    final isTeamMember = widget.vaultState.isTeamMember;
    final canEdit = !isTeamMember || (widget.vaultState.currentRole?.canEditItems ?? false);
    final canDelete = !isTeamMember || (widget.vaultState.currentRole?.canDeleteItems ?? false);

    // Filter recent items for bottom activity
    final recentItems = List<VaultItem>.from(widget.vaultState.items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final displayRecents = recentItems.take(1).toList(); // Only show active/selected context or most recent

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Visual Header & Quick Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual Header Card
                Expanded(
                  flex: 3,
                  child: _buildVisualHeaderCard(item),
                ),
                const SizedBox(width: 16),
                // Quick Actions Card
                Expanded(
                  flex: 2,
                  child: _buildQuickActionsCard(item, canEdit, canDelete),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Credential Field Values (Left) & Item Info (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Decrypted Values List (e.g. Email Address, Password, Note Content)
                Expanded(
                  flex: 3,
                  child: _buildCredentialValuesCard(item),
                ),
                const SizedBox(width: 16),
                // Item Info Card (Created / Last Updated)
                Expanded(
                  flex: 2,
                  child: _buildItemInfoCard(item),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 3: Details Table & Activity Graph
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Details Card
                Expanded(
                  child: _buildDetailsTableCard(item),
                ),
                const SizedBox(width: 16),
                // Activity Graph Card
                const Expanded(
                  child: SizedBox(
                    height: 236,
                    child: ActivityGraphWidget(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 4: Recent Activity
            _buildRecentActivityCard(displayRecents),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualHeaderCard(VaultItem item) {
    IconData icon;
    switch (item.type) {
      case VaultType.password: icon = Icons.vpn_key_rounded; break;
      case VaultType.apiKey: icon = Icons.code_rounded; break;
      case VaultType.email: icon = Icons.alternate_email_rounded; break;
      case VaultType.note: icon = Icons.sticky_note_2_rounded; break;
      case VaultType.image: icon = Icons.image_rounded; break;
      case VaultType.card: icon = Icons.credit_card_rounded; break;
      case VaultType.document: icon = Icons.description_rounded; break;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Neon Green Icon Circle
          Container(
            height: 64,
            width: 64,
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
            child: Icon(icon, size: 28, color: AppColors.highlight),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Category Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.highlight.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.highlight.withOpacity(0.3)),
            ),
            child: Text(
              item.type.name.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: AppColors.highlight, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(VaultItem item, bool canEdit, bool canDelete) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Edit Action Card
              if (canEdit)
                _buildQuickActionItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: AppColors.highlight,
                  onTap: () => _showAddEditDialog(item.type, itemToEdit: item),
                ),
              // Share Action Card
              _buildQuickActionItem(
                icon: Icons.share_rounded,
                label: 'Share',
                color: AppColors.highlight,
                onTap: _shareSelectedItem,
              ),
              // Delete Action Card
              if (canDelete)
                _buildQuickActionItem(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete',
                  color: const Color(0xFFEF5350),
                  onTap: _deleteSelectedItem,
                ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialValuesCard(VaultItem item) {
    final fields = <Widget>[];

    switch (item.type) {
      case VaultType.password:
        if (item.username != null) fields.add(_buildDecryptedField('Username', item.username!));
        if (item.email != null) fields.add(_buildDecryptedField('Email Address', item.email!));
        if (item.password != null) {
          fields.add(_buildDecryptedField(
            'Password',
            item.password!,
            obscure: true,
            isRevealed: _revealPassword,
            onRevealToggle: () => setState(() => _revealPassword = !_revealPassword),
          ));
        }
        if (item.website != null) {
          fields.add(_buildDecryptedField(
            'Website URL',
            item.website!,
            onWebsiteTap: () async {
              final uri = Uri.parse(item.website!.startsWith('http') ? item.website! : 'https://${item.website}');
              try { await launchUrl(uri); } catch (_) {}
            },
          ));
        }
        break;

      case VaultType.apiKey:
        if (item.service != null) fields.add(_buildDecryptedField('Service/Provider', item.service!));
        if (item.apiKey != null) {
          fields.add(_buildDecryptedField(
            'API Key',
            item.apiKey!,
            obscure: true,
            isRevealed: _revealApiKey,
            onRevealToggle: () => setState(() => _revealApiKey = !_revealApiKey),
          ));
        }
        if (item.secretKey != null) {
          fields.add(_buildDecryptedField(
            'Secret Key',
            item.secretKey!,
            obscure: true,
            isRevealed: _revealSecretKey,
            onRevealToggle: () => setState(() => _revealSecretKey = !_revealSecretKey),
          ));
        }
        if (item.environment != null) fields.add(_buildDecryptedField('Environment', item.environment!));
        break;

      case VaultType.email:
        if (item.email != null) fields.add(_buildDecryptedField('Email Address', item.email!));
        if (item.username != null) fields.add(_buildDecryptedField('Username', item.username!));
        if (item.password != null && item.password!.isNotEmpty) {
          fields.add(_buildDecryptedField(
            'Password',
            item.password!,
            obscure: true,
            isRevealed: _revealPassword,
            onRevealToggle: () => setState(() => _revealPassword = !_revealPassword),
          ));
        }
        break;

      case VaultType.note:
        if (item.content != null) {
          fields.add(_buildDecryptedField('Secure Note Content', item.content!, longText: true));
        }
        break;

      case VaultType.image:
      case VaultType.document:
        if (item.fileVaultPath != null) {
          final sizeKb = item.fileSize != null ? (item.fileSize! / 1024).toStringAsFixed(1) : '0';
          fields.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.highlight,
                    child: Icon(item.type == VaultType.image ? Icons.image_rounded : Icons.description_rounded),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.originalFileName ?? 'Attachment', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Size: $sizeKb KB • Type: ${item.mimeType ?? "unknown"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FileViewerScreen(
                            vaultState: widget.vaultState,
                            vaultRelativePath: item.fileVaultPath!,
                            originalName: item.originalFileName ?? 'decrypted_file',
                            mimeType: item.mimeType,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.black),
                    label: const Text('View', style: TextStyle(color: Colors.black, fontSize: 12)),
                  )
                ],
              ),
            ),
          );
        }
        break;

      case VaultType.card:
        if (item.cardHolderName != null) fields.add(_buildDecryptedField('Card Holder Name', item.cardHolderName!));
        if (item.company != null) fields.add(_buildDecryptedField('Company', item.company!));
        if (item.phone != null) fields.add(_buildDecryptedField('Phone Number', item.phone!));
        if (item.email != null) fields.add(_buildDecryptedField('Email Address', item.email!));
        if (item.website != null) {
          fields.add(_buildDecryptedField(
            'Website',
            item.website!,
            onWebsiteTap: () async {
              final uri = Uri.parse(item.website!.startsWith('http') ? item.website! : 'https://${item.website}');
              try { await launchUrl(uri); } catch (_) {}
            },
          ));
        }
        break;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Decrypted Credentials', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Expanded(
            child: fields.isEmpty
                ? const Center(child: Text('No credential details available', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: fields,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecryptedField(
    String label,
    String value, {
    bool obscure = false,
    bool isRevealed = false,
    VoidCallback? onRevealToggle,
    VoidCallback? onWebsiteTap,
    bool longText = false,
  }) {
    if (value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    obscure && !isRevealed ? '••••••••••••••••' : value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontFamily: obscure && !isRevealed ? 'monospace' : null,
                      height: longText ? 1.4 : null,
                    ),
                    maxLines: longText ? 3 : 1,
                    overflow: longText ? TextOverflow.ellipsis : TextOverflow.fade,
                  ),
                ),
                if (obscure && onRevealToggle != null)
                  IconButton(
                    icon: Icon(isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                    onPressed: onRevealToggle,
                    color: AppColors.highlight,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onWebsiteTap != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    onPressed: onWebsiteTap,
                    color: AppColors.highlight,
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () => _copyToClipboard(label, value),
                  color: AppColors.highlight,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemInfoCard(VaultItem item) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Item Info',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const Spacer(),
          // Created Date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Created', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFormat.format(item.createdAt)}  ${timeFormat.format(item.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Last Updated Date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.watch_later_rounded, size: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Last Updated', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFormat.format(item.updatedAt)}  ${timeFormat.format(item.updatedAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDetailsTableCard(VaultItem item) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    return Container(
      height: 236,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          _buildDetailsTableRow('Type', item.type.name.toUpperCase(), isValueGreen: true),
          const Divider(color: AppColors.border, height: 16),
          _buildDetailsTableRow('Username', item.username ?? item.email ?? 'N/A'),
          const Divider(color: AppColors.border, height: 16),
          _buildDetailsTableRow('Added On', dateFormat.format(item.createdAt)),
          const Divider(color: AppColors.border, height: 16),
          _buildDetailsTableRow('Last Modified', dateFormat.format(item.updatedAt)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDetailsTableRow(String label, String value, {bool isValueGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              label == 'Type'
                  ? Icons.label_rounded
                  : label == 'Username'
                      ? Icons.person_rounded
                      : label == 'Added On'
                          ? Icons.date_range_rounded
                          : Icons.edit_note_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: isValueGreen ? AppColors.highlight : Colors.white,
            fontSize: 13,
            fontWeight: isValueGreen ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard(List<VaultItem> recents) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (recents.isEmpty)
            const Text('No recent activity', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            Column(
              children: recents.map((item) {
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.highlight,
                      child: const Icon(Icons.alternate_email_rounded, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                          const SizedBox(height: 2),
                          const Text('Email updated', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      dateFormat.format(item.updatedAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class ActivityGraphWidget extends StatelessWidget {
  const ActivityGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _ActivityGraphPainter(),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppColors.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.highlight.withOpacity(0.18),
          AppColors.highlight.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final points = [
      Offset(size.width * 0.08, size.height * 0.7), // Aug 16
      Offset(size.width * 0.22, size.height * 0.45), // Aug 17
      Offset(size.width * 0.36, size.height * 0.75), // Aug 18
      Offset(size.width * 0.5, size.height * 0.25),  // Aug 19
      Offset(size.width * 0.64, size.height * 0.7),  // Aug 20
      Offset(size.width * 0.78, size.height * 0.48), // Aug 21
      Offset(size.width * 0.92, size.height * 0.65), // Aug 22
    ];

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Draw background fill under path
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height * 0.85);
    fillPath.lineTo(points[0].dx, size.height * 0.85);
    fillPath.close();
    canvas.drawPath(fillPath, paintFill);

    // Draw the green Bezier curve
    canvas.drawPath(path, paintLine);

    // Draw active indicator glow on last point (Aug 22)
    final lastPt = points.last;
    final dotPaint = Paint()
      ..color = AppColors.highlight
      ..style = PaintingStyle.fill;
    
    final glowPaint = Paint()
      ..color = AppColors.highlight.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lastPt, 8, glowPaint);
    canvas.drawCircle(lastPt, 4, dotPaint);

    // Draw X-axis dates
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final dates = ['Aug 16', 'Aug 17', 'Aug 18', 'Aug 19', 'Aug 20', 'Aug 21', 'Aug 22'];
    for (int i = 0; i < points.length; i++) {
      textPainter.text = TextSpan(
        text: dates[i],
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(points[i].dx - textPainter.width / 2, size.height * 0.9));
    }

    // Draw Y-axis labels (0, 1, 2, 3)
    final yLabels = ['3', '2', '1', '0'];
    final yPositions = [size.height * 0.2, size.height * 0.42, size.height * 0.64, size.height * 0.85];
    for (int i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yPositions[i] - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
