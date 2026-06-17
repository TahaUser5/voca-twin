class Validators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return "Email is required";
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(email)) return "Invalid email format";
    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) return "Phone number is required";
    final regex = RegExp(r'^\d{10}$');
    if (!regex.hasMatch(phone)) return "Enter a valid 10-digit phone number";
    return null;
  }
}
