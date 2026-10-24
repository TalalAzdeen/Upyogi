String confirmationEmailMessage(String status) => const {
  'queued':'Booking confirmed. Confirmation email is queued.',
  'processing':'Sending the confirmation email...',
  'submitted':'Confirmation email submitted to the mail provider.',
  'delivered':'Delivery of the confirmation email was confirmed.',
  'delayed':'The mail provider reported a delivery delay.',
  'bounced':'The confirmation email could not be delivered. Check your registered email.',
  'recipient_invalid':'Your account uses a test or invalid email. Sign in with a real email address.',
  'recipient_unverified':'Verify your account email before receiving booking confirmations.',
  'not_configured':'Booking confirmed. Email has not been sent because the mail provider is not configured.',
  'failed':'Booking confirmed, but email could not be sent. You can retry.',
  'blocked':'The confirmation email could not be sent. Check the account email and mail settings.',
  'not_requested':'You can request a confirmation email to your registered account email.',
}[status] ?? 'Booking confirmed. Confirmation email is queued.';
