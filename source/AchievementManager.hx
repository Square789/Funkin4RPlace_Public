
import haxe.ValueException;
import haxe.ds.StringMap;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;

using StringTools;

// maps (only interested in their keys (no sets in this language)) whose
// keys are valid groups for the "single-handed smackdown" achievement.
private final SHS_MAPS:Array<Map<FlxKey, Bool>> = [
	[W => true, A => true, S => true, D => true],
	[UP => true, LEFT => true, DOWN => true, RIGHT => true],
];


private function _intCompare(op:AchievementOperation, v0:Int, v1:Int):Bool {
	return switch op {
		case LT:  v0 < v1;
		case LTE: v0 <= v1;
		case EQ:  v0 == v1;
		case NEQ: v0 != v1;
		case GT:  v0 > v1;
		case GTE: v0 >= v1;
	}
}


private function _stringCompare(op:AchievementOperation, v0:String, v1:String):Bool {
	return switch op {
		case LT:  v0 < v1;
		case LTE: v0 <= v1;
		case EQ:  v0 == v1;
		case NEQ: v0 != v1;
		case GT:  v0 > v1;
		case GTE: v0 >= v1;
	}
}


enum AchievementOperation {
	LT;
	LTE;
	EQ;
	NEQ;
	GT;
	GTE;
}


enum AchievementCriterium {
	MISSES(op:AchievementOperation, v:Int);
	DIFFICULTY(op:AchievementOperation, v:Int);
	STORY_MODE_DIFFICULTY(op:AchievementOperation, v:Int);
	IN_STORY_MODE;
	PLAYING_AS_OPPONENT;
	SONG_NAME(op:AchievementOperation, v:String);
	WEEK_NAME(op:AchievementOperation, v:String);
	ALWAYS_TRUE;
}


enum AchievementEvent {
	KEY_PRESSED;
	SONG_WON;
	WEEK_WON;
	BLUE_BALLED;
	GAME_STARTED;
	ACHIEVEMENTS_ADVANCED;
	AMOGER_CLICKED;
}

// Lots and lots of PlayState god object attribute access, but look: The alternative
// would be constructing a parallel, 2nd PlayState based on AchievementEvents and that
// sucks hard as well.
private function isCriteriumFulfilled(criterium:AchievementCriterium):Bool {
	switch (criterium) {
	case MISSES(op, v):
		return _intCompare(op, PlayState.instance.songMisses, v);
	case DIFFICULTY(op, v):
		return _intCompare(op, PlayState.storyDifficulty, v);
	case STORY_MODE_DIFFICULTY(op, v):
		return _intCompare(op, PlayState.lowestDifficultyThisStoryRun, v);
	case IN_STORY_MODE:
		return PlayState.isStoryMode;
	case PLAYING_AS_OPPONENT:
		return PlayState.instance.opponentChart;
	case SONG_NAME(op, v):
		return _stringCompare(op, PlayState.instance.curSong, v);
	case WEEK_NAME(op, v):
		return _stringCompare(op, WeekData.getWeekFileName(), v);
	case ALWAYS_TRUE:
		return true;
	case _:
		throw new ValueException('Unknown criterium: $criterium ');
	}
}


enum PersistentAchievementDataShape {
	BOOL;
	INT;
	FLOAT;
	STRING;
	ARRAY(size:Int, type:PersistentAchievementDataShape);
	TUPLE(size:Int, types:Array<PersistentAchievementDataShape>);
}

// REQUEST: DO NOT LOOK AT THIS CODE
// IT IS SHAMEFUL. SO VERY SHAMEFUL.

abstract private class _DataInterfacer {
	abstract public function set<T>(v:T):T;
	abstract public function get():Dynamic;
}

private class _MapInterfacer extends _DataInterfacer {
	private var map:Map<String, Dynamic>;
	private var key:String;
	public function new(map:Map<String, Dynamic>, key:String) { this.map = map; this.key = key; }
	public function set<T>(v:T):T { return map[key] = v; }
	public function get():Dynamic { return map[key]; }
}

private class _ArrayInterfacer extends _DataInterfacer {
	private var arr:Array<Dynamic>;
	private var idx:Int;
	public function new(arr:Array<Dynamic>, idx:Int) { this.arr = arr; this.idx = idx; }
	public function set<T>(v:T):T { return arr[idx] = v; }
	public function get():Dynamic { return arr[idx]; }
}

/**
 * Happily typecasting and type-checking mystery blob structure that
 * provides access to achievement data.
 */
class PersistentAchievementData {
	var shape:PersistentAchievementDataShape;
	private var interfacer:_DataInterfacer;
	private var parent:PersistentAchievementData;
	private var children:Null<Array<PersistentAchievementData>>;

