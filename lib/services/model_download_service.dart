import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';

class ModelDownloadService {
  /// Gemma 3 1B-IT q4 quantized, 2048-token context (555 MB).
  /// Repo: litert-community/gemma-3-1b-it-tflite
  static const String defaultModelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  /// The filename extracted from the URL – used for install / uninstall checks.
  static const String defaultModelFilename =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  final String modelUrl;
  final String modelFilename;
  final ModelType modelType;
  final ModelFileType fileType;

  ModelDownloadService({
    this.modelUrl = defaultModelUrl,
    this.modelFilename = defaultModelFilename,
    this.modelType = ModelType.gemmaIt,
    this.fileType = ModelFileType.task,
  });

  /// Reads HUGGING_FACE_TOKEN from the .env file.  Returns null when empty.
  String? get _token {
    final token = dotenv.env['HUGGING_FACE_TOKEN'] ?? '';
    if (token.isEmpty) {
      if (kDebugMode) {
        debugPrint('Warning: HUGGING_FACE_TOKEN not set in .env');
      }
      return null;
    }
    return token;
  }

  /// Whether the model is already downloaded & installed on-device.
  Future<bool> get isModelInstalled async {
    try {
      return await FlutterGemma.isModelInstalled(modelFilename);
    } catch (e) {
      debugPrint('Error checking model status: $e');
      return false;
    }
  }

  /// Downloads the Gemma 3 1B model and reports progress via [onProgress] (0–100).
  Future<void> downloadModel({
    required void Function(double progress) onProgress,
  }) async {
    try {
      await FlutterGemma.installModel(modelType: modelType, fileType: fileType)
          .fromNetwork(modelUrl, token: _token)
          .withProgress((progress) => onProgress(progress.toDouble()))
          .install();
    } catch (e) {
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }

  /// Removes the model file and its metadata from the device.
  Future<void> deleteModel() async {
    try {
      await FlutterGemma.uninstallModel(modelFilename);
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }
}
