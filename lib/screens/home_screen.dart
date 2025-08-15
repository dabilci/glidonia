import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/trip_provider.dart';
import '../widgets/date_selection_widget.dart';
import '../widgets/city_selection_widget.dart';
import '../widgets/trip_settings_widget.dart';
import '../widgets/search_button_widget.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF2E86C1),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Gelidonia',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2E86C1),
                      const Color(0xFF3498DB),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 50,
                      right: 20,
                      child: Icon(
                        Icons.flight_takeoff,
                        size: 100,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Akıllı Avrupa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            'Tatil Planlayıcısı',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Message
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E86C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: const Color(0xFF2E86C1),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'En Uygun Rotayı Bulalım!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tarihleri ve şehirleri seç, biz en ucuz rotayı bulalım.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2),
                  
                  const SizedBox(height: 24),
                  
                  // Date Selection
                  _buildSectionTitle('📅 Tatil Tarihleri'),
                  const SizedBox(height: 12),
                  const DateSelectionWidget()
                    .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 24),
                  
                  // City Selection
                  _buildSectionTitle('🌍 Gezilecek Şehirler'),
                  const SizedBox(height: 12),
                  const CitySelectionWidget()
                    .animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 24),
                  
                  // Trip Settings
                  _buildSectionTitle('⚙️ Tatil Ayarları'),
                  const SizedBox(height: 12),
                  const TripSettingsWidget()
                    .animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 32),
                  
                  // Search Button
                  const SearchButtonWidget()
                    .animate().fadeIn(duration: 400.ms, delay: 400.ms).scale(begin: Offset(0.8, 0.8)),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2C3E50),
      ),
    );
  }
}
