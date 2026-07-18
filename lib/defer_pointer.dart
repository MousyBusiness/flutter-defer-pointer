library expanded_hit_test;

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

part 'deferred_pointer_handler_link.dart';
part 'deferred_pointer_handler.dart';

/// Create a StatelessWidget to wrap our RenderObjectWidget so we can bind to inherited widget.
class DeferPointer extends StatelessWidget {
  const DeferPointer({
    Key? key,
    required this.child,
    this.paintOnTop = false,
    this.link,
    this.priority = 0,
  }) : super(key: key);
  final Widget child;

  /// child will be painted in the [DeferredPointerHandler] causing it to render on top of any siblings in the it's current context.
  final bool paintOnTop;

  /// an optional link that can be shared with a [DeferredPointerHandler],
  /// if not provided, `DeferredHitTestRegion.of()` will be called.
  final DeferredPointerHandlerLink? link;

  /// Hit-test priority. Higher priority is tested first by the
  /// [DeferredPointerHandler] — i.e. an entity painted "on top" should get a
  /// higher priority than one painted behind it. Without an explicit value,
  /// priority falls back to attach order (last-attached wins), which is what
  /// the original `defer_pointer` package shipped. Use this when the consumer
  /// owns a deterministic paint stack (e.g. an infinity canvas with its own
  /// paint-order map) and the attach order does not match it.
  final int priority;

  @override
  Widget build(BuildContext context) {
    final link = this.link ?? DeferredPointerHandler.of(context).link;
    return _DeferPointerRenderObjectWidget(
      link: link,
      child: child,
      deferPaint: paintOnTop,
      priority: priority,
    );
  }
}

/// Single child render object returns a custom render object [_DeferPointerRenderObject]
class _DeferPointerRenderObjectWidget extends SingleChildRenderObjectWidget {
  const _DeferPointerRenderObjectWidget({
    required this.link,
    required Widget child,
    Key? key,
    required this.deferPaint,
    required this.priority,
  }) : super(child: child, key: key);

  final DeferredPointerHandlerLink link;

  final bool deferPaint;

  final int priority;

  @override
  RenderObject createRenderObject(BuildContext context) => _DeferPointerRenderObject(link, deferPaint, priority);

  @override
  void updateRenderObject(BuildContext context, _DeferPointerRenderObject renderObject) {
    renderObject.link = link;
    renderObject.deferPaint = deferPaint;
    renderObject.priority = priority;
  }
}

class _DeferPointerRenderObject extends RenderProxyBox {
  _DeferPointerRenderObject(DeferredPointerHandlerLink link, this.deferPaint, this._priority, {RenderBox? child})
      : super(child) {
    this.link = link;
  }

  bool deferPaint;
  bool _linked = false;
  int _priority;

  /// The hit-test priority assigned by the [DeferPointer] consumer. The link
  /// sorts painters by this descending before reverse-iterating registration
  /// order; see [DeferredPointerHandlerLink.painters].
  int get priority => _priority;
  set priority(int value) {
    if (_priority == value) return;
    _priority = value;
    _link.markOrderDirty();
  }

  late DeferredPointerHandlerLink _link;
  DeferredPointerHandlerLink get link => _link;
  set link(DeferredPointerHandlerLink link) {
    _link = link;
    link.add(this);
    _linked = true;
  }

  @override
  set child(RenderBox? child) {
    if (_linked) {
      link.remove(this);
      _linked = false;
    }
    super.child = child;
    if (this.child != null) {
      link.add(this);
      _linked = true;
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    link.add(this);
  }

  @override
  void detach() {
    link.remove(this);
    super.detach();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (deferPaint) return; // skip the draw if an ancestor is supposed to handle it
    context.paintChild(child!, offset);
  }

  @override
  void markNeedsPaint() {
    if (deferPaint) {
      _link.descendantNeedsPaint();
    } else {
      super.markNeedsPaint();
    }
  }
}
