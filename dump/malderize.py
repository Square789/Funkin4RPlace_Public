import json

def main(src, tgt):
	with open(src, "r", encoding="utf-8") as f:
		d = json.load(f)

	for section in d["song"]["notes"]:
		for note in section["sectionNotes"]:
			if (note[1] >= 4) ^ (section["mustHitSection"]):
				note[4] = [1]

	with open(tgt, "w", encoding="utf-8") as f:
		json.dump(d, f, indent="\t")


if __name__ == "__main__":
	main(
		"/tmp/malder/malder.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder/malder.json",
	)
	main(
		"/tmp/malder/malder-hard.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder/malder-hard.json",
	)
	main(
		"/tmp/malder/malder-mania.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder/malder-mania.json",
	)

	main(
		"/tmp/malder-gold/malder-gold.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder-gold/malder-gold.json",
	)
	main(
		"/tmp/malder-gold/malder-gold-hard.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder-gold/malder-gold-hard.json",
	)
	main(
		"/tmp/malder-gold/malder-gold-mania.json",
		"/home/square/Code/haxe/Funkin4RPlace/assets/preload/data/malder-gold/malder-gold-mania.json",
	)