	public function new(
		parent:Null<PersistentAchievementData>,
		interfacer:_DataInterfacer,
		shapeSubtree:PersistentAchievementDataShape
	) {
		this.interfacer = interfacer;
		this.shape = shapeSubtree;
		this.parent = parent;

		switch (shapeSubtree) {
		case ARRAY(size, type_):
			var trueStructure = cast(interfacer.get(), Array<Dynamic>);
			if (trueStructure.length != size) {
				throw new ValueException('Bad length for stored ARRAY. Was ${trueStructure.length}, expected $size');
			}

			this.children = [
				for (i in 0...size)
				new PersistentAchievementData(this, new _ArrayInterfacer(trueStructure, i), type_)
			];
		case TUPLE(size, types):
			var trueStructure = cast(interfacer.get(), Array<Dynamic>);
			if (trueStructure.length != size) {
				throw new ValueException('Bad length for stored TUPLE. Was ${trueStructure.length}, expected $size');
			}

			this.children = [
				for (i in 0...size)
				new PersistentAchievementData(this, new _ArrayInterfacer(trueStructure, i), types[i])
			];
		case _:
			this.children = null;
		}

		// Verify initial data from value container
		var data:Dynamic = interfacer.get();
		switch (shapeSubtree) {
			case BOOL: cast(data, Bool);
			case INT: cast(data, Int);
			case FLOAT: cast(data, Float);
			case STRING: cast(data, String);
			// These will already have happened as consequence of the child node creation above
			case ARRAY(size, type_):
			case TUPLE(size, types):
		}
	}

	public static function makeDefault(shape:PersistentAchievementDataShape):Dynamic {
		return switch (shape) {
		case BOOL: false;
		case INT: 0;
		case FLOAT: 0.0;
		case STRING: "";
		case ARRAY(size, type_): [for (_ in 0...size) makeDefault(type_)];
		case TUPLE(size, types): [for (i in 0...size) makeDefault(types[i])];
		};
	}

	private inline function _verifyType(x:PersistentAchievementDataShape):Void {
		if (shape != x) {
			throw new ValueException('Shape is not ${x}!');
		}
	}

	public function reset() {
		switch (shape) {
		case (ARRAY(_, _) | TUPLE(_, _)):
			for (c in children) {
				c.reset();
			}
		case _:
			interfacer.set(makeDefault(shape));
		}
	}

	public function getInt():Int {
		_verifyType(INT);
		return cast(interfacer.get(), Int);
	}

	public function setInt(v:Int):Int {
		_verifyType(INT);
		return interfacer.set(v);
	}

	public function getFloat():Float {
		_verifyType(FLOAT);
		return cast(interfacer.get(), Float);
	}

	public function setFloat(v:Float):Float {
		_verifyType(FLOAT);
		return interfacer.set(v);
	}

	public function getString():String {
		_verifyType(STRING);
		return cast(interfacer.get(), String);
	}

	public function setString(v:String):String {
		_verifyType(STRING);
		return interfacer.set(v);
	}

	public function getBool():Bool {
		_verifyType(BOOL);
		return cast(interfacer.get(), Bool);
	}

	public function setBool(v:Bool):Bool {
		_verifyType(BOOL);
		return interfacer.set(v);
	}

	public function sub(idx:Int):PersistentAchievementData {
		switch (shape) {
		case (ARRAY(_, _) | TUPLE(_, _)):
			return children[idx];
		case _:
			throw new ValueException('Can not subscribe a ${shape.getName()}!');
		}
	}
}

typedef PersistenceInfo = {
	shape:PersistentAchievementDataShape,
	?defaultProviderFunc:Null<Void->Dynamic>,
	?verifierFunc:Null<Dynamic->Bool>,
}


typedef AchievementLayerInfo = {
	name:String,
	desc:String,
	sound:String,
};


final class AchievementElement {
	public static final ICON:Int = 1;
	public static final NAME:Int = 2;
	public static final DESC:Int = 4;
	// No, ALL != ((ICON | NAME | DESC) == 7) as achievement displayers should act
	// like it doesn't even exist for this flag.
	public static final ALL:Int = 8;
}


class Achievement {
	/**
	 * The id of the achievement. Must be unique across all achievements known to the
	 * AchievementManager.
	 */
	public var id(default, null):String;

	public var layerCount(default, null):Int;

	/**
	 * Descriptions and names for each of the achievement's layers. If the array's length is 1,
	 * the same will be used for each layer. If the array's length is 0 or not equal to the
	 * layer count otherwise, an error is hurled.
	 */
	public var layerInfo:Array<AchievementLayerInfo>;

	/**
	 * Events that should cause the achievement's `checkUnlockProgressFunc` to be called.
	 * These may be empty. In that case, you will need direct calls to the achievement manager's
	 * `advanceAchievement` method.
	 */
	public var checkOnEvents:Array<AchievementEvent>;

	/**
	 * Which parts of the achievement should be obscured/withheld/replaced by a placeholder from
	 * any achievement listing if the achievement is locked.
	 * The special bit `AchievementElement.ALL` signals that the achievement should be entirely
	 * withheld as if it was not there. You might call that a secret achievement, and when this
	 * bit is set, the others effectively do not matter.
	 * By default this attribute is `AchievementElement.ICON | AchievementElement.NAME`.
	 */
	var hideWhenLocked:Int;

