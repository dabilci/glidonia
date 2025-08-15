import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/trip_provider.dart';
import '../services/api_service.dart';
import '../screens/results_screen.dart';

class SearchButtonWidget extends StatelessWidget {
  const SearchButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        return Column(
          children: [
            // Search Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: tripProvider.canSearch && !tripProvider.isLoading
                    ? () => _performSearch(context, tripProvider)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tripProvider.canSearch 
                      ? const Color(0xFF2E86C1) 
                      : Colors.grey[400],
                  foregroundColor: Colors.white,
                  elevation: tripProvider.canSearch ? 8 : 0,
                  shadowColor: const Color(0xFF2E86C1).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: tripProvider.isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'En İyi Rotalar Bulunuyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'En Uygun Rotayı Bul',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
            
            // Requirements Info
            if (!tripProvider.canSearch) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arama için gerekli bilgiler:',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getMissingRequirements(tripProvider),
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Quick Tips
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E86C1).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2E86C1).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: const Color(0xFF2E86C1),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İpucu: Daha fazla şehir seçerek daha çok rota seçeneği elde edebilirsiniz!',
                      style: TextStyle(
                        color: const Color(0xFF2E86C1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMissingRequirements(TripProvider tripProvider) {
    List<String> missing = [];
    
    if (tripProvider.startDate == null || tripProvider.endDate == null) {
      missing.add('• Tatil tarihleri seçin');
    }
    
    if (tripProvider.selectedCities.isEmpty) {
      missing.add('• En az bir şehir seçin');
    }
    
    if (tripProvider.tripDuration <= 0) {
      missing.add('• Tatil süresini ayarlayın');
    }
    
    return missing.join('\n');
  }

  Future<void> _performSearch(BuildContext context, TripProvider tripProvider) async {
    try {
      tripProvider.setLoading(true);
      
      // Get trip data
      final tripData = tripProvider.getTripData();
      
      // Call API service
      final apiService = ApiService();
      
      // Önce backend'in çalışıp çalışmadığını kontrol et
      final isBackendHealthy = await apiService.checkBackendHealth();
      
      List<Map<String, dynamic>> results;
      
      if (isBackendHealthy) {
        // Backend çalışıyor, gerçek arama yap
        results = await apiService.searchRoutes(tripData);
        // Eğer sonuç yoksa, kullanıcıya net şekilde bildir ve demo moduna düş
        if (results.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kriterlere uygun gerçek sonuç bulunamadı, demo veriler gösteriliyor'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          results = apiService.getMockResults();
          tripProvider.setLastResultsFromDemo(true);
        } else {
          tripProvider.setLastResultsFromDemo(false);
        }
      } else {
        // Backend çalışmıyor, mock veriler göster
        print('Backend çalışmıyor, mock veriler gösteriliyor...');
        await Future.delayed(const Duration(seconds: 2)); // Gerçekçi yükleme süresi
        results = apiService.getMockResults();
        tripProvider.setLastResultsFromDemo(true);
        
        // Kullanıcıya backend çalışmadığını bildir
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backend bağlantısı yok, demo veriler gösteriliyor'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
      
      // Update provider with results
      tripProvider.setSearchResults(results);
      
      // Navigate to results
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ResultsScreen(),
          ),
        );
      }
      
    } catch (e) {
      // Hata durumunda mock veriler göster
      print('Hata oluştu, mock veriler gösteriliyor: $e');
      final apiService = ApiService();
      final mockResults = apiService.getMockResults();
      tripProvider.setSearchResults(mockResults);
      tripProvider.setLastResultsFromDemo(true);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı sorunu, demo veriler gösteriliyor'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ResultsScreen(),
          ),
        );
      }
    } finally {
      tripProvider.setLoading(false);
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[600],
            ),
            const SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Text(
          'Arama sırasında bir hata oluştu:\n$error\n\nLütfen tekrar deneyin.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tamam',
              style: TextStyle(
                color: const Color(0xFF2E86C1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
