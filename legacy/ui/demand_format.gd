class_name DemandFormat
extends RefCounted

## Shared formatting for arrival/turned-away lists, used by the day log and
## the Build menu's forecast panel so "what does the demand look like" reads
## the same everywhere.

static func summarize_arrivals(arrivals: Array, species_catalog: Dictionary) -> String:
	var counts: Dictionary = {}
	for arrival in arrivals:
		var id: String = arrival["species_id"]
		counts[id] = int(counts.get(id, 0)) + 1
	return summarize_counts(counts, species_catalog)


static func summarize_counts(counts: Dictionary, species_catalog: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var ids: Array = counts.keys()
	ids.sort()
	var parts: Array = []
	for id in ids:
		var name: String = species_catalog.get(id, {}).get("name", id)
		var needs: Array = species_catalog.get(id, {}).get("needs", [])
		parts.append("%dx %s (%s)" % [int(counts[id]), name, String(", ").join(needs)])
	return String(", ").join(parts)
