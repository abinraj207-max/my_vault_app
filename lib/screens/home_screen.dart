import 'package:flutter/material.dart';
import '../models/vault_models.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';
import 'item_list_screen.dart';
import 'item_detail_screen.dart';
import 'edit_item_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VaultState vaultState;

  const HomeScreen({super.key, required this.vaultState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      default: return false;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  List<VaultItem> _getFilteredItems() {
    final query = _searchQuery.toLowerCase().trim();
    final allItems = widget.vaultState.items;

    if (query.isEmpty) {
      return allItems;
    }

    return allItems.where((item) {
      final matchesTitle = item.title.toLowerCase().contains(query);
      final matchesTags = item.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );
      final matchesCategory = item.type.name.toLowerCase().contains(query);

      // Secondary text fields
      final matchesUsername =
          item.username?.toLowerCase().contains(query) ?? false;
      final matchesEmail = item.email?.toLowerCase().contains(query) ?? false;
      final matchesCompany =
          item.company?.toLowerCase().contains(query) ?? false;
      final matchesWebsite =
          item.website?.toLowerCase().contains(query) ?? false;

      return matchesTitle ||
          matchesTags ||
          matchesCategory ||
          matchesUsername ||
          matchesEmail ||
          matchesCompany ||
          matchesWebsite;
    }).toList();
  }

  int _getItemCount(VaultType type) {
    return widget.vaultState.items.where((e) => e.type == type).length;
  }

  void _showAddBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Add New Item',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (_canView(VaultType.password))
                      _buildAddMenuItem(
                        VaultType.password,
                        Icons.vpn_key_rounded,
                        Colors.blue,
                        'Password',
                      ),
                    if (_canView(VaultType.apiKey))
                      _buildAddMenuItem(
                        VaultType.apiKey,
                        Icons.code_rounded,
                        Colors.indigo,
                        'API Key',
                      ),
                    if (_canView(VaultType.email))
                      _buildAddMenuItem(
                        VaultType.email,
                        Icons.alternate_email_rounded,
                        Colors.teal,
                        'Email',
                      ),
                    if (_canView(VaultType.note))
                      _buildAddMenuItem(
                        VaultType.note,
                        Icons.sticky_note_2_rounded,
                        Colors.amber,
                        'Secure Note',
                      ),
                    if (_canView(VaultType.image))
                      _buildAddMenuItem(
                        VaultType.image,
                        Icons.image_rounded,
                        Colors.green,
                        'Image',
                      ),
                    if (_canView(VaultType.card))
                      _buildAddMenuItem(
                        VaultType.card,
                        Icons.credit_card_rounded,
                        Colors.purple,
                        'Visiting Card',
                      ),
                    if (_canView(VaultType.document))
                      _buildAddMenuItem(
                        VaultType.document,
                        Icons.description_rounded,
                        Colors.orange,
                        'Document',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddMenuItem(
    VaultType type,
    IconData icon,
    Color color,
    String label,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EditItemScreen(vaultState: widget.vaultState, type: type),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.highlight,
            radius: 26,
            child: Icon(icon, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (widget.vaultState.isTeamMember && !(widget.vaultState.currentRole?.canAddItems ?? false)) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _showAddBottomSheet,
      tooltip: 'Add new item',
      child: const Icon(Icons.add_rounded, size: 28, color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final recentItems = List<VaultItem>.from(widget.vaultState.items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MyVault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(vaultState: widget.vaultState),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.lock_rounded, color: AppColors.highlight),
            tooltip: 'Lock Vault Now',
            onPressed: () {
              widget.vaultState.lockVault();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vault locked securely.'),
                  backgroundColor: AppColors.surfaceVariant,
                ),
              );
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Welcome Greeting
            Text(
              '${_getGreeting()} 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // const Text(
            //   'Your data is 100% secure',
            //   style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            // ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search your vault...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: AppColors.highlight,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.highlight,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await widget.vaultState.syncWithCloud();
                },
                color: AppColors.highlight,
                child: _searchQuery.isNotEmpty
                    ? _buildSearchResults(filteredItems)
                    : _buildDashboard(recentItems),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildDashboard(List<VaultItem> recents) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        // High-Tech Security Status Banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.highlight.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.highlight.withOpacity(0.04),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: AppColors.highlight.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.gpp_good_rounded,
                      color: AppColors.highlight,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'SECURE STORAGE ACTIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: AppColors.highlight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'AES-256-GCM hardware-backed offline encryption is protecting your files and credentials.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Categories Title
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Categories Grid
        SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            if (_canView(VaultType.password))
              _buildCategoryCard(
                VaultType.password,
                Icons.vpn_key_rounded,
                'Passwords',
              ),
            if (_canView(VaultType.apiKey))
              _buildCategoryCard(
                VaultType.apiKey,
                Icons.code_rounded,
                'API Keys',
              ),
            if (_canView(VaultType.email))
              _buildCategoryCard(
                VaultType.email,
                Icons.alternate_email_rounded,
                'Emails',
              ),
            if (_canView(VaultType.note))
              _buildCategoryCard(
                VaultType.note,
                Icons.sticky_note_2_rounded,
                'Secure Notes',
              ),
            if (_canView(VaultType.image))
              _buildCategoryCard(VaultType.image, Icons.image_rounded, 'Images'),
            if (_canView(VaultType.card))
              _buildCategoryCard(
                VaultType.card,
                Icons.credit_card_rounded,
                'Cards',
              ),
            if (_canView(VaultType.document))
              _buildCategoryCard(
                VaultType.document,
                Icons.description_rounded,
                'Documents',
              ),
            _buildCategoryCard(
              null,
              Icons.grid_view_rounded,
              'All Items',
            ),
          ],
        ),

        // Recent items Title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemListScreen(
                          vaultState: widget.vaultState,
                          categoryType: null,
                          categoryTitle: 'All Items',
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View all',
                    style: TextStyle(color: AppColors.highlight),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recent Items list
        recents.isEmpty
            ? SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your vault is empty.\nTap the + button below to add your first item.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = recents[index];
                  return _buildItemCard(item);
                }, childCount: recents.length > 5 ? 5 : recents.length),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildCategoryCard(VaultType? type, IconData icon, String title) {
    final count = type != null
        ? _getItemCount(type)
        : widget.vaultState.items.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemListScreen(
                vaultState: widget.vaultState,
                categoryType: type,
                categoryTitle: title,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                foregroundColor: AppColors.highlight,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withOpacity(count > 0 ? 1 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: count > 0 ? Colors.black : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(VaultItem item) {
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.highlight,
          child: Icon(icon, size: 20),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.highlight,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ItemDetailScreen(vaultState: widget.vaultState, item: item),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildSearchResults(List<VaultItem> results) {
    if (results.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No items found matching your search.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Search Results (${results.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return _buildItemCard(results[index]);
            },
          ),
        ),
      ],
    );
  }
}
