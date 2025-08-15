import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';

class TripSettingsWidget extends StatelessWidget {
  const TripSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E86C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings,
                        color: const Color(0xFF2E86C1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tatil Ayarları',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Trip Duration
                _buildDurationSection(tripProvider),
                
                const SizedBox(height: 20),
                
                // Start/End Location
                _buildLocationSection(tripProvider),
                
                const SizedBox(height: 20),
                
                // Equal Days Toggle
                _buildEqualDaysSection(tripProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDurationSection(TripProvider tripProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule,
              color: const Color(0xFF2E86C1),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Tatil Süresi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: tripProvider.tripDuration > 1
                    ? () => tripProvider.setTripDuration(tripProvider.tripDuration - 1)
                    : null,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: tripProvider.tripDuration > 1 
                      ? const Color(0xFF2E86C1) 
                      : Colors.grey[400],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${tripProvider.tripDuration}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E86C1),
                      ),
                    ),
                    Text(
                      'gün',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: tripProvider.tripDuration < 30
                    ? () => tripProvider.setTripDuration(tripProvider.tripDuration + 1)
                    : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: tripProvider.tripDuration < 30 
                      ? const Color(0xFF2E86C1) 
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(TripProvider tripProvider) {
    final locations = ['Istanbul', 'Ankara', 'Izmir', 'Antalya'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              color: const Color(0xFF2E86C1),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Başlangıç & Bitiş Noktası',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLocationDropdown(
                'Nereden',
                tripProvider.startLocation,
                locations,
                (value) => tripProvider.setStartLocation(value!),
                Icons.flight_takeoff,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLocationDropdown(
                'Nereye Dönüş',
                tripProvider.endLocation,
                locations,
                (value) => tripProvider.setEndLocation(value!),
                Icons.flight_land,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationDropdown(
    String hint,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: const Color(0xFF2E86C1),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEqualDaysSection(TripProvider tripProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.balance,
              color: const Color(0xFF2E86C1),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Şehirlerde Kalış Süresi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToggleOption(
                'Eşit Gün',
                'Her şehirde eşit süre',
                tripProvider.equalDays,
                () => tripProvider.setEqualDays(true),
                Icons.balance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToggleOption(
                'Farklı Gün',
                'Algoritma karar versin',
                !tripProvider.equalDays,
                () => tripProvider.setEqualDays(false),
                Icons.auto_awesome,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E86C1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E86C1) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF2E86C1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white.withOpacity(0.8) 
                    : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
