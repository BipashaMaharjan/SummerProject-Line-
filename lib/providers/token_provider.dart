import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/token.dart';
import '../models/service.dart';
import '../models/room.dart';

class TokenProvider extends ChangeNotifier {
  List<Token> _userTokens = [];
  List<Service> _services = [];
  List<Room> _rooms = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Token> get userTokens => _userTokens;
  List<Service> get services => _services;
  List<Room> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TokenProvider() {
    _loadServices();
    _loadRooms();
    _loadUserTokens();
    ensureAllServicesHaveWorkflows();
  }

  Future<void> _loadServices() async {
    try {
      debugPrint('TokenProvider: Starting to load services...');
      
      final response = await SupabaseConfig.client
          .from('services')
          .select()
          .eq('is_active', true);

      debugPrint('TokenProvider: Services response: $response');
      debugPrint('TokenProvider: Response type: ${response.runtimeType}');
      debugPrint('TokenProvider: Response length: ${(response as List).length}');

      _services = (response as List)
          .map((json) {
            debugPrint('TokenProvider: Processing service JSON: $json');
            return Service.fromJson(json);
          })
          .toList();
          
      debugPrint('TokenProvider: Successfully loaded ${_services.length} services');
      notifyListeners();
    } catch (error) {
      debugPrint('TokenProvider: Error loading services: $error');
      debugPrint('TokenProvider: Error type: ${error.runtimeType}');
      _setError('Failed to load services: $error');
      
      // Add fallback services if database fails
      _services = _getFallbackServices();
      debugPrint('TokenProvider: Using fallback services: ${_services.length} services');
      notifyListeners();
    }
  }

  Future<void> reloadServices() async {
    _clearError();
    await _loadServices();
  }

