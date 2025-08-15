import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  // Backend URL - Web için canlı sunucu, mobil için localhost
  static const String _liveBaseUrl = 'https://glidonia.onrender.com'; // Canlı backend adresi
  static const String _localBaseUrl = 'http://127.0.0.1:8000';
  
  static String get baseUrl {
    // Eğer web platformundaysak canlı sunucuyu, değilsek (mobil, masaüstü) yerel sunucuyu kullan
    if (kIsWeb) {
      return _liveBaseUrl;
    }
    return _localBaseUrl;
  }
  
  // POST isteği ile rota arama
  Future<List<Map<String, dynamic>>> searchRoutes(Map<String, dynamic> tripData) async {
    try {
      final url = Uri.parse('$baseUrl/find-route');
      
      // Headers - JSON formatında veri gönderdiğimizi belirtiyoruz
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Backend formatına dönüştür
      final backendPayload = _convertToBackendFormat(tripData);
      
      // Request body - backend formatında veri gönder
      final body = jsonEncode(backendPayload);
      
      print('API Request URL: $url');
      print('API Request Body: $body');
      
      // POST isteği gönder
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(
        const Duration(seconds: 30), // 30 saniye timeout
      );
      
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      
      // Response kontrolü
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        // Backend response formatı: {"best_route": {...}, "alternatives": [...]}
        if (jsonResponse is Map<String, dynamic>) {
          List<Map<String, dynamic>> routes = [];
          
          // En iyi rotayı ekle
          if (jsonResponse.containsKey('best_route')) {
            routes.add(_convertFromBackendFormat(jsonResponse['best_route']));
          }
          
          // Alternatifleri ekle
          if (jsonResponse.containsKey('alternatives')) {
            final alternatives = List<Map<String, dynamic>>.from(jsonResponse['alternatives']);
            routes.addAll(alternatives.map((alt) => _convertFromBackendFormat(alt)));
          }
          
          return routes;
        } else {
          throw Exception('Beklenmeyen response formatı');
        }
      } else if (response.statusCode == 404) {
        // Kriterlere uygun rota bulunamadı
        return [];
      } else if (response.statusCode == 500) {
        throw Exception('Sunucu hatası. Lütfen daha sonra tekrar deneyin.');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
      
    } on SocketException {
      throw Exception('İnternet bağlantısı yok veya backend servisi çalışmıyor.');
    } on HttpException {
      throw Exception('HTTP bağlantı hatası.');
    } on FormatException {
      throw Exception('Sunucudan gelen veri formatı hatalı.');
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else {
        throw Exception('Bilinmeyen hata: ${e.toString()}');
      }
    }
  }
  
  // Backend sağlık kontrolü
  Future<bool> checkBackendHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Frontend formatından backend formatına dönüştür
  Map<String, dynamic> _convertToBackendFormat(Map<String, dynamic> tripData) {
    // Şehir kodlarını IATA kodlarına dönüştür
    final cityCodeMap = {
      'ROM': 'FCO',  // Roma
      'BCN': 'BCN',  // Barcelona  
      'PAR': 'CDG',  // Paris
      'BER': 'BER',  // Berlin
      'AMS': 'AMS',  // Amsterdam
      'PRG': 'PRG',  // Prague
      'VIE': 'VIE',  // Vienna
      'BUD': 'BUD',  // Budapest
    };
    
    final startLocationMap = {
      'Istanbul': 'IST',
      'Ankara': 'ESB',
      'Izmir': 'ADB',
      'Antalya': 'AYT',
    };
    
    final cities = List<String>.from(tripData['cities'] ?? []);
    final iataCodeCities = cities.map((city) => cityCodeMap[city] ?? city).toList();
    
    return {
      'start_range_start': tripData['start_date']?.toString().split('T')[0] ?? '',
      'start_range_end': tripData['end_date']?.toString().split('T')[0] ?? '',
      'trip_length_days': tripData['trip_duration'] ?? 7,
      'start_airport': startLocationMap[tripData['start_location']] ?? 'IST',
      'end_airport': startLocationMap[tripData['end_location']] ?? 'IST',
      'cities': iataCodeCities,
      'equal_days': tripData['equal_days'] ?? true,
      'max_candidates': 20,
    };
  }
  
  // Backend formatından frontend formatına dönüştür
  Map<String, dynamic> _convertFromBackendFormat(Map<String, dynamic> backendRoute) {
    final legDetails = List<Map<String, dynamic>>.from(backendRoute['leg_details'] ?? []);
    final route = List<String>.from(backendRoute['route'] ?? []);
    final daysPerCity = List<int>.from(backendRoute['days_per_city'] ?? []);
    
    // Uçuş bilgilerini oluştur
      List<Map<String, dynamic>> flights = legDetails.map((leg) {
      // Havayolu ve uçuş numarasını birleştir
      String airlineDisplay = leg['airline'] ?? 'TBD';
      if (leg['flight_number'] != null && leg['flight_number'] != 'TBD') {
        airlineDisplay = '${leg['airline']} ${leg['flight_number']}';
      }
      
      // Fiyat ve para birimini birleştir
      String priceDisplay = '${leg['min_price']}';
      if (leg['currency'] != null && leg['currency'] != 'TBD') {
        priceDisplay = '${leg['min_price']} ${leg['currency']}';
      }
      
      return {
        'from': _getLocationName(leg['origin']),
        'to': _getLocationName(leg['destination']),
        'date': leg['departure_date'],
        'price': priceDisplay,
        'airline': airlineDisplay,
        'duration': leg['duration'] ?? 'TBD',
        'raw_price': leg['min_price'],
        'currency': leg['currency'] ?? 'TBD',
        'flight_number': leg['flight_number'] ?? 'TBD',
        'departure_time': leg['departure_time'] ?? 'TBD',
        'flight_link': leg['flight_link'] ?? 'TBD',
      };
    }).toList();
    
    // Şehir programını oluştur
    List<Map<String, dynamic>> itinerary = [];
    for (int i = 0; i < daysPerCity.length && i + 1 < route.length - 1; i++) {
      final cityCode = route[i + 1]; // İlk eleman start location
      final days = daysPerCity[i];
      
      itinerary.add({
        'city': _getLocationName(cityCode),
        'days': days,
        'arrival': legDetails.length > i ? legDetails[i]['departure_date'] : '',
        'departure': legDetails.length > i + 1 ? legDetails[i + 1]['departure_date'] : '',
      });
    }
    
    return {
      'route_id': DateTime.now().millisecondsSinceEpoch, // Unique ID
      'total_price': backendRoute['total_price'],
      'total_duration': daysPerCity.isNotEmpty ? daysPerCity.reduce((a, b) => a + b) : 0,
      'flights': flights,
      'itinerary': itinerary,
      'start_date': backendRoute['start_date'],
    };
  }
  
  // IATA kodundan şehir ismi al
  String _getLocationName(String code) {
    final codeToName = {
      'IST': 'Istanbul',
      'ESB': 'Ankara', 
      'ADB': 'Izmir',
      'AYT': 'Antalya',
      'FCO': 'Roma',
      'BCN': 'Barcelona',
      'CDG': 'Paris',
      'BER': 'Berlin',
      'AMS': 'Amsterdam',
      'PRG': 'Prague',
      'VIE': 'Vienna',
      'BUD': 'Budapest',
    };
    
    return codeToName[code] ?? code;
  }
  
  // Test verisi - backend yoksa mock data dönderir
  List<Map<String, dynamic>> getMockResults() {
    return [
      {
        'route_id': 1,
        'total_price': 450.0,
        'total_duration': 12,
        'flights': [
          {
            'from': 'Istanbul',
            'to': 'Berlin',
            'date': '2024-06-15',
            'price': 120.0,
            'airline': 'Turkish Airlines',
            'duration': '3h 30m'
          },
          {
            'from': 'Berlin',
            'to': 'Barcelona',
            'date': '2024-06-18',
            'price': 80.0,
            'airline': 'Ryanair',
            'duration': '2h 15m'
          },
          {
            'from': 'Barcelona',
            'to': 'Paris',
            'date': '2024-06-21',
            'price': 95.0,
            'airline': 'Vueling',
            'duration': '1h 45m'
          },
          {
            'from': 'Paris',
            'to': 'Roma',
            'date': '2024-06-24',
            'price': 85.0,
            'airline': 'Air France',
            'duration': '2h 30m'
          },
          {
            'from': 'Roma',
            'to': 'Istanbul',
            'date': '2024-06-27',
            'price': 70.0,
            'airline': 'Turkish Airlines',
            'duration': '3h 45m'
          }
        ],
        'itinerary': [
          {'city': 'Berlin', 'days': 3, 'arrival': '2024-06-15', 'departure': '2024-06-18'},
          {'city': 'Barcelona', 'days': 3, 'arrival': '2024-06-18', 'departure': '2024-06-21'},
          {'city': 'Paris', 'days': 3, 'arrival': '2024-06-21', 'departure': '2024-06-24'},
          {'city': 'Roma', 'days': 3, 'arrival': '2024-06-24', 'departure': '2024-06-27'}
        ]
      },
      {
        'route_id': 2,
        'total_price': 480.0,
        'total_duration': 12,
        'flights': [
          {
            'from': 'Istanbul',
            'to': 'Roma',
            'date': '2024-06-15',
            'price': 140.0,
            'airline': 'Turkish Airlines',
            'duration': '3h 15m'
          },
          {
            'from': 'Roma',
            'to': 'Paris',
            'date': '2024-06-18',
            'price': 85.0,
            'airline': 'Alitalia',
            'duration': '2h 30m'
          },
          {
            'from': 'Paris',
            'to': 'Barcelona',
            'date': '2024-06-21',
            'price': 90.0,
            'airline': 'Air France',
            'duration': '1h 45m'
          },
          {
            'from': 'Barcelona',
            'to': 'Berlin',
            'date': '2024-06-24',
            'price': 95.0,
            'airline': 'Vueling',
            'duration': '2h 15m'
          },
          {
            'from': 'Berlin',
            'to': 'Istanbul',
            'date': '2024-06-27',
            'price': 70.0,
            'airline': 'Turkish Airlines',
            'duration': '3h 30m'
          }
        ],
        'itinerary': [
          {'city': 'Roma', 'days': 3, 'arrival': '2024-06-15', 'departure': '2024-06-18'},
          {'city': 'Paris', 'days': 3, 'arrival': '2024-06-18', 'departure': '2024-06-21'},
          {'city': 'Barcelona', 'days': 3, 'arrival': '2024-06-21', 'departure': '2024-06-24'},
          {'city': 'Berlin', 'days': 3, 'arrival': '2024-06-24', 'departure': '2024-06-27'}
        ]
      }
    ];
  }
}
