/**
 * Homegrown system for the specification and layout of text and images with a
 * mild variety of styling options.
 **/

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import haxe.ValueException;

import CoolUtil.PointStruct;
import ChainEffects;
import TextHelper.TextMeasurerCache;
import TextHelper.splitTextAndWordIntoLines;

using StringTools;


// Hallowed be thy name.
private final STANDARD_FONT:String = "VCR OSD Mono";
private final STANDARD_FONT_SIZE:Int = 28;

typedef QuoteLocation = Int;

enum QuoteEffectId {CHAIN_EFFECTS; RANDOM_QUOTE_ARG_UPDATE; HEARTBEAT; TWEEN; FLICKER; TYPEOUT;}

abstract class QuoteEffectUpdater {
	private var objs:Array<FlxSprite>;

	public function new(objs:Array<FlxSprite>) {
		this.objs = objs;
	}

	public abstract function update(dt:Float):Void;
}

abstract class QuoteEffect {
	public abstract function getId():QuoteEffectId;

	public function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> { return []; }

	/**
	 * Alters the properties of a quote. If you change it, it should be copied beforehand.
	 * It is also a bad idea to modify the effects as they are typically being iterated over
	 * while this method is called.
	 */
	public function alterQuote(in_:Quote):Quote { return in_; }
}


class ChainEffectsQuoteEffectUpdater extends QuoteEffectUpdater {
	private var shader:RuntimeShader;

	public function new(objs:Array<FlxSprite>, shader:RuntimeShader) {
		super(objs);
		this.shader = shader;
	}

	public function update(dt:Float) {
		shader.data.time.value[0] += dt;
	}
}
class ChainEffectsQuoteEffect extends QuoteEffect {
	var effects:Array<ChainEffect>;
	var shaderSource:Null<String>;
	private var isTimeShader:Bool;

	public function new(effects:Array<ChainEffect>) {
		this.effects = effects;
		this.shaderSource = null;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.CHAIN_EFFECTS; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		// Using the same shader for multiple sprites did not work out as the TextureSize
		// uniforms were bad. This creates possibly dozens of shaders per credits screen but oh well
		if (shaderSource == null) {
			shaderSource = ChainEffectShaderGenerator.buildFragmentSource(effects, true);
		}
		var updaters:Array<QuoteEffectUpdater> = [];
		for (spr in sprites) {
			var shader = new RuntimeShader(shaderSource);
			ChainEffectShaderGenerator.setNonHardcodableUniforms(shader, effects);
			if (Reflect.hasField(shader.data, "time")) {
				shader.data.time.value = [0.0];
				updaters.push(new ChainEffectsQuoteEffectUpdater(null, shader));
			}
			spr.shader = shader;
		}
		return updaters;
	}
}

typedef HeartbeatQuoteEffectOptions = {intensity:Float, beatTime:Float}
/**
 * Formula stolen from u/lucasvb in this thread:
 * https://www.reddit.com/r/Physics/comments/30royq/whats_the_equation_of_a_human_heart_beat/
 */
private function heartbeatEase(x:Float):Float {
	return (
		0.1*(Math.exp(-Math.pow(x+0.5, 2) / (2*0.06)) + Math.exp(-Math.pow(x-0.5, 2) / (2*0.06))) +
		(1.0 - Math.abs(x / 0.15) - x) * Math.exp(-Math.pow(7*x, 2) / 2)
	);
}
class HeartbeatQuoteEffect extends QuoteEffect {
	var options:HeartbeatQuoteEffectOptions;

	public function new(?options:Null<HeartbeatQuoteEffectOptions>) {
		this.options = options == null ? {intensity: 1.15, beatTime: 0.4} : options;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.HEARTBEAT; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		for (spr in sprites) {
			FlxTween.tween(
				spr,
				{"scale.x": options.intensity, "scale.y": options.intensity},
				options.beatTime,
				{ease: heartbeatEase, type: LOOPING}
			);
		}
		return [];
	}
}

class RandomQuoteArgUpdateQuoteEffect extends QuoteEffect {
	var choices:Array<QuoteArgs>;

	public function new(?choices:Null<Array<QuoteArgs>>) {
		this.choices = choices ?? [{}];
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.RANDOM_QUOTE_ARG_UPDATE; }
	public override function alterQuote(in_:Quote):Quote {
		var args = in_.getQuoteArgs();
		var choice = CoolUtil.randomChoice(choices);
		for (f in Reflect.fields(choice)) {
			Reflect.setField(args, f, Reflect.field(choice, f));
		}
		return new Quote(args);
	}
}

typedef TweenQuoteEffectOptions = {values:Dynamic, ?duration:Float, ?ease:EaseFunction, ?type:FlxTweenType}
class TweenQuoteEffect extends QuoteEffect {
	var values:Dynamic;
	var duration:Float;
	var ease:EaseFunction;
	var type:FlxTweenType;