  List<Service> _getFallbackServices() {
    return [
      Service(
        id: 'fallback-license-renewal',
        name: 'License Renewal',
        type: ServiceType.licenseRenewal,
        description: 'Renew your existing license',
        estimatedTimeMinutes: 30,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Service(
        id: 'fallback-new-license',
        name: 'New License Application',
        type: ServiceType.newLicense,
        description: 'Apply for a new license',
        estimatedTimeMinutes: 45,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _loadRooms() async {
    try {
      final response = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('is_active', true)
          .order('room_number');

      _rooms = (response as List)
          .map((json) => Room.fromJson(json))
          .toList();
      notifyListeners();
    } catch (error) {
      _setError('Failed to load rooms: $error');
    }
  }

  // Load user tokens from the database
  Future<void> _loadUserTokens() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('''
            *,
            user:users(name, phone),
            service:services(name, type),
            room:rooms(name, room_number)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _userTokens = (response as List)
          .map((json) => Token.fromJson(json))
          .toList();
      
      notifyListeners();
    } catch (error) {
      _setError('Failed to load user tokens: $error');
    }
  }

  Future<bool> createToken({
    required String serviceId,
    required String serviceName,
    required int estimatedWaitTime,
    required String roomId,
    required String roomName,
    String? scheduledDate,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        _setError('User not authenticated. Please log in again.');
        return false;
      }

      // First, verify the service exists and is active
      try {
        final serviceResponse = await SupabaseConfig.client
            .from('services')
            .select()
            .eq('id', serviceId)
            .eq('is_active', true)
            .maybeSingle();

        if (serviceResponse == null) {
          _setError('Selected service is not available or inactive');
          return false;
        }
        
        debugPrint('Found service: ${serviceResponse['name']} (${serviceResponse['id']})');

        // Ensure service workflow exists
        final hasWorkflow = await _ensureServiceWorkflow(serviceId);
        if (!hasWorkflow) {
          _setError('Could not set up service workflow. Please try again or contact support.');
          return false;
        }

        // Get the first room for the service workflow
        try {
          final workflowResponse = await SupabaseConfig.client
              .from('service_workflow')
              .select('room_id, room:rooms(id, name, room_number)')
              .eq('service_id', serviceId)
              .order('sequence_order')
              .limit(1)
              .maybeSingle();

          debugPrint('Workflow response: $workflowResponse');

          if (workflowResponse == null || workflowResponse['room_id'] == null) {
            // Get all services and their workflows for debugging
            final allWorkflows = await SupabaseConfig.client
                .from('service_workflow')
                .select('service_id, service:services(name), room_id, rooms:rooms(name, room_number)')
                .order('service_id, sequence_order');
                
            debugPrint('All workflows in system: $allWorkflows');
            
            _setError('''No workflow configuration found for this service. 
Please contact support and provide this information:
Service ID: $serviceId
Service Name: $serviceName

Available workflows: $allWorkflows''');
            return false;
          }

          final firstRoomId = workflowResponse['room_id'] as String;
          final roomData = workflowResponse['room'] as Map<String, dynamic>?;
          final roomName = roomData?['name']?.toString() ?? 'Unknown Room';
          
          debugPrint('Using room ID: $firstRoomId, Name: $roomName');

          // Create the token with all required fields
          final tokenData = {
            'user_id': user.id,
            'service_id': serviceId,
            'current_room_id': firstRoomId,
            'current_sequence': 1,
            'status': 'waiting',
            'estimated_wait_time': estimatedWaitTime,
            'scheduled_date': scheduledDate,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          // Insert the token
          final tokenResponse = await SupabaseConfig.client
              .from('tokens')
              .insert(tokenData)
              .select()
              .single();

          if (tokenResponse == null) {
            throw 'Failed to create token: No response from server';
          }

          // Create token history entry
          await SupabaseConfig.client
              .from('token_history')
              .insert({
                'token_id': tokenResponse['id'],
                'room_id': firstRoomId,
                'status': 'waiting',
                'sequence_number': 1,
                'action': 'created',
                'notes': 'Token created for $serviceName',
                'created_at': DateTime.now().toIso8601String(),
              });

          // Refresh user tokens
          await _loadUserTokens();
          
          _setLoading(false);
          return true;
        } catch (e) {
          _setError('Failed to get workflow configuration: ${e.toString()}');
          return false;
        }
      } catch (e) {
        _setError('Error verifying service: $e');
        return false;
      }
    } catch (error) {
      _setError('An unexpected error occurred: ${error.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _ensureServiceWorkflow(String serviceId) async {
    try {
      debugPrint('🔍 Checking workflow for service: $serviceId');
      
      // Check if workflow exists
      final existingWorkflow = await SupabaseConfig.client
          .from('service_workflow')
          .select()
          .eq('service_id', serviceId)
          .maybeSingle()
          .catchError((error) {
            debugPrint('❌ Error checking workflow: $error');
            return null;
          });

      if (existingWorkflow != null) {
        debugPrint('✅ Workflow exists for service: $serviceId');
        return true;
      }

      debugPrint('ℹ️ No workflow found, creating default workflow...');

      // Get default reception room (R001)
      final receptionRoom = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('room_number', 'R001')
          .maybeSingle()
          .catchError((error) {
            debugPrint('❌ Error fetching reception room: $error');
            return null;
          });

      if (receptionRoom == null) {
        debugPrint('❌ Default reception room (R001) not found');
        return false;
      }

      debugPrint('ℹ️ Found reception room: ${receptionRoom['id']}');

      // Create a simple one-step workflow that goes to reception
      final response = await SupabaseConfig.client
          .from('service_workflow')
          .insert({
            'service_id': serviceId,
            'room_id': receptionRoom['id'],
            'sequence_order': 1,
            'is_required': true,
          })
          .select()
          .single()
          .catchError((error) {
            debugPrint('❌ Error creating workflow: $error');
            return null;
          });

      if (response != null) {
        debugPrint('✅ Created workflow for service: $serviceId');
        return true;
      } else {
        debugPrint('❌ Failed to create workflow for service: $serviceId');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error in _ensureServiceWorkflow: $e');
      return false;
    }
  }

  Future<void> loadUserTokens() async {
    try {
      _setLoading(true);
      _clearError();
      
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        _setError('User not authenticated');
        return;
      }
      
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('''
            *,
            services:service_id(*),
            rooms:current_room_id(*)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      _userTokens = (response as List).map((json) {
        // Map the nested service and room data to the token
        final serviceData = json['services'] ?? {};
        final roomData = json['rooms'] ?? {};
        
        return Token.fromJson({
          ...json,
          'service_name': serviceData['name'],
          'service_type': serviceData['type'],
          'current_room_name': roomData['name'],
          'current_room_number': roomData['room_number'],
        });
      }).toList();
      
      notifyListeners();
    } catch (error) {
      _setError('Failed to load user tokens: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Token>> getTodaysQueue() async {
    try {
      // Get today's date at 00:00:00
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('''
            *,
            services:service_id(*),
            rooms:current_room_id(*),
            user:user_id(id, full_name, phone)
          ''')
          .gte('created_at', todayStart.toIso8601String())
          .order('created_at', ascending: true);

      // Create a map to track positions for each service and status
      final servicePositions = <String, int>{};
      
      final tokens = (response as List).map((json) {
        // Map the nested service and room data to the token
        final serviceData = json['services'] ?? {};
        final roomData = json['rooms'] ?? {};
        final userData = json['user'] ?? {};
        
        // Calculate queue position
        final serviceId = json['service_id'] as String;
        final status = json['status'] as String;
        final key = '$serviceId-$status';
        final queuePosition = (servicePositions[key] = (servicePositions[key] ?? 0) + 1);
        
        return Token.fromJson({
          ...json,
          'service_name': serviceData['name'],
          'service_type': serviceData['type'],
          'current_room_name': roomData['name'],
          'current_room_number': roomData['room_number'],
          'queue_position': queuePosition,
          'user_name': userData['full_name'],
          'user_phone': userData['phone'],
        });
      }).toList();
      
      // Update the local tokens list
      _userTokens = tokens;
      notifyListeners();
      
      return tokens;
    } catch (error) {
      _setError('Failed to load today\'s queue: $error');
      return [];
    }
  }

  Future<Token?> getTokenById(String tokenId) async {
    try {
      final response = await SupabaseConfig.client
          .from('current_queue')
          .select()
          .eq('id', tokenId)
          .select();

      return Token.fromJson(response as Map<String, dynamic>);
    } catch (error) {
      _setError('Failed to load token: $error');
      return null;
    }
  }

  Future<int> getQueuePosition(String tokenId) async {
    try {
      final token = await getTokenById(tokenId);
      if (token == null) return 0;

      final query = SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('status', 'waiting')
          .lt('created_at', token.createdAt.toIso8601String());
      
      final response = token.currentRoomId != null
          ? query.eq('current_room_id', token.currentRoomId!)
          : query.isFilter('current_room_id', null);

      return (response as List).length + 1;
    } catch (error) {
      _setError('Failed to get queue position: $error');
      return 0;
    }
  }

  Future<bool> cancelToken(String tokenId) async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseConfig.client
          .from('tokens')
          .update({'status': 'rejected'})
          .eq('id', tokenId);

      // Add history entry
      await SupabaseConfig.client
          .from('token_history')
          .insert({
            'token_id': tokenId,
            'status': 'rejected',
            'action': 'cancelled',
            'notes': 'Token cancelled by user',
          });

      await loadUserTokens();
      _setLoading(false);
      return true;
    } catch (error) {
      _setError('Failed to cancel token: $error');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> startOperation(String tokenId, String roomId) async {
    try {
      _setLoading(true);
      _clearError();

      // Update token status to 'processing'
      await SupabaseConfig.client
          .from('tokens')
          .update({
            'status': 'processing',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tokenId);

      // Add history entry
      await SupabaseConfig.client
          .from('token_history')
          .insert({
            'token_id': tokenId,
            'room_id': roomId,
            'status': 'processing',
            'action': 'started',
            'notes': 'Operation started by staff',
          });

      await loadUserTokens();
      _setLoading(false);
      return true;
    } catch (error) {
      _setError('Failed to start operation: $error');
      _setLoading(false);
      return false;
    }
  }

  Future<void> ensureAllServicesHaveWorkflows() async {
    try {
      // Get all services
      final services = await SupabaseConfig.client
          .from('services')
          .select('id, name')
          .eq('is_active', true);

      // Get default reception room
      final receptionRoom = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('room_number', 'R001')
          .maybeSingle();

      if (receptionRoom == null) {
        debugPrint('Default reception room (R001) not found');
        return;
      }

      // For each service, check if it has a workflow and create one if not
      for (final service in services) {
        final workflowExists = await SupabaseConfig.client
            .from('service_workflow')
            .select()
            .eq('service_id', service['id'])
            .maybeSingle()
            .then((value) => value != null)
            .catchError((_) => false);

        if (!workflowExists) {
          await SupabaseConfig.client.from('service_workflow').insert({
            'service_id': service['id'],
            'room_id': receptionRoom['id'],
            'sequence_order': 1,
            'is_required': true,
          });
          debugPrint('Created default workflow for service: ${service['name']}');
        }
      }
    } catch (e) {
      debugPrint('Error ensuring service workflows: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
