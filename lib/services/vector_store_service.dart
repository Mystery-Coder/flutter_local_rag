import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Result returned by [VectorStoreService.search].
class SearchResult {
  final String id;
  final String content;
  final double similarity;

  /// Metadata stored as a JSON string. Use [metadataMap] for decoded access.
  final String? metadata;

  const SearchResult({
    required this.id,
    required this.content,
    required this.similarity,
    this.metadata,
  });

  /// Decodes [metadata] into a `Map`, or returns `null` if absent / invalid.
  Map<String, dynamic>? get metadataMap {
    if (metadata == null) return null;
    try {
      return jsonDecode(metadata!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'SearchResult(id: $id, similarity: ${similarity.toStringAsFixed(4)})';
}

/// Manages the embedding model and an on-device vector store powered by
/// flutter_gemma's built-in SQLite-backed VectorStore.
///
/// Typical lifecycle:
/// ```dart
/// final vs = VectorStoreService();
/// await vs.initialize();               // opens DB + loads embedder
/// await vs.addDocument('id', 'text');   // embed & store
/// final hits = await vs.search('query');
/// await vs.dispose();                   // release resources
/// ```
class VectorStoreService {
  // ---------------------------------------------------------------------------
  // Default embedding model – EmbeddingGemma-300M, 1024-token context
  // ---------------------------------------------------------------------------
  static const String defaultModelUrl =
      'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq1024_mixed-precision.tflite';
  static const String defaultTokenizerUrl =
      'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model';

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  final String modelUrl;
  final String tokenizerUrl;
  final String? token;
  final String _dbName;

  VectorStoreService({
    this.modelUrl = defaultModelUrl,
    this.tokenizerUrl = defaultTokenizerUrl,
    this.token,
    String dbName = 'vector_store.db',
  }) : _dbName = dbName;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------
  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Embedding model installation
  // ---------------------------------------------------------------------------

  /// Whether the embedding model files are already on device.
  ///
  /// Checks for both the `.tflite` model and the `sentencepiece.model`
  /// tokenizer by looking at their filenames.
  Future<bool> get isEmbedderInstalled async {
    try {
      final modelFile = Uri.parse(modelUrl).pathSegments.last;
      final tokenizerFile = Uri.parse(tokenizerUrl).pathSegments.last;
      final modelOk = await FlutterGemma.isModelInstalled(modelFile);
      final tokenizerOk = await FlutterGemma.isModelInstalled(tokenizerFile);
      return modelOk && tokenizerOk;
    } catch (e) {
      debugPrint('Error checking embedder status: $e');
      return false;
    }
  }

  /// Downloads the embedding model + tokenizer.
  ///
  /// [onModelProgress] and [onTokenizerProgress] report 0 – 100 individually.
  Future<void> installEmbedder({
    void Function(double progress)? onModelProgress,
    void Function(double progress)? onTokenizerProgress,
  }) async {
    var builder = FlutterGemma.installEmbedder()
        .modelFromNetwork(modelUrl, token: token)
        .tokenizerFromNetwork(tokenizerUrl);

    if (onModelProgress != null) {
      builder = builder.withModelProgress((p) => onModelProgress(p.toDouble()));
    }
    if (onTokenizerProgress != null) {
      builder = builder.withTokenizerProgress(
        (p) => onTokenizerProgress(p.toDouble()),
      );
    }

    await builder.install();
  }

  // ---------------------------------------------------------------------------
  // Initialisation (call once after embedder is installed)
  // ---------------------------------------------------------------------------

  /// Opens the SQLite vector store and loads the embedding model.
  ///
  /// Must be called **after** [installEmbedder] has completed at least once.
  Future<void> initialize({
    PreferredBackend preferredBackend = PreferredBackend.gpu,
  }) async {
    if (_initialized) return;

    // 1. Initialise the VectorStore database
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}/$_dbName';
    await FlutterGemmaPlugin.instance.initializeVectorStore(dbPath);

    _initialized = true;
    debugPrint('VectorStoreService initialised  (db: $dbPath)');
  }

  // ---------------------------------------------------------------------------
  // Document operations
  // ---------------------------------------------------------------------------

  /// Embeds [content] and stores it in the vector store.
  ///
  /// [id] must be unique per document / chunk.  Optional [metadata] (a `Map`)
  /// is JSON-encoded before storage.
  ///
  /// The plugin computes the embedding internally – no need to manage the
  /// embedder yourself.
  Future<void> addDocument(
    String id,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    _assertInitialized();

    await FlutterGemmaPlugin.instance.addDocument(
      id: id,
      content: content,
      metadata: metadata != null ? jsonEncode(metadata) : null,
    );
  }

  /// Stores [content] together with a **pre-computed** [embedding].
  ///
  /// Use this when you already have the embedding vector (e.g. from a batch
  /// job) and want to skip the on-device inference.
  Future<void> addDocumentWithEmbedding(
    String id,
    String content,
    List<double> embedding, {
    Map<String, dynamic>? metadata,
  }) async {
    _assertInitialized();

    await FlutterGemmaPlugin.instance.addDocumentWithEmbedding(
      id: id,
      content: content,
      embedding: embedding,
      metadata: metadata != null ? jsonEncode(metadata) : null,
    );
  }

  /// Embeds every entry in [documents] and stores them.
  ///
  /// Keys are treated as IDs, values as content.
  Future<void> addDocuments(
    Map<String, String> documents, {
    Map<String, dynamic>? sharedMetadata,
  }) async {
    _assertInitialized();

    final metaJson = sharedMetadata != null ? jsonEncode(sharedMetadata) : null;

    for (final entry in documents.entries) {
      await FlutterGemmaPlugin.instance.addDocument(
        id: entry.key,
        content: entry.value,
        metadata: metaJson,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Performs a semantic search against the vector store.
  ///
  /// Returns up to [topK] results whose cosine similarity is ≥ [threshold].
  Future<List<SearchResult>> search(
    String query, {
    int topK = 5,
    double threshold = 0.7,
  }) async {
    _assertInitialized();

    final results = await FlutterGemmaPlugin.instance.searchSimilar(
      query: query,
      topK: topK,
      threshold: threshold,
    );

    return results
        .map(
          (r) => SearchResult(
            id: r.id,
            content: r.content,
            similarity: r.similarity,
            metadata: r.metadata,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases the embedding model and marks the service as uninitialised.
  ///
  /// You can call [initialize] again later to re-open.
  Future<void> dispose() async {
    _initialized = false;
    debugPrint('VectorStoreService disposed');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'VectorStoreService has not been initialised. '
        'Call initialize() first.',
      );
    }
  }
}
