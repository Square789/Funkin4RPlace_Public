package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import haxe.Json;
import haxe.ValueException;
import haxe.ds.IntMap;
import haxe.ds.StringMap;
import openfl.Assets;

import TextHelper;

using CoolUtil.InflatedPixelSpriteExt;
using StringTools;


private final INTER_MESSAGE_PADDING:Int = 8;
private final INTRA_MESSAGE_PADDING:Int = 10;
private final POST_MESSAGE_SECTION_PADDING:Int = 6;
private final SIDE_PADDING:Int = 25;
private final EMOTE_DIMENSIONS:Int = 28;
private final EMOTE_PADDING:Int = 4;
private final FONT_SIZE:Int = 16;
private final HIGHLIGHT_BORDER_WIDTH:Int = 8;
private final HIGHLIGHT_BORDER_COLOR:Int = 0xFFFF75E6;
private final HIGHLIGHT_BACKGROUND_COLOR:Int = 0xFF1F1F23;

final DEFAULT_SPEWER_CHANCE:Int = 1000;

// Some limitations on these: They may not start or end with whitespace,
// and shouldn't contain any extravagant characters.
final SPEWER_NAMES = [
	"constant", "player_winning", "player_losing", "rare", "highlight", "before_voices",
	"botplay", "mashing"
];


// For some reason, single-line text reports its height as larger than multiline text.
// This screws with the highlights, so this class is created to also make multiline add
// some pixels to its height.
private class LiarFlxText extends FlxText {
	override function get_height():Float {
		// I believe we're in this mess due to FlxText's weird `VERTICAL_GUTTER` constant, which is 4.
		return (
			super.get_height() +
			((text.length > 0 && textField.getLineIndexOfChar(text.length - 1) > 0) ? 4.0 : 0.0)
		);
	}
}


typedef EmoteInfo = {frameCount:Int, fps:Float, ?w:Int, ?h:Int, ?graphicName:String};

