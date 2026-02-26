import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../widgets/empty_state.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasApi = AppConfig.offersApiBaseUrl != null && AppConfig.offersApiBaseUrl!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: EmptyState(
        icon: Icons.local_offer_outlined,
        title: hasApi
            ? 'Nothing is available'
            : 'No offers configured',
        subtitle: hasApi
            ? 'Configure your offers API to see card-based offers here.'
            : 'Set AppConfig.offersApiBaseUrl to show offers by card type.',
      ),
    );
  }
}
