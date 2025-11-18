import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class MobileCameraScreen extends StatefulWidget {
  @override
  _MobileCameraScreenState createState() => _MobileCameraScreenState();
}

class _MobileCameraScreenState extends State<MobileCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _controller = CameraController(_cameras![0], ResolutionPreset.high);
        await _controller!.initialize();
        setState(() => _isInitialized = true);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        final XFile photo = await _controller!.takePicture();
        final bytes = await photo.readAsBytes();
        final base64Data = base64Encode(bytes);
        
        await _saveToFirebase(base64Data, 'capture');
        
        Navigator.pop(context, {
          'imageData': base64Data,
          'imageUrl': 'data:image/jpeg;base64,$base64Data',
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Data = base64Encode(bytes);
      
      await _saveToFirebase(base64Data, 'upload');
      
      Navigator.pop(context, {
        'imageData': base64Data,
        'imageUrl': 'data:image/jpeg;base64,$base64Data',
      });
    }
  }

  Future<void> _saveToFirebase(String base64Data, String source) async {
    try {
      final position = await _getCurrentPosition();
      final weather = await _getWeatherData(position.latitude, position.longitude);
      final now = DateTime.now();
      
      await FirebaseFirestore.instance.collection('plant_images').add({
        'timestamp': Timestamp.fromDate(now),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'temperature': weather['temperature'],
        'humidity': weather['humidity'],
        'weather': weather['weather'],
        'fileName': '${source}_${now.millisecondsSinceEpoch}.jpg',
        'imageData': base64Data,
        'imageUrl': 'data:image/jpeg;base64,$base64Data',
        'source': source,
        'status': source == 'capture' ? 'captured' : 'uploaded',
      });
    } catch (e) {
      print('Error saving to Firebase: $e');
    }
  }

  Future<Position> _getCurrentPosition() async {
    await Permission.location.request();
    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, dynamic>> _getWeatherData(double lat, double lng) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true&hourly=temperature_2m,relativehumidity_2m&temperature_unit=fahrenheit&forecast_days=1';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];
        
        return {
          'temperature': currentWeather['temperature']?.toDouble() ?? 70.0,
          'humidity': hourly['relativehumidity_2m'][0]?.toDouble() ?? 50.0,
          'weather': 'Pleasant',
        };
      }
    } catch (e) {
      print('Weather API error: $e');
    }
    
    return {'temperature': 70.0, 'humidity': 50.0, 'weather': 'Pleasant'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Capture Plant Image'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialized
                ? CameraPreview(_controller!)
                : Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _pickFromGallery,
                  child: Icon(Icons.photo_library),
                  backgroundColor: Colors.blue,
                ),
                FloatingActionButton(
                  onPressed: _capturePhoto,
                  child: Icon(Icons.camera_alt),
                  backgroundColor: Colors.green,
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
    _controller?.dispose();
    super.dispose();
  }
}