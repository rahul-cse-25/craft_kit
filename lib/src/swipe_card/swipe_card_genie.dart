part of 'swipe_card_stack.dart';

class _GenieRun {
  _GenieRun({
    required this.image,
    required this.quad,
    required this.target,
    required this.lag,
  }) : shader = ui.ImageShader(
         image,
         TileMode.clamp,
         TileMode.clamp,
         Matrix4.identity().storage,
         filterQuality: FilterQuality.medium,
       ),
       topology = SwipeGenie.topology() {
    // The mesh's texture coordinates in pixels of the picture. They never
    // change, so they are worked out once, not on every frame.
    final fractions = topology.uvs;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    textureCoordinates = Float32List(fractions.length);
    for (var i = 0; i < fractions.length; i += 2) {
      textureCoordinates[i] = fractions[i] * w;
      textureCoordinates[i + 1] = fractions[i + 1] * h;
    }
  }

  final ui.Image image;
  final ui.ImageShader shader;
  final GenieTopology topology;
  late final Float32List textureCoordinates;

  /// The card's corners in stack coordinates.
  final List<Offset> quad;

  /// The point the card pours into.
  final Offset target;
  final double lag;

  /// 0: the card as it was; 1: all of it in the target.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Drives [progress] backwards when the card pours back out.
  ScalarSpring? reverse;
  double reverseStart = double.nan;

  /// Releases everything. [keepImage] hands the picture to someone else.
  void dispose({bool keepImage = false}) {
    progress.dispose();
    shader.dispose();
    if (!keepImage) _disposeImage(image);
  }
}

class _GeniePainter extends CustomPainter {
  _GeniePainter({required this.run, this.slot, Listenable? repaint})
    : super(repaint: repaint ?? run.progress);

  final _GenieRun run;

  /// Extra transform, in stack coordinates, for a card that is still finding
  /// its place in the deck.
  final Matrix4 Function()? slot;

  @override
  void paint(Canvas canvas, Size size) {
    final g = run.progress.value.clamp(0.0, 1.0);
    final alpha = SwipeGenie.opacity(g);
    if (alpha <= 0) return;

    // Only the vertex positions change from frame to frame; how they connect
    // and which part of the picture each shows are fixed.
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      SwipeGenie.positions(
        quad: run.quad,
        target: run.target,
        progress: g,
        lag: run.lag,
      ),
      textureCoordinates: run.textureCoordinates,
      indices: run.topology.indices,
    );
    final paint =
        Paint()
          ..shader = run.shader
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(255, 255, 255, alpha),
            BlendMode.modulate,
          );
    canvas.save();
    final extra = slot?.call();
    if (extra != null) canvas.transform(extra.storage);
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    canvas.restore();
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_GeniePainter oldDelegate) => true;
}

/// How many captured card pictures are alive right now. Every picture is
/// counted when captured and uncounted when released, so a test can prove
/// nothing leaks.
@visibleForTesting
int debugLiveGenieImages = 0;

void _disposeImage(ui.Image? image) {
  if (image == null) return;
  image.dispose();
  debugLiveGenieImages--;
}
