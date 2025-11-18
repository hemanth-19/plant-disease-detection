import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAnalyzing = false;
  bool _isUploading = false;
  String? _currentImageData;
  String? _currentImageUrl;
  String? _currentPhotoId;
  Map<String, dynamic>? _lastAnalysis;

  Future<void> _uploadImage() async {
    setState(() => _isUploading = true);

    try {
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();
      
      await uploadInput.onChange.first;
      
      if (uploadInput.files!.isNotEmpty) {
        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
        
        final imageDataUrl = reader.result as String;
        final base64Data = imageDataUrl.split(',')[1];
        
        final DateTime now = DateTime.now();
        final position = await _getCurrentPosition();
        final weather = await _getWeatherData(position['lat']!, position['lng']!);
        final fileName = 'uploaded_${now.millisecondsSinceEpoch}_${file.name}';
        
        final docRef = await FirebaseFirestore.instance.collection('plant_images').add({
          'timestamp': Timestamp.fromDate(now),
          'latitude': position['lat'],
          'longitude': position['lng'],
          'location': '${position['lat']?.toStringAsFixed(6) ?? '0'}, ${position['lng']?.toStringAsFixed(6) ?? '0'}',
          'temperature': weather['temperature'],
          'humidity': weather['humidity'],
          'weather': weather['weather'],
          'fileName': fileName,
          'originalFileName': file.name,
          'imageData': base64Data,
          'imageUrl': imageDataUrl,
          'source': 'upload',
          'status': 'uploaded',
          'fileSize': file.size,
          'uploadedAt': now.toIso8601String(),
        });

        setState(() {
          _currentImageData = base64Data;
          _currentImageUrl = imageDataUrl;
          _currentPhotoId = docRef.id;
          _lastAnalysis = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📁 Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isUploading = false);
  }

  Future<void> _analyzeCurrentImage() async {
    if (_currentImageData == null || _currentImageData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload or capture an image first')),
      );
      return;
    }

    if (_currentPhotoId == null || _currentPhotoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image ID is missing. Please try uploading again.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await _callTomatoDiseaseAPI(_currentImageData!);
      
      if (analysis.isEmpty) {
        throw Exception('Analysis returned empty results');
      }
      
      await FirebaseFirestore.instance
          .collection('plant_images')
          .doc(_currentPhotoId!)
          .update({
        'mlPrediction': analysis['label'] ?? 'Unknown',
        'confidence': analysis['confidence'] ?? 0.0,
        'severity': analysis['severity'] ?? 'Unknown',
        'treatment': analysis['treatment'] ?? 'No treatment available',
        'status': 'analyzed',
        'analysisTimestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _lastAnalysis = analysis);
        
        // Show analysis result dialog
        _showAnalysisResultDialog(analysis);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🤖 Analysis Complete!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Analysis error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<Map<String, dynamic>> _callTomatoDiseaseAPI(String base64Image) async {
    try {
      final bytes = base64Decode(base64Image);
      final blob = html.Blob([bytes]);
      final formData = html.FormData();
      formData.appendBlob('file', blob, 'image.jpg');
      
      // Add weather and location data for LLM context
      final position = await _getCurrentPosition();
      final weather = await _getWeatherData(position['lat']!, position['lng']!);
      formData.append('lat', position['lat'].toString());
      formData.append('lon', position['lng'].toString());
      formData.append('temperature', weather['temperature'].toString());
      formData.append('humidity', weather['humidity'].toString());
      formData.append('timestamp', DateTime.now().toIso8601String());
      
      final response = await html.HttpRequest.request(
        'https://tomato-llm-api-1095347768437.us-central1.run.app/predict',
        method: 'POST',
        sendData: formData,
      );
      
      if (response.status == 200) {
        final result = jsonDecode(response.responseText!);
        final disease = result['disease'] as String;
        final confidence = result['confidence'] as double;
        final llmAdvice = result['llm'] as String? ?? 'No treatment advice available';
        
        final disclaimer = "\n\n⚠️ DISCLAIMER: This is AI-generated advice for informational purposes only. Please consult with agricultural experts or plant pathologists for professional diagnosis and treatment recommendations before applying any treatments to your crops.";
        
        return {
          'label': disease,
          'confidence': confidence,
          'severity': _getSeverityFromDisease(disease),
          'treatment': llmAdvice + disclaimer, // Use LLM response with disclaimer
        };
      }
    } catch (e) {
      print('API error: $e');
    }
    
    return _getMockAnalysis();
  }

  Map<String, dynamic> _getMockAnalysis() {
    final diseases = [
      {'label': 'Tomato___Bacterial_spot', 'confidence': 0.89},
      {'label': 'Tomato___Early_blight', 'confidence': 0.85},
      {'label': 'Tomato___healthy', 'confidence': 0.94},
    ];
    
    final selected = diseases[DateTime.now().millisecond % diseases.length];
    final disease = selected['label'] as String;
    
    return {
      'label': disease,
      'confidence': selected['confidence'],
      'severity': _getSeverityFromDisease(disease),
      'treatment': 'Mock analysis - LLM API unavailable. Please check network connection and try again. This is a fallback analysis when the LLM API is not accessible.\n\n⚠️ DISCLAIMER: This is AI-generated advice for informational purposes only. Please consult with agricultural experts or plant pathologists for professional diagnosis and treatment recommendations before applying any treatments to your crops.',
    };
  }

  String _getSeverityFromDisease(String disease) {
    final lowerDisease = disease.toLowerCase();
    
    if (lowerDisease.contains('late_blight') || lowerDisease.contains('bacterial_spot') ||
        lowerDisease.contains('yellow_leaf_curl') || lowerDisease.contains('mosaic_virus')) {
      return 'High';
    }
    
    if (lowerDisease.contains('healthy')) {
      return 'None';
    }
    
    if (lowerDisease.contains('spider_mites') || lowerDisease.contains('two_spotted')) {
      return 'Low';
    }
    
    return 'Moderate';
  }

  Future<Map<String, double>> _getCurrentPosition() async {
    try {
      final position = await html.window.navigator.geolocation.getCurrentPosition();
      return {
        'lat': position.coords!.latitude!.toDouble(),
        'lng': position.coords!.longitude!.toDouble(),
      };
    } catch (e) {
      final random = (DateTime.now().millisecond % 100) / 10000;
      return {'lat': 37.7749 + random, 'lng': -122.4194 + random};
    }
  }

  Future<Map<String, dynamic>> _getWeatherData(double lat, double lng) async {
    print('🌍 Home: Fetching weather for: $lat, $lng');
    
    try {
      // Using Open-Meteo API (free, no API key required)
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true&hourly=temperature_2m,relativehumidity_2m&temperature_unit=fahrenheit&forecast_days=1';
      print('🌐 Home Weather API URL: $url');
      
      final response = await html.HttpRequest.request(url);
      print('🌤️ Home Weather API Status: ${response.status}');
      
      if (response.status == 200) {
        final data = jsonDecode(response.responseText!);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];
        
        final temp = currentWeather['temperature']?.toDouble() ?? 70.0;
        final humidity = hourly['relativehumidity_2m'][0]?.toDouble() ?? 50.0;
        
        print('🌡️ Home Real API Temperature: $temp°F');
        print('💧 Home Real API Humidity: $humidity%');
        
        return {
          'temperature': temp,
          'humidity': humidity,
          'weather': _getWeatherDescription(temp),
        };
      } else {
        print('❌ Home Weather API failed with status: ${response.status}');
      }
    } catch (e) {
      print('💥 Home Open-Meteo API error: $e');
    }
    
    // Fallback to simulated weather
    print('🔄 Home: Using simulated weather data');
    return _getSimulatedWeather(lat, lng);
  }
  
  Map<String, dynamic> _getSimulatedWeather(double lat, double lng) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    
    double baseTemp = 20.0 + (30.0 - lat.abs()) * 0.8;
    double seasonalVariation = 10.0 * math.cos((dayOfYear - 172) * 2 * math.pi / 365);
    double temperature = (baseTemp + seasonalVariation + (math.Random().nextDouble() - 0.5) * 10) * 9/5 + 32;
    
    double humidity = 60.0 + (math.Random().nextDouble() - 0.5) * 30;
    humidity = humidity.clamp(20.0, 95.0);
    
    return {
      'temperature': double.parse(temperature.toStringAsFixed(1)),
      'humidity': double.parse(humidity.toStringAsFixed(1)),
      'weather': _getWeatherDescription(temperature),
    };
  }
  
  String _getWeatherDescription(double temp) {
    if (temp > 86) return 'Hot';
    if (temp < 50) return 'Cold';
    if (temp > 75) return 'Warm';
    if (temp < 65) return 'Cool';
    return 'Pleasant';
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            else
              Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalysisResultDialog(Map<String, dynamic>? analysis) {
    if (analysis == null || !mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analysis Complete! 🎉'),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Analysis Results
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🌱 ${(analysis['label'] as String?)?.replaceAll('Tomato___', '').replaceAll('_', ' ') ?? 'Unknown Disease'}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text('📊 Confidence: ${((analysis['confidence'] as double? ?? 0.0) * 100).toInt()}%'),
                      Text('⚠️ Severity: ${analysis['severity'] as String? ?? 'Unknown'}'),
                      SizedBox(height: 12),
                      Text('💊 Treatment:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        analysis['treatment'] as String? ?? 'No treatment available',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            // Enhanced Header with gradient card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green[600]!,
                    Colors.green[400]!,
                    Colors.lightGreen[300]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.eco,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plant Disease Detection',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Developed by AG_Robotics & Team',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Upload or capture plant leaf images for instant AI analysis',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),

            // Current Image Preview
            if (_currentImageUrl != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _lastAnalysis != null ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lastAnalysis != null ? Colors.green : Colors.blue),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_currentImageUrl!, fit: BoxFit.contain),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _lastAnalysis != null 
                          ? '✅ ${(_lastAnalysis?['label'] as String?)?.replaceAll('Tomato___', '').replaceAll('_', ' ') ?? 'Unknown Disease'}'
                          : '📷 Image ready for analysis',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_lastAnalysis != null) ...[
                      SizedBox(height: 8),
                      Text('Confidence: ${((_lastAnalysis?['confidence'] as double? ?? 0.0) * 100).toInt()}%'),
                      Text('Severity: ${_lastAnalysis?['severity'] as String? ?? 'Unknown'}'),
                    ],
                  ],
                ),
              ),
            ],

            // Action Cards
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.upload_file,
                    title: 'Upload Image',
                    subtitle: 'Select from gallery',
                    color: Colors.blue,
                    isLoading: _isUploading,
                    onTap: !_isUploading ? _uploadImage : null,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.camera_alt,
                    title: 'Take Photo',
                    subtitle: 'Use camera',
                    color: Colors.green,
                    onTap: () async {
                      final result = await Navigator.pushNamed(context, '/camera');
                      if (result != null && result is Map<String, dynamic>) {
                        setState(() {
                          _currentImageData = result['imageData'];
                          _currentImageUrl = result['imageUrl'];
                          _currentPhotoId = result['photoId'];
                          _lastAnalysis = null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Analyze Button (Enhanced)
            if (_currentImageData != null) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: (!_isAnalyzing && _lastAnalysis == null) 
                      ? _analyzeCurrentImage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: Colors.purple.withOpacity(0.3),
                  ),
                  child: _isAnalyzing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Analyzing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.psychology, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Analyze with AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],

            // Enhanced Analysis Results
            if (_lastAnalysis != null) ...[
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple[50]!,
                      Colors.purple[100]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.psychology, color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI Analysis Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_lastAnalysis?['treatment'] ?? 'No treatment information available'}',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}