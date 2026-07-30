// lib/education/education_resources.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/education_user.dart';

class EducationResources extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const EducationResources({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationResources> createState() => _EducationResourcesState();
}

class _EducationResourcesState extends State<EducationResources> {
  String _selectedCategory = 'all';
  String _sortBy = 'newest';

  final List<String> _categories = [
    'all',
    'studyMaterials',
    'videos',
    'documents',
    'visualResources',
    'externalLinks',
  ];

  final Map<String, String> _categoryLabels = {
    'all': 'All Resources',
    'studyMaterials': '📚 Study Materials',
    'videos': '📹 Videos',
    'documents': '📄 Documents',
    'visualResources': '🖼️ Visual Resources',
    'externalLinks': '🔗 External Links',
  };

  final Map<String, IconData> _categoryIcons = {
    'all': Icons.apps,
    'studyMaterials': Icons.menu_book,
    'videos': Icons.video_library,
    'documents': Icons.description,
    'visualResources': Icons.image,
    'externalLinks': Icons.link,
  };

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          if (widget.role == EduRole.teacher)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showUploadDialog(),
            ),
        ],
      ),
      body: Row(
        children: [
          // Category sidebar (tablet/desktop only)
          if (!isMobile) _buildCategorySidebar(),
          
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildResourcesList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar() {
    return Container(
      width: 240,
      color: Colors.grey[100],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ListTile(
                  leading: Icon(
                    _categoryIcons[category],
                    color: isSelected ? const Color(0xFF003900) : Colors.grey,
                  ),
                  title: Text(
                    _categoryLabels[category] ?? category,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF003900) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF003900).withValues(alpha: 0.1),
                  onTap: () => setState(() => _selectedCategory = category),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category dropdown for mobile
          if (MediaQuery.of(context).size.width < 600)
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use  — value: (not initialValue:) needed: _selectedCategory is also set from the desktop chip selector outside this widget's own onChanged.
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                isExpanded: true,
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(_categoryLabels[cat] ?? cat, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
            ),
          if (MediaQuery.of(context).size.width < 600) const SizedBox(width: 12),
          
          // Sort dropdown - flexible on mobile, fixed on desktop
          MediaQuery.of(context).size.width < 600
              ? Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use  — kept consistent with the other sort dropdown instance below.
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                      DropdownMenuItem(value: 'mostViewed', child: Text('Views')),
                      DropdownMenuItem(value: 'mostDownloaded', child: Text('Downloads')),
                    ],
                    onChanged: (val) => setState(() => _sortBy = val!),
                  ),
                )
              : SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use  — value: (not initialValue:) needed so this stays in sync if the mobile/desktop sort dropdown swaps on resize.
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                      DropdownMenuItem(value: 'mostViewed', child: Text('Most Viewed')),
                      DropdownMenuItem(value: 'mostDownloaded', child: Text('Most Downloaded')),
                    ],
                    onChanged: (val) => setState(() => _sortBy = val!),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildResourcesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getResourcesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;
        final isMobile = MediaQuery.of(context).size.width < 600;

        if (isMobile) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildResourceCard(docs[index]),
          );
        } else {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildResourceGridCard(docs[index]),
          );
        }
      },
    );
  }

  Widget _buildResourceCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final uploadedBy = data['uploadedByName'] ?? 'Unknown';
    final category = data['category'] ?? 'unknown';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final viewCount = data['viewCount'] ?? 0;
    final downloadCount = data['downloadCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF003900),
          child: Icon(_categoryIcons[category] ?? Icons.file_present, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By $uploadedBy'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$viewCount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(width: 12),
                Icon(Icons.download, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('$downloadCount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openResource(doc),
      ),
    );
  }

  Widget _buildResourceGridCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final uploadedBy = data['uploadedByName'] ?? 'Unknown';
    final category = data['category'] ?? 'unknown';
    final viewCount = data['viewCount'] ?? 0;
    final downloadCount = data['downloadCount'] ?? 0;

    return Card(
      child: InkWell(
        onTap: () => _openResource(doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF003900),
                child: Icon(_categoryIcons[category] ?? Icons.file_present, 
                  color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('By $uploadedBy', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$viewCount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.download, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$downloadCount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No resources available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (widget.role == EduRole.teacher)
            ElevatedButton.icon(
              onPressed: _showUploadDialog,
              icon: const Icon(Icons.add),
              label: const Text('Upload Resource'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003900),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getResourcesStream() {
    Query query = FirebaseFirestore.instance
        .collection('EducationResources')
        .where('schoolName', isEqualTo: widget.schoolName);

    // Filter by category
    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Filter by class
    query = query.where('classId', whereIn: [widget.classId, 'all']);

    // Sort
    switch (_sortBy) {
      case 'newest':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'oldest':
        query = query.orderBy('createdAt', descending: false);
        break;
      case 'mostViewed':
        query = query.orderBy('viewCount', descending: true);
        break;
      case 'mostDownloaded':
        query = query.orderBy('downloadCount', descending: true);
        break;
    }

    return query.snapshots();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Resources'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement search logic
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    // Implementation for file upload dialog
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Upload Resource'),
        content: Text('Upload dialog implementation goes here'),
      ),
    );
  }

  void _openResource(QueryDocumentSnapshot doc) {
    // Increment view count
    doc.reference.update({'viewCount': FieldValue.increment(1)});
    
    // Open resource viewer
    // Implementation depends on resource type
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}