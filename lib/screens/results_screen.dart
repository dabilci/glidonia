import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/trip_provider.dart';
import '../widgets/route_card_widget.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Bulunan Rotalar'),
        backgroundColor: const Color(0xFF2E86C1),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter options
            },
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return _buildLoadingState();
          }
          
          if (tripProvider.searchResults.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return Column(
            children: [
              if (tripProvider.lastResultsFromDemo)
                Container(
                  width: double.infinity,
                  color: Colors.orange[100],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DEMO MODU: Backend sonucu yerine örnek veriler görüntüleniyor',
                          style: TextStyle(color: Colors.orange[900], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildResultsList(context, tripProvider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF2E86C1),
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat())
          .rotate(duration: 2000.ms),
          
          const SizedBox(height: 32),
          
          Text(
            'En İyi Rotalar Bulunuyor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C3E50),
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .then()
          .shimmer(duration: 1200.ms, color: const Color(0xFF2E86C1)),
          
          const SizedBox(height: 16),
          
          Text(
            'Bu işlem birkaç saniye sürebilir',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          )
          .animate()
          .fadeIn(duration: 800.ms, delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
            )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
            
            const SizedBox(height: 24),
            
            Text(
              'Sonuç Bulunamadı',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),
            
            const SizedBox(height: 12),
            
            Text(
              'Seçtiğiniz kriterlere uygun rota bulunamadı.\nFarklı tarihler veya şehirler deneyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 400.ms),
            
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.refresh),
              label: Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E86C1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 600.ms)
            .scale(begin: const Offset(0.8, 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, TripProvider tripProvider) {
    return CustomScrollView(
      slivers: [
        // Results Header
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2E86C1),
                  const Color(0xFF3498DB),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${tripProvider.searchResults.length} Rota Bulundu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'En ucuz seçeneklerden en pahalıya doğru sıralandı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTripSummary(tripProvider),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -0.2),
        ),
        
        // Results List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final route = tripProvider.searchResults[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  index == 0 ? 0 : 8,
                  20,
                  index == tripProvider.searchResults.length - 1 ? 20 : 8,
                ),
                child: RouteCardWidget(
                  route: route,
                  index: index,
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100 * index))
                .slideX(begin: 0.2),
              );
            },
            childCount: tripProvider.searchResults.length,
          ),
        ),
      ],
    );
  }

  Widget _buildTripSummary(TripProvider tripProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Şehirler',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tripProvider.selectedCities
                      .map((city) => city.name)
                      .join(', '),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Süre',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tripProvider.tripDuration} gün',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