	/**
	 * A function that should report which layer an achievement has reached based on the
	 * potentially given `PersistentAchievementData`, the `AchievementEvent` that caused the check
	 * and a possible supplement value describing the event further.
	 */
	 public var checkUnlockProgressFunc:(PersistentAchievementData, AchievementEvent, Dynamic) -> Int;

	/**
	 * If given, `PersistentAchievementData` will be supplied by the AchievementManager each time
	 * `checkUnlockProgressFunc` is called. It will retain data between invocations
	 * of that function which is also stored between game launches in the SaveData.
	 */
	public var persistenceInfo:Null<PersistenceInfo>;

	public function new(
		id:String,
		layerCount:Int,
		layerInfo:Array<AchievementLayerInfo>,
		checkOnEvents:Array<AchievementEvent>,
		?hideWhenLocked:Null<Int>,
		?checkUnlockProgressFunc:Null<(PersistentAchievementData, AchievementEvent, Dynamic)->Int>,
		?persistenceInfo:Null<PersistenceInfo>
	) {
		if (layerCount <= 0) {
			throw new ValueException("Achievements must have at least one layer!");
		}
		this.id = id;
		this.layerCount = layerCount;
		if (layerCount != 1 && layerInfo.length == 1) {
			this.layerInfo = [for (_i in 0...layerCount) layerInfo[0]];
		} else if (layerInfo.length == layerCount) {
			this.layerInfo = layerInfo;
		} else {
			throw new ValueException('Bad layer data length, expected 1 or $layerCount');
		}
		this.checkOnEvents = checkOnEvents;
		this.hideWhenLocked = hideWhenLocked == null ?
			AchievementElement.ICON | AchievementElement.NAME :
			hideWhenLocked;
		this.persistenceInfo = persistenceInfo;
		this.checkUnlockProgressFunc = checkUnlockProgressFunc;
	}

	/**
	 * Creates an achievement, but with less flexible args and more compactness in the code creating it.
	 * Similar to the SimpleAchievement constructor.
	 */
	public static function makeCompact(
		id:String,
		layerNames:Array<String>,
		layerDescs:Array<String>,
		checkOnEvents:Array<AchievementEvent>,
		?hideWhenLocked:Null<Int>,
		?checkUnlockProgressFunc:Null<(PersistentAchievementData, AchievementEvent, Dynamic)->Int>,
		?persistenceInfo:Null<PersistenceInfo>
	):Achievement {
		if (layerNames.length != 1 && layerDescs.length != 1 && layerNames.length != layerDescs.length) {
			throw new ValueException("per-layer info length discrepancies in SimpleAchievement.");
		}
		var layerCount = FlxMath.maxInt(layerNames.length, layerDescs.length);
		var layerInfo = [for (i in 0...layerCount)
			{
				name: layerNames[layerNames.length == 1 ? 0 : i],
				desc: layerDescs[layerDescs.length == 1 ? 0 : i],
				sound: "confirmMenu",
			}
		];
		return new Achievement(
			id, layerCount, layerInfo, checkOnEvents, hideWhenLocked, checkUnlockProgressFunc, persistenceInfo
		);
	}

	public function checkUnlockProgress(
		pad:PersistentAchievementData,
		eventType:AchievementEvent,
		supplement:Dynamic
	):Int {
		if (checkUnlockProgressFunc == null) {
			return 0;
		}
		return checkUnlockProgressFunc(pad, eventType, supplement);
	}

	public inline function shouldHideIconWhenLocked():Bool {
		return (hideWhenLocked & AchievementElement.ICON) == AchievementElement.ICON;
	}

	public inline function shouldHideNameWhenLocked():Bool {
		return (hideWhenLocked & AchievementElement.NAME) == AchievementElement.NAME;
	}

	public inline function shouldHideDescriptionWhenLocked():Bool {
		return (hideWhenLocked & AchievementElement.DESC) == AchievementElement.DESC;
	}

	/**
	 * Convenience function for testing whether the achievement has the AchievementElement.ALL
	 * bit set in its `hideWhenLocked` attribute.
	 */
	public inline function isSecret():Bool {
		return (hideWhenLocked & AchievementElement.ALL) == AchievementElement.ALL;
	}
}


class SimpleAchievement extends Achievement {
	private var criteria:Array<Array<AchievementCriterium>>;

	public function new(
		id:String,
		displayNames:Array<String>,
		descriptions:Array<String>,
		checkOnEvents:Array<AchievementEvent>,
		criteria:Array<Array<AchievementCriterium>>,
		?hideWhenLocked:Null<Int>
	) {
		if (criteria.length == 0) {
			throw new ValueException("My good friend, you need at least one criterium for this thing.");
		}
		if (
			(displayNames.length != 1 && displayNames.length != criteria.length) ||
			(descriptions.length != 1 && descriptions.length != criteria.length)
		) {
			throw new ValueException("per-layer info length discrepancies in SimpleAchievement.");
		}
		super(
			id,
			criteria.length,
			[
				for (i in 0...criteria.length)
					{
						name: displayNames[displayNames.length == criteria.length ? i : 0],
						desc: descriptions[descriptions.length == criteria.length ? i : 0],
						sound: "confirmMenu",
					}
			],
			checkOnEvents,
			hideWhenLocked
		);
		this.criteria = criteria;
	}