private final EMOTE_MAP:Map<String, EmoteInfo> = [
	"monkaS" =>           {frameCount:   1, fps: 0},
	"PogU" =>             {frameCount:   1, fps: 0},
	"LULW" =>             {frameCount:   1, fps: 0},
	"LuL" =>              {frameCount:   1, fps: 0},
	"OMEGALUL" =>         {frameCount:   1, fps: 0},
	"EZ" =>               {frameCount:   1, fps: 0},
	"PagChomp" =>         {frameCount:   1, fps: 0},
	"monkaEyes" =>        {frameCount:   1, fps: 0, w: 75, h: 20},
	"monkaW" =>           {frameCount:   1, fps: 0, w: 32, h: 32},
	"WICKED" =>           {frameCount:   1, fps: 0, w: 32, h: 22},
	"Pepepains" =>        {frameCount:   1, fps: 0, w: 32, h: 32},
	"dickL" =>            {frameCount:   1, fps: 0},
	"rossG" =>            {frameCount:   1, fps: 0},
	"AYAYA" =>            {frameCount:   1, fps: 0, w: 32, h: 31},
	"peepoSad" =>         {frameCount:   1, fps: 0},
	"monkaLaugh" =>       {frameCount:   1, fps: 0},
	"forsenCD" =>         {frameCount:   1, fps: 0},
	"WeirdChamp" =>       {frameCount:   1, fps: 0, w: 31, h: 32},
	"HUH" =>              {frameCount:   1, fps: 0, w: 32, h: 32},
	"PepeLaugh" =>        {frameCount:   1, fps: 0, w: 32, h: 32},
	"PagMan" =>           {frameCount:   1, fps: 0},
	"Pepega" =>           {frameCount:   1, fps: 0, w: 32, h: 25},
	"MEGALUL" =>          {frameCount:   1, fps: 0, w: 32, h: 30},
	"D:" =>               {frameCount:   1, fps: 0, graphicName: "Gasp"},
	"PauseChamp" =>       {frameCount:   1, fps: 0},
	"Pog" =>              {frameCount:   1, fps: 0},
	"xqcL" =>             {frameCount:   1, fps: 0},
	"xqcLL" =>            {frameCount:   1, fps: 0},
	"TrollDespair" =>     {frameCount:   1, fps: 0},
	"xqcDespair" =>       {frameCount:   1, fps: 0},
	"youthinkyoursafe" => {frameCount:   1, fps: 0, w: 25},
	"Clueless" =>         {frameCount:   1, fps: 0},
	"skHomie" =>          {frameCount:   1, fps: 0},
	"smoking" =>          {frameCount:   1, fps: 0},
	"dash" =>             {frameCount:   1, fps: 0},
	"ppOverheat" =>       {frameCount:  10, fps: 1/0.02},
	"pepeJAM" =>          {frameCount:   4, fps: 1/0.07},
	"xqcDisco" =>         {frameCount:  75, fps: 1/0.09},
	"xqcTechno" =>        {frameCount:  97, fps: 1/0.087},
	"PepePls" =>          {frameCount:  43, fps: 1/0.03},
	"goblinPls" =>        {frameCount:  12, fps: 1/0.03},
	"forsenPls" =>        {frameCount:  71, fps: 1/0.04},
	"AlienPls3" =>        {frameCount:  73, fps: 1/0.04},
	"fijiWater" =>        {frameCount: 135, fps: 1/0.02},
	"Copege" =>           {frameCount: 131, fps: 1/0.04},
	"DinkDonk" =>         {frameCount:   2, fps: 1/0.05},
	"RIPBOZO" =>          {frameCount:  81, fps: 1/0.06},
	"Aware" =>            {frameCount:  61, fps: 1/0.05},
	"PepegaChat" =>       {frameCount:   2, fps: 1/0.08},
	"Chatting" =>         {frameCount:   8, fps: 1/0.02},
	"Clap" =>             {frameCount:   2, fps: 1/0.2},
	"pepeMeltdown" =>     {frameCount:  10, fps: 1/0.03},
	"WAYTOODANK" =>       {frameCount:  90, fps: 1/0.02},
	"ppHop" =>            {frameCount:  39, fps: 1/0.04},
	"batPls" =>           {frameCount:  67, fps: 1/0.07},
	"Citto" =>            {frameCount:  28, fps: 1/0.1},
	"pepeD" =>            {frameCount:   6, fps: 1/0.12},
	"catJAM" =>           {frameCount: 158, fps: 1/0.04},
	"PepegaPls" =>        {frameCount:  10, fps: 1/0.03, w: 25},
	"xqcJAM" =>           {frameCount:  10, fps: 1/0.03},
	"xqcPls" =>           {frameCount:  22, fps: 1/0.07},
	"nymnCorn" =>         {frameCount:  29, fps: 1/0.06}
];

private final USERNAME_FORMATS:Array<FlxTextFormat> = [
	0xff0000, // red
	0x0000ff, // blue
	0x008000, // green
	0xb22222, // firebrick
	0xff7f50, // coral
	0x9acd32, // yellow green
	0xff4500, // orange red
	0x2e8b57, // sea green
	0xdaa520, // golden rod
	0xd2691e, // chocolate
	0x5f9ea0, // cadet blue
	0x1e90ff, // dodger blue
	0xff69b4, // hot pink
	0x00ff7f, // spring green
].map((color) -> new FlxTextFormat(color, true));

private final LINE_SPACING_FORMAT = (() -> {
	var _ = new FlxTextFormat();
	_.leading = Std.int(INTRA_MESSAGE_PADDING / 2);
	return _;
})();

private final HIGHLIGHT_COLOR:Int = 0xff755ebc;

private final EMOTE_SEPARATOR_REGEX = (
	"\\s*((?:" +
	[for (k in EMOTE_MAP.keys()) EReg.escape(k)].join('|') +
	")(?:\\s+|$))+"
);
private final USERNAME_REGEX = ~/^[A-Za-z0-9_]{4,28}$/;


enum MESSAGE_SECTION_TYPE {
	USERNAME_TEXT;
	TEXT;
	EMOTE;
}

typedef MessageSection = {
	type:MESSAGE_SECTION_TYPE,
	content:String,
}

private function setBasicTextProperties(flxText:FlxText) {
	flxText.setFormat(Paths.font("Inter-Regular.otf"), FONT_SIZE, 0xFFEFEFF1, FlxTextAlign.LEFT);
	flxText.addFormat(LINE_SPACING_FORMAT, 0, -1);
	flxText.antialiasing = ClientPrefs.globalAntialiasing;
	flxText.textField.antiAliasType = ADVANCED;
	flxText.textField.gridFitType = PIXEL;
	flxText.textField.sharpness = -400;
}

