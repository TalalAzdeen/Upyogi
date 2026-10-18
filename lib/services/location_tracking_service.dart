import 'package:signalr_netcore/signalr_client.dart';
import 'app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationTrackingService {
  static String get hubUrl => AppConfig.locationHubUrl;

  HubConnection? _hubConnection;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    await _hubConnection!.start()?.timeout(const Duration(seconds: 30));
  }

  Future<void> joinBookingGroup(int bookingId) async {
    await _hubConnection?.invoke("JoinBookingGroup", args: [bookingId]);
  }

  Future<void> leaveBookingGroup(int bookingId) async {
    await _hubConnection?.invoke("LeaveBookingGroup", args: [bookingId]);
  }

  Future<void> sendLocation(int bookingId, double lat, double lng) async {
    await _hubConnection?.invoke("SendLocation", args: [bookingId, lat, lng]);
  }

  void onLocationReceived(Function(double lat, double lng) callback) {
    _hubConnection?.on("ReceiveLocation", (arguments) {
      if (arguments != null && arguments.length >= 2) {
        final lat = (arguments[0] as num).toDouble();
        final lng = (arguments[1] as num).toDouble();
        callback(lat, lng);
      }
    });
  }

  Future<void> disconnect() async {
    final connection = _hubConnection;
    _hubConnection = null;
    try {
      await connection?.stop()?.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Cleanup must not surface an unhandled exception after screen disposal.
    }
  }
}
