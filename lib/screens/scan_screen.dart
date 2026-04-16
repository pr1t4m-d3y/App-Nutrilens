import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/scan_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<String?> _extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (recognizedText.text.trim().isEmpty) return null;
      return recognizedText.text;
    } catch (e) {
      debugPrint("OCR Error: $e");
      return null;
    }
  }

  void _captureAndProcess() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final scanProvider = Provider.of<ScanProvider>(context, listen: false);

    try {
      if (_controller != null && _controller!.value.isInitialized) {
        final image = await _controller!.takePicture();
        final text = await _extractTextFromImage(image.path);

        if (text != null && text.isNotEmpty) {
          scanProvider.startScan(text, imagePath: null); 
          if (mounted) context.push('/processing');
        } else {
          scanProvider.setError("No readable text found. Please ensure the ingredient list is clear.");
        }
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      scanProvider.startScan("Failed to capture image. Please try again.", imagePath: null);
      if (mounted) context.push('/processing');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _pickFromGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final scanProvider = Provider.of<ScanProvider>(context, listen: false);

    try {
      final ImagePicker picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final text = await _extractTextFromImage(image.path);
        
        if (text != null && text.isNotEmpty) {
          scanProvider.startScan(text, imagePath: null);
          if (mounted) context.push('/processing');
        } else {
          scanProvider.setError("No readable text found in gallery image.");
        }
      }
    } catch (e) {
      debugPrint("Gallery error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openMedicineScan() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) context.pushReplacement('/medicine-scan');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? size.width,
                  height: _controller!.value.previewSize?.width ?? size.height,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            Center(child: CircularProgressIndicator(color: primaryColor)),

          // 2. Dark Overlay with cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize * 1.1,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Scan Area Border (Primary Color for food)
          Center(
            child: Container(
              width: scanAreaSize,
              height: scanAreaSize * 1.1,
              decoration: BoxDecoration(
                border: Border.all(color: primaryColor.withOpacity(0.6), width: 2),
                borderRadius: BorderRadius.circular(32),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .fadeIn(duration: 1.seconds, curve: Curves.easeInOut)
             .then().fadeOut(duration: 1.seconds, curve: Curves.easeInOut),
          ),

          // 4. Top Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  Row(
                    children: [
                      _TopButton(
                        icon: Icons.flash_off_rounded,
                        onTap: () {}, // Add flash toggle logic later
                      ),
                      const SizedBox(width: 12),
                      _TopButton(
                        icon: Icons.help_outline_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Align instruction pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('Align ingredient label',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms).fadeIn(),
                  
                  const SizedBox(height: 32),

                  // Capture, Upload, Recent Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Upload from Gallery
                      _BottomAction(
                        icon: Icons.upload_rounded,
                        label: 'Upload',
                        onTap: _pickFromGallery,
                      ),

                      // Main Capture Button
                      GestureDetector(
                        onTap: _captureAndProcess,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 4),
                          ),
                          child: Center(
                            child: _isProcessing
                                ? SizedBox(
                                    width: 32, height: 32,
                                    child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.2), // slightly transparent for food scan
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                                    ),
                                  ),
                          ),
                        ),
                      ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),

                      // Medicine Scanner Toggle
                      _BottomAction(
                        icon: Icons.medication_liquid_rounded,
                        label: 'Medicine',
                        onTap: _openMedicineScan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _TopButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 22),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
