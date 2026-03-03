import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/core/model_management/cancel_token.dart';

/// Manages downloading, checking, and removing on-device inference models
/// using the flutter_gemma **modern API**.
///
/// The HuggingFace token is accepted via the constructor so it can be
/// supplied from a compile-time define (`--dart-define-from-file=config.json`)
/// instead of being bundled inside a `.env` asset (which leaks into the APK).
///
/// **Initialisation requirement** – call [ModelDownloadService.ensureInitialized]
/// (or `FlutterGemma.initialize(…)` yourself) once at app startup before using
/// any other method.
class ModelDownloadService {
  // ---------------------------------------------------------------------------
  // Default model – Gemma 3 1B-IT q4 quantized, 2048-token context (555 MB)
  // Repo: litert-community/Gemma3-1B-IT
  // ---------------------------------------------------------------------------
  static const String defaultModelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  static const String defaultModelFilename =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  // ---------------------------------------------------------------------------
  // Instance fields
  // ---------------------------------------------------------------------------
  final String modelUrl;
  final String modelFilename;
  final ModelType modelType;
  final ModelFileType fileType;

  /// Optional HuggingFace token for gated model repos.
  /// Pass via `const String.fromEnvironment('HUGGINGFACE_TOKEN')`.
  final String? token;

  ModelDownloadService({
    this.modelUrl = defaultModelUrl,
    this.modelFilename = defaultModelFilename,
    this.modelType = ModelType.gemmaIt,
    this.fileType = ModelFileType.task,
    this.token,
  });

  // ---------------------------------------------------------------------------
  // One-time initialisation (call once in main)
  // ---------------------------------------------------------------------------

  static bool _initialized = false;

  /// Initialises `FlutterGemma` with the given [huggingFaceToken].
  /// Safe to call multiple times – only the first call takes effect.
  static void ensureInitialized({String? huggingFaceToken}) {
    if (_initialized) return;
    FlutterGemma.initialize(
      huggingFaceToken:
          (huggingFaceToken != null && huggingFaceToken.isNotEmpty)
          ? huggingFaceToken
          : null,
      maxDownloadRetries: 10,
    );
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Model status
  // ---------------------------------------------------------------------------

  /// Whether the model is already downloaded & installed on-device.
  Future<bool> get isModelInstalled async {
    try {
      return await FlutterGemma.isModelInstalled(modelFilename);
    } catch (e) {
      debugPrint('Error checking model status: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

  /// Downloads the model and reports progress via [onProgress] (0 – 100).
  ///
  /// Pass an optional [cancelToken] to support user-initiated cancellation.
  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    var builder =
        FlutterGemma.installModel(modelType: modelType, fileType: fileType)
            .fromNetwork(modelUrl, token: token)
            .withProgress((progress) => onProgress(progress.toDouble()));

    if (cancelToken != null) {
      builder = builder.withCancelToken(cancelToken);
    }

    await builder.install();
  }

  // ---------------------------------------------------------------------------
  // Deletion
  // ---------------------------------------------------------------------------

  /// Removes the model file and its metadata from the device.
  ///
  /// Returns `true` if deletion succeeded, `false` otherwise.
  Future<bool> deleteModel() async {
    try {
      await FlutterGemma.uninstallModel(modelFilename);
      return true;
    } catch (e) {
      debugPrint('Error deleting model: $e');
      return false;
    }
  }
}
