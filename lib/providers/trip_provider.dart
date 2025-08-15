import 'package:flutter/foundation.dart';

class City {
  final String name;
  final String code;
  final String emoji;
  bool isSelected;

  City({
    required this.name,
    required this.code,
    required this.emoji,
    this.isSelected = false,
  });
}

class TripProvider extends ChangeNotifier {
  // Date Selection
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Trip Duration
  int _tripDuration = 7;
  
  // Cities
  final List<City> _availableCities = [
    City(name: 'Roma', code: 'ROM', emoji: '🇮🇹'),
    City(name: 'Barcelona', code: 'BCN', emoji: '🇪🇸'),
    City(name: 'Paris', code: 'PAR', emoji: '🇫🇷'),
    City(name: 'Berlin', code: 'BER', emoji: '🇩🇪'),
    City(name: 'Amsterdam', code: 'AMS', emoji: '🇳🇱'),
    City(name: 'Prague', code: 'PRG', emoji: '🇨🇿'),
    City(name: 'Vienna', code: 'VIE', emoji: '🇦🇹'),
    City(name: 'Budapest', code: 'BUD', emoji: '🇭🇺'),
  ];
  
  // Trip Settings
  String _startLocation = 'Istanbul';
  String _endLocation = 'Istanbul';
  bool _equalDays = true;
  
  // Loading states
  bool _isLoading = false;
  
  // Results
  List<Map<String, dynamic>> _searchResults = [];
  bool _lastResultsFromDemo = false;

  // Getters
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  int get tripDuration => _tripDuration;
  List<City> get availableCities => _availableCities;
  List<City> get selectedCities => _availableCities.where((city) => city.isSelected).toList();
  String get startLocation => _startLocation;
  String get endLocation => _endLocation;
  bool get equalDays => _equalDays;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get lastResultsFromDemo => _lastResultsFromDemo;
  
  bool get canSearch => 
    _startDate != null && 
    _endDate != null && 
    selectedCities.isNotEmpty && 
    _tripDuration > 0;

  // Setters
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void setTripDuration(int duration) {
    _tripDuration = duration;
    notifyListeners();
  }

  void toggleCity(int index) {
    _availableCities[index].isSelected = !_availableCities[index].isSelected;
    notifyListeners();
  }

  void setStartLocation(String location) {
    _startLocation = location;
    notifyListeners();
  }

  void setEndLocation(String location) {
    _endLocation = location;
    notifyListeners();
  }

  void setEqualDays(bool equal) {
    _equalDays = equal;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSearchResults(List<Map<String, dynamic>> results) {
    _searchResults = results;
    notifyListeners();
  }

  void setLastResultsFromDemo(bool value) {
    _lastResultsFromDemo = value;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults.clear();
    notifyListeners();
  }

  Map<String, dynamic> getTripData() {
    return {
      'start_date': _startDate?.toIso8601String(),
      'end_date': _endDate?.toIso8601String(),
      'trip_duration': _tripDuration,
      'cities': selectedCities.map((city) => city.code).toList(),
      'start_location': _startLocation,
      'end_location': _endLocation,
      'equal_days': _equalDays,
    };
  }
}
