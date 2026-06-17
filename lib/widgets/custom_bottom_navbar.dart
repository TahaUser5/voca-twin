import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      color: const Color(0xFFF2F5F8),
      elevation: 10,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavButton(Icons.home, 'Home', 0),
            const SizedBox(width: 50), // Space for mic
            _buildNavButton(Icons.settings, 'Settings', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;
    final activeColor = const Color(0xFF2F3CFA);
    final inactiveColor = Colors.grey;

    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? activeColor : inactiveColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
