import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/trip_provider.dart';

class CitySelectionWidget extends StatelessWidget {
  const CitySelectionWidget({super.key});

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
                        Icons.location_city,
                        color: const Color(0xFF2E86C1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Gitmek İstediğiniz Şehirler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'En az 2 şehir seçmeniz önerilir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                
                // City Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: tripProvider.availableCities.length,
                  itemBuilder: (context, index) {
                    final city = tripProvider.availableCities[index];
                    return _buildCityCard(context, city, index, tripProvider);
                  },
                ),
                
                // Selected Cities Summary
                if (tripProvider.selectedCities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF27AE60).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: const Color(0xFF27AE60),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Seçilen Şehirler (${tripProvider.selectedCities.length})',
                              style: TextStyle(
                                color: const Color(0xFF27AE60),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: tripProvider.selectedCities
                              .map((city) => Chip(
                                    label: Text(
                                      '${city.emoji} ${city.name}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: const Color(0xFF27AE60).withOpacity(0.1),
                                    side: BorderSide(
                                      color: const Color(0xFF27AE60).withOpacity(0.3),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityCard(
    BuildContext context,
    City city,
    int index,
    TripProvider tripProvider,
  ) {
    return GestureDetector(
      onTap: () => tripProvider.toggleCity(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: city.isSelected 
              ? const Color(0xFF2E86C1) 
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: city.isSelected 
                ? const Color(0xFF2E86C1) 
                : Colors.grey[300]!,
            width: city.isSelected ? 2 : 1,
          ),
          boxShadow: city.isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E86C1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              city.emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    city.name,
                    style: TextStyle(
                      color: city.isSelected ? Colors.white : const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    city.code,
                    style: TextStyle(
                      color: city.isSelected 
                          ? Colors.white.withOpacity(0.8) 
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (city.isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              )
            else
              Icon(
                Icons.add_circle_outline,
                color: Colors.grey[400],
                size: 20,
              ),
          ],
        ),
      ),
    ).animate(target: city.isSelected ? 1 : 0)
     .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02));
  }
}