private abstract class LayoutFragment {
	public var x(default, null):Float;
	public var y(default, null):Float;

	public function new(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public abstract function create(username:String, usernameFormat:FlxTextFormat):FlxSprite;

	public abstract function getSectionType():MESSAGE_SECTION_TYPE;

	public function toString() {
		var n = Type.getClassName(Type.getClass(this)).split('.');
		return '<${n[n.length - 1]} at $x, $y>';
	}
}

private class TextLayoutFragment extends LayoutFragment {
	public var fieldWidth(default, null):Float;
	public var text(default, null):String;

	public function new(
		x:Float,
		y:Float,
		fieldWidth:Float,
		text:String
	) {
		super(x, y);
		this.fieldWidth = fieldWidth;
		this.text = text;
	}

	public function create(_:String, __:FlxTextFormat):FlxText {
		var flxText = new LiarFlxText(x, y, fieldWidth, text, FONT_SIZE);
		setBasicTextProperties(flxText);
		return flxText;
	}

	public function getSectionType():MESSAGE_SECTION_TYPE {
		return TEXT;
	}
}

private class EmoteLayoutFragment extends LayoutFragment {
	public var emoteName(default, null):String;

	public function new(x:Float, y:Float, emoteName:String) {
		super(x, y);
		this.emoteName = emoteName;
	}

	public function create(_:String, __:FlxTextFormat):FlxSprite {
		var emoteInfo = EMOTE_MAP[emoteName];
		if (emoteInfo == null) {
			return new FlxSprite(x, y);
		}

		var width = emoteInfo.w != null ? emoteInfo.w : EMOTE_DIMENSIONS;
		var height = emoteInfo.h != null ? emoteInfo.h : EMOTE_DIMENSIONS;
		var loadedName = emoteInfo.graphicName == null ? emoteName : emoteInfo.graphicName;
		var fc = emoteInfo.frameCount;
		var isAnimated = fc > 1;

		var sprite = new FlxSprite(x, y - ((height - EMOTE_DIMENSIONS) / 2));
		sprite.loadGraphic(Paths.image('twitch_chat/emotes/$loadedName'), isAnimated, width, height);
		// @Square789: Least we can do here regarding quality i guess
		// [why the fuck is this done via a stringcomp i am going to strangle the psych engine crew (in minecraft)]
		// @CoolingTool: [im pretty sure its `ClientPrefs.lowQuality` in normal psych, yet another pe extra blunder]
		if (ClientPrefs.gameQuality == "Normal" && isAnimated) {
			sprite.animation.add("emote", [for (i in 0...fc) i], emoteInfo.fps, true);
			sprite.animation.play("emote", true);
		}
		return sprite;
	}

	public function getSectionType():MESSAGE_SECTION_TYPE {
		return EMOTE;
	}
}

private class UsernameTextLayoutFragment extends TextLayoutFragment {
	public override function create(username:String, usernameFormat:FlxTextFormat):FlxText {
		var flxText = new LiarFlxText(x, y, fieldWidth, '$username: $text', FONT_SIZE);
		setBasicTextProperties(flxText);
		flxText.addFormat(usernameFormat, 0, username.length);
		return flxText;
	}

	public override function getSectionType():MESSAGE_SECTION_TYPE {
		return USERNAME_TEXT;
	}
}


// fuck me why do i overcomplicate everything i touch like this
private class LayoutBuilder {
	private var nextFreePosition:FlxPoint;

	private var maxWidth:Int;

	public var textMeasurer:TextMeasurer;
	public var boldTextMeasurer:TextMeasurer;

	public function new(maxWidth:Int) {
		this.maxWidth = maxWidth;
		textMeasurer = new TextMeasurer(Paths.font("Inter-Regular.otf"), FONT_SIZE, false, LiarFlxText);
		boldTextMeasurer = new TextMeasurer(Paths.font("Inter-Bold.otf"), FONT_SIZE, false, LiarFlxText);
	}

	private function reset() {
		nextFreePosition = new FlxPoint(0, 0);
	}