	public function new(options:TweenQuoteEffectOptions) {
		this.values = options.values;
		this.duration = options.duration == null ? 1.0 : options.duration;
		this.ease = options.ease == null ? FlxEase.linear : options.ease;
		this.type = options.type == null ? FlxTweenType.ONESHOT : options.type;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.TWEEN; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		for (spr in sprites) {
			FlxTween.tween(spr, values, duration, {ease: ease, type: type});
		}
		return [];
	}
}

enum FlickerQuoteEffectUpdaterState {HIDDEN; FLICKER_IN; SHOWN; FLICKER_OUT;}
typedef RandomizableTime = {?standard:Float, ?randomOffset:{a:Float, b:Float}}
typedef FlickerQuoteEffectOptions = {
	var ?initialStates:Null<{c:Array<FlickerQuoteEffectUpdaterState>, ?w:Array<Float>}>;
	var ?initialTime:Null<RandomizableTime>;
	var ?limit:Null<Int>; // This is a pretty crappy field honestly but whatever. Works for its single use.
	var ?hideTime:Null<RandomizableTime>;
	var ?showTime:Null<RandomizableTime>;
	var ?transitionTime:Null<RandomizableTime>;
}
class FlickerQuoteEffectUpdater extends QuoteEffectUpdater {
	private var state:FlickerQuoteEffectUpdaterState;
	private var currentStateTime:Float;
	private var currentStatePassedTime:Float;
	private var limit:Int;
	private var hideTime:RandomizableTime;
	private var showTime:RandomizableTime;
	private var transitionTime:RandomizableTime;

	public function new(objs:Array<FlxSprite>, options:FlickerQuoteEffectOptions) {
		super(objs);

		this.limit = options.limit;
		this.hideTime = options.hideTime;
		this.showTime = options.showTime;
		this.transitionTime = options.transitionTime;

		state = FlxG.random.getObject(options.initialStates.c, options.initialStates.w);
		var starterStateTime = options.initialTime.standard != null ?
			options.initialTime.standard :
			getStateTime(state);
		var starterOffset = options.initialTime.randomOffset != null ?
			FlxG.random.float(options.initialTime.randomOffset.a, options.initialTime.randomOffset.b) :
			0.0;
		currentStateTime = starterStateTime + starterOffset;
		currentStatePassedTime = 0.0;

		update(0.0);
	}

	private inline function getNextState(s:FlickerQuoteEffectUpdaterState):FlickerQuoteEffectUpdaterState {
		return switch (state) {
			case HIDDEN: FLICKER_IN; case FLICKER_IN: SHOWN; case SHOWN: FLICKER_OUT; case FLICKER_OUT: HIDDEN;
		}
	}

	private inline function getStateTime(s:FlickerQuoteEffectUpdaterState):Float {
		var struct = switch (state) { case HIDDEN: hideTime; case SHOWN: showTime; case _: transitionTime; }
		return struct.standard + (
			struct.randomOffset != null ? FlxG.random.float(struct.randomOffset.a, struct.randomOffset.b) : 0.0
		);
	}

	public function update(dt:Float) {
		if (limit == 0) {
			return;
		}

		currentStatePassedTime += dt;
		while (currentStatePassedTime > currentStateTime && (limit == -1 || limit > 0)) {
			currentStatePassedTime -= currentStateTime;
			state = getNextState(state);
			currentStateTime = Math.max(0.001, getStateTime(state));
			if (limit > 0) {
				limit -= 1;
			}
		}
		var x:Float = currentStatePassedTime / currentStateTime;
		var visible = switch (state) {
			case HIDDEN: false;
			case SHOWN: true;
			case FLICKER_IN:  (Math.sin(x * 20) + 4*Math.pow(x, 3) + Math.sin(x * 120)) > 1.0;
			case FLICKER_OUT: (Math.sin(x * 20) + 4*Math.pow(x, 3) + Math.sin(x * 120)) <= 1.0;
		}
		for (text in objs) {
			text.visible = visible;
		}
	}
}
class FlickerQuoteEffect extends QuoteEffect {
	private var options:FlickerQuoteEffectOptions;

	final public function getId():QuoteEffectId { return QuoteEffectId.FLICKER; }

	public function new(?options:Null<FlickerQuoteEffectOptions>) {
		if (options == null)                          options = {};
		if (options.initialStates == null)            options.initialStates = {c: [HIDDEN]};
		if (options.limit == null)                    options.limit = -1;
		if (options.initialTime == null)              options.initialTime = {};
		if (options.hideTime == null)                 options.hideTime = {};
		if (options.hideTime.standard == null)        options.hideTime.standard = 2.0;
		if (options.showTime == null)                 options.showTime = {};
		if (options.showTime.standard == null)        options.showTime.standard = 2.0;
		if (options.transitionTime == null)           options.transitionTime = {};
		if (options.transitionTime.standard == null)  options.transitionTime.standard = 0.5;
		this.options = options;
	}

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		return [new FlickerQuoteEffectUpdater(sprites, options)];
	}
}

