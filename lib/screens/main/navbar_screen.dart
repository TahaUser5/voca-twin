import 'package:flutter/material.dart';

class CustomNavBar extends StatelessWidget {
  final void Function(int) onItemSelected;
  final int selectedIndex;

  const CustomNavBar({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      selectedItemColor: Colors.blue[800],
      unselectedItemColor: Colors.grey,
    );
  }
}