	/**
	 * Builds layout information for a TwitchChatMessage. It will try to stay in the area
	 * given by `maxWidth`.
	 * Note that the `messageSections` should alternate between eachother, as e.g. two
	 * consecutive `TextMessageSection`s will not be merged together. Consecutive sections
	 * of same type will have padding weirdness going on between them.
	 * Notable is that text sections immediatedly following username text sections will be
	 * merged into a single username text section.
	 */
	public function buildLayout(messageSections:Array<MessageSection>):Array<LayoutFragment> {
		reset();

		if (messageSections.length == 0) {
			throw new ValueException("MessageSections are empty, cringe.");
		}

		var res:Array<LayoutFragment> = [];
		var i = 0;
		while (i < messageSections.length) {
			var curSec = messageSections[i];
			switch(curSec.type) {
				case TEXT:          res = res.concat(cast addTextSection(curSec.content));
				case EMOTE:         res = res.concat(cast addEmoteSection(curSec.content));
				case USERNAME_TEXT:
					if ((messageSections.length > i + 1) && messageSections[i + 1].type == TEXT) {
						res = res.concat(cast addUsernameTextSection(curSec.content, messageSections[i + 1].content));
						i++;
					} else {
						res = res.concat(cast addUsernameTextSection(curSec.content, ""));
					}
			}
			i++;
		}

		return res;
	}

	/**
	 * Adds a text section to the message, wrapping on line boundaries and pushing
	 * away the `nextFreePosition`.
	 */
	private function addTextSection(text:String):Array<TextLayoutFragment> {
		if (text.length == 0) { // Safeguard since some stuff below will fail otherwise.
			return [];
		}

		var res:Array<TextLayoutFragment> = [];
		// We are adding text in the middle of a line
		if (nextFreePosition.x != 0) {
			var _tmp = splitTextIntoRemainingSpace(text, maxWidth - nextFreePosition.x, textMeasurer);
			var head = _tmp.h; var tail = _tmp.t;
			if (!isSpace(head)) {
				res.push(new TextLayoutFragment(nextFreePosition.x, nextFreePosition.y, 0, head));
				nextFreePosition.x += textMeasurer.measure(head) + POST_MESSAGE_SECTION_PADDING;
			}
			if (!isSpace(tail)) {
				nextFreePosition.x = 0;
				lowerFreePositionY(1);
				text = tail;
			} else {
				return res;
			}
		}

		res.push(new TextLayoutFragment(0, nextFreePosition.y, maxWidth, text));
		adjustFreePositionFromText(text);
		return res;
	}

	private function addEmoteSection(contents:String):Array<EmoteLayoutFragment> {
		var res:Array<EmoteLayoutFragment> = [];
		var emoteNames = ~/\s+/g.split(contents);
		for (i => emote in emoteNames) {
			var width = getEmoteWidth(emote);
			breakLineIfNecessary(width);
			res.push(new EmoteLayoutFragment(nextFreePosition.x, nextFreePosition.y, emote));
			nextFreePosition.x += (
				width +
				(i == emoteNames.length - 1 ? POST_MESSAGE_SECTION_PADDING : EMOTE_PADDING)
			);
		}
		return res;
	}

	private function addUsernameTextSection(username:String, text:String):Array<TextLayoutFragment> {
		var startingX = nextFreePosition.x;
		var startingY = nextFreePosition.y;
		var firstElement:TextLayoutFragment;
		var rawAddTextResult = addTextSection('$username: $text');
		var res:Array<TextLayoutFragment> = [];
		for (i => element in rawAddTextResult) {
			if (i == 0) {
				firstElement = element;
				var firstElementStoredText = element.text.replace('$username: ', '');
				res.push(new UsernameTextLayoutFragment(
					element.x, element.y, element.fieldWidth, firstElementStoredText
				));
			} else {
				res.push(element);
			}
		}
		// CoolingTool: try to correct nextFreePosition being incorrect because of username being bold
		var boldOffset = boldTextMeasurer.measure(username) - textMeasurer.measure(username);
		if (nextFreePosition.y == startingY) {
			nextFreePosition.x += boldOffset;
		} else if (startingX == 0 && res.length == 1) {
			// in case the bold username causes a word to wrap :)))))))
			var _tmp = splitTextIntoRemainingSpace('$username: $text', maxWidth, textMeasurer);
			var head = _tmp.h.trim(); var tail = _tmp.t.trim();
			if ((textMeasurer.measure(head) + boldOffset) > maxWidth) {
				var lastword = ~/(\S+)$/;
				lastword.match(head);
				var sinner = lastword.matched(1);

				nextFreePosition.x = startingX;
				nextFreePosition.y = startingY;
				lowerFreePositionY(1);

				adjustFreePositionFromText('$sinner $tail');
			}
		}
		return res;
	}