// @Square789: NOTE: This command was finalized in the last hours of the mod, and has barely been tested.
// It is probably very buggy, and notably subsequent overype typeout commands always fallback to the initial text.
// It has not been made json-parsable.
// Works in the two spots it appears in though B)
typedef TypeoutQuoteEffectCommand = {
	command:String,
	?text:Null<String>,     // for "typeout"
	?count:Null<Int>,
	?speed:Null<Float>,
	?overtype:Null<Bool>,
	?time:Null<Float>,      // for "wait"
	?whence:Null<Int>,      // for "set_cursor"
	?relative:Null<Bool>,
}
typedef TypeoutQuoteEffectOptions = {
	?startTypedOut:Null<Bool>,
	?loopCommands:Null<Bool>,
	?commands:Null<Array<TypeoutQuoteEffectCommand>>,
}
typedef TypeoutQuoteEffectUpdaterOriginalTextInfo = {originalText:String, objIdx:Int};
typedef TypeoutQuoteEffectUpdaterSection = {objIdx:Int, startIndex:Int, endIndex:Int, text:String, priorText:Null<String>, unaffectedTextPre:String, unaffectedTextPost:String, cursorSpeed:Float}
class TypeoutQuoteEffectUpdater extends QuoteEffectUpdater {
	private var originalTextInfo:Array<TypeoutQuoteEffectUpdaterOriginalTextInfo>;
	private var originalTextLength:Int;
	private var cursorPos:Float;
	private var currentSectionIdx:Int;
	private var sections:Array<TypeoutQuoteEffectUpdaterSection>;
	private var currentlyWaiting:Bool;
	private var commands:Array<TypeoutQuoteEffectCommand>;
	private var nextCommandIdx:Int;
	private var loopCommands:Bool;
	private var waitTimeRemaining:Float;

	public function new(objs:Array<FlxSprite>, options:TypeoutQuoteEffectOptions) {
		super(objs);

		this.currentlyWaiting = false;
		this.nextCommandIdx = 0;
		this.loopCommands = options.loopCommands;
		this.waitTimeRemaining = 0.0;

		this.originalTextInfo = [];
		this.originalTextLength = 0;
		for (i => o in objs) {
			if (Std.isOfType(o, FlxText)) {
				originalTextInfo.push({originalText: cast(o, FlxText).text, objIdx: i});
				originalTextLength += cast(o, FlxText).text.length;
			}
		}

		this.cursorPos = 0.0;
		commands = options.commands;
		prepareForNextCommand();

		if (!options.startTypedOut) {
			for (o in objs) {
				if (Std.isOfType(o, FlxText)) {
					cast(o, FlxText).text = "";
				}
			}
		}
	}

	public function update(dt:Float) {
		var stopFlag = false;
		while (!stopFlag) {
			if (nextCommandIdx == -1) {
				return;
			}

			if (currentlyWaiting) {
				waitTimeRemaining -= dt;
				if (waitTimeRemaining <= 0.0) {
					dt = -waitTimeRemaining;
					prepareForNextCommand();
				} else {
					stopFlag = true;
				}
			} else {
				var budget = dt;
				while (budget > 0.0) {
					var currentSection = sections[currentSectionIdx];
					var reach = budget * currentSection.cursorSpeed;
					if (cursorPos + reach > currentSection.endIndex) {
						var diff = currentSection.endIndex - cursorPos;
						cast(objs[currentSection.objIdx], FlxText).text = currentSection.unaffectedTextPre + currentSection.text + currentSection.unaffectedTextPost;
						budget -= diff / currentSection.cursorSpeed;
						cursorPos = currentSection.endIndex;
						if (currentSectionIdx >= sections.length - 1) {
							prepareForNextCommand();
							dt = budget;
							budget = 0.0;
						} else {
							currentSectionIdx += 1;
						}
					} else {
						budget = 0.0;
						cursorPos += reach;

						var newTextPartLen = Std.int(cursorPos) - currentSection.startIndex;
						var rpart = currentSection.priorText == null ?
							currentSection.text.substr(0, newTextPartLen) :
							currentSection.text.substr(0, newTextPartLen) + currentSection.priorText.substr(newTextPartLen)
						;
						cast(objs[currentSection.objIdx], FlxText).text = currentSection.unaffectedTextPre + rpart + currentSection.unaffectedTextPost;

						stopFlag = true;
					}
				}
			}
		}
	}

	private function halt() {
		nextCommandIdx = -1;
	}

	private function prepareForNextCommand() {
		if (commands.length == 0) {
			halt();
			return;
		}

		if (nextCommandIdx >= commands.length) {
			if (loopCommands) {
				nextCommandIdx = 0;
			} else {
				halt();
				return;
			}
		}

		
		var ncmd = commands[nextCommandIdx];
		if (ncmd.command == "typeout") {
			currentlyWaiting = false;
			cursorPos = Math.ffloor(cursorPos);
			prepareSections(ncmd.text, ncmd.count, ncmd.speed, ncmd.overtype ?? true);
		} else if (ncmd.command == "wait") {
			currentlyWaiting = true;
			waitTimeRemaining = Math.max(0.0, ncmd.time);
		} else if (ncmd.command == "set_cursor") {
			if (ncmd.relative) {
				cursorPos = CoolUtil.boundInt(Std.int(cursorPos) + ncmd.whence, 0, 99999999);
			} else {
				cursorPos = CoolUtil.boundInt(ncmd.whence, 0, 999999999);
			}
		} else {
			FlxG.log.warn("TypeoutQuoteEffectUpdate encountered unknown command!");
			halt();
			return;
		}
		nextCommandIdx += 1;
	}

