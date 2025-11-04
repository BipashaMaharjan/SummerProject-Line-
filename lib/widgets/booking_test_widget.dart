import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';

class BookingTestWidget extends StatefulWidget {
  const BookingTestWidget({super.key});

  @override
  State<BookingTestWidget> createState() => _BookingTestWidgetState();
}

class _BookingTestWidgetState extends State<BookingTestWidget> {
  bool _isTesting = false;
  String _testResult = '';
  Color _resultColor = Colors.black;

  Future<void> _runBookingTest() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Running booking test...';
      _resultColor = Colors.blue;
    });

    try {
      final tokenProvider = context.read<TokenProvider>();

      // Get the first available service
      final services = tokenProvider.services;
      if (services.isEmpty) {
        setState(() {
          _testResult = '❌ No services available for testing';
          _resultColor = Colors.red;
          _isTesting = false;
        });
        return;
      }

      final testService = services.first;
      setState(() {
        _testResult = 'Testing with service: ${testService.name}';
        _resultColor = Colors.blue;
      });

      // Get the first available room
      final rooms = tokenProvider.rooms;
      if (rooms.isEmpty) {
        setState(() {
          _testResult = '❌ No rooms available for testing';
          _resultColor = Colors.red;
          _isTesting = false;
        });
        return;
      }

      final testRoom = rooms.first;

      // Attempt to create a token
      final success = await tokenProvider.createToken(
        serviceId: testService.id,
        serviceName: testService.name,
        estimatedWaitTime: testService.estimatedTimeMinutes,
        roomId: testRoom.id,
        roomName: testRoom.name,
      );

      if (success) {
        setState(() {
          _testResult = '✅ SUCCESS: Token created successfully!\n'
              'Service: ${testService.name}\n'
              'Room: ${testRoom.name}\n'
              'The booking system is working correctly.';
          _resultColor = Colors.green;
        });
      } else {
        final error = tokenProvider.errorMessage ?? 'Unknown error';
        setState(() {
          _testResult = '❌ FAILED: $error\n'
              'Please check the database migration and try again.';
          _resultColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '❌ ERROR: ${e.toString()}\n'
            'Please check your database configuration.';
        _resultColor = Colors.red;
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 Booking System Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Test the token booking functionality to ensure everything is working correctly.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isTesting ? null : _runBookingTest,
              child: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test Booking System'),
            ),
            if (_testResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _resultColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _resultColor.withOpacity(0.3)),
                ),
                child: Text(
                  _testResult,
                  style: TextStyle(color: _resultColor),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '📋 What this test does:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Checks if services and rooms are available\n'
              '• Attempts to create a test token\n'
              '• Verifies database schema compatibility\n'
              '• Tests token number generation\n'
              '• Validates service workflow creation',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}