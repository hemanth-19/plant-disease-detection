import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isCapturing = false;
  bool _cameraInitialized = false;
  bool _showCamera = false;
  bool _showPreview = false;
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  String _videoElementId = 'video-${DateTime.now().millisecondsSinceEpoch}';
  String _currentCamera = 'environment'; // 'user' for front, 'environment' for back
  String? _capturedImageUrl;
  Map<String, dynamic>? _capturedData;

  Future<void> _initializeCamera() async {
    try {
      setState(() => _showCamera = true);
      
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
          'facingMode': _currentCamera
        },
        'audio': false
      });

      _videoElement!.srcObject = stream;
      _canvasElement = html.CanvasElement(width: 640, height: 480);

      setState(() => _cameraInitialized = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera access denied: $e')),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_videoElement?.srcObject != null) {
      final stream = _videoElement!.srcObject as html.MediaStream;
      stream.getTracks().forEach((track) => track.stop());
    }

    setState(() {
      _currentCamera = _currentCamera == 'environment' ? 'user' : 'environment';
      _cameraInitialized = false;
    });

    await _initializeCamera();
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

      // Show preview instead of immediately returning
      setState(() {
        _showPreview = true;
        _capturedImageUrl = imageDataUrl;
        _capturedData = {
          'imageData': base64Data,
          'imageUrl': imageDataUrl,
          'photoId': docRef.id,
        };
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📸 Photo captured! Review and continue or retake.'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isCapturing = false);
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
    try {
      // Using Open-Meteo API (free, no API key required)
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true&hourly=temperature_2m,relativehumidity_2m&temperature_unit=fahrenheit&forecast_days=1';
      
      final response = await html.HttpRequest.request(url);
      
      if (response.status == 200) {
        final data = jsonDecode(response.responseText!);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];
        
        return {
          'temperature': currentWeather['temperature']?.toDouble() ?? 70.0,
          'humidity': hourly['relativehumidity_2m'][0]?.toDouble() ?? 50.0,
          'weather': _getWeatherDescription(currentWeather['temperature']?.toDouble() ?? 70.0),
        };
      }
    } catch (e) {
      print('Open-Meteo API error: $e');
    }
    
    // Fallback to simulated weather
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera'),
        backgroundColor: Colors.green,
        actions: [
          if (_cameraInitialized && !_showPreview)
            IconButton(
              icon: Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview or Captured Image Preview
          Expanded(
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _showPreview && _capturedImageUrl != null
                    ? Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Image.network(_capturedImageUrl!, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Preview',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _showCamera && _cameraInitialized
                        ? HtmlElementView(viewType: _videoElementId)
                        : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_showCamera) ...[
                                    Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _initializeCamera,
                                      icon: Icon(Icons.camera_alt),
                                      label: Text('Start Camera'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ] else ...[
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Initializing camera...'),
                                  ],
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ),

          // Camera Controls
          Container(
            padding: EdgeInsets.all(20),
            child: _showPreview
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Retake Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _showPreview = false;
                            _capturedImageUrl = null;
                            _capturedData = null;
                          });
                          // Restart camera for retake
                          await _initializeCamera();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Retake'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),

                      // Continue Button
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, _capturedData);
                        },
                        icon: Icon(Icons.check),
                        label: Text('Continue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel Button
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                        label: Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),

                      // Capture Button
                      ElevatedButton.icon(
                        onPressed: (_cameraInitialized && !_isCapturing) ? _capturePhoto : null,
                        icon: _isCapturing 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.camera),
                        label: Text('Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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