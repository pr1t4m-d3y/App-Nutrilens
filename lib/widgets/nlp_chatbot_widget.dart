import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/nutri_nlu_service.dart';
import '../services/food_data_service.dart';
import '../providers/chat_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<dynamic>? products;

  ChatMessage({required this.text, required this.isUser, this.products});
}

class NlpChatbotWidget extends StatefulWidget {
  const NlpChatbotWidget({super.key});

  @override
  State<NlpChatbotWidget> createState() => _NlpChatbotWidgetState();
}

class _NlpChatbotWidgetState extends State<NlpChatbotWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NutriNLUService _nluService = NutriNLUService();
  final FoodDataService _foodService = FoodDataService();
  
  bool _isLoading = false;

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    chatProvider.addMessage(ChatMessage(text: query, isUser: true));
    
    _scrollToBottom();
    _controller.clear();

    try {
      final intent = await _nluService.predictIntent(query);
      final products = await _foodService.searchProductsByIntent(query, intent);
      
      final bool hasMore = products.length > 5;
      final displayProducts = hasMore ? List<dynamic>.from(products.take(5)) : List<dynamic>.from(products);
      
      if (hasMore) {
        displayProducts.add({'isViewAll': true, 'fullList': products, 'intent': intent});
      }
      
      final replyText = products.isEmpty 
        ? "No matching products found for '$query'." 
        : "Found ${products.length} items. Here are the top matches:";
        
      chatProvider.addMessage(ChatMessage(
        text: replyText, 
        isUser: false,
        products: displayProducts.isNotEmpty ? displayProducts : null,
      ));
    } catch (e) {
      chatProvider.addMessage(ChatMessage(text: "Error analyzing request: $e", isUser: false));
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!msg.isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: msg.isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (msg.isUser)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
                ),
            ],
          ),
          if (msg.products != null && msg.products!.isNotEmpty)
            Container(
              height: 180,
              margin: const EdgeInsets.only(top: 8, left: 28),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: msg.products!.length,
                itemBuilder: (context, index) {
                  final p = msg.products![index];
                  if (p is Map && p['isViewAll'] == true) {
                    return _ViewAllCard(fullList: p['fullList'], intent: p['intent'] ?? '');
                  }
                  // Pass the filtered display list (excluding the 'View All' object) to the modal
                  final validProducts = msg.products!.where((e) => !(e is Map && e['isViewAll'] == true)).toList();
                  return NlpProductCard(product: p, allProducts: validProducts, initialIndex: index);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 300,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(chatProvider.messages[index], theme);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "E.g., Find vegan snacks",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: _handleSearch,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () => _handleSearch(_controller.text),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class NlpProductCard extends StatelessWidget {
  final dynamic product;
  final List<dynamic>? allProducts;
  final int initialIndex;

  const NlpProductCard({super.key, required this.product, this.allProducts, this.initialIndex = 0});

  Color _getScoreColor(ThemeData theme, double s) {
    if (s < 4.0) return theme.colorScheme.error;
    if (s < 7.0) return Colors.orange;
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = product['ProductName'] ?? 'Unknown';
    final String category = product['Category'] ?? 'Uncategorized';
    final double score = (product['HealthRating'] as num?)?.toDouble() ?? (product['TotalScore'] as num?)?.toDouble() ?? 0.0;
    
    final List<dynamic> good = product['GoodIngredients'] ?? [];
    final List<dynamic> bad = product['BadIngredients'] ?? [];
    
    return GestureDetector(
      onTap: () {
        if (allProducts != null) {
          _showProductModal(context, allProducts!, initialIndex);
        }
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getScoreColor(theme, score).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score.toStringAsFixed(1),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _getScoreColor(theme, score),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(category, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          if (good.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(good.take(2).join(', '), style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          if (bad.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text(bad.take(2).join(', '), style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          if (score >= 8)
            Text("Excellent choice!", style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontStyle: FontStyle.italic))
          else if (bad.isNotEmpty)
            Text("Consume in moderation", style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange, fontStyle: FontStyle.italic))
          else
            Text("Average", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        ],
      ),
    ));
  }
}

// ─── View All Button Card ───
class _ViewAllCard extends StatelessWidget {
  final List<dynamic> fullList;
  final String intent;

  const _ViewAllCard({required this.fullList, required this.intent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        context.push('/chatbot-view-all', extra: {
          'products': fullList,
          'intent': intent,
        });
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'View All\n${fullList.length} Items',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product Expansion Modal ───
void _showProductModal(BuildContext context, List<dynamic> products, int initialIndex) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ProductModalContent(products: products, initialIndex: initialIndex);
    },
  );
}

class _ProductModalContent extends StatefulWidget {
  final List<dynamic> products;
  final int initialIndex;

  const _ProductModalContent({required this.products, required this.initialIndex});

  @override
  State<_ProductModalContent> createState() => _ProductModalContentState();
}

class _ProductModalContentState extends State<_ProductModalContent> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.products.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              
              // Top Pagination indicator
              Text('${_currentIndex + 1} of ${widget.products.length}', style: theme.textTheme.labelMedium),
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: widget.products.length,
                  itemBuilder: (context, index) {
                    final product = widget.products[index];
                    final String name = product['ProductName'] ?? 'Unknown';
                    final String category = product['Category'] ?? 'Uncategorized';
                    final double score = (product['HealthRating'] as num?)?.toDouble() ?? (product['TotalScore'] as num?)?.toDouble() ?? 0.0;
                    
                    final List<dynamic> good = product['GoodIngredients'] ?? [];
                    final List<dynamic> bad = product['BadIngredients'] ?? [];
                    final String explanation = product['HealthImpact'] ?? product['Explanation'] ?? 'No detail available.';
                    
                    final Color scoreColor = score >= 7 ? Colors.green : (score >= 4 ? Colors.orange : theme.colorScheme.error);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(score.toStringAsFixed(1), style: theme.textTheme.titleMedium?.copyWith(color: scoreColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(category, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                            child: Text(explanation, style: theme.textTheme.bodyMedium),
                          ),
                          
                          const SizedBox(height: 24),
                          if (good.isNotEmpty) ...[
                            Text("Positives", style: theme.textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...good.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [const Icon(Icons.check, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(e.toString()))]))),
                            const SizedBox(height: 16),
                          ],
                          
                          if (bad.isNotEmpty) ...[
                            Text("Concerns", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...bad.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(Icons.warning, color: theme.colorScheme.error, size: 16), const SizedBox(width: 8), Expanded(child: Text(e.toString()))]))),
                          ]
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Side Navigation Arrows
          if (_currentIndex > 0)
            Positioned(
              left: 12, top: size.height * 0.3 - 24,
              child: IconButton(
                onPressed: _prevPage,
                icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.arrow_back_ios_rounded, size: 20)),
              ),
            ),
          
          if (_currentIndex < widget.products.length - 1)
            Positioned(
              right: 12, top: size.height * 0.3 - 24,
              child: IconButton(
                onPressed: _nextPage,
                icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.arrow_forward_ios_rounded, size: 20)),
              ),
            ),
        ],
      ),
    );
  }
}