	public override function checkUnlockProgress(_, __, ___:Dynamic):Int {
		var currentLayer = 0;
		for (ca in criteria) {
			for (c in ca) {
				if (!isCriteriumFulfilled(c)) {
					return currentLayer;
				}
			}
			currentLayer += 1;
		}
		return currentLayer;
	}
}


class KonamiCodeAchievement extends Achievement {
	private var keybuffer:Array<FlxKey>;

	public function new(id:String, displayName:String, description:String) {
		super(id, 1, [{name: displayName, desc: description, sound: "confirmMenu"}], [KEY_PRESSED], AchievementElement.ALL);
		keybuffer = [];
	}

	public override function checkUnlockProgress(_, __, key_:Dynamic):Int {
		var key = cast(key_, FlxKey);
		if (keybuffer.length == 10) {
			keybuffer.shift();
		}
		keybuffer.push(key);
		switch (keybuffer) {
			case [UP, UP, DOWN, DOWN, LEFT, RIGHT, LEFT, RIGHT, B, A]: return 1;
			case _: return 0;
		}
	}
}


class AchievementRegistryEntry {
	public var achievement(default, null):Achievement;
	/**
	 * Index of the achievement depending when it was added to the AchievementManager.
	 * Will always form an unbroken range starting from 0 with all other registered achievements.
	 **/
	public var index:Int;
	public var unlockProgress:Int;
	public var saveData(default, null):Null<PersistentAchievementData>;

	public function new(achievement:Achievement, index:Int, unlockProgress:Int, saveData:Null<PersistentAchievementData>) {
		this.achievement = achievement;
		this.index = index;
		this.unlockProgress = unlockProgress;
		this.saveData = saveData;
	}

	/**
	 * Returns the layer info at `layerIndex` if `layerIndex` is given.
	 * Remember to subtract 1 from `unlockProgress` to get a proper layer index!
	 * Otherwise, returns the layer info of the currently unlocked layer, or the 1st one if
	 * the achievement is locked.
	 * May return `null` when the unlockProgress is broken but at that point you have
	 * different problems.
	 */
	public function getLayerInfo(layerIndex:Int = -1):Null<AchievementLayerInfo> {
		if (layerIndex != -1) {
			return achievement.layerInfo[layerIndex];
		}

		if (unlockProgress == 0) {
			return achievement.layerInfo[0];
		}
		return achievement.layerInfo[unlockProgress - 1];
	}

	/**
	 * Returns whether the achievement is fully unlocked, that is: At its highest tier.
	 */
	public function isUnlocked():Bool {
		return unlockProgress == achievement.layerCount;
	}

	/**
	 * Returns whether the achievement is fully locked, that is: at `unlockProgress` 0.
	 */
	public function isLocked():Bool {
		return unlockProgress == 0;
	}
}

