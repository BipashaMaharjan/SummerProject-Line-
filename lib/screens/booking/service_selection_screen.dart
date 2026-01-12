import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../models/service.dart';
import 'token_confirmation_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  Service? _selectedService;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Service'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Consumer<TokenProvider>(
        builder: (context, tokenProvider, child) {
          // Debug: Log what services are available
          debugPrint('🔍 ServiceSelectionScreen - Services available: ${tokenProvider.services.length}');
          for (var service in tokenProvider.services) {
            debugPrint('   - ${service.name} (ID: ${service.id})');
          }
          
          // Filter services based on search query
          final filteredServices = _searchQuery.isEmpty
              ? tokenProvider.services
              : tokenProvider.services
                  .where((service) =>
                      service.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (service.description?.toLowerCase() ?? '')
                          .contains(_searchQuery.toLowerCase()))
                  .toList();
          // Show error state with retry option
          if (tokenProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to Load Services',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tokenProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Trigger a reload of services
                        tokenProvider.reloadServices();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Show loading state
          if (tokenProvider.services.isEmpty && tokenProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading services...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Show empty state if no services and not loading
          if (tokenProvider.services.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Services Available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are currently no active services available for booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        tokenProvider.reloadServices();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the service you need:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Search Field + Dropdown Filter
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search services...',
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Select Dropdown
                    PopupMenuButton<Service>(
                      icon: const Icon(Icons.expand_more),
                      tooltip: 'Quick Select',
                      onSelected: (service) {
                        setState(() {
                          _selectedService = service;
                          _searchQuery = ''; // Clear search
                        });
                      },
                      itemBuilder: (context) => tokenProvider.services
                          .map((service) => PopupMenuItem(
                                value: service,
                                child: Text(service.name),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Show no results message if search returns nothing
                if (filteredServices.isEmpty && _searchQuery.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No services found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Try searching with different keywords',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredServices.length,
                      itemBuilder: (context, index) {
                        final service = filteredServices[index];
                        final isSelected = _selectedService?.id == service.id;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            elevation: isSelected ? 4 : 1,
                            color: isSelected ? Colors.blue.shade50 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getServiceIcon(service.type),
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                service.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (service.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      service.description!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.blue.shade600,
                                      size: 24,
                                    )
                                  : Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.grey.shade400,
                                      size: 24,
                                    ),
                              onTap: () {
                                setState(() {
                                  _selectedService = service;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedService != null ? _continueToConfirmation : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getServiceIcon(ServiceType type) {
    switch (type) {
      case ServiceType.licenseRenewal:
        return Icons.refresh;
      case ServiceType.newLicense:
        return Icons.add_card;
    }
  }

  void _continueToConfirmation() {
    if (_selectedService != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TokenConfirmationScreen(service: _selectedService!),
        ),
      );
    }
  }
}
