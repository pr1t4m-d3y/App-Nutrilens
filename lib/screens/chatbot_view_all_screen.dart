import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/nlp_chatbot_widget.dart' show NlpProductCard;

class ChatbotViewAllScreen extends StatelessWidget {
  final List<dynamic> products;
  final String intent;

  const ChatbotViewAllScreen({
    super.key,
    required this.products,
    required this.intent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out the 'isViewAll' marker just in case it got passed
    final validProducts = products.where((e) => !(e is Map && e['isViewAll'] == true)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Search Results', style: theme.textTheme.titleMedium),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${validProducts.length} items',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: validProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = validProducts[index];
                    // Constrain the width for vertical layout or wrap in a generic container
                    return SizedBox(
                      height: 180,
                      child: NlpProductCard(
                        product: item,
                        allProducts: validProducts,
                        initialIndex: index,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
