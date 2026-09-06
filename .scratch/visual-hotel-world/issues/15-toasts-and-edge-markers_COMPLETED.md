# 14 — Toasts and off-screen edge markers

**What to build:** Feedback tied to the place that produced it. A brief message appears near where its event happened — now a node anchored to a world position projected through the camera, rather than a rect re-derived from a Control every frame.

When an event's anchor is outside the current framing, a small arrow marker appears on the corresponding screen edge, so zooming in never hides an event. Tapping the marker pans the camera to the anchor, making follow-up one gesture. The retired day-log ticker is not revived.

**Blocked by:** 08, 09

**Status:** ready-for-agent

- [ ] A toast appears at its event's world anchor and tracks that anchor as the camera pans and zooms
- [ ] An event anchored outside the current framing raises an arrow marker on the correct screen edge
- [ ] Tapping the marker pans the camera to the anchor
- [ ] Toasts for Room events anchor to the correct Room bay, and Terrace and lobby events to their own places
- [ ] No day-log ticker returns
