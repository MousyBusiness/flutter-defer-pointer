import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:defer_pointer/defer_pointer.dart';

/// Two `DeferPointer`s occupying the same rect. Under the original package the
/// `DeferredPointerHandler` hit-tests them in reverse REGISTRATION order
/// (last-attached wins), which decouples from the visual paint stack whenever a
/// child detaches/reattaches. The `priority` field lets a consumer that owns a
/// deterministic paint order (the infinity canvas) drive hit ordering instead.
Widget _overlay({
  required int priorityA,
  required int priorityB,
  required void Function(String) onTap,
}) {
  Widget cell(String id, int priority) => Positioned(
        left: 0,
        top: 0,
        child: DeferPointer(
          priority: priority,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(id),
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
  return MaterialApp(
    home: DeferredPointerHandler(
      child: Stack(
        children: [
          // 'A' attaches FIRST (tested last under reverse-registration order).
          cell('A', priorityA),
          // 'B' attaches LAST (tested first under reverse-registration order).
          cell('B', priorityB),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('higher priority wins even when it attached first', (tester) async {
    String? tapped;
    // A attaches first but has the higher priority — it must win, proving
    // priority overrides attach order.
    await tester.pumpWidget(_overlay(priorityA: 10, priorityB: 1, onTap: (id) => tapped = id));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(tapped, 'A');
  });

  testWidgets('higher priority wins when it attached last too', (tester) async {
    String? tapped;
    await tester.pumpWidget(_overlay(priorityA: 1, priorityB: 10, onTap: (id) => tapped = id));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(tapped, 'B');
  });

  testWidgets('equal priority falls back to last-attached-wins (original semantics)', (tester) async {
    String? tapped;
    await tester.pumpWidget(_overlay(priorityA: 0, priorityB: 0, onTap: (id) => tapped = id));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(tapped, 'B', reason: 'B attached last, so with no priority difference it keeps the original last-wins order');
  });
}