private function getDefaultAchievements():Array<Achievement> {
	var defaultAchievements:Array<Achievement> = [];

	for (arr in [
		["Enveloped", "swarm"],
		["Dissatisfied", "consume"],
		["Place's end", "enough"],
		["SIX PIXELS", "malder"],
		["Invader", "bubbo"],
		["Spectator", "boundary"],
		// ["New neighbors", "real-estate"],
	]) {
		var achName = arr[0];
		var songName = arr[1];

		var diffs = CoolUtil.getDifficultiesRet(songName, true);
		if (diffs == null || diffs.length == 0) diffs = CoolUtil.defaultDifficulties.copy();

		var criteriums = [for (i in 0...diffs.length) [DIFFICULTY(GTE, i)]];
		criteriums[0].insert(0, SONG_NAME(EQ, songName));
		criteriums.push([MISSES(EQ, 0)]);

		diffs.push(diffs[diffs.length-1] + " FC");

		defaultAchievements.push(new SimpleAchievement(
			songName,
			[achName],
			[for (d in diffs)
				'Beat \"${songName.toUpperCase().replace("-", " ")}\" on $d'],
			[SONG_WON],
			criteriums
		));
	}

	defaultAchievements.push(new SimpleAchievement(
		"week1",
		["Null and Void"],
		[for (d in ["Normal", "Hard", "Mania"]) 'Beat the VOID WEEK on $d'],
		[WEEK_WON],
		[[WEEK_NAME(EQ, "void"), STORY_MODE_DIFFICULTY(GTE, 0)], [STORY_MODE_DIFFICULTY(GTE, 1)], [STORY_MODE_DIFFICULTY(GTE, 2)]]
	));
	// Smoking that AchievementCriterium.PLAYING_AS_OPPONENT pack
	// rest in piss you won't be missed
	// defaultAchievements.push(new SimpleAchievement(
	// 	"week1_op",
	// 	["The Dark Side"],
	// 	["Beat the VOID WEEK while playing as the opponent."],
	// 	[WEEK_WON],
	// 	[[WEEK_NAME(EQ, "void"), PLAYING_AS_OPPONENT]]
	// ));
	defaultAchievements.push(new Achievement(
		"freeplay_complete",
		3,
		[for (d in ["Normal", "Hard", "Mania"])
			{name: 'Snooping as Usual, I See?', desc: 'Beat "MALDER", "BUBBO" and "BOUNDARY" on $d', sound: "confirmMenu"}],
		[ACHIEVEMENTS_ADVANCED],
		null,
		(_, __, ___) -> {
			var e = AchievementManager.getAchievements(["malder", "bubbo", "boundary"]);
			if (e.length != 3) {
				throw new ValueException("Bad achievement registry array length, expected three.");
			}
			var minProgress = 9999;
			for (entry in e) {
				minProgress = FlxMath.minInt(minProgress, entry.unlockProgress);
			}
			return FlxMath.minInt(minProgress, 3);
		}
	));

	defaultAchievements.push(Achievement.makeCompact(
		"voided",
		["Voided"],
		["Die by having your entire health bar consumed by the Void"],
		[BLUE_BALLED],
		null,
		(_, __, ___) -> {
			// As the void sets min and max clamps on the health that the health is constrained to,
			// consider a void death if the clamps add up to the health range (2.0), with some
			// small error value sprinkled in cause you can't trust floats.
			return (PlayState.instance.voidedHealth + 0.001 >= 2.0) ? 1 : 0;
		}
	));

	defaultAchievements.push(Achievement.makeCompact(
		"all_consuming",
		["All-Consuming"],
		["Beat the void week with the color brightness of all notes set to -100"],
		[WEEK_WON],
		null,
		(_, __, ___) -> {
			if (!isCriteriumFulfilled(WEEK_NAME(EQ, "void"))) {
				return 0;
			}
			// NOTE: Hardcode a key amount of 4 here. Maybe try removing this multi-key leftover
			// code altogether
			for (i in 0...4) {
				if (ClientPrefs.arrowHSV[3][i][2] > -100) {
					return 0;
				}
			}
			return 1;
		}
	));

	// Welp, none of that i guess.
	// defaultAchievements.push(new Achievement(
	// 	"amogus",
	// 	1,
	// 	[{name: "Amogus", desc: "Click every Crewmate in the stages"}],
	// 	[AMOGER_CLICKED],
	// 	null,
	// 	function (pad:PersistentAchievementData, _, id_:Dynamic):Int {
	// 		var id = cast(id_, Int);
	// 		if (id < 0 || id >= AMOGER_COUNT) {
	// 			return 0;
	// 		}

	// 		var amogersLeft = pad.sub(1).getInt();
	// 		var amogerSlot = pad.sub(0).sub(id);
	// 		if (!amogerSlot.getBool()) {
	// 			amogerSlot.setBool(true);
	// 			amogersLeft -= 1;
	// 		}
	// 		return pad.sub(1).setInt(amogersLeft) == 0 ? 1 : 0;
	// 	},
	// 	{
	// 		shape: TUPLE(2, [ARRAY(AMOGER_COUNT, BOOL), INT]),
	// 		defaultProviderFunc: () -> {
	// 			var r:Array<Dynamic>;
	// 			r = [[for (_ in 0...AMOGER_COUNT) false], 32];
	// 			return r;
	// 		},
	// 		verifierFunc: (pad:PersistentAchievementData) -> {
	// 			var x = pad.sub(1).getInt();
	// 			return x >= 0 && x <= 32;
	// 		},
	// 	}
	// ));

	defaultAchievements.push(Achievement.makeCompact(
		"look_ma_one_hand",
		["Single-handed Smackdown"],
		["Beat the Void Week using only WASD or only the Arrow Keys"],
		[WEEK_WON],
		null,
		(_, __, ___) -> {
			var pressedKeys:Array<FlxKey> = [for (k in PlayState.pressedKeysThisStoryRun.keys()) k];
			for (allowed in SHS_MAPS) {
				var mapValid = true;
				for (key in pressedKeys) {
					if (!allowed.exists(key)) {
						mapValid = false;
						break;
					}
				}
				if (mapValid) {
					return 1;
				}
			}
			return 0;
		}
	));

	defaultAchievements.push(Achievement.makeCompact(
		"completionist",
		["A Place in Our Hearts"],
		["Unlock every (standard) achievement", "Unlock every (standard) achievement on its highest tier"],
		[ACHIEVEMENTS_ADVANCED],
		null,
		(_, __, ___) -> {
			var platinum:Bool = true;
			var gold:Bool = true;
			var e = AchievementManager.getAchievements([
				"week1", "swarm", "consume", "enough", "malder", "bubbo", "boundary", "freeplay_complete", "voided", "all_consuming", "look_ma_one_hand"
			]);
			for (entry in e) {
				if (!entry.isUnlocked()) {
					platinum = false;
				}
				if (entry.isLocked()) {
					gold = false;
				}
			}
			return platinum ? 2 : (gold ? 1 : 0);
		}
	));

	defaultAchievements = defaultAchievements.concat([
		// NOTE: These achievements do not trigger on any events and need to be explicitly advanced
		// due to their unique and localized unlock situation
		Achievement.makeCompact(
			"reddit_mod", ["Reddit Mod"], ["Press 7 or 8"], [], AchievementElement.ALL
		),
		// Achievement.makeCompact(
		// 	"tbd", ["Insert"], ["Find Someone"], [], AchievementElement.ALL
		// ),
		Achievement.makeCompact(
			"special_load", ["Evil Master Plan"], ["See the rare loading screen"], [], AchievementElement.ALL
		),
		Achievement.makeCompact(
			"yippee", ["Yippee!!"], ["Click on the 'Yippee' creature in the Consume background"], [], AchievementElement.ALL
		),
		new Achievement(
			"l_statue", 1, [{name: "[GREEN] Prizes", desc: "Get the Secret Plaque in the Swarm background\n[FREEPLAY ONLY]", sound: "luj"}], [], AchievementElement.ALL
		),
		// ===== //
		new Achievement(
			"friday_night_play",
			1,
			[{name: "Freaky on a Friday Night", desc: "Play on a Friday... Night", sound: "confirmMenu"}],
			[GAME_STARTED],
			AchievementElement.ALL,
			function (_, __, ___) {
				var curDate = Date.now();
				return (curDate.getDay() == 5 && curDate.getHours() >= 18) ? 1 : 0;
			}
		),
		new Achievement(
			"replayer",
			1,
			[{name: "Replayer", desc: "Boot up the mod a few times", sound: "confirmMenu"}],
			[GAME_STARTED],
			AchievementElement.DESC | AchievementElement.ICON,
			function (data:PersistentAchievementData, _, __) {
				return data.setInt(data.getInt() + 1) > 3 ? 1 : 0;
			},
			{shape: INT}
		),
		new KonamiCodeAchievement("konami_code", "Nice try", "But this is all you get"),
	]);

	return defaultAchievements;
}