	private function adjustFreePositionFromText(text:String) {
		var tmpText = new LiarFlxText(0, nextFreePosition.y, maxWidth, text);
		tmpText.setFormat(Paths.font("Inter-Regular.otf"), FONT_SIZE);
		var lastLineIdx = tmpText.textField.getLineIndexOfChar(text.length - 1);
		lowerFreePositionY(lastLineIdx);
		nextFreePosition.x += tmpText.textField.getLineMetrics(lastLineIdx).width + POST_MESSAGE_SECTION_PADDING;
		tmpText.destroy();
	}

	private function breakLineIfNecessary(elementWidth:Int) {
		if (nextFreePosition.x + elementWidth >= maxWidth) {
			nextFreePosition.x = 0;
			lowerFreePositionY(1);
		}
	}

	private function lowerFreePositionY(lineCount:Int) {
		nextFreePosition.y += lineCount * (FONT_SIZE + INTRA_MESSAGE_PADDING);
	}

	public static function getEmoteWidth(name:String):Int {
		return EMOTE_MAP[name] == null ?
			32 :
			EMOTE_MAP[name].w == null ?
				EMOTE_DIMENSIONS :
				EMOTE_MAP[name].w;
	}
}

private function splitMessageIntoSections(message:String):Array<MessageSection> {
	var sections:Array<MessageSection> = [];
	var re = new EReg(EMOTE_SEPARATOR_REGEX, "");
	while (re.match(message)) {
		var prvText = re.matchedLeft().trim();
		var matchedText = re.matched(0).trim();
		sections.push({type: TEXT,  content: prvText});
		sections.push({type: EMOTE, content: matchedText});
		message = re.matchedRight();
	}
	var rest = message.trim();
	sections.push({type: TEXT, content: rest});
	return sections;
}


typedef TemplateInfo = {text:String, sep:String, min:Int, max:Int, current:Int, justOverrun:Bool};

private function deescape(text:String):String {
	return (~/((?<!\\)(?:\\\\)*)\\%/g)
		.map(text, (r:EReg) -> r.matched(1) + '%')
		.replace("\\\\", "\\");
}

// le overengineering has arrived
// do i want to prove i'm a good programmer? i think it's that. is it weird?
// this leads nowhere, so at the very least it is mega-counterproductive
// ===
// Hey, 4 months later update from me to myself: This is not "good programmer" material
// what crack were you on dude
/**
 * Produces all possible template variations for a template message, with
 * limits in place (That is, no more than 128 will be returned and repetition
 * ranges are moved to sane values in case they aren't.)
 */
private function getTemplateSubstitutions(message:String):Array<String> {
	var templateRe = ~/%(.*?)(?:(?<=[^\\])(?:\\\\)*)%(.*?)(?:(?<=[^\\])(?:\\\\)*)%(\d+),(\d+)%/;
	var textSections:Array<String> = [];
	var templateSections:Array<TemplateInfo> = [];
	while (templateRe.match(message)) {
		var min = Std.parseInt(templateRe.matched(3));
		var max = Std.parseInt(templateRe.matched(4));
		if (max <= min) {
			throw new ValueException('Bad template repetition range: $min...$max');
		}
		// idk why im doing this, every fnf mod can be horribly broken if assets are manipulated
		// protecting against this makes literally no sense but uuh whatever
		// Also, amount of templates isnt limited so lmfao
		if (min > 32) {
			max -= (min - 32);
			min = 32;
		}
		if (max > min + 8) {
			max = min + 8;
		}
		var i:TemplateInfo = {
			text: deescape(templateRe.matched(1)),
			sep: deescape(templateRe.matched(2)),
			min: min,
			max: max,
			current: min,
			justOverrun: false,
		};
		textSections.push(templateRe.matchedLeft());
		templateSections.push(i);
		message = templateRe.matchedRight();
	}
	textSections.push(message);

	if (templateSections.length == 0) {
		return [message];
	}

	var res:Array<String> = [];
	while (!templateSections[0].justOverrun && res.length <= 128) {
		var nextStr = "";
		// textSections.length - 1 == templateSections.length
		for (i => text in textSections) {
			nextStr += text;
			if (i != textSections.length - 1) {
				var tempSec = templateSections[i];
				nextStr += [for (_i in 0...tempSec.current) tempSec.text].join(tempSec.sep);
			}
		}
		res.push(nextStr);

		for (i in 0...templateSections.length) {
			var ts = templateSections[templateSections.length - 1 - i];
			ts.current += 1;
			ts.justOverrun = false;
			if (ts.current == ts.max) {
				ts.justOverrun = true;
				ts.current = ts.min;
			}
			if (!ts.justOverrun) {
				break;
			}
		}

	}
	return res;
}

typedef JsonMessageObject = {text:String, ?is_template:Bool, ?highlight:Bool};
typedef _SpewerBlock = Array<JsonMessageObject>;
typedef MessageJson = {
	constant:_SpewerBlock,
	player_winning:_SpewerBlock,
	player_losing:_SpewerBlock,
	rate:_SpewerBlock,
	highlight:_SpewerBlock,
	before_voices:_SpewerBlock,
	botplay:_SpewerBlock,
	mashing:_SpewerBlock,
};


typedef MessageInfo = {sections:Array<MessageSection>, text:String, highlight:Bool}

typedef UsernameInfo = {
	/**
	 * Pixel width of a username. This is insanely useful as multiple
	 * usernames can use the same MessageLayout with it.
	 */
	width:Int,
	section:MessageSection,
	format:FlxTextFormat,
};


/**
 * Brainrot simulator.
 */
class TwitchChatbox extends FlxSpriteGroup {
	static var instanceCount:Int = 0;
	static var usernames:Array<String> = null;
	static var messageRegistry:Null<Array<MessageInfo>>;
	static var spewerMap:Null<Map<String, Array<Int>>>;

