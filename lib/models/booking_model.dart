class BookingModel {
  final int id;
  final String confirmationEmailStatus;
  final int serviceId;
  final String serviceTitle;
  final String customerName;
  final String customerPhone;
  final String providerName;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String serviceAddress;
  final String? notes;
  final double amount;
  final String paymentStatus;
  final String bookingStatus;

  BookingModel({
    required this.id,
    this.confirmationEmailStatus = 'not_requested',
    required this.serviceId,
    required this.serviceTitle,
    required this.customerName,
    required this.customerPhone,
    required this.providerName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.serviceAddress,
    this.notes,
    required this.amount,
    required this.paymentStatus,
    required this.bookingStatus,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? 0,
      confirmationEmailStatus: json['confirmationEmailStatus'] ?? 'not_requested',
      serviceId: json['serviceId'] ?? 0,
      serviceTitle: json['serviceTitle'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      providerName: json['providerName'] ?? '',
      appointmentDate: DateTime.tryParse(json['appointmentDate'] ?? '') ?? DateTime.now(),
      appointmentTime: json['appointmentTime'] ?? '',
      serviceAddress: json['serviceAddress'] ?? '',
      notes: json['notes'],
      amount: (json['amount'] ?? 0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      bookingStatus: json['bookingStatus'] ?? 'Requested',
    );
  }
}
