import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/token.dart';
import '../models/service.dart';
import '../models/room.dart';

class TokenProvider extends ChangeNotifier {
  List<Token> _userTokens = [];
  List<Token> _allTokens = []; // For staff dashboard
  List<Service> _services = [];
  List<Room> _rooms = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Token> get userTokens => _userTokens;
  List<Token> get allTokens => _allTokens; // For staff dashboard
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
      
      // Clear any previous error state
      _errorMessage = null;
      
      final response = await SupabaseConfig.client
          .from('services')
          .select();

      debugPrint('TokenProvider: Services response: $response');
      debugPrint('TokenProvider: Response type: ${response.runtimeType}');
      debugPrint('TokenProvider: Response length: ${(response as List).length}');

      if ((response as List).isEmpty) {
        debugPrint('TokenProvider: No services found in database, using fallback');
        _services = _getFallbackServices();
      } else {
        _services = (response as List)
            .map((json) {
              debugPrint('TokenProvider: Processing service JSON: $json');
              return Service.fromJson(json);
            })
            .toList();
      }
          
      debugPrint('TokenProvider: Successfully loaded ${_services.length} services');
      // Clear error state on successful load
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      debugPrint('TokenProvider: Error loading services: $error');
      debugPrint('TokenProvider: Error type: ${error.runtimeType}');
      _setError('Failed to load services: $error');
      
      // Add fallback services if database fails
      _services = _getFallbackServices();
      debugPrint('TokenProvider: Using fallback services: ${_services.length} services');
      // Clear error when using fallback services
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> reloadServices() async {
    debugPrint('🔄 Reloading services...');
    _clearError();
    await _loadServices();
    debugPrint('✅ Services reloaded. Found ${_services.length} services');
    for (var service in _services) {
      debugPrint('   - ${service.name} (ID: ${service.id})');
    }
  }

