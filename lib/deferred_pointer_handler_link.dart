part of 'defer_pointer.dart';

/// Holds the [_DeferPointerRenderObject]s currently registered against this
/// link. [DeferredPointerHandler] hit-tests them in priority order: painters
/// with the highest [_DeferPointerRenderObject.priority] are checked first,
/// falling back to reverse registration order within the same priority. The
/// painter list is kept in registration order and re-sorted lazily when any
/// painter's priority changes or membership shifts.
class DeferredPointerHandlerLink extends ChangeNotifier with EquatableMixin {
  DeferredPointerHandlerLink();
  final List<_DeferPointerRenderObject> _painters = [];
  List<_DeferPointerRenderObject>? _sortedForHitTest;

  void descendantNeedsPaint() => notifyListeners();

  /// Registration-order view. [DeferredPointerHandler.paint] iterates this so
  /// a painter's paintOnTop draw composes after its siblings, not by priority.
  List<_DeferPointerRenderObject> get painters => UnmodifiableListView(_painters);

  /// Hit-test order: painters sorted by `priority` descending, with reverse
  /// registration order as the tie-breaker so equal-priority painters keep
  /// the package's original "last-attached wins" behaviour. Lazy; invalidated
  /// by [markOrderDirty].
  List<_DeferPointerRenderObject> get hitTestOrder {
    if (_sortedForHitTest != null) return _sortedForHitTest!;
    final reversed = _painters.reversed.toList(growable: false);
    reversed.sort((a, b) => b.priority.compareTo(a.priority));
    _sortedForHitTest = reversed;
    return _sortedForHitTest!;
  }

  void markOrderDirty() {
    _sortedForHitTest = null;
  }

  void add(_DeferPointerRenderObject value) {
    if (!_painters.contains(value)) {
      _painters.add(value);
      _sortedForHitTest = null;
      notifyListeners();
    }
  }

  void remove(_DeferPointerRenderObject value) {
    if (_painters.contains(value)) {
      _painters.remove(value);
      _sortedForHitTest = null;
      notifyListeners();
    }
  }

  void removeAll() {
    _painters.clear();
    _sortedForHitTest = null;
    notifyListeners();
  }

  @override
  List<Object?> get props => _painters;
}
