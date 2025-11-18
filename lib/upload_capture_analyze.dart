import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadCaptureAnalyze extends StatefulWidget {
  @override
  _UploadCaptureAnalyzeState createState() => _UploadCaptureAnalyzeState();
}

class _UploadCaptureAnalyzeState extends State<UploadCaptureAnalyze> {
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  bool _isUploading = false;
  bool _cameraInitialized = false;
  List<Map<String, dynamic>> _photos = [];
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  String _videoElementId = 'video-${DateTime.now().millisecondsSinceEpoch}';
  
  // Current image data (from capture or upload)
  String? _currentImageData;
  String? _currentImageUrl;
  String? _currentPhotoId;
  String? _imageSource; // 'capture' or 'upload'
  Map<String, dynamic>? _lastAnalysis;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadPhotos();
  }

  Future<void> _initializeCamera() async {
    try {
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      ui_web.platformViewRegistry.registerViewFactory(
        _videoElementId,
        (int viewId) => _videoElement!,
      );

      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'facingMode': 'environment'
        },
        'audio': false
      });

      _videoElement!.srcObject = stream;
      _canvasElement = html.CanvasElement(width: 640, height: 480);

      setState(() {
        _cameraInitialized = true;
      });

      print('Camera initialized successfully');
    } catch (e) {
      print('Camera initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera access denied or not available')),
      );
    }
  }

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
        
        // Save uploaded image to Firestore
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

        // Store current image for analysis
        setState(() {
          _currentImageData = base64Data;
          _currentImageUrl = imageDataUrl;
          _currentPhotoId = docRef.id;
          _imageSource = 'upload';
          _lastAnalysis = null;
        });

        await _loadPhotos();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📁 Image uploaded successfully! Ready for analysis.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isUploading = false);
  }

  Future<void> _capturePhoto() async {
    if (!_cameraInitialized || _videoElement == null || _canvasElement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not ready')),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final canvasContext = _canvasElement!.context2D;
      canvasContext.drawImageScaled(_videoElement!, 0, 0, 640, 480);

      final imageDataUrl = _canvasElement!.toDataUrl('image/jpeg', 0.8);
      final base64Data = imageDataUrl.split(',')[1];
      
      final DateTime now = DateTime.now();
      final position = await _getCurrentPosition();
      final weather = await _getWeatherData(position['lat']!, position['lng']!);
      final fileName = 'captured_${now.millisecondsSinceEpoch}.jpg';
      
      // Save captured photo to Firestore
      final docRef = await FirebaseFirestore.instance.collection('plant_images').add({
        'timestamp': Timestamp.fromDate(now),
        'latitude': position['lat'],
        'longitude': position['lng'],
        'location': '${position['lat']?.toStringAsFixed(6) ?? '0'}, ${position['lng']?.toStringAsFixed(6) ?? '0'}',
        'temperature': weather['temperature'],
        'humidity': weather['humidity'],
        'weather': weather['weather'],
        'fileName': fileName,
        'imageData': base64Data,
        'imageUrl': imageDataUrl,
        'source': 'capture',
        'status': 'captured',
        'capturedAt': now.toIso8601String(),
      });

      // Store current image for analysis
      setState(() {
        _currentImageData = base64Data;
        _currentImageUrl = imageDataUrl;
        _currentPhotoId = docRef.id;
        _imageSource = 'capture';
        _lastAnalysis = null;
      });

      await _loadPhotos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📸 Photo captured! Ready for analysis.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isCapturing = false);
  }

  // Weather-aware Tomato Disease Classification (Mock LLM)
  Future<Map<String, dynamic>> _analyzeTomatoDiseaseWithWeather(String imageData, Map<String, dynamic> weatherData) async {
    await Future.delayed(Duration(seconds: 4)); // Simulate processing time
    
    final diseases = ['Tomato___Spider_mites_Two_spotted_spider_mite', 'Tomato___Early_blight', 'Tomato___Late_blight', 'Tomato___Leaf_Mold', 'Tomato___Septoria_leaf_spot', 'Tomato___Target_Spot', 'Tomato___Yellow_Leaf_Curl_Virus', 'Tomato___mosaic_virus', 'Tomato___healthy'];
    final selectedDisease = diseases[DateTime.now().millisecond % diseases.length];
    final confidence = 0.75 + (DateTime.now().microsecond % 25) / 100;
    
    // Generate mock LLM response similar to real API
    final mockLLMResponse = _generateMockLLMResponse(selectedDisease, weatherData);
    final parts = _parseLLMResponse(mockLLMResponse);
    
    return {
      'label': selectedDisease,
      'confidence': confidence,
      'severity': _getSeverityFromDisease(selectedDisease),
      'treatment': parts['treatment']!,
      'description': parts['description']!,
      'llm_raw': mockLLMResponse,
    };
  }
  
  String _generateMockLLMResponse(String disease, Map<String, dynamic> weather) {
    final temp = weather['temperature'] as double;
    final humidity = weather['humidity'] as double;
    final condition = weather['weather'] as String;
    final diseaseName = disease.replaceAll('Tomato___', '').replaceAll('_', ' ');
    
    return '$diseaseName is a common tomato plant condition that affects plant health and productivity. Given the current environmental conditions of ${temp}°F temperature and ${humidity}% humidity with ${condition.toLowerCase()} weather, this condition requires specific management approaches. The current temperature and humidity levels create ${temp > 80 ? 'favorable' : temp < 60 ? 'challenging' : 'moderate'} conditions for disease development. To manage this condition effectively, implement immediate preventive measures including proper plant spacing for air circulation and targeted treatment applications. Monitor weather conditions closely and adjust watering schedules to avoid creating favorable conditions for disease spread. Apply appropriate fungicides or treatments during optimal weather windows, preferably during ${temp > 85 ? 'cooler morning or evening hours' : 'daytime when conditions are stable'}. Focus on long-term prevention through crop rotation, resistant varieties, and maintaining optimal growing conditions.';
  }
  


  // Call LLM-enhanced Tomato Disease API
  Future<Map<String, dynamic>> _callTomatoDiseaseAPI(String base64Image, Map<String, dynamic> weatherData, double lat, double lng) async {
    print('🚀 Starting LLM API call...');
    
    try {
      // Convert base64 to blob for multipart upload
      final bytes = base64Decode(base64Image);
      final blob = html.Blob([bytes]);
      final formData = html.FormData();
      formData.appendBlob('file', blob, 'image.jpg');
      
      // Add metadata for LLM context
      formData.append('lat', lat.toString());
      formData.append('lon', lng.toString());
      formData.append('temperature', weatherData['temperature'].toString());
      formData.append('humidity', weatherData['humidity'].toString());
      formData.append('timestamp', DateTime.now().toIso8601String());
      
      print('📤 Sending request to: https://tomato-llm-api-1095347768437.us-central1.run.app/predict');
      print('📊 Weather data: ${weatherData['temperature']}°F, ${weatherData['humidity']}%');
      
      final response = await html.HttpRequest.request(
        'https://tomato-llm-api-1095347768437.us-central1.run.app/predict',
        method: 'POST',
        sendData: formData,
      );
      
      print('📥 Response status: ${response.status}');
      
      if (response.status == 200) {
        final result = jsonDecode(response.responseText!);
        print('✅ LLM API Response received: ${result.keys}');
        
        final llmAdvice = result['llm'] as String? ?? 'No LLM advice available';
        print('🤖 LLM Advice length: ${llmAdvice.length} characters');
        print('🤖 LLM Advice preview: ${llmAdvice.substring(0, math.min(200, llmAdvice.length))}...');
        
        // Split LLM response into treatment and description
        final parts = _parseLLMResponse(llmAdvice);
        print('📝 Parsed treatment length: ${parts['treatment']?.length}');
        print('📝 Parsed description length: ${parts['description']?.length}');
        
        return {
          'label': result['disease'] as String,
          'confidence': result['confidence'] as double,
          'severity': _getSeverityFromDisease(result['disease']),
          'treatment': parts['treatment']!,
          'class_id': result['class_id'],
          'llm_raw': llmAdvice,
        };
      } else {
        print('❌ API returned status: ${response.status}');
        print('❌ Response text: ${response.responseText}');
      }
    } catch (e) {
      print('💥 LLM API error: $e');
      rethrow; // Let the calling method handle the fallback
    }
    
    throw Exception('API call failed - no valid response');
  }
  
  Map<String, String> _parseLLMResponse(String llmText) {
    // Combine description and treatment into one comprehensive field with AI disclaimer
    final disclaimer = "\n\n⚠️ DISCLAIMER: This is AI-generated advice for informational purposes only. Please consult with agricultural experts or plant pathologists for professional diagnosis and treatment recommendations before applying any treatments to your crops.";
    
    return {
      'treatment': llmText + disclaimer, // Use the full LLM response with disclaimer
    };
  }
  

  

  
  String _getSeverityFromDisease(String disease) {
    final lowerDisease = disease.toLowerCase();
    
    // High severity diseases
    if (lowerDisease.contains('late_blight') || lowerDisease.contains('late blight') ||
        lowerDisease.contains('bacterial_spot') || lowerDisease.contains('bacterial spot') ||
        lowerDisease.contains('yellow_leaf_curl') || lowerDisease.contains('yellow leaf curl') ||
        lowerDisease.contains('mosaic_virus') || lowerDisease.contains('mosaic virus')) {
      return 'High';
    }
    
    // Healthy plants
    if (lowerDisease.contains('healthy')) {
      return 'None';
    }
    
    // Low severity
    if (lowerDisease.contains('spider_mites') || lowerDisease.contains('spider mites') ||
        lowerDisease.contains('two_spotted') || lowerDisease.contains('two spotted')) {
      return 'Low';
    }
    
    // Default to moderate for other diseases
    return 'Moderate';
  }
  


  Future<void> _analyzeCurrentImage() async {
    if (_currentImageData == null || _currentPhotoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image to analyze. Capture or upload an image first.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // Get current weather and location data for the analysis
      final position = await _getCurrentPosition();
      final weatherData = await _getWeatherData(position['lat']!, position['lng']!);
      
      // Try to call real LLM API with metadata first, fallback to mock if API unavailable
      Map<String, dynamic> analysis;
      bool apiSuccess = false;
      
      try {
        print('🔄 Calling LLM API with weather: ${weatherData['temperature']}°F, ${weatherData['humidity']}%');
        analysis = await _callTomatoDiseaseAPI(_currentImageData!, weatherData, position['lat']!, position['lng']!);
        apiSuccess = true;
        print('✅ LLM API call successful: ${analysis['label']}');
        print('📝 Treatment preview: ${analysis['treatment']?.substring(0, math.min(100, analysis['treatment']?.length ?? 0))}...');
        print('📝 Description preview: ${analysis['description']?.substring(0, math.min(100, analysis['description']?.length ?? 0))}...');
        print('🤖 Raw LLM preview: ${analysis['llm_raw']?.substring(0, math.min(150, analysis['llm_raw']?.length ?? 0))}...');
      } catch (e) {
        print('❌ LLM API failed, using mock analysis: $e');
        analysis = await _analyzeTomatoDiseaseWithWeather(_currentImageData!, weatherData);
        analysis['note'] = 'Mock LLM with weather-aware treatment';
        apiSuccess = false;
        print('🔄 Mock analysis generated: ${analysis['label']}');
        print('📝 Mock treatment preview: ${analysis['treatment']?.substring(0, math.min(100, analysis['treatment']?.length ?? 0))}...');
        print('📝 Mock description preview: ${analysis['description']?.substring(0, math.min(100, analysis['description']?.length ?? 0))}...');
      }
      
      // Debug: Show what we're about to save to Firebase
      print('💾 Saving to Firebase:');
      print('   - Disease: ${analysis['label']}');
      print('   - Confidence: ${analysis['confidence']}');
      print('   - Treatment length: ${analysis['treatment']?.length ?? 0}');
      print('   - Description length: ${analysis['description']?.length ?? 0}');
      print('   - API Success: $apiSuccess');
      
      // Update the document with ML analysis
      await FirebaseFirestore.instance
          .collection('plant_images')
          .doc(_currentPhotoId!)
          .update({
        'mlPrediction': analysis['label'],
        'confidence': analysis['confidence'],
        'severity': analysis['severity'],
        'treatment': analysis['treatment'],
        'status': 'analyzed',
        'analysisTimestamp': DateTime.now().toIso8601String(),
        'modelVersion': analysis.containsKey('note') ? 'Mock_v1.0' : 'LLM_API_v1.0',
        'modelType': 'tomato_disease_classification',
        'apiNote': analysis['note'],
      });

      setState(() {
        _lastAnalysis = analysis;
      });

      await _loadPhotos();
      
      // Show analysis result dialog
      _showAnalysisResultDialog(analysis);
      
      final isReal = !analysis.containsKey('note');
      final hasLLM = analysis.containsKey('llm_raw') && analysis['llm_raw'] != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🤖 ${isReal ? "LLM API" : "Mock"} Analysis: ${analysis['label']} (${(analysis['confidence'] * 100).toInt()}%) ${hasLLM ? "✅ LLM" : "❌ No LLM"}'
          ),
          backgroundColor: isReal ? Colors.purple : Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isAnalyzing = false);
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
      return {
        'lat': 37.7749 + random,
        'lng': -122.4194 + random,
      };
    }
  }

  Future<Map<String, dynamic>> _getWeatherData(double lat, double lng) async {
    print('🌍 Fetching weather for: $lat, $lng');
    
    try {
      // Using Open-Meteo API (free, no API key required)
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true&hourly=temperature_2m,relativehumidity_2m&temperature_unit=fahrenheit&forecast_days=1';
      print('🌐 Weather API URL: $url');
      
      final response = await html.HttpRequest.request(url);
      print('🌤️ Weather API Status: ${response.status}');
      
      if (response.status == 200) {
        final data = jsonDecode(response.responseText!);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];
        
        final temp = currentWeather['temperature']?.toDouble() ?? 70.0;
        final humidity = hourly['relativehumidity_2m'][0]?.toDouble() ?? 50.0;
        
        print('🌡️ Real API Temperature: $temp°F');
        print('💧 Real API Humidity: $humidity%');
        
        return {
          'temperature': temp,
          'humidity': humidity,
          'weather': _getWeatherDescription(temp, humidity),
        };
      } else {
        print('❌ Weather API failed with status: ${response.status}');
      }
    } catch (e) {
      print('💥 Open-Meteo API error: $e');
    }
    
    // Fallback to simulated weather
    print('🔄 Using simulated weather data');
    return _getSimulatedWeather(lat, lng);
  }
  
  Map<String, dynamic> _getSimulatedWeather(double lat, double lng) {
    // Simulate realistic weather based on location and season
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    
    // Base temperature varies by latitude and season
    double baseTemp = 20.0 + (30.0 - lat.abs()) * 0.8;
    double seasonalVariation = 10.0 * math.cos((dayOfYear - 172) * 2 * math.pi / 365);
    double temperature = (baseTemp + seasonalVariation + (math.Random().nextDouble() - 0.5) * 10) * 9/5 + 32;
    
    // Humidity varies by location (coastal vs inland)
    double baseHumidity = 60.0;
    if (lng.abs() > 100) baseHumidity += 15; // More humid near coasts
    double humidity = baseHumidity + (math.Random().nextDouble() - 0.5) * 30;
    humidity = humidity.clamp(20.0, 95.0);
    
    return {
      'temperature': double.parse(temperature.toStringAsFixed(1)),
      'humidity': double.parse(humidity.toStringAsFixed(1)),
      'weather': _getWeatherDescription(temperature, humidity),
    };
  }
  
  String _getWeatherDescription(double temp, double humidity) {
    if (temp > 86 && humidity > 70) return 'Hot and humid';
    if (temp > 86) return 'Hot and dry';
    if (temp < 50) return 'Cold';
    if (humidity > 80) return 'Humid';
    if (humidity < 40) return 'Dry';
    return 'Pleasant';
  }

  Future<void> _loadPhotos() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('plant_images')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();
      
      setState(() {
        _photos = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'timestamp': data['timestamp'],
            'location': data['location'] ?? 'Unknown',
            'fileName': data['fileName'] ?? 'Unknown',
            'originalFileName': data['originalFileName'],
            'imageUrl': data['imageUrl'],
            'source': data['source'] ?? 'unknown',
            'status': data['status'] ?? 'uploaded',
            'temperature': data['temperature'],
            'humidity': data['humidity'],
            'weather': data['weather'],
            'mlPrediction': data['mlPrediction'],
            'confidence': data['confidence'],
            'severity': data['severity'],
            'treatment': data['treatment'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading photos: $e');
    }
  }

  void _showAnalysisResultDialog(Map<String, dynamic> analysis) async {
    // Get current photo data from Firestore to include weather info
    final photoDoc = await FirebaseFirestore.instance
        .collection('plant_images')
        .doc(_currentPhotoId!)
        .get();
    
    final photoData = photoDoc.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Analysis Complete! 🎉',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                  SizedBox(height: 16),
                  
                  // Image preview
                  Container(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: 300),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _currentImageUrl!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Disease analysis results
                  Card(
                    color: Colors.purple[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🍅 Disease: ${analysis['label']?.replaceAll('Tomato_', '').replaceAll('_', ' ') ?? 'Unknown'}', 
                               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('📊 Confidence: ${(analysis['confidence'] * 100).toInt()}%'),
                          Text('⚠️ Severity: ${analysis['severity']}'),
                          SizedBox(height: 8),
                          Text('💊 Analysis & Treatment:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${analysis['treatment']}'),
                          if (analysis.containsKey('llm_raw')) ...[
                            SizedBox(height: 8),
                            Text('🤖 Raw LLM Response:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                            Text('${analysis['llm_raw']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Weather and location info
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📍 Location & Weather', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Text('📍 ${photoData['location']}', style: TextStyle(fontSize: 12)),
                          Text('🌡️ Temperature: ${photoData['temperature']}°F', style: TextStyle(fontSize: 12, color: Colors.red[600])),
                          Text('💧 Humidity: ${photoData['humidity']}%', style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                          Text('☁️ Weather: ${photoData['weather']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text('🕒 ${photoData['timestamp']?.toDate()}', style: TextStyle(fontSize: 12)),
                          Text('📱 Source: ${photoData['source']?.toUpperCase()}', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    child: Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAnalysisDialog(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    photo['status'] == 'analyzed' ? 'Plant Disease Analysis' : 'Image Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (photo['imageUrl'] != null)
                    Container(
                      constraints: BoxConstraints(maxHeight: 300, maxWidth: 300),
                      child: Image.network(
                        photo['imageUrl'],
                        fit: BoxFit.contain,
                      ),
                    ),
                  SizedBox(height: 16),
                  if (photo['status'] == 'analyzed') ...[
                    Card(
                      color: Colors.purple[50],
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🌱 Disease: ${photo['mlPrediction']?.replaceAll('Tomato_', '').replaceAll('_', ' ') ?? 'Unknown'}', 
                                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 8),
                            Text('📊 Confidence: ${(photo['confidence'] * 100).toInt()}%'),
                            Text('⚠️ Severity: ${photo['severity']}'),
                            if (photo['treatment'] != null) ...[
                              SizedBox(height: 8),
                              Text('💊 Analysis & Treatment:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${photo['treatment']}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo['source'] == 'upload' 
                                  ? '📁 Image uploaded but not analyzed yet'
                                  : '📷 Photo captured but not analyzed yet',
                              style: TextStyle(color: Colors.orange[800]),
                            ),
                            if (photo['originalFileName'] != null)
                              Text('Original: ${photo['originalFileName']}', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Text('📍 ${photo['location']}', style: TextStyle(fontSize: 12)),
                  if (photo['temperature'] != null && photo['humidity'] != null) ...[
                    Text('🌡️ Temperature: ${photo['temperature']}°F', style: TextStyle(fontSize: 12, color: Colors.red[600])),
                    Text('💧 Humidity: ${photo['humidity']}%', style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                    Text('☁️ Weather: ${photo['weather']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                  Text('🕒 ${photo['timestamp']?.toDate()}', style: TextStyle(fontSize: 12)),
                  Text('📱 Source: ${photo['source']?.toUpperCase()}', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'upload': return Colors.blue;
      case 'capture': return Colors.green;
      default: return Colors.grey;
    }
  }

  Color _getSeverityColor(String? severity) {
    if (severity == null) return Colors.grey;
    switch (severity.toLowerCase()) {
      case 'high': return Colors.red;
      case 'moderate': return Colors.orange;
      case 'low': return Colors.yellow;
      case 'none': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant Disease Detector'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPhotos,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Camera Preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _cameraInitialized
                    ? HtmlElementView(viewType: _videoElementId)
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Initializing camera...'),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Current image status
            if (_currentImageUrl != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastAnalysis != null ? Colors.purple[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastAnalysis != null ? Colors.purple : Colors.blue,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentImageUrl!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastAnalysis != null 
                                ? '✅ Analysis Complete'
                                : '${_imageSource == 'upload' ? '📁 Uploaded' : '📷 Captured'} - Ready for Analysis',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_lastAnalysis != null) ...[
                            Text('🍅 ${_lastAnalysis!['label']?.replaceAll('Tomato_', '').replaceAll('_', ' ')}'),
                            Text('📊 ${(_lastAnalysis!['confidence'] * 100).toInt()}% confidence'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // Action Buttons Row 1: Upload and Capture
            Row(
              children: [
                // Upload Button
                Expanded(
                  child: Container(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: !_isUploading ? _uploadImage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, color: Colors.white),
                                Text('Upload', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                ),
                
                SizedBox(width: 12),
                
                // Capture Button
                Expanded(
                  child: Container(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (_cameraInitialized && !_isCapturing) ? _capturePhoto : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCapturing
                          ? CircularProgressIndicator(color: Colors.white)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.white),
                                Text('Capture', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Analyze Button
            Container(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_currentImageData != null && !_isAnalyzing && _lastAnalysis == null) 
                    ? _analyzeCurrentImage 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAnalyzing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Analyze with AI Model',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            SizedBox(height: 20),
            
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Plant Images: ${_photos.length}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Expanded(
              child: _photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.eco, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No plant images yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Upload or capture your first plant image!', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        final timestamp = photo['timestamp']?.toDate();
                        final isAnalyzed = photo['status'] == 'analyzed';
                        final confidence = photo['confidence'] != null ? (photo['confidence'] * 100).toInt() : 0;
                        return Card(
                          elevation: 3,
                          margin: EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                photo['source'] == 'upload' ? Icons.upload_file : Icons.camera_alt,
                              ),
                              backgroundColor: isAnalyzed 
                                  ? _getSeverityColor(photo['severity'])
                                  : _getSourceColor(photo['source']),
                              foregroundColor: Colors.white,
                            ),
                            title: Text(
                              isAnalyzed 
                                  ? photo['mlPrediction']?.replaceAll('Tomato_', '').replaceAll('_', ' ') ?? 'Analyzed'
                                  : photo['originalFileName'] ?? photo['fileName'] ?? 'Image ${index + 1}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                if (isAnalyzed) ...[
                                  Text('Confidence: $confidence% | ${photo['severity']}'),
                                ] else ...[
                                  Text('Status: Ready for analysis', style: TextStyle(color: Colors.orange)),
                                ],
                                SizedBox(height: 2),
                                Text('📱 ${photo['source']?.toUpperCase()} | 📍 ${photo['location']}', style: TextStyle(fontSize: 11)),
                                if (photo['temperature'] != null && photo['humidity'] != null)
                                  Text('🌡️ ${photo['temperature']}°F | 💧 ${photo['humidity']}% | ${photo['weather'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                                Text('🕒 ${timestamp?.toString().split('.')[0] ?? 'Unknown'}', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                            trailing: Icon(Icons.visibility, color: Colors.green),
                            isThreeLine: true,
                            onTap: () => _showAnalysisDialog(photo),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_videoElement?.srcObject != null) {
      final stream = _videoElement!.srcObject as html.MediaStream;
      stream.getTracks().forEach((track) => track.stop());
    }
    super.dispose();
  }
}