  List<Service> _getFallbackServices() {
    // Use real database service IDs to match what's actually in Supabase
    return [
      Service(
        id: '02a27834-69d3-4c4b-9635-81f91130945f', // Real License Renewal ID from database
        name: 'License Renewal',
        type: ServiceType.licenseRenewal,
        description: 'Renew your existing license',
        estimatedTimeMinutes: 30,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Service(
        id: '76251969-6be7-4135-bfca-6ab9a31df87f', // Real New License ID from database
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

      if ((response as List).isNotEmpty) {
        _rooms = (response as List)
            .map((json) => Room.fromJson(json))
            .toList();
      } else {
        // Use fallback rooms if database is empty
        _rooms = _getFallbackRooms();
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Error loading rooms: $error');
      // Use fallback rooms if database fails
      _rooms = _getFallbackRooms();
      notifyListeners();
    }
  }

  List<Room> _getFallbackRooms() {
    return [
      Room(
        id: 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360', // Real Reception ID from database
        name: 'Reception',
        roomNumber: 'R001',
        description: 'Main reception area',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Room(
        id: 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361', // Real Document Verification ID from database
        name: 'Document Verification',
        roomNumber: 'R002',
        description: 'Document verification counter',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
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
          .order('booked_at', ascending: false);

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
        _setLoading(false);
        return false;
      }

      debugPrint('🔄 Starting token creation for user: ${user.id}');
      debugPrint('📋 Service ID: $serviceId');
      debugPrint('🏢 Room ID: $roomId');

      // Validate UUID format
      if (!_isValidUuid(serviceId)) {
        debugPrint('❌ Invalid service ID format: $serviceId');
        _setError('Invalid service ID format. Please refresh and try again.');
        _setLoading(false);
        return false;
      }

      if (!_isValidUuid(roomId)) {
        debugPrint('❌ Invalid room ID format: $roomId');
        _setError('Invalid room ID format. Please refresh and try again.');
        _setLoading(false);
        return false;
      }

      if (!_isValidUuid(user.id)) {
        debugPrint('❌ Invalid user ID format: ${user.id}');
        _setError('Invalid user ID format. Please log out and log in again.');
        _setLoading(false);
        return false;
      }

      debugPrint('✅ UUID validation passed');

      // Map IDs to real database IDs
      final realServiceId = _mapToRealServiceId(serviceId);
      final realRoomId = _mapToRealRoomId(roomId);

      debugPrint('📋 Using real service ID: $realServiceId');
      debugPrint('📋 Using real room ID: $realRoomId');

      // Validate that service and room exist
      debugPrint('🔍 Validating service and room...');
      final validationResult = await _validateServiceAndRoom(serviceId, roomId);
      if (!validationResult) {
        debugPrint('❌ Service or room validation failed');
        _setLoading(false);
        return false;
      }
      debugPrint('✅ Service and room validation passed');

      // Generate token number using database function
      String? tokenNumber;
      try {
        debugPrint('🔄 Generating token number using database function...');
        final tokenResponse = await SupabaseConfig.client
            .rpc('generate_token_number', params: {'service_id_param': realServiceId});

        if (tokenResponse != null) {
          tokenNumber = tokenResponse.toString();
          debugPrint('✅ Generated token number: $tokenNumber');
        } else {
          throw Exception('Token number generation returned null');
        }
      } catch (e) {
        debugPrint('⚠️ Database function failed, using fallback: $e');
        // Fallback token number generation
        final now = DateTime.now();
        tokenNumber = 'T${now.millisecondsSinceEpoch.toString().substring(8)}';
        debugPrint('📋 Fallback token number: $tokenNumber');
      }

      // Create token with correct column names and real IDs
      final tokenData = {
        'user_id': user.id,
        'service_id': realServiceId,
        'status': 'waiting',
        'current_sequence': 1,
        'token_number': tokenNumber,
        'current_room_id': realRoomId,
        'estimated_wait_minutes': estimatedWaitTime,
        'booked_at': DateTime.now().toIso8601String(),
      };

      if (scheduledDate != null) {
        tokenData['scheduled_date'] = scheduledDate;
      }

      debugPrint('📝 Final token data: $tokenData');

      // Insert the token
      final tokenResponse = await SupabaseConfig.client
          .from('tokens')
          .insert(tokenData)
          .select()
          .single();

      if (tokenResponse == null) {
        throw Exception('Failed to create token: No response from server');
      }

      debugPrint('✅ Token created successfully: ${tokenResponse['id']}');

      // Try to create token history (optional)
      try {
        await SupabaseConfig.client
            .from('token_history')
            .insert({
              'token_id': tokenResponse['id'],
              'action': 'created',
              'notes': 'Token created for $serviceName',
              'performed_by': user.id,
            });
        debugPrint('✅ Token history created');
      } catch (historyError) {
        debugPrint('⚠️ Could not create token history (optional): $historyError');
        // Don't fail the entire operation for history errors
      }

      // Refresh user tokens
      await _loadUserTokens();

      _setLoading(false);
      return true;

    } catch (error) {
      debugPrint('❌ Error in createToken: $error');

      // Provide user-friendly error messages
      String errorMessage = 'Failed to create token. ';

      final errorString = error.toString().toLowerCase();

      if (errorString.contains('invalid input syntax for type uuid')) {
        errorMessage += 'Invalid ID format detected. Please refresh the page and try again.';
      } else if (errorString.contains('violates foreign key constraint')) {
        if (errorString.contains('tokens_service_id_fkey')) {
          errorMessage += 'Service not found. Please refresh and try again.';
        } else if (errorString.contains('tokens_current_room_id_fkey')) {
          errorMessage += 'Room not found. Please refresh and try again.';
        } else {
          errorMessage += 'Invalid service or room selected. Please try a different service.';
        }
      } else if (errorString.contains('duplicate key value')) {
        errorMessage += 'Token already exists. Please try again.';
      } else if (errorString.contains('violates not-null constraint')) {
        errorMessage += 'Required information is missing.';
      } else if (errorString.contains('permission denied')) {
        errorMessage += 'You do not have permission to create tokens.';
      } else if (errorString.contains('jwt') || errorString.contains('auth')) {
        errorMessage += 'Authentication error. Please log out and log in again.';
      } else if (errorString.contains('connection') || errorString.contains('network')) {
        errorMessage += 'Network connection error. Please check your internet connection.';
      } else {
        errorMessage += 'Database error occurred. Please try again later.';
      }

      debugPrint('❌ Detailed error: $error');

      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  Future<String> _generateFallbackTokenNumber(String serviceId) async {
    try {
      // Get service prefix
      final serviceResponse = await SupabaseConfig.client
          .from('services')
          .select('name')
          .eq('id', serviceId)
          .maybeSingle();

      String prefix = 'T'; // Default prefix
      if (serviceResponse != null && serviceResponse['name'] != null) {
        final serviceName = serviceResponse['name'] as String;
        prefix = serviceName.length >= 1 ? serviceName[0].toUpperCase() : 'T';
      }

      // Get today's date for uniqueness
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // Get count of tokens created today for this service
      final todayStart = DateTime(now.year, now.month, now.day);
      final countResponse = await SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('service_id', serviceId)
          .gte('booked_at', todayStart.toIso8601String())
          .catchError((error) {
            debugPrint('Error counting tokens: $error');
            return [];
          });

      final count = (countResponse as List).length + 1;

      // Generate token number: PREFIX + DATE + COUNT (e.g., L20250828001)
      return '$prefix$dateStr${count.toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error in fallback token generation: $e');
      // Ultimate fallback
      return 'T${DateTime.now().millisecondsSinceEpoch}';
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
          .maybeSingle();

      if (existingWorkflow != null) {
        debugPrint('✅ Workflow exists for service: $serviceId');
        return true;
      }

      debugPrint('ℹ️ No workflow found, creating default workflow...');

      // Get default reception room (R001) or any available room
      var receptionRoom = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('room_number', 'R001')
          .eq('is_active', true)
          .maybeSingle();

      // If R001 doesn't exist, get the first available active room
      if (receptionRoom == null) {
        debugPrint('ℹ️ R001 not found, looking for any active room...');
        final anyRoom = await SupabaseConfig.client
            .from('rooms')
            .select()
            .eq('is_active', true)
            .order('room_number')
            .limit(1)
            .maybeSingle();

        if (anyRoom != null) {
          receptionRoom = anyRoom;
          debugPrint('ℹ️ Using room: ${receptionRoom['room_number']} (${receptionRoom['name']})');
        }
      }

      if (receptionRoom == null) {
        debugPrint('❌ No active rooms found in database');
        _setError('No active rooms available. Please contact support.');
        return false;
      }

      debugPrint('ℹ️ Found room: ${receptionRoom['id']} (${receptionRoom['room_number']})');

      // Create a simple one-step workflow
      final workflowData = {
        'service_id': serviceId,
        'room_id': receptionRoom['id'],
        'sequence_order': 1,
        'is_required': true,
        'estimated_duration': 15,
      };

      debugPrint('ℹ️ Creating workflow with data: $workflowData');

      final response = await SupabaseConfig.client
          .from('service_workflow')
          .insert(workflowData)
          .select()
          .single();

      if (response != null) {
        debugPrint('✅ Created workflow for service: $serviceId');
        return true;
      } else {
        debugPrint('❌ Failed to create workflow for service: $serviceId');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error in _ensureServiceWorkflow: $e');
      // Check for specific PostgreSQL errors
      if (e.toString().contains('violates foreign key constraint')) {
        _setError('Database constraint error. The service or room may not exist.');
      } else if (e.toString().contains('duplicate key value')) {
        debugPrint('ℹ️ Workflow already exists (race condition)');
        return true; // Consider it successful
      } else {
        _setError('Failed to set up service workflow: ${e.toString()}');
      }
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
          .order('booked_at', ascending: false);
      
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

      debugPrint('TokenProvider: Loading tokens from: ${todayStart.toIso8601String()}');

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('*')
          // .gte('booked_at', todayStart.toIso8601String()) // Temporarily disabled for testing
          .order('booked_at', ascending: true);

      debugPrint('TokenProvider: Raw tokens response: $response');
      debugPrint('TokenProvider: Tokens count: ${(response as List).length}');

      // Create a map to track positions for each service and status
      final servicePositions = <String, int>{};
      
      final tokens = (response as List).map((json) {
        debugPrint('TokenProvider: Processing token JSON: $json');
        
        // Calculate queue position
        final serviceId = json['service_id'] as String?;
        final status = json['status'] as String?;
        final key = '$serviceId-$status';
        final queuePosition = (servicePositions[key] = (servicePositions[key] ?? 0) + 1);
        
        return Token.fromJson({
          ...json,
          'queue_position': queuePosition,
        });
      }).toList();
      
      // Update the all tokens list for staff dashboard
      _allTokens = tokens;
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
          .lt('booked_at', token.createdAt.toIso8601String());

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

  // Helper method to validate UUID format
  bool _isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return false;
    }

    // UUID v4 regex pattern
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    return uuidRegex.hasMatch(uuid);
  }

  // Validate that service and room exist in database
  Future<bool> _validateServiceAndRoom(String serviceId, String roomId) async {
    try {
      debugPrint('🔍 Validating service: $serviceId and room: $roomId');

      // Check if this is a known fallback service ID and map it to real database ID
      final realServiceId = _mapToRealServiceId(serviceId);
      final realRoomId = _mapToRealRoomId(roomId);

      debugPrint('📋 Mapped service ID: $serviceId → $realServiceId');
      debugPrint('📋 Mapped room ID: $roomId → $realRoomId');

      // Check if service exists
      final serviceCheck = await SupabaseConfig.client
          .from('services')
          .select('id, name')
          .eq('id', realServiceId)
          .maybeSingle();

      if (serviceCheck == null) {
        debugPrint('❌ Service not found: $realServiceId');
        _setError('Service not found. Please refresh and try again.');
        return false;
      }

      // Check if room exists
      final roomCheck = await SupabaseConfig.client
          .from('rooms')
          .select('id, name')
          .eq('id', realRoomId)
          .maybeSingle();

      if (roomCheck == null) {
        debugPrint('❌ Room not found: $realRoomId');
        _setError('Room not found. Please refresh and try again.');
        return false;
      }

      debugPrint('✅ Service and room validation passed');
      return true;
    } catch (e) {
      debugPrint('❌ Error validating service and room: $e');
      // If validation fails due to network or other issues, allow the token creation to proceed
      debugPrint('⚠️ Validation failed, proceeding with token creation anyway');
      return true;
    }
  }

  // Map fallback service IDs to real database IDs
  String _mapToRealServiceId(String serviceId) {
    const fallbackToRealMap = {
      '550e8400-e29b-41d4-a716-446655440001': '02a27834-69d3-4c4b-9635-81f91130945f', // License Renewal
      '550e8400-e29b-41d4-a716-446655440002': '76251969-6be7-4135-bfca-6ab9a31df87f', // New License
    };

    return fallbackToRealMap[serviceId] ?? serviceId;
  }

  // Map fallback room IDs to real database IDs
  String _mapToRealRoomId(String roomId) {
    const fallbackToRealMap = {
      '550e8400-e29b-41d4-a716-446655440101': 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79360', // Reception
      '550e8400-e29b-41d4-a716-446655440102': 'd2d08402-cb3b-4cb0-ae6e-c34d9bb79361', // Document Verification
    };

    return fallbackToRealMap[roomId] ?? roomId;
  }
}
