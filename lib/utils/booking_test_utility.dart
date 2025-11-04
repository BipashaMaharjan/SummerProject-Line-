import '../config/supabase_config.dart';
import '../models/service.dart';
import 'database_inspector.dart';

class BookingTestUtility {
  static Future<Map<String, dynamic>> runBookingTest() async {
    final testResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'overall_success': false,
    };

    try {
      // Test 1: Database Health Check
      print('🩺 Running database health check...');
      final healthReport = await DatabaseInspector.performHealthCheck();
      testResults['tests']['database_health'] = {
        'success': healthReport['issues'].isEmpty,
        'issues': healthReport['issues'],
        'recommendations': healthReport['recommendations'],
      };

      // Test 2: Service Availability
      print('🔍 Checking service availability...');
      final servicesTest = await _testServicesAvailability();
      testResults['tests']['services'] = servicesTest;

      // Test 3: Room Availability
      print('🏢 Checking room availability...');
      final roomsTest = await _testRoomsAvailability();
      testResults['tests']['rooms'] = roomsTest;

      // Test 4: Workflow Configuration
      print('⚙️ Checking workflow configuration...');
      final workflowTest = await _testWorkflowConfiguration();
      testResults['tests']['workflow'] = workflowTest;

      // Test 5: Token Creation Simulation
      print('🎫 Testing token creation simulation...');
      final tokenCreationTest = await _testTokenCreationSimulation();
      testResults['tests']['token_creation'] = tokenCreationTest;

      // Overall assessment
      final allTestsPassed = testResults['tests'].values.every((test) => test['success'] == true);
      testResults['overall_success'] = allTestsPassed;

      _printTestResults(testResults);

    } catch (e) {
      print('❌ Test utility failed: $e');
      testResults['error'] = e.toString();
    }

    return testResults;
  }

  static Future<Map<String, dynamic>> _testServicesAvailability() async {
    try {
      final response = await SupabaseConfig.client
          .from('services')
          .select()
          .eq('is_active', true);

      final services = (response as List).map((json) => Service.fromJson(json)).toList();

      return {
        'success': services.isNotEmpty,
        'count': services.length,
        'services': services.map((s) => {'id': s.id, 'name': s.name}).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testRoomsAvailability() async {
    try {
      final response = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('is_active', true);

      return {
        'success': (response as List).isNotEmpty,
        'count': (response as List).length,
        'rooms': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testWorkflowConfiguration() async {
    try {
      final response = await SupabaseConfig.client
          .from('service_workflow')
          .select('service_id, service:services(name), room_id, rooms:rooms(room_number)');

      return {
        'success': (response as List).isNotEmpty,
        'count': (response as List).length,
        'workflows': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testTokenCreationSimulation() async {
    try {
      // Get a test service
      final servicesResponse = await SupabaseConfig.client
          .from('services')
          .select()
          .eq('is_active', true)
          .limit(1);

      if ((servicesResponse as List).isEmpty) {
        return {
          'success': false,
          'error': 'No active services found',
        };
      }

      final testService = servicesResponse[0];
      final serviceId = testService['id'];

      // Test token number generation
      final tokenNumberTest = await _testTokenNumberGeneration(serviceId);

      // Test workflow retrieval
      final workflowTest = await _testWorkflowRetrieval(serviceId);

      return {
        'success': tokenNumberTest['success'] && workflowTest['success'],
        'token_number_generation': tokenNumberTest,
        'workflow_retrieval': workflowTest,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testTokenNumberGeneration(String serviceId) async {
    try {
      final response = await SupabaseConfig.client
          .rpc('generate_token_number', params: {'service_id': serviceId});

      return {
        'success': response != null,
        'generated_number': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testWorkflowRetrieval(String serviceId) async {
    try {
      final response = await SupabaseConfig.client
          .from('service_workflow')
          .select('room_id, room:rooms(id, name, room_number)')
          .eq('service_id', serviceId)
          .order('sequence_order')
          .limit(1);

      return {
        'success': (response as List).isNotEmpty,
        'workflow_count': (response as List).length,
        'first_room': (response as List).isNotEmpty ? response[0] : null,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static void _printTestResults(Map<String, dynamic> results) {
    print('\n${'=' * 50}');
    print('🎯 BOOKING SYSTEM TEST RESULTS');
    print('=' * 50);
    print('Test Time: ${results['timestamp']}');

    final tests = results['tests'] as Map<String, dynamic>;
    final overallSuccess = results['overall_success'] as bool;

    print('\n📊 OVERALL STATUS: ${overallSuccess ? '✅ PASSED' : '❌ FAILED'}');

    tests.forEach((testName, testResult) {
      final success = testResult['success'] as bool;
      final status = success ? '✅' : '❌';
      print('\n$status ${testName.replaceAll('_', ' ').toUpperCase()}:');

      if (testResult.containsKey('error')) {
        print('   Error: ${testResult['error']}');
      }

      if (testResult.containsKey('count')) {
        print('   Count: ${testResult['count']}');
      }

      if (testResult.containsKey('issues') && (testResult['issues'] as List).isNotEmpty) {
        print('   Issues:');
        for (var issue in (testResult['issues'] as List)) {
          print('     - $issue');
        }
      }

      if (testResult.containsKey('recommendations') && (testResult['recommendations'] as List).isNotEmpty) {
        print('   Recommendations:');
        for (var rec in (testResult['recommendations'] as List)) {
          print('     - $rec');
        }
      }
    });

    if (results.containsKey('error')) {
      print('\n❌ TEST UTILITY ERROR: ${results['error']}');
    }

    print('\n${'=' * 50}');

    if (overallSuccess) {
      print('🎉 All tests passed! Token booking should work correctly.');
    } else {
      print('⚠️  Some tests failed. Please check the issues above and run the database migration script.');
    }

    print('=' * 50);
  }

  /// Quick test method that can be called from anywhere
  static Future<void> quickTest() async {
    print('🚀 Starting quick booking test...');
    final results = await runBookingTest();

    if (results['overall_success'] == true) {
      print('✅ Quick test passed!');
    } else {
      print('❌ Quick test failed. Check the detailed results above.');
    }
  }
}