	private var chatMessages:Array<TwitchChatMessage>;
	private var spewerChances:Map<String, Int>;
	private var totalSpewerChance:Int;
	private var chatboxWidth:Int;
	private var messageAreaWidth:Int;
	private var messageAreaHeight:Int;
	private var messageAreaFreeSpaceOffset:Int;
	private var messageAreaNextFreeY:Int;
	private var messageInsertionIdx:Int;

	private var usernameCache:Map<String, UsernameInfo>;
	private var messageLayoutCache:Map<Int, Array<LayoutFragment>>;
	private var layoutBuilder:LayoutBuilder;
	// private var layoutTree:LayoutTreeNode;

	static function maybeCacheData() {
		instanceCount += 1;
		if (instanceCount != 1) {
			return;
		}

		usernames = [];
		for (line in (
			CoolUtil.getTextFileLines(Paths.txt("usernames")).concat(
			CoolUtil.getTextFileLines(Paths.txt("twitch_chat/usernames")))
		)) {
			if (USERNAME_REGEX.match(line)) {
				usernames.push(line);
			}
		}
		if (usernames.length == 0) {
			usernames.push("what_are_u_doing_this_is_wrong");
		}

		var messages:MessageJson = Json.parse(Assets.getText(Paths.json("twitch_chat/messages")));
		messageRegistry = [];
		spewerMap = new StringMap();
		for (name in SPEWER_NAMES) {
			var castBlock:_SpewerBlock = Reflect.field(messages, name);
			if (castBlock == null) {
				throw new ValueException('Required message spewer $name missing.');
			}
			for (message in castBlock) {
				registerMessageObject(name, message);
			}
		}
	}

	static function maybeDestroyCachedData() {
		instanceCount -= 1;
		if (instanceCount > 0) {
			return;
		}

		trace("adios to the cached twitch data");
		usernames = null;
		messageRegistry = null;
		spewerMap = null;
	}

	private static function registerMessageObject(spewerName:String, message:JsonMessageObject) {
		var isTemplate = message.is_template == null ? false : message.is_template;
		var isHighlight = message.highlight == null ? false : message.highlight;
		var text = message.text;

		if (!isTemplate) {
			registerMessage(spewerName, text, isHighlight);
			return;
		}

		for (variation in getTemplateSubstitutions(text)) {
			registerMessage(spewerName, variation, isHighlight);
		}
	}

