# 03 — Slice the hotel background into contract slots

**What to build:** `assets/hotel-background.jpg` is a single fixed painting of a five-band hotel. The game needs a building that grows to eight bands (Ground Floor, Terrace at Level 1, and up to six Room floors), so the painting is cut into parts that compose.

Cut it into named PNG slots — lossless, because JPEG ringing on pixel art is visible at nearest-neighbour zoom. The parts are: the night sky and city as its own layer behind everything; the ground plinth and pavement; one interior band per Room type the painting supplies (the jungle, ice and bamboo bands); the Terrace band (the kitchen/bar pass — its redraw to a table-service bistro is later work, this ticket takes it as drawn); the lobby band; the framed column with planters that repeats once per floor; the elevator shaft segment that repeats once per floor; and the roofline with its marquee sign, which caps whatever the top floor happens to be.

The repeating parts are the load-bearing ones: the frame column and the shaft segment must tile vertically with no seam, at any floor count, and the roof cap must sit flush on the topmost band. Verify that by stacking eight bands, not three.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Every slot is a lossless PNG imported with nearest-neighbour filtering
- [ ] The sky and city are a separate layer with no building pixels baked into it, and the building slices carry no sky
- [ ] The frame column and elevator shaft segments tile vertically with no visible seam across an eight-band stack
- [ ] The roof cap sits flush on the top band at three bands and at eight
- [ ] The three Room-type interior bands, the Terrace band, the lobby band and the ground plinth are separate files
- [ ] A test composition of the original five bands is pixel-comparable to the source painting, proving nothing was lost in the cut
