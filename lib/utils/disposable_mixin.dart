import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mixin to help with automatic disposal of resources
/// Use this in StatefulWidget states to ensure cleanup
mixin DisposableMixin on State {
  final List<StreamSubscription> _subscriptions = [];
  final List<RealtimeChannel> _channels = [];
  final List<StreamController> _controllers = [];

  /// Register a subscription for automatic disposal
  void registerSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Register a Realtime channel for automatic disposal
  void registerChannel(RealtimeChannel channel) {
    _channels.add(channel);
  }

  /// Register a stream controller for automatic disposal
  void registerController(StreamController controller) {
    _controllers.add(controller);
  }

  /// Dispose all registered resources
  /// Call this in your dispose() method
  void disposeResources() {
    // Cancel all subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Unsubscribe all channels
    for (var channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();

    // Close all controllers
    for (var controller in _controllers) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    disposeResources();
    super.dispose();
  }
}

/// Example usage:
/// 
/// class MyWidgetState extends State<MyWidget> with DisposableMixin {
///   @override
///   void initState() {
///     super.initState();
///     
///     // Register subscriptions for auto-cleanup
///     final subscription = someStream.listen((data) { ... });
///     registerSubscription(subscription);
///     
///     final channel = supabase.channel('my-channel');
///     registerChannel(channel);
///   }
///   
///   // No need to override dispose() - it's handled by the mixin!
/// }
