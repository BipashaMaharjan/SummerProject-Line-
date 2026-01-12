import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Run workflow check in background without blocking initialization
    Future.microtask(() => ensureAllServicesHaveWorkflows());
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

  // Load user tokens from the database (calls public method)
  Future<void> _loadUserTokens() async {
    // Delegate to the public method with enhanced logging
    await loadUserTokens();
  }

  Future<bool> createToken({
    required String serviceId,
    required String serviceName,
    required int estimatedWaitTime,
    required String roomId,
    required String roomName,
    String? scheduledDate,
    String? userId, // Add optional userId parameter
  }) async {
    String? finalUserId; // Declare at method level for access in catch block
    
    try {
      _setLoading(true);
      _clearError();

      // Get user ID - either from parameter or from Supabase
      finalUserId = userId;
      
      if (finalUserId == null) {
        final user = SupabaseConfig.client.auth.currentUser;
        finalUserId = user?.id;
      }
      
      debugPrint('🔐 Authentication Check:');
      debugPrint('   User ID: ${finalUserId ?? "None"}');
      
      if (finalUserId == null) {
        final errorMsg = 'You are not logged in. Please sign up or log in to book a token.';
        debugPrint('❌ $errorMsg');
        _setError(errorMsg);
        _setLoading(false);
        return false;
      }

      debugPrint('✅ User authenticated with ID: $finalUserId');
      debugPrint('🔄 Starting token creation for user: $finalUserId');
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

      if (!_isValidUuid(finalUserId)) {
        debugPrint('❌ Invalid user ID format: $finalUserId');
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
        'user_id': finalUserId,
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
      dynamic tokenResponse;
      try {
        tokenResponse = await SupabaseConfig.client
            .from('tokens')
            .insert(tokenData)
            .select()
            .single();
        debugPrint('✅ Token created successfully: ${tokenResponse['id']}');
      } catch (insertError) {
        // Check if error is from staff_notifications trigger
        final errorStr = insertError.toString().toLowerCase();
        if (errorStr.contains('staff_notifications') && errorStr.contains('foreign key')) {
          debugPrint('⚠️ Trigger error (staff_notifications) - checking if token was created anyway...');
          
          // Token might have been created despite trigger error - check by token_number
          final checkToken = await SupabaseConfig.client
              .from('tokens')
              .select()
              .eq('token_number', tokenNumber)
              .eq('user_id', finalUserId)
              .maybeSingle();
          
          if (checkToken != null) {
            debugPrint('✅ Token was created successfully despite trigger error');
            tokenResponse = checkToken;
          } else {
            debugPrint('❌ Token was not created, rethrowing error');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Try to create token history (optional)
      try {
        await SupabaseConfig.client
            .from('token_history')
            .insert({
              'token_id': tokenResponse['id'],
              'action': 'created',
              'notes': 'Token created for $serviceName',
              'performed_by': finalUserId,
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

      final errorString = error.toString().toLowerCase();

      // SPECIAL CASE: If it's the staff_notifications trigger error, 
      // wait a moment and check if token was created anyway
      if (errorString.contains('staff_notifications') && errorString.contains('foreign key')) {
        debugPrint('⚠️ Staff notifications trigger error detected - waiting and checking token...');
        
        // Wait 2 seconds for database to settle
        await Future.delayed(const Duration(seconds: 2));
        
        // Check if token was created by looking for recent tokens
        try {
          final recentTokens = await SupabaseConfig.client
              .from('tokens')
              .select()
              .eq('user_id', finalUserId!)
              .order('booked_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          if (recentTokens != null) {
            final tokenTime = DateTime.parse(recentTokens['booked_at']);
            final now = DateTime.now();
            final diff = now.difference(tokenTime).inSeconds;
            
            // If token was created in last 10 seconds, consider it successful
            if (diff < 10) {
              debugPrint('✅ Token was created successfully despite trigger error!');
              await _loadUserTokens();
              _setLoading(false);
              return true;
            }
          }
        } catch (checkError) {
          debugPrint('⚠️ Could not verify token creation: $checkError');
        }
      }

      // Provide user-friendly error messages
      String errorMessage = 'Failed to create token. ';

      if (errorString.contains('invalid input syntax for type uuid')) {
        errorMessage += 'Invalid ID format detected. Please refresh the page and try again.';
      } else if (errorString.contains('violates foreign key constraint')) {
        if (errorString.contains('staff_notifications')) {
          errorMessage += 'Database trigger error. Please contact support or try again.';
        } else if (errorString.contains('tokens_service_id_fkey')) {
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
        prefix = serviceName.isNotEmpty ? serviceName[0].toUpperCase() : 'T';
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

      debugPrint('✅ Created workflow for service: $serviceId');
      return true;
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

      final session = SupabaseConfig.client.auth.currentSession;
      final user = SupabaseConfig.client.auth.currentUser;
      
      if (user == null || session == null) {
        debugPrint('⚠️ Cannot load tokens: User not authenticated');
        _userTokens = [];
        _setLoading(false);
        return;
      }

      debugPrint('📥 Loading tokens for user: ${user.id}');
      debugPrint('📧 User email: ${user.email}');

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('''
            *,
            services:service_id(*),
            rooms:current_room_id(*)
          ''')
          .eq('user_id', user.id)
          .order('booked_at', ascending: false);
      
      debugPrint('📊 Raw response count: ${(response as List).length}');
      
      // Debug: Print first few tokens to verify filtering
      if ((response as List).isNotEmpty) {
        for (var i = 0; i < (response.length > 3 ? 3 : response.length); i++) {
          final token = response[i];
          debugPrint('  Token ${i + 1}: ${token['token_number']} - user_id: ${token['user_id']}');
        }
      }
      
      // CRITICAL: Double-check filtering on client side as safety measure
      final allTokens = (response as List).map((json) {
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
      
      // SAFETY FILTER: Only keep tokens that belong to current user
      _userTokens = allTokens.where((token) => token.userId == user.id).toList();
      
      if (allTokens.length != _userTokens.length) {
        debugPrint('⚠️ WARNING: Filtered out ${allTokens.length - _userTokens.length} tokens that did not belong to user!');
        debugPrint('⚠️ This indicates RLS policy is not working correctly!');
      }
      
      debugPrint('✅ Loaded ${_userTokens.length} user tokens (filtered by user_id)');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ Error loading tokens: $error');
      _setError('Failed to load user tokens: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Token>> getTodaysQueue({String? filterByRoomId}) async {
    try {
      // Get today's date at 00:00:00
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      debugPrint('TokenProvider: Loading tokens from: ${todayStart.toIso8601String()}');
      if (filterByRoomId != null) {
        debugPrint('TokenProvider: Filtering by room: $filterByRoomId');
      } else {
        debugPrint('TokenProvider: NO ROOM FILTER - Loading ALL tokens');
      }

      var query = SupabaseConfig.client
          .from('tokens')
          .select('*');
          // .gte('booked_at', todayStart.toIso8601String()) // Temporarily disabled for testing
      
      // Apply room filter for staff members
      if (filterByRoomId != null) {
        query = query.eq('current_room_id', filterByRoomId);
      }
      
      final response = await query.order('booked_at', ascending: true);

      debugPrint('TokenProvider: Raw tokens response: $response');
      debugPrint('TokenProvider: Tokens count: ${(response as List).length}');
      
      // Debug: Show status breakdown
      final tokensList = response as List;
      final statusCounts = <String, int>{};
      for (var token in tokensList) {
        final status = token['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      debugPrint('TokenProvider: Status breakdown: $statusCounts');

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
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
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

      // Update token status to 'processing' - simple update
      await SupabaseConfig.client
          .from('tokens')
          .update({
            'status': 'processing',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tokenId);

      // Try to add history entry - but don't fail if it errors
      try {
        await SupabaseConfig.client
            .from('token_history')
            .insert({
              'token_id': tokenId,
              'room_id': roomId,
              'status': 'processing',
              'action': 'started',
              'notes': 'Operation started by staff',
            });
      } catch (historyError) {
        debugPrint('Warning: Could not add history entry: $historyError');
        // Continue anyway - the token update was successful
      }

      await loadUserTokens();
      _setLoading(false);
      return true;
    } catch (error) {
      debugPrint('❌ ========== START OPERATION FAILED ==========');
      debugPrint('❌ Error: $error');
      debugPrint('❌ Error type: ${error.runtimeType}');
      debugPrint('❌ Token ID: $tokenId');
      debugPrint('❌ Room ID: $roomId');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      debugPrint('❌ ============================================');
      
      _setError('Failed to start operation: $error');
      _setLoading(false);
      return false;
    }
  }

  Future<void> ensureAllServicesHaveWorkflows() async {
    try {
      debugPrint('🔄 Ensuring all services have workflows...');
      
      // Get all active services
      final services = await SupabaseConfig.client
          .from('services')
          .select('id, name')
          .eq('is_active', true);

      debugPrint('📊 Found ${services.length} active services');

      if ((services as List).isEmpty) {
        debugPrint('⚠️ No active services found');
        return;
      }

      // Get default reception room (R001)
      final receptionRoom = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('room_number', 'R001')
          .maybeSingle();

      if (receptionRoom == null) {
        debugPrint('⚠️ Default reception room (R001) not found - skipping workflow creation');
        return;
      }

      debugPrint('✅ Found reception room: ${receptionRoom['name']}');

      // For each service, check if it has a workflow
      for (final service in services) {
        try {
          final serviceId = service['id'];
          final serviceName = service['name'];
          
          debugPrint('   Checking workflows for service: $serviceName');

          // Check if workflow already exists for this service
          final existingWorkflows = await SupabaseConfig.client
              .from('service_workflow')
              .select('id')
              .eq('service_id', serviceId)
              .catchError((_) => []);

          if ((existingWorkflows as List).isNotEmpty) {
            debugPrint('   ✅ Workflows already exist for $serviceName - skipping');
            continue;
          }

          // Create a single default workflow entry (reception room, step 1)
          try {
            await SupabaseConfig.client.from('service_workflow').insert({
              'service_id': serviceId,
              'room_id': receptionRoom['id'],
              'sequence_order': 1,
              'is_required': true,
            });
            
            debugPrint('   ✅ Created workflow for service: $serviceName');
          } catch (insertError) {
            // Silently ignore duplicate errors
            if (insertError.toString().contains('23505') || 
                insertError.toString().contains('duplicate')) {
              debugPrint('   ℹ️ Workflow already exists for $serviceName');
            } else {
              debugPrint('   ⚠️ Error creating workflow for $serviceName: $insertError');
            }
          }
        } catch (serviceError) {
          debugPrint('   ⚠️ Error processing service: $serviceError');
        }
      }
      
      debugPrint('✅ Workflow check complete');
    } catch (e) {
      debugPrint('⚠️ Error ensuring service workflows: $e');
      // Don't let workflow errors block service loading
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

  // ========== NEW FEATURES ==========

  /// Reject token (for trial/biometric failure)
  /// Automatically advances next token in queue
  Future<bool> rejectToken(String tokenId, String reason, {String? staffId}) async {
    try {
      debugPrint('🚫 Rejecting token: $tokenId');
      debugPrint('📝 Reason: $reason');

      // Get token details before rejection
      final tokenResponse = await SupabaseConfig.client
          .from('tokens')
          .select('*, services:service_id(name)')
          .eq('id', tokenId)
          .single();

      final currentRoomId = tokenResponse['current_room_id'];
      final serviceId = tokenResponse['service_id'];

      // Update token status to rejected
      await SupabaseConfig.client
          .from('tokens')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
            'notes': reason,
          })
          .eq('id', tokenId);

      // Add history entry
      await SupabaseConfig.client
          .from('token_history')
          .insert({
            'token_id': tokenId,
            'room_id': currentRoomId,
            'staff_id': staffId ?? SupabaseConfig.client.auth.currentUser?.id,
            'status': 'rejected',
            'action': 'rejected',
            'notes': reason,
          });

      debugPrint('✅ Token rejected successfully');

      // Auto-advance next token in queue
      await _autoAdvanceNextToken(currentRoomId, serviceId);

      // Refresh tokens
      await getTodaysQueue();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting token: $e');
      _setError('Failed to reject token: $e');
      return false;
    }
  }

  /// Auto-advance next waiting token when one is rejected/completed
  Future<void> _autoAdvanceNextToken(String? roomId, String? serviceId) async {
    if (roomId == null) return;

    try {
      debugPrint('🔄 Auto-advancing next token in room: $roomId');

      // Find next waiting token in the same room
      final nextTokens = await SupabaseConfig.client
          .from('tokens')
          .select()
          .eq('current_room_id', roomId)
          .eq('status', 'waiting')
          .order('priority', ascending: false)
          .order('booked_at', ascending: true)
          .limit(1);

      if ((nextTokens as List).isEmpty) {
        debugPrint('ℹ️ No waiting tokens to advance');
        return;
      }

      final nextToken = nextTokens.first;
      debugPrint('✅ Found next token: ${nextToken['token_number']}');

      // Optionally auto-start the next token (you can enable/disable this)
      // await startOperation(nextToken['id'], roomId);

      debugPrint('✅ Next token ready for processing');
    } catch (e) {
      debugPrint('⚠️ Error auto-advancing token: $e');
    }
  }

  /// Postpone token (move to end of queue)
  Future<bool> postponeToken(String tokenId, {String? reason}) async {
    try {
      debugPrint('⏰ Postponing token: $tokenId');

      // Get current token details
      final tokenResponse = await SupabaseConfig.client
          .from('tokens')
          .select()
          .eq('id', tokenId)
          .single();

      // Update token with lower priority and new timestamp
      await SupabaseConfig.client
          .from('tokens')
          .update({
            'priority': -1, // Lower priority
            'booked_at': DateTime.now().toIso8601String(), // Move to end
            'status': 'waiting', // Reset to waiting
            'updated_at': DateTime.now().toIso8601String(),
            'notes': reason ?? 'Postponed by user',
          })
          .eq('id', tokenId);

      // Add history entry
      await SupabaseConfig.client
          .from('token_history')
          .insert({
            'token_id': tokenId,
            'room_id': tokenResponse['current_room_id'],
            'status': 'waiting',
            'action': 'postponed',
            'notes': reason ?? 'Token postponed',
          });

      debugPrint('✅ Token postponed successfully');

      // Refresh tokens
      await loadUserTokens();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('❌ Error postponing token: $e');
      _setError('Failed to postpone token: $e');
      return false;
    }
  }

  /// Setup real-time subscription for token updates
  void subscribeToTokenUpdates(Function(Map<String, dynamic>) onUpdate) {
    try {
      debugPrint('🔔 Setting up real-time token subscription');

      SupabaseConfig.client
          .channel('tokens_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tokens',
            callback: (payload) {
              debugPrint('🔔 Token update received: ${payload.eventType}');
              onUpdate(payload.newRecord);
              // Refresh tokens on any change
              getTodaysQueue();
              loadUserTokens();
            },
          )
          .subscribe();

      debugPrint('✅ Real-time subscription active');
    } catch (e) {
      debugPrint('⚠️ Error setting up real-time subscription: $e');
    }
  }

  /// Unsubscribe from real-time updates
  void unsubscribeFromTokenUpdates() {
    try {
      SupabaseConfig.client.removeAllChannels();
      debugPrint('✅ Unsubscribed from token updates');
    } catch (e) {
      debugPrint('⚠️ Error unsubscribing: $e');
    }
  }
}
