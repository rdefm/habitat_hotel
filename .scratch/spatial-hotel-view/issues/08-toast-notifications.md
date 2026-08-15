# 08 — Toast notifications replace the day log

**What to build:** Remove the day-log ticker. Replace its three feeds (day summary, posted review, next-day forecast) with brief, auto-dismissing toast nodes that appear anchored near the relevant spatial location instead of appending to a ticker: arrivals/turn-aways/forecast summaries near the Reception floor, a checkout's review near the specific Room cell it came from. Toast text content is the same formatted strings these feeds already produce.

**Blocked by:** 05, 06

**Status:** ready-for-agent

- [ ] The day-log ticker no longer exists anywhere in the UI
- [ ] A day summary (arrivals/checkouts/turned-away counts) appears as a toast near the Reception floor
- [ ] A posted review appears as a toast near the Room cell the stay happened in
- [ ] A next-day forecast appears as a toast near the Reception floor
- [ ] Toasts auto-dismiss after a short duration and don't block or intercept drag/drop or tap interaction with the floor beneath them
- [ ] Multiple toasts firing in quick succession (e.g. several checkouts at once) don't overlap illegibly or leak nodes