	private function prepareSections(text:Null<String>, count:Null<Int>, speed:Null<Float>, usePriorText:Bool) {
		currentSectionIdx = 0;
		sections = [];

		// @Square789: none of this is tested lol
		var gReplacementStart = Std.int(cursorPos);
		var gReplacementEnd;
		if (text == null) {
			if (count == null) {
				gReplacementEnd = originalTextLength;
			} else {
				gReplacementEnd = FlxMath.minInt(originalTextLength, gReplacementStart + FlxMath.maxInt(count, 0));
			}
		} else {
			if (count == null) {
				gReplacementEnd = FlxMath.minInt(originalTextLength, gReplacementStart + text.length);
			} else {
				gReplacementEnd = FlxMath.minInt(originalTextLength, gReplacementStart + FlxMath.minInt(FlxMath.maxInt(count, 0), text.length));
			}
		}

		var tidx = 0;
		for (ti in originalTextInfo) {
			var tidxEnd = tidx + ti.originalText.length;
			// push a section if this text is in range of the replacement part
			if (tidxEnd > gReplacementStart && tidx < gReplacementEnd) {
				var sectionStartIndex = FlxMath.maxInt(gReplacementStart, tidx);
				var sectionEndIndex = FlxMath.minInt(tidxEnd, gReplacementEnd);
				var tPre = ti.originalText.substr(0, sectionStartIndex - tidx);
				var tPost = ti.originalText.substr(sectionEndIndex - tidx);

				var tTrue;
				if (text == null) {
					tTrue = ti.originalText.substring(sectionStartIndex - tidx, sectionEndIndex - tidx);
				} else {
					tTrue = text.substr(sectionStartIndex - gReplacementStart, sectionEndIndex - sectionStartIndex);
				}

				sections.push({
					objIdx: ti.objIdx,
					startIndex: sectionStartIndex,
					endIndex: sectionEndIndex,
					text: tTrue,
					priorText: usePriorText ? ti.originalText.substring(sectionStartIndex - tidx, sectionEndIndex - tidx) : null,
					unaffectedTextPre: tPre,
					unaffectedTextPost: tPost,
					cursorSpeed: speed ?? 16.0,
				});
				// trace('new sec ${sections[sections.length - 1]}');
			}
			tidx = tidxEnd;
		}

	}
}
class TypeoutQuoteEffect extends QuoteEffect {
	private var options:TypeoutQuoteEffectOptions;

	final public function getId():QuoteEffectId { return QuoteEffectId.TYPEOUT; }

	public function new(?options:Null<TypeoutQuoteEffectOptions>) {
		if (options == null)               options = {};
		if (options.commands == null)      options.commands = [{command: "typeout", time: 2.0, overtype: false}];
		if (options.startTypedOut == null) options.startTypedOut = false;
		if (options.loopCommands == null)  options.loopCommands = false;
		this.options = options;
	}

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		return [new TypeoutQuoteEffectUpdater(sprites, options)];
	}
}


class QuoteSlot {
	private var initialPosition:PointStruct;
	private var currentQuoteControlParameters:Array<String>;
	private var currentQuoteOffset:PointStruct;
	private var currentQuoteStartPosition:PointStruct;
	private var currentQuoteIgnoreOffsetX:Bool;
	private var currentQuoteIgnoreOffsetY:Bool;
	public var currentPosition:PointStruct;

	public function new() {
		initialPosition = {x: 0.0, y: 0.0};
		currentQuoteControlParameters = [];
		currentQuoteOffset = {x: 0.0, y: 0.0};
		currentQuoteStartPosition = {x: -1.0, y: -1.0};
		currentQuoteIgnoreOffsetX = false;
		currentQuoteIgnoreOffsetY = false;
		currentPosition = {x: 0.0, y: 0.0};
	}

	public function setInitial(x:Float, y:Float) {
		initialPosition.x = currentPosition.x = x;
		initialPosition.y = currentPosition.y = y;
	}

	/**
	 * Set the control parameters and offset given by the current quote.
	 * This function will also be called with both parameters set to null once a
	 * quote's sprites have all been laid out.
	 */
	public function setControlParameters(parameters:Null<Array<String>>, offset:Null<PointStruct>) {
		if (parameters == null) {
			offset = null; // Just to be sure. But there's only one call site, this doesn't matter.
			onQuotePlacementDone();
		}
		currentQuoteControlParameters = parameters ?? [];
		currentQuoteOffset = offset == null ? {x: 0.0, y: 0.0} : {x: offset.x, y: offset.y};
		currentQuoteStartPosition = {x: currentPosition.x, y: currentPosition.y};
		currentQuoteIgnoreOffsetX = currentQuoteControlParameters.contains("IGNORE_OFFSET_X");
		currentQuoteIgnoreOffsetY = currentQuoteControlParameters.contains("IGNORE_OFFSET_Y");
		if (parameters != null) {
			onQuotePlacementBegin();
		}
	}

