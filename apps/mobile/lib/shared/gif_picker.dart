import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';

class _GifItem {
  final String url;
  const _GifItem(this.url);
}

/// Show GIF picker bottom sheet.
/// Returns the selected GIF URL, or null if dismissed.
Future<String?> showGifPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GifPickerSheet(),
  );
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet();

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<_GifItem> _gifs = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGifs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGifs([String query = '']) async {
    const apiKey = String.fromEnvironment('GIPHY_API_KEY');
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final uri = query.trim().isEmpty
          ? Uri.https('api.giphy.com', '/v1/gifs/trending', {
              'api_key': apiKey,
              'limit': '25',
              'rating': 'g',
            })
          : Uri.https('api.giphy.com', '/v1/gifs/search', {
              'api_key': apiKey,
              'q': query.trim(),
              'limit': '25',
              'rating': 'g',
            });
      final response = await http.get(uri);
      if (!mounted) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>;
      setState(() {
        _gifs = data
            .map((item) {
              final images = item['images'] as Map<String, dynamic>;
              final url =
                  (images['fixed_height'] as Map<String, dynamic>?)?['url']
                      as String? ??
                  '';
              return _GifItem(url);
            })
            .where((g) => g.url.isNotEmpty)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) => _fetchGifs(query);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4A3E3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellowWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF4A3228),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search GIFs...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    )
                  : _gifs.isEmpty
                  ? const Center(
                      child: Text(
                        'No GIFs found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: _gifs.length,
                      itemBuilder: (_, i) {
                        final gif = _gifs[i];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, gif.url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              gif.url,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white54,
                                        strokeWidth: 2,
                                      ),
                                    ),
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.white12,
                                alignment: Alignment.center,
                                child: const Text(
                                  'GIF',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
