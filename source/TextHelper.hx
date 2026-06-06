// Some extracted functionality for text layout.

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import openfl.geom.Rectangle;
import openfl.errors.RangeError;

using StringTools;


interface ITextMeasurer extends IFlxDestroyable {
	// public var size(get, set):Int;
	public function measure(text:String):Float;
}

class TextMeasurer implements ITextMeasurer {
	private var _text:FlxText;

	public var size(get, set):Int;
	public function get_size():Int {
		return _text.size;
	}
	public function set_size(newSize:Int):Int {
		return _text.size = newSize;
	}

	public function new(font:String, size:Int, bold:Bool = false, ?customSubclass:Null<Class<FlxText>>) {
		if (customSubclass == null) {
			_text = new FlxText(0, 0, 0, "");
		} else {
			_text = Type.createInstance(customSubclass, [0, 0, 0, ""]);
		}
		_text.setFormat(font, size);
	}

	public function measure(text:String):Float {
		// Bypass graphics regeneration, it's not needed
		// _text.text = text;
		_text.textField.text = text;
		try {
			return _text.textField.getLineMetrics(0).width;
		} catch (e:RangeError) {
			// Since ignoring errors and just doing something with default values seems to be the
			// hf way of doing things
			return 0.0;
		}
	}

	public function destroy():Void {
		_text.destroy();
		_text = null; // idkfa
	}
}


class TextMeasurerCache implements IFlxDestroyable {
	// If only haxe had nice-to-use tuples as key or something but hey
	private var _map:Map<String, Map<Int, ITextMeasurer>>;
	public function new() {
		this._map = new Map<String, Map<Int, ITextMeasurer>>();
	}

	public function get(font:String, size:Int, bold:Bool) {
		var secondKey:haxe.Int32 = (size & 0xFFFF) | ((bold ? 1 : 0) << 16);
		_maybeCreateMap(font);
		if (!_map[font].exists(secondKey)) {
			_map[font][secondKey] = new TextMeasurer(font, size, bold);
		}
		return _map[font][secondKey];
	}

	private function _maybeCreateMap(font:String) {
		if (!_map.exists(font)) {
			_map[font] = new Map<Int, ITextMeasurer>();
		}
	}

	public function destroy() {
		for (m in _map) {
			for (tm in m) {
				tm.destroy();
			}
			m.clear(); m = null;
		}
		_map.clear(); _map = null;
	}
}


/**
 * Returns whether text is only made up of whitespace.
 * Empty strings are also considered space, so that will result in true.
 */
function isSpace(text:String):Bool {
	return ~/^\s*$/.match(text);
}

private function hasLinebreak(text:String):Bool {
	for (i in 0...text.length) {
		var char = text.charAt(i);
		if (char == '\n' || char == '\u2028') {
			return true;
		}
	}
	return false;
}

private function stripFirstLinebreak(text:String):String {
	for (i in 0...text.length) {
		var char = text.charAt(i);
		if (char == '\r') {
			if (i < text.length - 1 && text.charAt(i + 1) == '\n') { // idk what im doing but this feels right
				return text.substr(0, i) + text.substr(i + 2);
			}
		} else if (char == '\n' || char == '\u2028') {
			return text.substr(0, i) + text.substr(i + 1);
		}
	}
	return text;
}

// i am aware `\b` is also a thing, but that only works for a-zA-Z0-9 so yeah
/**
 * This function does what splitting by `/^(?=\S)|(?<=\S)$|(?<=\S)(?=\s)|(?<=\s)(?=\S)/g` SHOULD
 * be doing, which is segmenting a string into an array of alternatingly only-space and no-space strings.
 */
function segmentText(text:String):Array<String> {
	if (text.length == 0) {
		return [""];
	}

	var res = [];
	var currentSegmentStart = 0;
	var inSpaceSegment = text.isSpace(0);
	for (i in 1...text.length) {
		var localInSpaceSegment = text.isSpace(i);
		if (inSpaceSegment != localInSpaceSegment) {
			res.push(text.substring(currentSegmentStart, i));
			currentSegmentStart = i;
			inSpaceSegment = localInSpaceSegment;
		}
	}
	res.push(text.substring(currentSegmentStart, text.length));
	return res;
}

class SegmentIterator {
	private var text:String;
	private var curSegmentStart:Int;
	private var inSpaceSegment:Bool;

	public function new(text:String) {
		this.text = text;
		curSegmentStart = 0;
		if (text != "") {
			this.inSpaceSegment = text.isSpace(0);
		}
	}

	public function hasNext():Bool {
		return curSegmentStart < text.length;
	}

	public function next():String {
		var start = curSegmentStart;
		while (curSegmentStart < text.length) {
			curSegmentStart += 1;
			var localInspaceSegment = text.isSpace(curSegmentStart);
			if (inSpaceSegment != localInspaceSegment) {
				inSpaceSegment = localInspaceSegment;
				break;
			}
		}
		return text.substring(start, curSegmentStart);
	}
}

/**
 * Splits a string into the given available space and returns a two-element structure
 * of `h[ead]` and `t[ail]`, where `h` is the part still fitting into the current line.
 * `h` will never be empty (unless the source string was) and always contain at least one
 * character, so that eventually feeding the `t` part into this function repeatedly will end
 * you up with a string broken into lines. In fact, that's what `splitTextAndWordIntoLines`
 * does.
 */
