# Habitat Hotel

An animal hotel management sim: guests of various species check into tagged rooms, staff run four live service stations, and a dining terrace runs breakfast and dinner service alongside room stays. Single context — this file covers the whole game.

## Language

### Guests & Rooms

**Room**:
A built, tagged space guests stay in. Belongs to exactly one Floor, which fixes its type.
_Avoid_: Habitat (reserved for the game's title/theme), Slot (a Room's container, not the Room itself)

**Tag**:
An environmental attribute (e.g. `warm`, `cold`, `water`, `high_perch`) that a Room has and a Species needs or likes. The whole seating puzzle is matching these.

**Species**:
A guest type: its Needs, Likes, budget tier, typical party size, and typical stay length.

**Need**:
A Tag a Species requires. A Room missing a needed Tag produces a mismatched stay (seatable, but a satisfaction penalty).

**Like**:
A Tag a Species prefers but doesn't require. Bonus satisfaction only, never blocks seating.

**Party**:
A group of one Species arriving together to check in. May exceed a single Room's capacity, in which case it splits across multiple Rooms.

**Match**:
The seating hint shown when a Party is selected and a Room is tapped: green (every Need met), amber (partial — seatable with a confirmation, at a penalty), or no highlight (not seatable). See [[0001-direct-manipulation-interaction]].

**Checkout**:
A Party's stay ending. Triggers a review, Hearts, and a Reputation change, and leaves the Room dirty for Housekeeping.

### Staff & Stations

**Station**:
One of the four live service posts — Reception, Bellhop, Housekeeping, Kitchen — that a Staffer can be assigned to. Distinct from a fixed job title: any Staffer can work any Station.
_Avoid_: Role (implies permanence; a Staffer's Station is freely reassignable)

**Staffer**:
A named individual with a Skill rating at every Station (lopsided toward a home specialty). New Staffers join the Roster by unlocking, not by hiring.
_Avoid_: Employee, hire

**Skill**:
A Staffer's 1–5 rating at a given Station. Determines service speed at that Station (cleaning time, meal service time, etc.).

**Roster**:
The set of Staffers currently unlocked and available for Station assignment. Grows via milestone unlocks (star level, cash, story beats) — never a procedurally generated hire/fire pool. See [[0002-staff-roster-unlocks]].

### Dining

**Terrace**:
The hotel's dining structure. Present and operating from day one — never built or star-gated — but can receive purchased or earned upgrades like a Room can. See [[0003-dining-core-pillar]].
_Avoid_: Restaurant (used in the original plan as a gated amenity; superseded)

**Walk-in Diner**:
A visitor who arrives for Dinner service only, without a booked Room. Distinct from a Party, which is always tied to a Room stay.

**Dining Party**:
The Evening dinner queue entry produced by a room guest's dinner add-on (opted into at check-in) once it joins Terrace service — carries its own Patience and gets the same Kitchen-skill gating and Reputation/Hearts scoring as a Walk-in Diner. Distinct from a Walk-in Diner: a Dining Party is always tied to an existing Room stay, not a standalone Terrace-only visit.

**Daily Special**:
A player-chosen, species-flavored dish that biases which Species show up as Walk-in Diners that evening.

**Patience**:
A queue entry's (Party, Walk-in Diner, or Dining Party) tolerance timer. Decays over time — faster if the relevant Station is unstaffed — passing through content → impatient → huffy → leave.

### Progression

**Reputation**:
A 0–100 meter within the current Star level. Rises on positive reviews (from Checkouts and served Dining guests alike) and falls on negative reviews and walk-aways.

**Hearts**:
The quality meta-currency, earned from happy Checkouts and well-served Dining guests. Spent on training, Room/Terrace upgrades, and Roster unlocks.

**Star**:
The hotel's overall rating, 1–5, a ratchet that never decreases. Gates which Species tiers, Room types, and Roster unlocks are available.

### Building

**Floor**:
The building's vertical unit. Exactly one Room type per Floor. See [[0004-floor-per-room-type]].
_Avoid_: Slot grid (the free-form generic-slot model this replaces)

**Build Slot**:
The open slot at the end of a Floor's row where another instance of that Floor's Room type can be constructed, up to a per-Floor cap.

**Amenity**:
A separate buildable slot-occupant (Pool, Sauna, Perch Garden) that boosts satisfaction for guests whose Likes match. Distinct from the Terrace, which is fixed rather than built.
