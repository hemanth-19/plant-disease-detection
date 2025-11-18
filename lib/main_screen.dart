import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'upload_capture_analyze.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    HomeScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF1F8E9), // Very light green
            Color(0xFFE8F5E8), // Light green
            Colors.white,
          ],
          stops: [0.0, 0.3, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _screens[_selectedIndex],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green[600]!,
                Colors.green[500]!,
                Colors.green[400]!,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.6),
              selectedLabelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedIndex == 0 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                    ),
                    child: Icon(Icons.home_rounded, size: 28),
                  ),
                  label: 'Home',
                ),

                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedIndex == 1 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                    ),
                    child: Icon(Icons.history_rounded, size: 28),
                  ),
                  label: 'History',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}