	/**
	 * An ugly means to an end. If the slot is already including the offset in its layout, and
	 * thus in `currentPosition`, the code performing the sprite placement will need
	 * to know not add the offset, or it'll be added twice.
	 * This function should either return 1.0 or 0.0 and is the vehicle for that information.
	 * For implementers: Override this function and `getOffsetMultiplierY` with logic consistent
	 * with a custom `advanceByCurrentOffset` entry.
	 */
	public function getOffsetMultiplierX():Float {
		return 1.0;
	}

	/**
	 * See `getOffsetMultiplierX`.
	 */
	public function getOffsetMultiplierY():Float {
		return currentQuoteIgnoreOffsetY ? 1.0 : 0.0;
	}

	/**
	 * Called by `setControlParameters` once the layout of a quote begins.
	 * By default, multiplies the corresponding values of `currentQuoteOffset` by 0 if `IGNORE_OFFSET_X`
	 * is present in the current slot control parameters.
	 * Then, calls into `advanceByCurrentOffset`.
	 */
	function onQuotePlacementBegin() {
		if (currentQuoteIgnoreOffsetX) {
			currentQuoteOffset.x *= 0.0;
		}
		if (currentQuoteIgnoreOffsetY) {
			currentQuoteOffset.y *= 0.0;
		}
		advanceByCurrentOffset();
	}

	/**
	 * Called by `setControlParameters` once a quote has been laid out completely.
	 * May be overridden to introduce effects that are supposed to happen after a quote's placement.
	 * Note that `currentQuoteControlParameters` and `currentQuoteOffset` are still available.
	 *
	 * By default, resets `currentPosition` to `currentQuoteStartPosition` if `IGNORE_ADVANCE` is present in
	 * the current slot control parameters.
	 */
	function onQuotePlacementDone() {
		if (currentQuoteControlParameters.contains("IGNORE_ADVANCE")) {
			currentPosition = currentQuoteStartPosition;
		}
	}

	/**
	 * Ask whether the given sprite fits into the quote slot.
	 * If this method returns false, currentPosition will have changed.
	 * In that case, retry with the new position.
	 * This method might in some cases cause problems. The overriding class should then just add a
	 * parameter to disable the behavior for some quotes (*cough* Lorebook's `NO_AUTO_PAGEBREAK` *cough*).
	 */
	public function tryFit(sprite:FlxSprite):Bool {
		return true;
	}

	/**
	 * Advance the slot, which can have multiple meanings depending on what kind of
	 * slot this is. Typically, this influences the next item's start position to be
	 * moved forward by `by` pixels.
	 * Returns whether to continue laying out items, typically `shouldContinue()`.
	 */
	public function advance(by:Float):Bool {
		currentPosition.y += by;
		currentPosition.x = initialPosition.x;
		return shouldContinue();
	}

	/**
	 * Similar to advance, but takes a sprite and gets the advance length information
	 * from it directly.
	 * This function should typically call into `advance` after getting the information
	 * from the sprite.
	 * On rare (and instable) occasions, this function may modify `sprite`.
	 */
	public function advanceBySprite(sprite:FlxSprite):Bool {
		return advance(sprite.height);
	}

	/**
	 * Cause a (typically single) initial advance based on the currently laid out quote's
	 * offset. This function should typically call into `advance` after getting the information
	 * from `currentQuoteOffset`.
	 */
	public function advanceByCurrentOffset() {
		advance(currentQuoteOffset.y);
	}

	/**
	 * Returns whether to continue laying out items.
	 * If false, the slot is basically full and cannot reasonably display any more items.
	 */
	public function shouldContinue():Bool {
		return currentPosition.y < FlxG.height;
	}
}


private class FreePositionSlot extends QuoteSlot {
	public override function advance(by:Float):Bool {
		return shouldContinue();
	}

	public override function shouldContinue() {
		return true;
	}
}


typedef QuoteImageInfo = {
	var name:String;
	var ?animated:Null<Bool>;
	var ?frameW:Null<Int>;
	var ?frameH:Null<Int>;
	var ?fps:Null<Float>;
	var ?scale:Null<Float>;
}
typedef CompleteImageInfo = {name:String, animated:Bool, frameW:Int, frameH:Int, fps:Float, scale:Float}

typedef QuoteArgs = {
	var ?text:Null<String>;
	var ?image:Null<QuoteImageInfo>;
	var ?textSize:Null<Int>;
	var ?bold:Null<Bool>;
	var ?font:Null<String>;
	var ?color:Null<FlxColor>;
	var ?effects:Null<Array<QuoteEffect>>;
	var ?linebreak:Null<Bool>;
	var ?postPadding:Null<Int>;
	var ?location:Null<QuoteLocation>;
	var ?slotControl:Null<Array<String>>;
	var ?offset:Null<PointStruct>;
	var ?widthOverride:Null<Float>;
}
class Quote {
	public var text(default, null):String;
	public var image(default, null):Null<CompleteImageInfo>;
	public var textSize(default, null):Int;
	public var bold(default, null):Bool;
	public var font(default, null):String;
	public var color(default, null):FlxColor;
	public var effects(default, null):Array<QuoteEffect>;
	public var linebreak(default, null):Bool;
	public var postPadding(default, null):Int;
	public var location(default, null):QuoteLocation;
	public var slotControl(default, null):Array<String>;
	public var offset(default, null):PointStruct;
	public var widthOverride(default, null):Null<Float>;