	private static function registerMessage(spewerName:String, message:String, isHighlight:Bool) {
		messageRegistry.push({sections: splitMessageIntoSections(message), text: message, highlight: isHighlight});
		if (!spewerMap.exists(spewerName)) {
			spewerMap[spewerName] = [];
		}
		spewerMap[spewerName].push(messageRegistry.length - 1);
		return;
	}

	public function new(x:Float, y:Float, chatboxWidth:Int = 420, chatboxHeight:Int = 600) {
		super(x, y);

		maybeCacheData();

		chatboxHeight = FlxMath.maxInt(chatboxHeight, 2 * INTER_MESSAGE_PADDING + 1);
		messageAreaWidth = Std.int(chatboxWidth) - 2 * SIDE_PADDING;
		messageAreaHeight = chatboxHeight - 2 * INTER_MESSAGE_PADDING;

		usernameCache = new StringMap();
		messageLayoutCache = new IntMap();
		layoutBuilder = new LayoutBuilder(messageAreaWidth);

		var headerLeft = new FlxSprite(0, 0, Paths.image("twitch_chat/header_left"));
		var headerRight = new FlxSprite(0, 0, Paths.image("twitch_chat/header_right"));
		var headerCenter = new FlxSprite(0, 0, Paths.image("twitch_chat/header_center"));

		var backgroundStartY:Float;
		var headerElements:Array<FlxSprite> = [];
		if (chatboxWidth < (headerLeft.frameWidth + headerRight.frameWidth + headerCenter.frameWidth)) {
			headerLeft.destroy();
			headerRight.destroy();
			headerCenter.destroy();
			var header = new FlxSprite(0, 0, Paths.image("twitch_chat/header"));
			header.origin.set(0.0, 0.0);
			header.antialiasing = ClientPrefs.globalAntialiasing;
			headerElements.push(header);
			backgroundStartY = header.height;
		} else {
			var headerPanel = new FlxSprite(0, 0, Paths.image("twitch_chat/header_panel8px"));
			headerPanel.setGraphicSize(chatboxWidth, headerPanel.frameHeight);
			headerPanel.origin.set(0.0, 0.0);
			headerCenter.x = (chatboxWidth - headerCenter.frameWidth) * 0.5;
			headerRight.x = (chatboxWidth - headerRight.frameWidth);
			headerElements = [headerPanel, headerRight, headerCenter, headerLeft];
			backgroundStartY = headerPanel.frameHeight;
		}

		var background = new FlxSprite(0, backgroundStartY);
		background.makeInflatedPixelGraphic(0xFF18181B, Std.int(chatboxWidth), chatboxHeight);

		add(background);
		for (e in headerElements) {
			add(e);
		}
		messageInsertionIdx = 1;

		this.chatboxWidth = chatboxWidth;
		messageAreaFreeSpaceOffset = Std.int(backgroundStartY + INTER_MESSAGE_PADDING);
		messageAreaNextFreeY = 0;
		chatMessages = [];
		spewerChances = [for (s in SPEWER_NAMES) s => DEFAULT_SPEWER_CHANCE];
		totalSpewerChance = DEFAULT_SPEWER_CHANCE * SPEWER_NAMES.length;
	}

	public override function destroy() {
		super.destroy();
		maybeDestroyCachedData();
	}

	public function uncacheUsername(username:String) {
		usernameCache.remove(username);
	}

	public function getSpewerChance(spewer:String):Int {
		if (!spewerChances.exists(spewer)) {
			return 0;
		}
		return spewerChances[spewer];
	}

	public function setSpewerChance(spewer:String, to:Int) {
		if (!spewerChances.exists(spewer)) {
			return;
		}
		to = FlxMath.maxInt(to, 0);
		var diff = to - spewerChances[spewer];
		spewerChances[spewer] = to;
		totalSpewerChance += diff;
	}

	public function changeSpewerChance(spewer:String, by:Int) {
		setSpewerChance(spewer, spewerChances[spewer] + by);
	}

	public function getSpewerChances():Map<String, Int> {
		return spewerChances.copy();
	}

	public function setSpewerChances(new_:Map<String, Int>) {
		for (k => v in new_) {
			if (spewerChances.exists(k)) {
				setSpewerChance(k, v);
			}
		}
	}

