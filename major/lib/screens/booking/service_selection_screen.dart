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
          if (tokenProvider.services.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
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
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: tokenProvider.services.length,
                    itemBuilder: (context, index) {
                      final service = tokenProvider.services[index];
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
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Est. ${service.estimatedTimeMinutes} minutes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
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