/**
 * Global static achievement manager class.
 * Takes control of `FlxG.save.data.unlockedAchievements` and `FlxG.save.data.persistentAchievementData`.
 */
class AchievementManager {
	private static var eventToPendingAchievementsMap:Map<AchievementEvent, Array<Achievement>>;
	private static var achievementRegistry:Map<String, AchievementRegistryEntry>;
	private static var registryLength = 0; // Cause apparently keeping track of a map's length is too much to ask for
	private static var isInitialized = false;

	/**
	 * Same object as `FlxG.save.data.unlockedAchievements` for shorter typing.
	 * Admittedly, this makes it very easy to oversee and break.
	 */
	private static var unlockedAchievements:Map<String, Int>;

	/**
	 * Array of unshown achievements. They will simply added here by the AchievementManager when
	 * unlocked. This is expected to be controlled by scenes that want to then display achievements.
	 */
	public static var unshownAchievements:Array<Achievement>;

	/**
	 * Initializes the AchievementManager, making it read achievements from the save data
	 * and allowing most other functions to work.
	 * It's probably a good idea to call `removeUnknownAchievements` soon after.
	 */
	public static function initialize():Void {
		if (isInitialized) {
			return;
		}

		unshownAchievements = [];

		// Also runs when it's null
		if (!Std.isOfType(FlxG.save.data.unlockedAchievements, StringMap)) {
			FlxG.log.notice("Creating unlockedAchievements map in save data");
			FlxG.save.data.unlockedAchievements = new Map<String, Int>();
		}
		unlockedAchievements = FlxG.save.data.unlockedAchievements;

		// Also also runs when it's null
		if (!Std.isOfType(FlxG.save.data.persistentAchievementData, StringMap)) {
			FlxG.log.notice("Creating persistentAchievementData map in save data");
			FlxG.save.data.persistentAchievementData = new Map<String, Dynamic>();
		}

		// Initialize ze event callback arrays
		eventToPendingAchievementsMap = new Map();
		for (e in AchievementEvent.getConstructors()) {
			eventToPendingAchievementsMap[AchievementEvent.createByName(e)] = [];
		}

		// Setup achievement registry
		achievementRegistry = new Map();
		for (a in getDefaultAchievements()) {
			registerAchievement(a);
		}

		isInitialized = true;
	}

