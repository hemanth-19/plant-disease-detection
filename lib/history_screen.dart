import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('plant_images')
          .orderBy('timestamp', descending: true)
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
            'description': data['description'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  void _showAnalysisDialog(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Analysis Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Image
                  if (photo['imageUrl'] != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photo['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Analysis Results
                  if (photo['status'] == 'analyzed') ...[
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
                            '🌱 ${photo['mlPrediction']?.replaceAll('Tomato___', '').replaceAll('_', ' ') ?? 'Unknown'}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text('📊 Confidence: ${photo['confidence'] != null ? (photo['confidence'] * 100).toInt() : 0}%'),
                          Text('⚠️ Severity: ${photo['severity'] ?? 'Unknown'}'),
                          
                          if (photo['treatment'] != null) ...[
                            SizedBox(height: 12),
                            Text('💊 Treatment:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(photo['treatment'], style: TextStyle(fontSize: 14)),
                          ],
                          
                          if (photo['description'] != null) ...[
                            SizedBox(height: 12),
                            Text('📝 Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(photo['description'], style: TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        photo['source'] == 'upload' 
                            ? '📁 Image uploaded but not analyzed yet'
                            : '📷 Photo captured but not analyzed yet',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 16),
                  
                  // Metadata
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📍 Location: ${photo['location']}', style: TextStyle(fontSize: 12)),
                        if (photo['temperature'] != null && photo['humidity'] != null) ...[
                          Text('🌡️ Temperature: ${photo['temperature']}°F', style: TextStyle(fontSize: 12)),
                          Text('💧 Humidity: ${photo['humidity']}%', style: TextStyle(fontSize: 12)),
                          Text('☁️ Weather: ${photo['weather'] ?? 'Unknown'}', style: TextStyle(fontSize: 12)),
                        ],
                        Text('🕒 ${photo['timestamp']?.toDate().toString().split('.')[0] ?? 'Unknown'}', style: TextStyle(fontSize: 12)),
                        Text('📱 Source: ${photo['source']?.toUpperCase() ?? 'UNKNOWN'}', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  Color _getSourceColor(String source) {
    switch (source) {
      case 'upload': return Colors.blue;
      case 'capture': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'History',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[800]),
                    ),
                    Text(
                      '${_photos.length} images analyzed',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadPhotos,
                  icon: Icon(Icons.refresh, color: Colors.green),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No images yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            SizedBox(height: 8),
                            Text('Upload or capture your first plant image!', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[index];
                          final timestamp = photo['timestamp']?.toDate();
                          final isAnalyzed = photo['status'] == 'analyzed';
                          final confidence = photo['confidence'] != null ? (photo['confidence'] * 100).toInt() : 0;
                          
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAnalyzed 
                                    ? _getSeverityColor(photo['severity'])
                                    : _getSourceColor(photo['source']),
                                child: Icon(
                                  photo['source'] == 'upload' ? Icons.upload_file : Icons.camera_alt,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                isAnalyzed 
                                    ? photo['mlPrediction']?.replaceAll('Tomato___', '').replaceAll('_', ' ') ?? 'Analyzed'
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
                                  if (photo['temperature'] != null && photo['humidity'] != null)
                                    Text('🌡️ ${photo['temperature']}°F | 💧 ${photo['humidity']}%', style: TextStyle(fontSize: 11)),
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
    );
  }
}