	public function new(args:QuoteArgs) {
		this.text =          args.text ?? "null";
		this.image =         args.image == null ? null : {
			name:     args.image.name,
			animated: args.image.animated ?? false,
			frameW:   args.image.frameW ?? 0,
			frameH:   args.image.frameH ?? 0,
			scale:    args.image.scale ?? 1.0,
			fps:      args.image.fps ?? 24.0,
		}

		this.textSize =      args.textSize ?? STANDARD_FONT_SIZE;
		this.bold =          args.bold ?? false;
		this.font =          args.font ?? STANDARD_FONT;
		this.color =         args.color ?? FlxColor.WHITE;
		this.effects = [];
		if (args.effects != null) {
			var seen:Map<QuoteEffectId, Bool> = [for (x in QuoteEffectId.createAll()) x => false];
			for (e in args.effects) {
				if (!seen[e.getId()]) {
					seen[e.getId()] = true;
					this.effects.push(e);
				}
			}
		}

		this.linebreak =     args.linebreak ?? true;
		this.postPadding =   args.postPadding ?? 16;
		this.location =      args.location ?? 0;
		this.slotControl =   args.slotControl ?? [];
		this.offset =        args.offset ?? {x: 0.0, y: 0.0};
		this.widthOverride = args.widthOverride == null ? null : Math.max(1.0, args.widthOverride);
	}

	public function getQuoteArgs():QuoteArgs {
		return {
			text: text, image: image, textSize: textSize, bold: bold,
			font: font, color: color, linebreak: linebreak, postPadding: postPadding, effects: effects,
			slotControl: slotControl, offset: offset, widthOverride: widthOverride
		};
	}

	public function applyEffectsTo(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		return [for (effect in effects) for (u in effect.apply(sprites)) u];
	}

	/**
	 * Returns a possibly altered quote, since there's effects that may just do it randomly.
	 */
	public function alterQuote() {
		var x = this;
		for (e in effects) {
			x = e.alterQuote(x);
		}
		return x;
	}
}

/**
 * Janky class to consolidate quote sprite creation logic into one place
 * Use it by accessing the quoteSlots map and setting their location, and then calling addSpritesFromQuote.
 */
class QuotePlacer {
	public var quoteSlots:Map<QuoteLocation, QuoteSlot>;
	private var fallbackQuoteSlot:FreePositionSlot;
	private var measurerCache:TextMeasurerCache;
	private var imagePathPrefix:String;

	public function new(measurerCache:TextMeasurerCache, ?quoteSlots:Null<Map<QuoteLocation, QuoteSlot>>, ?imagePathPrefix:Null<String>) {
		this.quoteSlots = quoteSlots ?? [];
		fallbackQuoteSlot = new FreePositionSlot();
		this.measurerCache = measurerCache;
		this.imagePathPrefix = imagePathPrefix ?? "";
	}

	// public function reset() {}

	public function addSpritesFromQuote(quote:Quote, target:FlxSpriteGroup, space:Float, lineLimit:Int):Array<QuoteEffectUpdater> {
		var qeus:Array<QuoteEffectUpdater> = [];

		var slot = quoteSlots[quote.location] ?? fallbackQuoteSlot;
		if (!slot.shouldContinue()) {
			return qeus;
		}

		quote = quote.alterQuote();

		var thisQuotesSprites:Array<FlxSprite> = [];

		slot.setControlParameters(quote.slotControl, quote.offset);
		var ox = quote.offset.x * slot.getOffsetMultiplierX();
		var oy = quote.offset.y * slot.getOffsetMultiplierY();

		if (quote.image != null) {
			var sprite = new FlxSprite(slot.currentPosition.x + ox, slot.currentPosition.y + oy);
			if (quote.image.animated) {
				sprite.loadGraphic(
					Paths.image('$imagePathPrefix${quote.image.name}'),
					true,
					quote.image.frameW,
					quote.image.frameH
				);
				sprite.animation.add("main", [for (i in 0...(sprite.frames.numFrames)) i], quote.image.fps, true);
				sprite.animation.play("main");
			} else {
				sprite.loadGraphic(Paths.image('$imagePathPrefix${quote.image.name}'));
			}
			if (quote.image.scale != 1.0) {
				sprite.scale.set(quote.image.scale, quote.image.scale);
				sprite.updateHitbox();
				sprite.origin.set(0.0, 0.0);
				sprite.offset.set(0.0, 0.0);
			}

			if (!slot.tryFit(sprite)) {
				// Could throw a loop in here, but don't bother retrying multiple times.
				// For the one instance this is used (lorebook), it won't matter
				sprite.setPosition(slot.currentPosition.x + ox, slot.currentPosition.y + oy);
			}
			if (slot.shouldContinue()) {
				slot.advanceBySprite(sprite);
				target.add(sprite);
				thisQuotesSprites.push(sprite);
			}
		} else {
			// Horrid text splitting and layout code follows
			var lines:Array<String>;
			if (!quote.linebreak) {
				lines = [quote.text.trim()];
			} else {
				lines = splitTextAndWordIntoLines(
					quote.text,
					quote.widthOverride ?? space,
					measurerCache.get(quote.font, quote.textSize, quote.bold),
					lineLimit
				);
			}

			for (line in lines) {
				var text = new FlxText(slot.currentPosition.x + ox, slot.currentPosition.y + oy, 0, line);
				text.alpha = quote.color.alphaFloat;
				text.setFormat(quote.font, quote.textSize, quote.color, LEFT);
				if (quote.bold) {
					text.addFormat(new FlxTextFormat(null, true));
				}

				if (!slot.tryFit(text)) {
					text.setPosition(slot.currentPosition.x + ox, slot.currentPosition.y + oy);
				}
				if (!slot.shouldContinue()) {
					break;
				}
				target.add(text);
				thisQuotesSprites.push(text);
				if (!slot.advanceBySprite(text)) {
					break;
				}
			}
		}
		slot.advance(quote.postPadding);
		slot.setControlParameters(null, null);

		for (updater in quote.applyEffectsTo(thisQuotesSprites)) {
			qeus.push(updater);
		}

		return qeus;
	}

