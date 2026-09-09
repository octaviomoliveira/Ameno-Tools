# E17 baseline

Captured on 2026-09-09 before changing the E16 implementation.

- source branch: `feature/e17-ameno-ux`
- frozen base: `f763059809d47c655ebe343a81b180407ef6710e`
- host target: 3ds Max 2026
- Python: 3.11.12 in the host; desktop verification also used Python 3.14
- Qt target: PySide6 / Qt 6.5.3
- E15 Python gates: pass
- E16 overlay model: 27/27 checks
- E16 callback lifecycle: 6/6 checks, maximum one registered callback
- E16 1,000 move harness: 5.120 s, zero full resolve, zero scene mutation,
  zero preview nodes
- E16 seven-segment commit: 181 ms total, 25.86 ms/segment average;
  scene preparation 1 ms and material setup 1 ms

The baseline is a hard E17 regression gate. Visual changes may not weaken
these limits or move scene work back into navigation, selectors, paint events
or mouse movement.
