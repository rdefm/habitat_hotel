# 15 — Modal pixel-art reskin

**What to build:** Opening a modal should not feel like leaving the game. Every surviving modal — seat-confirm, build-confirm, stay-info, staffer-detail, upgrade, terrace, and the reception admin tabs (prices, hire, reports, reviews) — is reskinned with a pixel-art theme sharing the world's palette and font.

Content and every `Sim`/`GameState` call stay exactly as they are. Moving any modal into the world is explicitly out of scope; the review pass that justifies or removes each one is later, separate work.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] Every listed modal uses the shared pixel-art theme, palette and font
- [ ] No modal's content, controls or Sim/GameState calls change
- [ ] A modal opened over the world reads as part of the same game, not a different one