function splitTextAndWordIntoRemainingSpace(text:String, space:Float, measurer:ITextMeasurer):{h:String, t:String} {
	if (text == "") {
		return {h: "", t: ""};
	}

	var segments:Array<String> = [];
	var currentWidth:Float = 0.0;
	var causedOverrun:Int = -1;
	var tailStart:Int = 0;
	for (segment in new SegmentIterator(text)) {
		segments.push(segment);
		tailStart += segment.length;
		if (hasLinebreak(segment)) {
			causedOverrun = segments.length - 1;
			break;
		}
		currentWidth += measurer.measure(segment);
		if (currentWidth > space) {
			causedOverrun = segments.length - 1;
			break;
		}
	}

	if (causedOverrun == -1) {
		// oh cool, it fits
		return {h: text, t: ""};
	}

	var tail = text.substring(tailStart, text.length);
	if (causedOverrun == 0) {
		// The first segment did not fit.
		var firstSegment = segments[0];
		if (isSpace(firstSegment)) {
			if (hasLinebreak(firstSegment)) {
				return {h: "", t: stripFirstLinebreak(firstSegment) + tail};
			}
			// If it's just regular space, throw it away.
			return {h: "", t: tail};
		}

		// First segment did not fit and is a word. Chop it up.
		var localWidth:Float = 0.0;
		for (i in 0...firstSegment.length) {
			localWidth += measurer.measure(firstSegment.charAt(i));
			if (localWidth > space) {
				// Space was exceeded, now return it.
				var wordSliceIdx = FlxMath.maxInt(i, 1);
				return {
					h: firstSegment.substr(0, wordSliceIdx),
					t: firstSegment.substr(wordSliceIdx) + tail,
				};
			}
		}
		// Oh, so now it DID fit???
		FlxG.log.notice('TextHelper weirdness; word $firstSegment fit into $space px when it previously didn\'t');
		return {h: firstSegment, t: tail};
	} else {
		// causedOverrun is at least 1
		if (isSpace(segments[causedOverrun])) {
			var head = segments.slice(0, causedOverrun).join("");
			if (hasLinebreak(segments[causedOverrun])) {
				return {h: head, t: stripFirstLinebreak(segments[causedOverrun]) + tail}
			}
			// Drop simple space segment
			return {h: head, t: tail}
		}
		// Because the segment prior is space, we include it only if the string would otherwise end up empty.
		// Arbitrary decision, but it solves the issue of space at the end of linebreaks.
		// Re-include overrunning segment in tail
		return {
			h: causedOverrun == 1 ? segments[0] : segments.slice(0, causedOverrun - 1).join(""),
			t: segments[causedOverrun] + tail,
		}
	}
}

/**
 * Repeatedly calls `splitTextAndWordIntoRemainingSpace` to deliver the input text
 * split into fitting substrings. Will give up once all text is processed or after `limit` strings
 * are generated.
 */
function splitTextAndWordIntoLines(
	text:String, space:Float, measurer:ITextMeasurer, limit:Int = FlxMath.MAX_VALUE_INT
):Array<String> {
	var tail = text;
	var res:Array<String> = [];
	while (tail.length > 0 && res.length < limit) {
		var r = splitTextAndWordIntoRemainingSpace(tail, space, measurer);
		res.push(r.h);
		tail = r.t;
	}
	return res;
}

/**
 * Returns an anonymous structure containing two strings, `h[ead]` and `t[ail]`.
 * `h` is the part of the input string that still fits in the current line,
 * `t` is the rest. Both might be empty strings, in which case no text appears
 * on the respective areas.
 */
function splitTextIntoRemainingSpace(text:String, space:Float, measurer:ITextMeasurer):{h:String, t:String} {
	if (text == "" || measurer.measure(text) <= space) {
		return {h: text, t: ""};
	}

	var segments = segmentText(text);

	var currentWidth:Float = 0;
	var causedOverrun = -1;
	for (segmentIdx => segment in segments) {
		currentWidth += measurer.measure(segment);
		if (currentWidth > space) {
			causedOverrun = segmentIdx;
			break;
		}
	}

	if (causedOverrun == -1) { // wtf
		return {h: text, t: ""};
	}

	// Available space has been exceeded, yield previous fragments
	if (causedOverrun == 0) {
		// First segment didn't fit already. If it's space (kinda weird), throw it away and return
		if (isSpace(segments[0])) {
			return {h: "", t: segments.slice(1, segments.length).join("")};
		}
		return {h: "", t: text}
	} else {
		if (isSpace(segments[causedOverrun])) {
			// Segment that overran was space; drop it
			return {
				h: segments.slice(0, causedOverrun).join(""),
				t: segments.slice(causedOverrun + 1, segments.length).join(""),
			};
		}

		return {
			h: segments.slice(0, causedOverrun).join(""),
			t: segments.slice(causedOverrun, segments.length).join(""),
		}
	}
}

/**
 * Returns the bounds of a FlxText based on it's alignment
 */
function alignmentBounds(text:FlxText):Rectangle {
	var x = text.x;
	var y = text.y;
	var twidth = text.textField.textWidth;
	var emptywidth = text.frameWidth - twidth;
	if (!text.autoSize) {
		switch (text.alignment) {
			case RIGHT: x += emptywidth;
			case CENTER: x += emptywidth / 2;
			default:
		}
	}
	return new Rectangle(x, y, twidth, text.frameHeight);
}