	/**
	 * Generates a message in the chatbox based on the spewer chances.
	 */
	public function generateMessage() {
		var rnd = FlxG.random.int(1, totalSpewerChance);
		var selectedSpewer:String = null;
		for (sp in SPEWER_NAMES) {
			selectedSpewer = sp;
			rnd -= spewerChances[sp];
			if (rnd <= 0) {
				break;
			}
		}

		_generateMessage(CoolUtil.randomChoice(spewerMap[selectedSpewer]));
	}

	private function _generateMessage(messageId:Int, ?username:Null<String>, ?usernameColor:Null<Int>) {
		var msg = messageRegistry[messageId];

		if (username == null) {
			username = CoolUtil.randomChoice(usernames);
		}
		if (!usernameCache.exists(username)) {
			usernameCache[username] = {
				// @Square789: NOTE: This introduces slight pixel errors after the user name, with
				// the upside of effectively quartering the memory needed for message layouts.
				// Can't really be noticed unless you're a giga-autist which tbh not sure how hard
				// my crew is represented in the fnf community
				width: Std.int(layoutBuilder.boldTextMeasurer.measure(username) / 4),
				section: {type: USERNAME_TEXT, content: username},
				format: usernameColor == null ?
					CoolUtil.randomChoice(USERNAME_FORMATS) :
					new FlxTextFormat(usernameColor, true)
			};
		}
		var usernameInfo = usernameCache[username];

		var trueSections = [usernameInfo.section].concat(msg.sections);
		// var layout = layoutTree.searchLayout(username, trueSections);
		var key:haxe.Int32 = ((usernameInfo.width & 0xFFF) << 20) | (messageId & 0xFFFFF);
		if (messageLayoutCache[key] == null) {
			messageLayoutCache[key] = layoutBuilder.buildLayout(trueSections);
		}

		var tcm = new TwitchChatMessage(messageLayoutCache[key], usernameInfo);
		if (msg.highlight) {
			tcm.addHighlight(chatboxWidth, -SIDE_PADDING);
		}

		pushBackMessages(Math.ceil(tcm.height) + INTER_MESSAGE_PADDING);

		var tcmY = messageAreaNextFreeY + messageAreaFreeSpaceOffset;
		messageAreaNextFreeY += Std.int(tcm.height) + INTER_MESSAGE_PADDING;
		tcm.textboxLocalY = messageAreaNextFreeY;
		tcm.x = SIDE_PADDING;
		tcm.y = tcmY;
		tcm.cameras = this.cameras; // These probably are used in a read-only fashion
		chatMessages.push(tcm);
		insert(messageInsertionIdx, tcm);
	}

	private function pushBackMessages(requestedHeight:Float) {
		var availableSpace = messageAreaHeight - messageAreaNextFreeY;
		var requiredNewSpace = requestedHeight - availableSpace;
		if (requiredNewSpace <= 0) {
			return;
		}

		for (message in chatMessages) {
			message.y -= requiredNewSpace;
			message.textboxLocalY -= requiredNewSpace;
		}
		while (chatMessages.length > 0 && chatMessages[0].textboxLocalY < 0) {
			remove(chatMessages.shift()).destroy();
		}
		messageAreaNextFreeY -= Std.int(requiredNewSpace);
	}
}


private class TwitchChatMessage extends FlxSpriteGroup {
	public var textboxLocalY:Float;

	public function new(layout:Array<LayoutFragment>, usernameInfo:UsernameInfo) {
		super();

		textboxLocalY = 0.0;

		for (element in layout) {
			add(element.create(usernameInfo.section.content, usernameInfo.format));
		}
	}

	public function addHighlight(highlightWidth:Int, highlightStart:Float) {
		var h = Std.int(height);
		var highlightBackground = new FlxSprite(highlightStart + HIGHLIGHT_BORDER_WIDTH, 0);
		highlightBackground.makeGraphic(highlightWidth - HIGHLIGHT_BORDER_WIDTH, h, HIGHLIGHT_BACKGROUND_COLOR);

		var highlightBorder = new FlxSprite(highlightStart, 0);
		highlightBorder.makeGraphic(HIGHLIGHT_BORDER_WIDTH, h, HIGHLIGHT_BORDER_COLOR);

		insert(0, highlightBackground);
		insert(1, highlightBorder);
	}
}
