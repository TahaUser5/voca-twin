import 'package:flutter/material.dart';

class Helpers {
  static void showSnackbar(BuildContext context, String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