	public function addSpritesFromQuotes(quotes:Array<Quote>, target:FlxSpriteGroup, space:Float, lineLimit:Int = 32) {
		var qeus:Array<QuoteEffectUpdater> = [];
		for (quote in quotes) {
			qeus = qeus.concat(addSpritesFromQuote(quote, target, space, lineLimit));
		}
		return qeus;
	}
}


// Json parsing functionality below //


typedef JsonFlxColor = Array<Int>;

typedef JsonQuoteEffects = {
	type:String,
	options:Null<Dynamic>,
}

typedef JsonQuoteArgs = {
	?text:String,
	?image:QuoteImageInfo,
	?textSize:Null<Int>,
	?bold:Null<Bool>,
	?font:Null<String>,
	?color:Null<JsonFlxColor>,
	?effects:Null<Array<JsonQuoteEffects>>,
	?linebreak:Null<Bool>,
	?postPadding:Null<Int>,
	?location:Null<Int>,
	?slotControl:Null<Array<String>>,
	?offset:Null<PointStruct>,
	?widthOverride:Null<Float>,
}

typedef JsonChainEffectsQuoteEffectOptions = Array<JsonQuoteEffects>;

typedef JsonTweenQuoteEffectOptions = {
	values:Dynamic,
	?duration:Null<Float>,
	?ease:Null<String>,
	?type:Null<String>,
}

typedef JsonRandomQuoteArgUpdateQuoteEffectOptions = {
	?array:Null<Array<JsonQuoteArgs>>,
}

typedef JsonHeartbeatQuoteEffectOptions = HeartbeatQuoteEffectOptions;

typedef JsonFlickerQuoteEffectOptions = {
	?initialStates:Null<{c: Array<String>, ?w: Null<Array<Float>>}>,
	?limit:Null<Int>,
	?initialTime:Null<RandomizableTime>,
	?hideTime:Null<RandomizableTime>,
	?showTime:Null<RandomizableTime>,
	?transitionTime:Null<RandomizableTime>,
}

private function convertFlxColorFromJson(color:Null<JsonFlxColor>):Null<FlxColor> {
	if (color == null) {
		return null;
	}
	if (color.length == 3) {
		return FlxColor.fromRGB(color[0], color[1], color[2]);
	} else if (color.length == 4) {
		return FlxColor.fromRGB(color[0], color[1], color[2], color[3]);
	} else {
		throw new ValueException("Bad color array length");
	}
}

// Act like FunkinLua.getFlxEaseByString
private function getFlxTweenTypeByString(s:String):FlxTweenType {
	return switch (s.toLowerCase().trim()) {
		case "pingpong": FlxTweenType.PINGPONG;
		case "backward": FlxTweenType.BACKWARD;
		case "persist": FlxTweenType.PERSIST;
		case "looping": FlxTweenType.LOOPING;
		case _: FlxTweenType.ONESHOT;
	}
}

private function getFlickerQuoteEffectUpdaterStateByName(s:String):FlickerQuoteEffectUpdaterState {
	return switch (s.toLowerCase().trim()) {
		case "hidden": FlickerQuoteEffectUpdaterState.HIDDEN;
		case "flickerin": FlickerQuoteEffectUpdaterState.FLICKER_IN;
		case "flickerout": FlickerQuoteEffectUpdaterState.FLICKER_OUT;
		case _: FlickerQuoteEffectUpdaterState.SHOWN;
	}
}