	private static function getPersistentData(achievement:Achievement):Null<PersistentAchievementData> {
		var info = achievement.persistenceInfo;
		if (info == null) {
			return null;
		}

		var padMap = cast(FlxG.save.data.persistentAchievementData, Map<String, Dynamic>);
		if (!padMap.exists(achievement.id)) {
			FlxG.log.notice('No existing PersistentAchievementData found for ${achievement.id}, creating default.');
			padMap[achievement.id] = PersistentAchievementData.makeDefault(info.shape);
		}

		var data:PersistentAchievementData = null;
		var originalCreationFailed:Bool = false;
		try {
			data = new PersistentAchievementData(null, new _MapInterfacer(padMap, achievement.id), info.shape);
		} catch (e) {
			FlxG.log.warn('Failed creating PersistentAchievementData from existing data for ${achievement.id}: $e');
			originalCreationFailed = true;
		}

		// NOTE: I guess in theory, the verifier may throw an exception.
		// In practice, this code is stupid and no one will use it or care, so whatever.
		var verificationFailed = originalCreationFailed || (info.verifierFunc != null && !info.verifierFunc(data));
		if (!verificationFailed) {
			return data;
		}

		FlxG.log.warn('Verification failure on existing persistent data for achievement ${achievement.id}');
		try {
			if (info.defaultProviderFunc != null) {
				padMap[achievement.id] = info.defaultProviderFunc();
			} else {
				padMap[achievement.id] = PersistentAchievementData.makeDefault(info.shape);
			}
			data = new PersistentAchievementData(null, new _MapInterfacer(padMap, achievement.id), info.shape);
		} catch (e) {
			trace(
				'Failed creating PersistentAchievementData from default for ${achievement.id}: $e'
			);
			throw e;
		}

		verificationFailed = (info.verifierFunc != null && !info.verifierFunc(data));
		if (verificationFailed) {
			trace('Verification failure on default achievement data.');
			throw new ValueException("Verification failure on default achievement data");
		}

		return data;
	}

	/**
	 * Registers an achievement, causing it to be checked for on any calls to `notify` with an
	 * event contained in the achievement's `checkOnEvents`.
	 * If an id with this name already exists in `unlockedAchievements`, will not check for it.
	 * If an achievement with the given one's id already existed, returns false and does not add it.
	 */
	public static function registerAchievement(achievement:Achievement):Bool {
		if (achievementRegistry.exists(achievement.id)) {
			FlxG.log.warn('Achievement with id "${achievement.id}" already registered.');
			return false;
		}

		var prog = unlockedAchievements.exists(achievement.id) ? unlockedAchievements[achievement.id] : 0;
		if (prog < 0 || prog > achievement.layerCount) {
			FlxG.log.warn('Stored unlock progress for ${achievement.id} is out of bounds, setting to 0');
			prog = 0;
		}
		achievementRegistry.set(
			achievement.id,
			new AchievementRegistryEntry(achievement, registryLength++, prog, getPersistentData(achievement))
		);
		registryLength += 1;

		if (achievementRegistry[achievement.id].unlockProgress == achievement.layerCount) {
			return true;
		}

		for (event in achievement.checkOnEvents) {
			eventToPendingAchievementsMap[event].push(achievement);
		}
		return true;
	}

	/**
	 * Removes achievements from the AchievementManager's registry.
	 * Does not remove them from the save data.
	 * Non-existent achievement ids are silently ignored.
	 * I don't really know why you'd ever need to call this method directly.
	 */
	public static function unregisterAchievements(achievementIds:Array<String>) {
		if (!isInitialized) {
			return;
		}

		var removedIndices:Array<Int> = [];
		for (idx in 0...achievementIds.length) {
			var id = achievementIds[idx];
			if (!achievementRegistry.exists(id)) {
				continue;
			}
			removedIndices.push(achievementRegistry[id].index);
			achievementRegistry.remove(id);
		}

		// Remove gaps in indices
		for (entry in achievementRegistry) {
			var shiftdown = 0;
			for (idx in removedIndices) {
				if (entry.index > idx) {
					shiftdown += 1;
				}
			}
			entry.index -= shiftdown;
		}
		registryLength -= removedIndices.length;
	}

	/**
	 * Removes unknown achievement ids from the unlocked achievements, that is: all achievement ids
	 * that haven't yet been introduced via `registerAchievement`.
	 */
	public static function removeUnknownAchievements() {
		if (!isInitialized) {
			return;
		}

		var newUnlockedAchievements:Map<String, Int> = [];
		for (id in unlockedAchievements.keys()) {
			if (!achievementRegistry.exists(id)) {
				FlxG.log.warn('Found unknown achievement id "$id" in save data, dropping.');
				(cast (FlxG.save.data.persistentAchievementData, Map<String, Dynamic>)).remove(id);
			} else {
				if (unlockedAchievements.exists(id)) {
					newUnlockedAchievements.set(id, unlockedAchievements[id]);
				}
			}
		}
		FlxG.save.data.unlockedAchievements = unlockedAchievements = newUnlockedAchievements;
	}


