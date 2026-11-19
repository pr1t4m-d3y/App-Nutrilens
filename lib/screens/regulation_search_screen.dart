import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/cloud_client.dart';
import '../services/cloud_config.dart';
import '../widgets/cloud_consent_dialog.dart';

/// Search over the regulation corpus. Results are verbatim passages from the
/// published documents with their source; nothing is generated.
class RegulationSearchScreen extends StatefulWidget {
  const RegulationSearchScreen({super.key});

  @override
  State<RegulationSearchScreen> createState() => _RegulationSearchScreenState();
}

enum _SearchState { idle, loading, done, unavailable }

class _RegulationSearchScreenState extends State<RegulationSearchScreen> {
  final _controller = TextEditingController();
  _SearchState _state = _SearchState.idle;
  List<RegulationHit> _hits = [];
  String _message = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() {
        _state = _SearchState.unavailable;
        _message = 'Type at least 3 characters.';
      });
      return;
    }
    if (!CloudConfig.isConfigured) {
      setState(() {
        _state = _SearchState.unavailable;
        _message = 'Regulation search needs the cloud service, which is not set up in this build.';
      });
      return;
    }
    final allowed = await ensureCloudConsent(context);
    if (!allowed) {
      if (!mounted) return;
      setState(() {
        _state = _SearchState.unavailable;
        _message = 'Cloud features are off. You can allow them under Account > Privacy.';
      });
      return;
    }

    setState(() => _state = _SearchState.loading);
    try {
      final hits = await CloudClient().search(query);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _state = _SearchState.done;
      });
    } catch (e) {
      debugPrint('[Search] failed: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _state = _SearchState.unavailable;
        _message = 'Search is unavailable right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text('Regulation search', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'An additive, E-number or labelling rule',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shows passages from published regulations with their source. '
              'Information only, not legal or medical advice.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case _SearchState.idle:
        return const SizedBox.shrink();
      case _SearchState.loading:
        return const Center(child: CircularProgressIndicator());
      case _SearchState.unavailable:
        return Text(_message, style: theme.textTheme.bodyMedium);
      case _SearchState.done:
        if (_hits.isEmpty) {
          return Text('No source found for that search.', style: theme.textTheme.bodyMedium);
        }
        return ListView.separated(
          itemCount: _hits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final hit = _hits[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(hit.locator,
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Text(hit.snippet, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}