private function convertQuoteEffectsFromJson(jqe:Null<Array<JsonQuoteEffects>>, depth:Int):Null<Array<QuoteEffect>> {
	if (jqe == null) {
		return null;
	}

	if (depth > 2) {
		throw new ValueException("Quote args are nesting too deeply for my tastes");
	}

	var res:Array<QuoteEffect> = [];
	for (obj in jqe) {
		switch (obj.type) {
		case "ChainEffects":
			if (obj.options == null) {
				throw new ValueException("Options must exist for ChainEffectsQuoteEffect!");
			}
			var curOpt:JsonChainEffectsQuoteEffectOptions = obj.options;
			var chainEffects:Array<ChainEffect> = [];
			for (jceOpt in curOpt) {
				switch (jceOpt.type) {
				case "Scroll":
					if (jceOpt.options == null) {
						chainEffects.push(new ChainEffects.ScrollEffect());
					} else {
						var ceOpt:ChainEffects.ScrollEffectOptions = jceOpt.options;
						chainEffects.push(new ChainEffects.ScrollEffect(ceOpt));
					}
				case "HueShift":
					if (jceOpt.options == null) {
						chainEffects.push(new ChainEffects.HueShiftEffect());
					} else {
						var ceOpt:ChainEffects.HueShiftEffectOptions = jceOpt.options;
						chainEffects.push(new ChainEffects.HueShiftEffect(ceOpt));
					}
				case "AberrationGlitch":
					if (jceOpt.options == null) {
						chainEffects.push(new ChainEffects.AberrationGlitchEffect());
					} else {
						var ceOpt:ChainEffects.AberrationGlitchEffectOptions = jceOpt.options;
						chainEffects.push(new ChainEffects.AberrationGlitchEffect(ceOpt));
					}
				case "HGradient":
					if (jceOpt.options == null) {
						throw new ValueException("Options must exist for HGradient chain effect!");
					} else {
						var ceOptRaw:{colors:Array<JsonFlxColor>} = jceOpt.options;
						var ceOpt:ChainEffects.HGradientEffectOptions = {
							colors: [for (jcol in ceOptRaw.colors) convertFlxColorFromJson(jcol)],
						};
						chainEffects.push(new ChainEffects.HGradientEffect(ceOpt));
					}
				case other:
					FlxG.log.warn('Unknown ChainEffect type: $other');

				}
			}
			res.push(new ChainEffectsQuoteEffect(chainEffects));

		case "RandomQuoteArgUpdate":
			if (obj.options == null) {
				res.push(new RandomQuoteArgUpdateQuoteEffect());
			} else {
				var curOpt:JsonRandomQuoteArgUpdateQuoteEffectOptions = obj.options;
				var qargs:Array<JsonQuoteArgs> = curOpt.array;
				res.push(new RandomQuoteArgUpdateQuoteEffect([for (qargsEntry in qargs) convertQuoteArgsFromJson(qargsEntry, depth + 1)]));
			}

		case "Heartbeat":
			if (obj.options == null) {
				res.push(new HeartbeatQuoteEffect());
			} else {
				var curOpt:JsonHeartbeatQuoteEffectOptions = obj.options;
				res.push(new HeartbeatQuoteEffect({intensity: curOpt.intensity, beatTime: curOpt.beatTime}));
			}

		case "Tween":
			if (obj.options == null) {
				throw new ValueException("Options must exist for TweenQuoteEffect!");
			}
			var curOpt:JsonTweenQuoteEffectOptions = obj.options;
			res.push(new TweenQuoteEffect({
				values: curOpt.values,
				type: curOpt.type == null ? null : getFlxTweenTypeByString(curOpt.type),
				ease: curOpt.ease == null ? null : FunkinLua.getFlxEaseByString(curOpt.ease),
				duration: curOpt.duration,
			}));

		case "Flicker":
			if (obj.options == null) {
				res.push(new FlickerQuoteEffect());
			} else {
				var curOpt:JsonFlickerQuoteEffectOptions = obj.options;
				res.push(new FlickerQuoteEffect({
					initialStates: (
						curOpt.initialStates == null ?
						null :
						{
							c: [for (s in curOpt.initialStates.c) getFlickerQuoteEffectUpdaterStateByName(s)],
							w: curOpt.initialStates.w,
						}
					),
					limit: curOpt.limit,
					initialTime: curOpt.initialTime,
					hideTime: curOpt.hideTime,
					showTime: curOpt.showTime,
					transitionTime: curOpt.transitionTime,
				}));
			}

		case other:
			FlxG.log.warn('Unknown quote effect type: $other');
		}
	}
	return res;
}


function convertQuoteArgsFromJson(obj:Dynamic, depth:Int = 0):QuoteArgs {
	var jqa:JsonQuoteArgs = obj;
	var qa:QuoteArgs = {
		text: jqa.text,
		image: jqa.image,
		textSize: jqa.textSize,
		bold: jqa.bold,
		font: jqa.font,
		color: convertFlxColorFromJson(jqa.color),
		effects: convertQuoteEffectsFromJson(jqa.effects, depth),
		linebreak: jqa.linebreak,
		postPadding: jqa.postPadding,
		location: cast(jqa.location, QuoteLocation),
		slotControl: jqa.slotControl,
		offset: jqa.offset,
		widthOverride: jqa.widthOverride,
	}
	return qa;
}