	/**
	 * Re-locks any known unlocked achievements. Unknown achievement ids will be left unlocked.
	 */
	public static function resetAchievements() {
		if (!isInitialized) {
			return;
		}

		// Use getAchievements to preserve order.
		for (entry in getAchievements()) {
			// Re-add the achievements to their event listener lists
			if (entry.isUnlocked()) {
				for (event in entry.achievement.checkOnEvents) {
					eventToPendingAchievementsMap[event].push(entry.achievement);
				}
			}
			// Lock it
			entry.unlockProgress = 0;
			// Reset persistent savedata
			if (entry.saveData != null) {
				entry.saveData.reset();
			}
		}
		// Reset unlocked achievements
		FlxG.save.data.unlockedAchievements = unlockedAchievements =
			[for (id => prog in unlockedAchievements) if (!achievementRegistry.exists(id)) id => prog];
	}

	/**
	 * Notifies the AchievementManager of an event, which causes it to query all associated
	 * achievements that have not been earned yet whether they now are.
	 * Adds all newly unlocked achievements to `unshownAchievements`.
	 * If really needed, you can pass a `supplement` value which can be just about anything.
	 * This value is passed through to each achievement's `checkUnlockProgress` function.
	 * Be sure they are gonna handle it properly.
	 */
	 public static function notify(event:AchievementEvent, ?supplement:Dynamic) {
		if (!isInitialized) {
			return;
		}

		// Check all achievements that may have been earned
		// var locallyAdvancedAchievements:Array<Achievement> = [];
		// if (eventToPendingAchievementsMap[event].length > 0) {
		// 	trace('Notifying: ${[for (a in eventToPendingAchievementsMap[event]) a.id]} for ${event.getName()}');
		// }

		var hadAdvances:Bool = false;
		// Iterate over copy since advanceAchievement modifies these arrays
		for (achievement in eventToPendingAchievementsMap[event].copy()) {
			if (advanceAchievement(
				achievement.id,
				achievement.checkUnlockProgress(achievementRegistry[achievement.id].saveData, event, supplement),
				true
			)) {
				// locallyAdvancedAchievements.push(achievement);
				hadAdvances = true;
			}
		}

		// This feels like uncontrolled recursion, even though it only happens for unlocked
		// achievements, and they literally have to stop at some point. It's fiiiiine
		if (hadAdvances) {
			notify(ACHIEVEMENTS_ADVANCED);
		}
	}

	/**
	 * Notifies a specific achievement of an event. Should be used cautiosly, as a bad supplement
	 * value is able to cause an exception or crash.
	 */
	public static function notifyAchievement(achievementId:String, event:AchievementEvent, ?supplement:Dynamic) {
		if (!isInitialized || !achievementRegistry.exists(achievementId)) {
			return;
		}

		var entry = achievementRegistry[achievementId];
		advanceAchievement(
			achievementId,
			entry.achievement.checkUnlockProgress(entry.saveData, event, supplement)
		);
	}

	/**
	 * Forcibly advance an achievement given by its id to the new progress.
	 * Adds it to `unshownAchievements` in the same way as `notify`.
	 * This will have no effect if the achievement does not exist or `newProgress` is <=
	 * the achievements current unlock progress.
	 * If the `preventAdvanceEvent` option is not set to false and the advance succeeds,
	 * the achievement manager will be notified with `ACHIEVEMENTS_ADVANCED` before this
	 * method returns.
	 * This will throw a ValueException if the new progress surpasses the achievement's
	 * layer count.
	 * Returns whether the achievement was advanced and added to `unshownAchievements`.
	 */
	public static function advanceAchievement(achievementId:String, newProgress:Int, preventAdvanceEvent:Bool = false):Bool {
		if (!isInitialized || !achievementRegistry.exists(achievementId)) {
			return false;
		}

		var entry = achievementRegistry[achievementId];
		if (newProgress <= entry.unlockProgress) {
			return false;
		}

		if (newProgress > entry.achievement.layerCount) {
			throw new ValueException("Achievement advanced past its layer count");
		} else if (newProgress == entry.achievement.layerCount) {
			// Fully unlocked, don't notify it of events anymore.
			for (event in entry.achievement.checkOnEvents) {
				eventToPendingAchievementsMap[event].remove(entry.achievement);
			}
		}
		unlockedAchievements[achievementId] = newProgress;
		entry.unlockProgress = newProgress;

		FlxG.log.notice('Advanced $achievementId to $newProgress');
		unshownAchievements.push(entry.achievement);
		if (!preventAdvanceEvent) {
			notify(ACHIEVEMENTS_ADVANCED);
		}

		return true;
	}

	/**
	 * Returns an array of achievement registry entries, sorted by index for your convenience.
	 * Do not modify these or suffer the consequences.
	 * If custom ids are supplied, unknown ones are skipped.
	 */
	public static function getAchievements(?ids:Null<Array<String>>):Array<AchievementRegistryEntry> {
		if (!isInitialized) {
			return [];
		}

		var arr:Array<AchievementRegistryEntry>;
		if (ids == null) {
			arr = [for (are in achievementRegistry) are];
		} else {
			arr = [for (id in ids) if (achievementRegistry.exists(id)) achievementRegistry[id]];
		}

		arr.sort((a, b) -> a.index - b.index);
		return arr;
	}
}
