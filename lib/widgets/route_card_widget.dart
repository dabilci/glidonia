import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteCardWidget extends StatefulWidget {
  final Map<String, dynamic> route;
  final int index;

  const RouteCardWidget({
    super.key,
    required this.route,
    required this.index,
  });

  @override
  State<RouteCardWidget> createState() => _RouteCardWidgetState();
}

class _RouteCardWidgetState extends State<RouteCardWidget> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.route['total_price']?.toDouble() ?? 0.0;
    final flights = List<Map<String, dynamic>>.from(widget.route['flights'] ?? []);
    final itinerary = List<Map<String, dynamic>>.from(widget.route['itinerary'] ?? []);
    
    return Card(
      elevation: widget.index == 0 ? 8 : 4,
      shadowColor: widget.index == 0 
          ? const Color(0xFF27AE60).withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.index == 0 
            ? BorderSide(color: const Color(0xFF27AE60), width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // Header with price and best offer badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.index == 0 
                  ? const Color(0xFF27AE60).withOpacity(0.1)
                  : null,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Best offer badge
                if (widget.index == 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EN İYİ FİYAT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Price and route summary
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            totalPrice.toString(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: widget.index == 0 
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFF2E86C1),
                            ),
                          ),
                          Text(
                            'Toplam ${flights.length} uçuş',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E86C1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${itinerary.length} şehir',
                            style: TextStyle(
                              color: const Color(0xFF2E86C1),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isExpanded = !isExpanded;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isExpanded ? 'Gizle' : 'Detaylar',
                                  style: TextStyle(
                                    color: const Color(0xFF2C3E50),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: const Color(0xFF2C3E50),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Quick route overview
                const SizedBox(height: 16),
                _buildRouteOverview(flights),
              ],
            ),
          ),
          
          // Expandable details
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isExpanded ? null : 0,
            child: isExpanded
                ? _buildExpandedDetails(flights, itinerary)
                : const SizedBox.shrink(),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showRouteDetails(context);
                    },
                    icon: Icon(Icons.info_outline),
                    label: Text('Detayları Görüntüle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E86C1),
                      side: BorderSide(color: const Color(0xFF2E86C1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _selectRoute(context);
                    },
                    icon: Icon(Icons.flight_takeoff),
                    label: Text('Bu Rotayı Seç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.index == 0 
                          ? const Color(0xFF27AE60)
                          : const Color(0xFF2E86C1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOverview(List<Map<String, dynamic>> flights) {
    if (flights.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.flight_takeoff,
                  color: const Color(0xFF2E86C1),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  flights.first['from'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward,
            color: Colors.grey[400],
            size: 16,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  flights.last['to'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.flight_land,
                  color: const Color(0xFF2E86C1),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    List<Map<String, dynamic>> flights,
    List<Map<String, dynamic>> itinerary,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight details
          _buildSectionTitle('Uçuş Detayları'),
          const SizedBox(height: 12),
          ...flights.map((flight) => _buildFlightCard(flight)).toList(),
          
          if (itinerary.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Şehir Programı'),
            const SizedBox(height: 12),
            ...itinerary.map((city) => _buildCityCard(city)).toList(),
          ],
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .slideY(begin: -0.1);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildFlightCard(Map<String, dynamic> flight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flight['from']} → ${flight['to']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                                 Text(
                   '${flight['airline']} • ${flight['duration']}',
                   style: TextStyle(
                     fontSize: 12,
                     color: Colors.grey[600],
                   ),
                 ),
                 if (flight['departure_time'] != null && flight['departure_time'] != 'TBD') ...[
                   const SizedBox(height: 2),
                   Text(
                     'Kalkış: ${flight['departure_time']}',
                     style: TextStyle(
                       fontSize: 11,
                       color: Colors.grey[500],
                     ),
                   ),
                 ],
                 // Gerçek kalkış tarihi göster (eğer istenenle farklıysa)
                 if (flight['actual_departure_date'] != null && 
                     flight['actual_departure_date'] != flight['departure_date']) ...[
                   const SizedBox(height: 2),
                   Text(
                     'Gerçek Kalkış: ${flight['actual_departure_date']}',
                     style: TextStyle(
                       fontSize: 11,
                       color: Colors.orange[600],
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
                             Text(
                 (flight['price'] ?? '0').toString(),
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                   color: const Color(0xFF2E86C1),
                 ),
               ),
                             Text(
                 flight['date'] ?? '',
                 style: TextStyle(
                   fontSize: 12,
                   color: Colors.grey[600],
                 ),
               ),
               if (flight['flight_link'] != null && flight['flight_link'] != 'TBD') ...[
                 const SizedBox(height: 4),
                                   GestureDetector(
                    onTap: () async {
                      try {
                        final url = flight['flight_link'];
                        if (url != null && url != 'TBD') {
                          // Use url_launcher to open in browser
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link açılamadı'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       color: const Color(0xFF2E86C1).withOpacity(0.1),
                       borderRadius: BorderRadius.circular(4),
                     ),
                     child: Text(
                       'Link',
                       style: TextStyle(
                         fontSize: 10,
                         color: const Color(0xFF2E86C1),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                 ),
               ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard(Map<String, dynamic> city) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city['city'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${city['arrival']} - ${city['departure']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${city['days']} gün',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Rota Detayları',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Detaylı rota bilgileri burada gösterilecek...'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRoute(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rota seçildi! Rezervasyon sayfasına yönlendiriliyor...'),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
    // TODO: Navigate to booking page
  }
}
