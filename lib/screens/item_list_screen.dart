import 'package:flutter/material.dart';
import '../models/vault_models.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';
import 'item_detail_screen.dart';
import 'edit_item_screen.dart';

class ItemListScreen extends StatefulWidget {
  final VaultState vaultState;
  final VaultType? categoryType;
  final String categoryTitle;

  const ItemListScreen({
    super.key,
    required this.vaultState,
    required this.categoryType,
    required this.categoryTitle,
  });

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultItem> _getItems() {
    final type = widget.categoryType;
    final allItems = widget.vaultState.items;

    // Filter by category
    final categoryItems = type != null
        ? allItems.where((e) => e.type == type).toList()
        : allItems;

    // Filter by search query
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

  @override
  Widget build(BuildContext context) {
    final items = _getItems();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input
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
                hintText: 'Search in ${widget.categoryTitle}...',
                prefixIcon: const Icon(Icons.search_rounded),
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

          // Items List
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
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No items in this category'
                                      : 'No matching items found',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
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
                        return _buildItemTile(item);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (widget.categoryType == null) return null;
    
    if (widget.vaultState.isTeamMember && !(widget.vaultState.currentRole?.canAddItems ?? false)) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditItemScreen(
              vaultState: widget.vaultState,
              type: widget.categoryType!,
            ),
          ),
        );
      },
      tooltip: 'Add New Item',
      child: const Icon(Icons.add_rounded),
    );
  }

  Widget _buildItemTile(VaultItem item) {
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
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.tags.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.tags.first,
                  style: const TextStyle(fontSize: 10, color: AppColors.highlight, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.highlight),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(
                vaultState: widget.vaultState,
                item: item,
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
