import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

/// The fixed part of a genie mesh: how the grid is connected and which part of
/// the card's picture each vertex shows. It never changes for a given
/// resolution, so it is built once per card and reused every frame.
final class GenieTopology {
  const GenieTopology._(this.columns, this.rows, this.uvs, this.indices);

  /// Grid cells across the card.
  final int columns;

  /// Grid cells down the card.
  final int rows;

  /// Texture coordinates, two floats (u, v) per vertex, as fractions (0 to 1)
  /// of the captured picture.
  final Float32List uvs;

  /// Triangles, three vertex indices each.
  final Uint16List indices;

  /// How many vertices the grid has.
  int get vertexCount => (columns + 1) * (rows + 1);
}

/// The "genie" warp: a card pours into a point like the macOS Dock minimize
/// effect and, run backwards, pours back out of it.
///
/// The funnel runs along the line from the card's centre to the target point,
/// whichever direction that is. Every vertex of a fine grid laid over the card
/// is described by how far along that line it is (`a`) and how far to the side
/// of it (`l`). As the effect runs:
///
/// * the vertices nearest the target start first and the rest follow (`lag`),
///   so the card stretches out behind its leading edge;
/// * each vertex slides along the line toward the target;
/// * each vertex squeezes toward the line, more the further it has travelled.
///
/// Because how far each vertex has got varies smoothly across the card, the
/// silhouette is a smooth S-shaped funnel, and it ends with the whole card
/// gathered into the single target point. Nothing depends on which side or
/// corner is closest.
///
/// This is pure geometry, so it is testable without any rendering.
abstract final class SwipeGenie {
  /// Grid cells per side. Fine enough that the funnel's curved sides look
  /// smooth, whichever way it points.
  static const int defaultResolution = 28;

  static final Map<int, GenieTopology> _topologies = <int, GenieTopology>{};

  /// The (cached) mesh topology for a grid of [resolution] cells per side.
  static GenieTopology topology([int resolution = defaultResolution]) {
    assert(resolution >= 1 && resolution <= 250, 'resolution out of range');
    return _topologies.putIfAbsent(
      resolution,
      () => _buildTopology(resolution),
    );
  }

  static GenieTopology _buildTopology(int n) {
    final stride = n + 1;
    final uvs = Float32List(stride * stride * 2);
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        final i = (r * stride + c) * 2;
        uvs[i] = c / n;
        uvs[i + 1] = r / n;
      }
    }
    final indices = Uint16List(n * n * 6);
    var k = 0;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final a = r * stride + c; // top left of the cell
        final b = a + 1;
        final d = a + stride;
        final e = d + 1;
        indices[k++] = a;
        indices[k++] = b;
        indices[k++] = d;
        indices[k++] = b;
        indices[k++] = e;
        indices[k++] = d;
      }
    }
    return GenieTopology._(n, n, uvs, indices);
  }

  /// The vertex positions at [progress] (0 = the card as it was, 1 = all of it
  /// gathered in [target]), two floats (x, y) per vertex, in the order of
  /// [topology].
  ///
  /// [quad] holds the card's corners in stack coordinates, in the order top
  /// left, top right, bottom right, bottom left, already including any tilt or
  /// scale. [lag] (0 to 1) is how far the far edge trails the near edge: 0
  /// moves the whole card together, larger values make a longer funnel.
  static Float32List positions({
    required List<Offset> quad,
    required Offset target,
    required double progress,
    double lag = 0.45,
    int resolution = defaultResolution,
  }) {
    assert(quad.length == 4, 'quad needs four corners');
    final n = resolution;
    final stride = n + 1;
    final out = Float32List(stride * stride * 2);

    // Plain doubles throughout: this runs for every vertex on every frame, so
    // it avoids allocating an Offset per step.
    final tlx = quad[0].dx, tly = quad[0].dy;
    final trx = quad[1].dx, try_ = quad[1].dy;
    final brx = quad[2].dx, bry = quad[2].dy;
    final blx = quad[3].dx, bly = quad[3].dy;
    final cx = (tlx + trx + brx + blx) / 4;
    final cy = (tly + try_ + bry + bly) / 4;

    // The funnel's axis: from the card's centre to the target.
    final tx = target.dx - cx;
    final ty = target.dy - cy;
    final distance = math.sqrt(tx * tx + ty * ty);
    final ax = distance < 1e-6 ? 0.0 : tx / distance;
    final ay = distance < 1e-6 ? 1.0 : ty / distance;
    final sx = -ay; // the perpendicular
    final sy = ax;

    // How far the card reaches along the axis, to say how "near" a vertex is.
    final a0 = (tlx - cx) * ax + (tly - cy) * ay;
    final a1 = (trx - cx) * ax + (try_ - cy) * ay;
    final a2 = (brx - cx) * ax + (bry - cy) * ay;
    final a3 = (blx - cx) * ax + (bly - cy) * ay;
    final aMin = math.min(math.min(a0, a1), math.min(a2, a3));
    final aMax = math.max(math.max(a0, a1), math.max(a2, a3));
    final range = math.max(aMax - aMin, 1e-6);
    final g = progress.clamp(0.0, 1.0);
    final reach = g * (1 + lag);

    var i = 0;
    for (var r = 0; r <= n; r++) {
      final v = r / n;
      final lx = tlx + (blx - tlx) * v;
      final ly = tly + (bly - tly) * v;
      final rx = trx + (brx - trx) * v;
      final ry = try_ + (bry - try_) * v;
      for (var c = 0; c <= n; c++) {
        final u = c / n;
        final relx = lx + (rx - lx) * u - cx;
        final rely = ly + (ry - ly) * u - cy;
        final a = relx * ax + rely * ay; // along the funnel
        final l = relx * sx + rely * sy; // across it

        // 1 at the edge facing the target, 0 at the far edge.
        final near = ((a - aMin) / range).clamp(0.0, 1.0);
        // Each vertex waits for its turn: the near edge starts at once, the
        // far edge after `lag`, and all arrive together at progress 1.
        final q = (reach - (1 - near) * lag).clamp(0.0, 1.0);
        final travel = _easeInOutSine(q);
        final squeeze = q * q * (3 - 2 * q); // smoothstep: flat at both ends

        final along = a + (distance - a) * travel;
        final across = l * (1 - squeeze);
        out[i++] = cx + ax * along + sx * across;
        out[i++] = cy + ay * along + sy * across;
      }
    }
    return out;
  }

  /// How opaque the card is at [progress]: it fades over the last part, so it
  /// dissolves into the target instead of ending as a hard sliver.
  static double opacity(double progress) {
    final f = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
    return 1 - f * f * (3 - 2 * f);
  }

  static double _easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;
}
