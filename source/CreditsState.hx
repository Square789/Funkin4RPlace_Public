package;

import CoolUtil.d2r;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.VarTween;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import haxe.ds.ArraySort;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

import CoolUtil.PointStruct;
import ChainEffects;
import Quotes;
import TextHelper;

using StringTools;

// === Utilities start ===

class RevRange {
	private var cur:Int;
	private var stop:Int;

	public function new(start:Int, stop:Int) {
		this.cur = start;
		this.stop = stop;
	}

	public function hasNext():Bool {
		return cur > stop;
	}

	public function next() {
		return cur--;
	}
}

class FinishableVarTween extends VarTween {
	public function instaFinishAndCancel() {
		if (!finished) {
			// Snippets taken and mushed together from FlxTween.update and VarTween.update
			if (Math.isNaN(_propertyInfos[0].startValue)) {
				setStartValues();
			}

			if (!_running) {
				_running = true;
				if (onStart != null) {
					onStart(this);
				}
			}
			percent = 1.00;
			scale = backward ? 0 : 1;

			if (active) {
				for (info in _propertyInfos) {
					Reflect.setProperty(info.object, info.field, info.startValue + info.range * scale);
				}
			}
		}

		// Fragment from `FlxTween.finish`
		executions += 1;
		if (onComplete != null) {
			onComplete(this);
		}

		cancel();
	}

	// This couldn't possibly go wrong!
	public static function finTween(obj:Dynamic, values:Dynamic, duration:Float = 1, ?options:TweenOptions) {
		var tween = new FinishableVarTween(options, FlxTween.globalManager);
		tween.tween(obj, values, duration);
		return FlxTween.globalManager.add(tween);
	}
}


typedef SpriteDissipatorEntry = {spr:FlxSprite, remainingTime:Float}
class SpriteDissipator implements IFlxDestroyable {
	// Composition instead of inheritance solely to not have the name
	// "velocity" shadowed
	public var group:FlxSpriteGroup;
	private var _nextSpawn:Float;
	private var _initialAlpha:Float;
	private var _spawnDelay:Float;
	private var _target:FlxSprite;
	private var _activeSprites:Array<SpriteDissipatorEntry>;
	public var dissipTime:Float;
	public var direction:Float;
	public var velocity:Float;
	public var initialDisplacement:Float;
	/**
	 * Whether the dissipator should continuously spawn new sprites.
	 **/
	 public var active:Bool;

	public function new(target:FlxSprite, spawnDelay:Float, dissipTime:Float, count:Int) {
		active = true;
		group = new FlxSpriteGroup(0.0, 0.0, count);
		_spawnDelay = _nextSpawn = spawnDelay;
		_activeSprites = [];
		_target = target;
		_initialAlpha = target.alpha;
		this.dissipTime = dissipTime;

		for (_ in 0...count) {
			var sprite = new FlxSprite();
			sprite.loadGraphicFromSprite(target);
			sprite.kill();
			group.add(sprite);
		}
	}

	public function update(dt:Float) {
		group.update(dt);

		var i = 0;
		while (i < _activeSprites.length) {
			_activeSprites[i].remainingTime -= dt;
			if (_activeSprites[i].remainingTime <= 0.0) {
				_activeSprites[i].spr.kill();
				FlxArrayUtil.swapAndPop(_activeSprites, i);
				continue;
			}
			_activeSprites[i].spr.alpha = FlxMath.bound(
				_activeSprites[i].remainingTime / dissipTime, 0.0, _initialAlpha
			);
			_activeSprites[i].spr.scale.y = FlxMath.bound(
				_activeSprites[i].remainingTime / dissipTime, 0.0, 1.0
			);
			i += 1;
		}

		if (!active) {
			return;
		}

		_nextSpawn -= dt;
		while (_nextSpawn <= 0.0 && group.countDead() > 0) {
			_nextSpawn += _spawnDelay;
			var newbie = group.getFirstAvailable();
			newbie.revive();
			_activeSprites.push({spr: newbie, remainingTime: dissipTime});

			newbie.setPosition(_target.x, _target.y);
			newbie.scale.copyFrom(_target.scale);
			newbie.angle = _target.angle;
			newbie.velocity.copyFrom(new FlxPoint(0.0, -velocity).rotateByDegrees(direction));
			var tmp = new FlxPoint(0.0, -initialDisplacement).rotateByDegrees(direction);
			newbie.x += tmp.x;
			newbie.y += tmp.y;

			newbie.alpha = _initialAlpha;
			newbie.scale.y = 1.0;
		}
		_nextSpawn = Math.max(_nextSpawn, -100000.0); // who cares
	}

	public function destroy() {
		_activeSprites.resize(0);
		group.destroy();
	}
}

// === Utilities end ===

private class QuoteFieldQuoteSlot extends QuoteSlot {
	private var owner:CreditsState;

	public function new(owner:CreditsState) {
		super();
		this.owner = owner;
	}

	public override function advance(by:Float):Bool {
		currentPosition.y += by;
		currentPosition.x = initialPosition.x - owner.getXDifferenceOnSlope(currentPosition.y - initialPosition.y);
		return shouldContinue();
	}

	public override function shouldContinue():Bool {
		return currentPosition.y < FlxG.height;
	}
}

// This slot grows to the right instead and lays stuff out behind the name, treating its
// position as the lower left instead of the upper left, which is why adjusting only
// has an effect on it.
private class BehindNameQuoteSlot extends QuoteFieldQuoteSlot {
	public override function advance(by:Float):Bool {
		currentPosition.x += by;
		return shouldContinue();
	}

	public override function advanceBySprite(sprite:FlxSprite):Bool {
		sprite.y -= sprite.height;
		return advance(sprite.width);
	}

	public override function advanceByCurrentOffset() {
		advance(currentQuoteOffset.x);
	}

	public override function getOffsetMultiplierX():Float {
		return currentQuoteIgnoreOffsetX ? 1.0 : 0.0;
	}

	public override function getOffsetMultiplierY():Float {
		return 1.0;
	}

	public override function shouldContinue() {
		return currentPosition.x < FlxG.width;
	}
}

enum abstract CreditsQuoteLocation(Int) from Int to Int {
	var QUOTE_FIELD;
	var BEHIND_NAME;
}

private class NameSpriteProducer {
	public function new() {}
	public function makeName(x:Float, y:Float, name:String):FlxSprite {
		var alphabet = new TitleCardFont(0, 0, name, false, false, 0, 1.5);
		// NOTE: The alphabet (TitleCardFont) will be raised by its height, however i want its
		// text's baseline to stay in the same place. At 0.5 it's 8px too much, at 1.5 it's 24px, at 2.5 40px
		// so, place the alphabet 24px lower to counteract that.
		alphabet.setPosition(x, y + (1.5 * 16));
		return alphabet;
	}
}

private class MauriiNameSpriteProducer extends NameSpriteProducer {
	override function makeName(x:Float, y:Float, name:String) {
		var name = new FlxText(x, y, 0, name);
		name.bold = true;
		name.setFormat("Inter", 60, FlxColor.RED, RIGHT, OUTLINE, FlxColor.BLACK);
		// As before, screw with the height a bit in order to make it look accurate.
		// The fontsize is 60, but the text's reported height is 77. Who knows what's going on.
		name.y += (name.height - 60);
		return name;
	}
}


private class Role {
	public static final ARTIST:Role =         new Role("artist");
	public static final CONCEPT_ARTIST:Role = new Role("concept_artist");
	public static final ANIMATOR:Role =       new Role("animator");
	public static final COMPOSER:Role =       new Role("composer");
	public static final PROGRAMMER:Role =     new Role("programmer");
	public static final CHARTER:Role =        new Role("charter");
	public static final DIRECTOR:Role =       new Role("director");
	public static final EX_DIRECTOR:Role =    new Role("ex_director", "Ex-Director");
	public static final VOICE_ACTOR:Role =    new Role("voice_actor");
	public static final MISCELLANEOUS:Role =  new Role("miscellaneous");

	public var animationName(default, null):String;
	public var displayString(default, null):String;

	private function new(animationName:String, ?displayString:Null<String>) {
		this.animationName = animationName;
		this.displayString = displayString == null ?
			~/(^| |_|-)([a-z])/g.map(
				animationName,
				(r) -> {
					var wasProbablyStart = r.matched(1) == null || r.matched(1).length == 0;
					return (wasProbablyStart ? "" : " ") + r.matched(2).toUpperCase();
				}
			) :
			displayString;
	}
}
private final ROLES = [
	Role.ARTIST, Role.CONCEPT_ARTIST, Role.ANIMATOR, Role.COMPOSER, Role.PROGRAMMER, Role.CHARTER,
	Role.DIRECTOR, Role.EX_DIRECTOR, Role.VOICE_ACTOR, Role.MISCELLANEOUS
];


private class Representation {
	public static final PORTRAIT = new Representation(16, "credits/portraits/", 1, PortraitRepresentationSpriteGroup, 0);
	public static final ICON     = new Representation(2,  "credits/icons/",     3, IconRepresentationSpriteGroup,     1);

	public var quoteLimit(default, null):Int;
	public var imagePath(default, null):String;
	public var memberDisplayCount(default, null):Int;
	public var representationGroupClass(default, null):Class<RepresentationSpriteGroup>;
	public var priority(default, null):Int;

	private function new(
		quoteLimit:Int,
		imagePath:String,
		memberDisplayCount:Int,
		representationGroupClass:Class<RepresentationSpriteGroup>,
		priority:Int
	) {
		this.quoteLimit = quoteLimit;
		this.imagePath = imagePath;
		this.memberDisplayCount = memberDisplayCount;
		this.representationGroupClass = representationGroupClass;
		this.priority = priority;
	}
}


private class CreditBlob {
	public var name:String;
	public var roles:Array<Role>;
	public var representation:Representation;
	public var representationImageName:Null<String>;
	public var quotes:Array<Quote>;
	public var color:FlxColor;
	public var links:Array<{link:String, iconName:String}>;
	public var offset:PointStruct;
	public var image:Null<FlxGraphic>;
	public var nameSpriteProducer:NameSpriteProducer;

	public function new(
		name:String,
		roles:Array<Role>,
		representation:Representation,
		representationImageName:Null<String>,
		quotes:Array<QuoteArgs>,
		color:FlxColor,
		?links:Null<Array<String>>,
		?offset:Null<PointStruct>,
		?nameSpriteProducer:Null<NameSpriteProducer>
	) {
		this.name = name;
		this.roles = roles;
		this.representation = representation;
		this.representationImageName = representationImageName;

		var ultimateArgs:Array<QuoteArgs> = [];
		if (quotes.length < 1) {
			ultimateArgs = [{text: "null"}];
		} else if (quotes.length > representation.quoteLimit) {
			ultimateArgs = quotes.slice(0, representation.quoteLimit + 1);
		} else {
			ultimateArgs = quotes;
		}
		this.quotes = [for (a in ultimateArgs) new Quote(a)];

		this.color = color;
		if (links == null) {
			this.links = [];
		} else {
			this.links = [for (link in links) {link: link, iconName: extractIconNameFromLink(link)}];
		}
		this.offset = offset == null ? {x: 0, y: 0} : offset;

		if (representationImageName != null) {
			this.image = Paths.image(representation.imagePath + representationImageName);
		} else {
			this.image = null;
		}

		this.nameSpriteProducer = nameSpriteProducer == null ? new NameSpriteProducer(): nameSpriteProducer;
	}

	private static function extractIconNameFromLink(link:String):String {
		var urlRe = ~/(?:[a-z0-9-]+?\.)*([a-z0-9-]+?\.[a-z0-9]{1,24})/; // literally who cares, good enough
		if (!urlRe.match(link)) {
			return "generic";
		}
		return switch (urlRe.matched(1)) {
			case "twitter.com":
				"twitter";
			case "youtube.com" | "youtu.be":
				"youtube";
			case "github.com":
				"github";
			case "reddit.com" | "redd.it":
				"reddit";
			case "steamcommunity.com" | "steampowered.com" | "s.team":
				"steam";
			case "spriters-resource.com":
				"spriters-resource";
			case "linktr.ee":
				"linktree";
			case "newgrounds.com":
				"newgrounds";
			case _:
				"generic";
		}
	}
}

/**
 * Full house and full backyard shed. Delegated to function as `CreditBlob`s load images.
 * Should really be turned into a bunch of .jsons
 */
private function makeCredits():Array<{name:String, members:Array<CreditBlob>}> { return [
	{
		name: "Funkin' 4 r/place Team",
		members: [
			new CreditBlob(
				"Sir Sins",
				[Role.EX_DIRECTOR, Role.CHARTER, Role.CONCEPT_ARTIST],
				Representation.PORTRAIT,
				"sir_sins",
				[
					{
						text: (
							"If you're reading this, then you must be interested in the people behind the mod, hm? " +
							"Well, let's have a chat.\n\n" +
							"I'm Sir Sins, the person who made the original post on Reddit back when r/place " +
							"happened. Never would've thought it'd come this far, and that the dev team would turn " +
							"into a massive friend group, but hey, you think I'm complaining?\n\n" +
							"Mod's nice and all, but I have a far greater apprecitation for the people I met on the " +
							"way, AKA, the rest of the dev team. Go check their quotes, see what they have to say " +
							"and enjoy the mod, if you will...\n\n" +
							"Once the keeper of chaos, always the keeper of chaos. Thanks for playing!"
						),
						//// color: FlxColor.PURPLE, // For the hue shifting to work //// nvm looks terrible
						effects: [
							new ChainEffectsQuoteEffect([
								new AberrationGlitchEffect({baseIntensity: 2.0, intensityVariance: 3.0, goNegative: false}),
								new HueShiftEffect({cycleSpeed: 0.5}), //// shifting the aberration however actually looks nice
							]),
						],
					},
				],
				0x9203EE,
				{x: 86, y: 162}
			),
			new CreditBlob(
				"RayTheMaymay",
				[Role.DIRECTOR, Role.ANIMATOR, Role.ARTIST],
				Representation.PORTRAIT,
				"ray",
				[
					{text: (
						"Hey it's me mr funnyman aka RayTheMaymay I do things follow me on twitter\n\n" +
						"Funny aside, I'm the current director of the mod. I'm really happy to see " +
						"how far its come, despite the many development issues along the way.\n\n" +
						"Thank you all for sticking around for so long, I hope it was worth the wait." )},
					{
						image: {name: "ray", animated: true, frameW: 16, frameH: 16, fps: 8, scale: 2.0},
						location: CreditsQuoteLocation.BEHIND_NAME,
					},
				],
				0xDD2222,
				["https://twitter.com/TheMarioWriter"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"DangDoodle",
				[Role.COMPOSER, Role.ANIMATOR, Role.VOICE_ACTOR],
				Representation.PORTRAIT,
				"doodle",
				[
					{text: "Just straight up chilling, go with the flow."},
					{image: {name: "doodle", animated: true, frameW: 96, frameH: 96, fps: 10}},
				],
				0x17B9F9,
				["youtube.com/c/DangDoodle", "twitter.com/DangDoodleMusic"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Captain",
				[Role.EX_DIRECTOR, Role.ARTIST, Role.CHARTER],
				Representation.PORTRAIT,
				"captain",
				[
					{text: (
						"yknow i dont typically write like this, but since its a special occasion, i suppose " +
						"i shall. i am very thankful to have gotten the opportunity to meet all these " +
						"talented people in such a short amount of time. f4rp has taught me many lessons " +
						"throughout its development and i hope each and every one of my new friends have a " +
						"successful life in whatever they choose to do. thank you f4rp for all of the " +
						"opportunities, and friends, you have given me"
					)},
					{image: {name: "captain_signature"}},
					{text: "malder gold sweeeeps!"},
				],
				0x5C92FF,
				[
					"https://steamcommunity.com/id/Funny_Captain/",
					"https://www.spriters-resource.com/submitter/CaptainGame17/",
				],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"MSV",
				[Role.COMPOSER],
				Representation.PORTRAIT,
				"msv",
				[{text: "I make certified hood classics"}],
				0x2468EF,
				["https://www.youtube.com/@msvi09official"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Pale Artist",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"pale_artist",
				[
					{
						text: (
							"Your name is NEPETA LEIJON.\n\n" +
							"You live in a CAVE that is also a HIVE, but still mostly just a CAVE. You like to engage " +
							"in FRIENDLY ROLE PLAYING, but not the DANGEROUS KIND. Never the DANGEROUS KIND. It's TOO " +
							"DANGEROUS! Too many of your good friends have gotten hurt that way.\n\n" +
							"Your daily routine is dangerous enough as it is. You prowl the wilderness for GREAT " +
							"BEASTS, and stalk them and take them down with nothing but your SHARP CLAWS AND TEETH! " +
							"You take them back to your cave and EAT THEM, and from time to time, WEAR THEIR PELTS FOR " +
							"FUN. You like to paint WALL COMICS using blood and soot and ash, depicting EXCITING TALES " +
							"FROM THE HUNT! And other goofy stories about you and your numerous pals. Your best pal of " +
							"all is A LITTLE BOSSY, and people wonder why you even bother with him. But someone has to " +
							"keep him pacified. If not you, then who? Everyone has an important job to do.\n\n" +
							"Your trolltag is arsenicCatnip and :33 < *your sp33ch precedes itself with the face of " +
							"your lusus who is pawssibly the cutast and purrhaps the bestest kitty you have ever " +
							"s33n!*\n\n" +
							"What will you do?"
						),
						textSize: 16,
						font: "Courier New",
						bold: true,
					},
					{text: "Follow me on TWITTER @Pale_Artist_"},
				],
				0xFFFFFF,
				["https://twitter.com/Pale_Artist_"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Sienna",
				[Role.COMPOSER, Role.PROGRAMMER],
				Representation.PORTRAIT,
				"sienna",
				[{text: "<3", effects: [new HeartbeatQuoteEffect({intensity: 1.35, beatTime: 0.72})]}],
				0x42E36B,
				["https://suprstarrd.com/"],
				{x: 119, y: 146}
			),
			new CreditBlob(
				"daftbrained",
				[Role.ARTIST, Role.ANIMATOR],
				Representation.PORTRAIT,
				"daftbrained",
				[
					{
						text: (
							"I should put an unreasonable amount of text in this because" +
							[for (_ in 0...85) ""].join(" its funny")
						),
					},
				],
				0x504027,
				null,
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Parasy",
				[Role.CHARTER],
				Representation.PORTRAIT,
				"parasy",
				[
					{
						text: (
							"Hiya! I'm the Mania charter for this mod, alongside the charter for some of the " +
							"Normal difficulties."
						)
					},
					{
						text: (
							"I'd like to say first of all, make sure to check out the other difficulties, as we " +
							"all put a lot of love into these charts regardless of their difficulty. Regardless, " +
							"I hope you enjoyed the charts that you played! Thanks a lot for playing!"
						)
					},
				],
				0xFFA7F0,
				["https://www.youtube.com/@314Pirasy"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Syembol",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"syembol",
				[
					{text: "Hello    .", slotControl: ["IGNORE_ADVANCE"]},
					{color: 0xFF0000FF, text: "      Bro "},
					{text: "im Syembol. You're probably wondering how i ended up here! Well.... It's a Long Story. Let's just say its like r/Place!"},
					{text: "Jokes Aside, if Anyone else besides the dev team is seeing this... the mod is done! And released! I hope you had a good time with it. We poured a bunch of Effort into it. lots of Coffee cups drunk and drank. Good times had!"},
					{text: "Anyways... go find me somewhere else"},
				],
				0xFF8920,
				["https://syembol123awesome.neocities.org/"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Square789",
				[Role.PROGRAMMER],
				Representation.PORTRAIT,
				"square",
				[
					{text: "It's done!"},
					{
						text: (
							"Thanks to EpicGamer from the Haxe Discord for crushing an annoying " +
							"shader issue within 5 minutes of looking at it!"
						),
					},
					{text: "And thank you for playing :D", postPadding: 32},
					{
						text: "[SHAMELESS PLU- I MEAN SPONSORED MESSAGE]",
						effects: [new ChainEffectsQuoteEffect([new AberrationGlitchEffect(
							{baseIntensity: 2.0, intensityVariance: 2.0, goNegative: false}
						)])],
						textSize: 20,
						postPadding: 0,
					},
					{
						text: "I'm rewriting FNF in Python, coming out Q4 2027 at this rate (Check my Github!)",
						postPadding: 30,
					},
					{
						text: "",
						color: 0xFFB2A8A8,
						effects: [new RandomQuoteArgUpdateQuoteEffect([
							{text: "Fun fact: This quote is randomly chosen!"},
							{text: "Fun fact: OpenFL is somewhat stuck on a GLSL version from 2004!"},
							{text: "Fun fact: Your front door's lock quality is rather substandard!"},
							{text: "Fun fact: Bielefeld does not exist!"},
							{text: "Fun fact: I am bad at my job!"},
							{text: "Fun fact: I wrote the menu you are enjoying right now!"},
							{text: "Fun fact: All tech infrastructure is held together by duct tape!"},
							{text: "Fun fact: It's strings all the way down!"},
							{text: "Fun fact: There is nothing you can do about it!"},
							{text: "Fun fact: FNF code is the best spaghetti i've ever had!"},
							{text: "Fun fact: You are not immune to propaganda!"},
							{text: "Fun fact: A monad is a monoid in the category of endofunctors!"},
							{text: "Fun fact: surveillance nanobots in your floorboards pry them out"},
							{text: "Fun fact: Four plus four plus four is twelve."},
							{text: "Fun fact: Epstein did not kill himself!"},
							{text: "Fun fact: I'm pretty much out of fun facts."},
							{text: "Fun fact: The more references i cram in here, the less funny it gets!"},
							{text: "Fun fact: The Area 51 Snack Bar Sucks"},
							{text: "Fun fact: These quotes are the result of a lifelong internet addiction!"},
							{text: "Fun fact: I need professional help!"},
							{
								text: (
									"Fun fact: Only after shoehorning achievement popups into MusicBeatState and " +
									"painfully sprinkling extra camera code around just for them, i noticed it " +
									"would've been possible to use `addChild` to add these above the actual game."
								),
							},
							{
								text: (
									"Fun fact: I think this menu is a performance nightmare.\n\n" +
									"But hey, that slanted text sure makes up for it!"
								),
							},
							{text: "Fun fact: This took a long time."},
							{text: "Fun fact: The most mundane stuff veils the most time-consuming workload."},
							{
								text: (
									"Fun fact: I wrote a hideously overengineered per-achievement data " +
									"storage, loading and defaulting mechanism with adventurous type validation " +
									"and access notation and that ended up unused. " +
									"Most definitely for the best!"
								),
							},
							{text: "Fun fact: There is a place in France"},
							{
								text: (
									"Fun fact: If someone didn't already name themselves Square123 on Minecraft all " +
									"these years ago, I'd have used that. It doesn't roll of the tongue as well, " +
									"so thanks Square123, whereever you are now!"
								),
							},
							{text: "Fun fact: The sun is a deadly laser."},
							{text: "Fun fact: [451 Unavailable for legal reasons]"},
							{
								text: (
									"Fun fact: All of this mod's libraries are on the same version as they were on " +
									"day 1 of development and are very much out of date."
								),
							},
							{text: "Fact: The Fact Sphere is always right!"},
							{text: "FICSIT does not waste!"},
							{text: "Objects in mirror are closer than they appear!"},
							{text: "It's a chronic buildup of my favorite iron dust!"},
							{text: "Your casual match is ready!"},
							{text: "thog dont caare"},
							{text: "You missed your Spanish lesson today.\n\nYou know what happens now."},
							{text: "I found the source of the ticking! It's a pipe bomb!"},
							{text: "Wer sagt denn, dass ich, wenn ich das hier trink', morgens 'nen Schädel hab'?"},
							{text: "Null Object Reference!"},
							{text: "Segmentation fault!"},
							{text: "Object reference not set to an instance of an object!"},
							{text: "Up, up, down, down, left, right, left, right, B, A!"},
							{text: "You are worth it."},
							{text: "You have angered the gods!"},
							{text: "It was like that when i got here!"},
							{text: "This is our fault"},
							{text: "You're cute!"},
							{
								text: (
									"I was thinking about why so many in the radical left participate " +
									"in \"speedrunning\"."
								),
							},
							{text: "Arstotzka so great, passport not required!"},
							{text: "Real Yakuza use a gamepad."},
							{text: "YOU'RE WINNER!"},
							{text: "I may be stupid,"},
							{text: "I don't much like the tone of your voice!"},
							{text: "I don't get it."},
							{text: "THERE'S NO FENCE ON THIS FENCE!"},
							{
								text: (
									"The end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never "
								),
							},
							{text: "At least there is Ceda Cedovic!"},
							{text: "snake_case forever!"},
							{text: "I like elephants and God likes elephants. Here's a, uh... a realistic elephant.\n/°)===,\n'´||||"},
							{text: "410,757,864,530 LINTER WARNINGS!"},
							{text: "Overengineering extravaganza!"},
							{
								text: (
									"SUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\n" +
									"SUPER.\n HOT."
								),
							},
							{text: "Hello World!"},
							{text: "#C$L&S@\n02402488"},
							{text: "for (u in effectUpdaters) {\n    u.update(dt);\n}"},
							{text: "I can't feel my beard! HEEELP!"},
							{text: "AAAHHHH! I NEEEEED A MEDIC BAG!"},
							{text: "Seymour! The house is on fire!"},
							{text: "Blessed be the regulations."},
							{text: "| || || |_"},
							{text: "This was a triumph."},
							{text: "He was my best friend, but he owed me seven dollars!"},
							{
								text: (
									"In this moment, I am euphoric. Not because of any phony god's blessing.\n" +
									"But because I am enlightened by my own intelligence"
								),
							},
							{text: "Thanks, and have fun!"},
							{text: "RIP r/gayspiderbrothel!"},
							{text: "Oh, SHUT UP about the bloody mushrooms already! Move it, team!"},
							{text: "God, these pretzels suck! How's your day been, buddy?"},
							{text: "Guys, the thermal drill. Go get it!"},
							{
								text: (
									"What are you talking about? If I didn't believe in what I was doing " +
									"I'd simply leave and find another job."
								)
							},
							{
								text: (
									"I'd just like to interject for a moment. What you're referring to as Linux, " +
									"is in fact, GNU/Linux, or as I've recently taken to calling it, GNU plus " +
									"Linux. Linux is not an operating system unto itself, but rather another free " +
									"component of a fully functioning GNU system made useful by the GNU corelibs, " +
									"shell utilities and vital system components comprising a full OS as defined by " +
									"POSIX.\n" +
									"Many computer users run a modified version of the GNU system every day, " +
									"without realizing it."
								),
							},
							{
								text: (
									"I feel ashamed. Again and again. Nothing to give. And no one to blame.\n" +
									"During the daaaaay, I guess I'm okay."
								),
							},
							{text: "Löckelle postera, lorsca undula kalit.\nLöckelle karakto, baldeni."},
							{text: "Enjoying the ride?"},
							{text: "Reticulating splines..."},
							{text: "\"git commit --amend\" my beloved"},
							{text: "THANK YOU FOR PARTICIPATING\nIN THIS\nENRICHMENT CENTER ACTIVITY!!"},
							{text: "Program received signal SIGSEGV 0x4007fc13 in _IO_FRESH_MOVES"},
							{text: "Terms and conditions may apply"},
							{text: "Hasta la vista! Feliz Navidad! Hasta gazpacho!"},
							{
								text: (
									"WARNING !!!\nyou appear to be incompatible with: THE WORLD\n" +
									"please contact TECH SUPPORT in...\nTHE INFORMATION SUPERHIGHWAY"
								),
							},
							{
								text: (
									"+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n" +
									"+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n+ ENRAGED\n+ PROJECTILE BOOST\n" +
									"+ DISRESPECT\n+ PROJECTILE BOOST"
								),
							},
							{
								text: (
									"If i had a nickel for every time a game in my Steam library made the only " +
									"robot character in its player character roster non-binary, i'd have two " +
									"nickels; which isn't a lot, but it's weird that it happened twice."
								),
							},
							{
								text: (
									"Funding for this program was made possible by the corporation for public " +
									"broadcasting and by annual financial support from viewers like you."
								),
							},
							{text: "I miss my wife, Tails. I miss her a lot. I'll be back."},
							{text: "understand(/*The*/Concept.of(\"LOVE\"));"},
							{
								text: (
									"Well, there are only 99,999 chips here, but they don't call me Lenny the " +
									"Lenient for nothin'. Go on through."
								),
							},
							{text: "^_^"},
							{text: "\\o/"},
							{text: ">download desktop app\n>look inside\n>browser"},
							{text: "Have you tried turning it off and on again?"},
							{text: "Stealth is an option."},
							{
								text: "WASSO WASSO WASSUUUP BITCONNEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE",
								linebreak: false,
							},
							{text: "Pick up that can."},
							{text: "enum Bool\n{\n    True,\n    False,\n    FileNotFound\n}"},
							{text: "Me when there'll be greyscale-and-red-as-only-accent-color art at the function:"},
							{text: "<3 Sähikäismenninkkäinen <3"},
							{text: "No, no, i don't really think"},
							{text: "No Save Scumming\nNo Slow Motion\nNo Frame Advance\nNo Rewind\nNo Memory Display\nNo Code Injection\nNo Pause\nNo Hope\nNo End"},
							{text: "The Queen of Dragonflies is sleeping and smiling"},
							{text: 'Beginning your title with "vote up if" is violation of intergalactic law.'},
							{text: "Big day today, Freeman."},
							{text: "L00MINARTY COMFIRM!!!!!!!!"},
							{text: "Collect my compiler warnings"},
							{text: "The bomb has almost reached the final terminus aHUAAA HAHAHAHAHAHAHAHA"},
							{text: "Despondent vermin..."},
							{text: "I'M BACK IN THE FUCKING BUILDING AGAIN?!"},
							{text: "Outlook not so good.\n\n\n\nSeriously, use Thunderbird instead. Or FairEmail for mobile."},
							{text: "You know exactly what to do."},
							{text: "There is no antimemetics division"},
							{text: "You do not recognize the bodies in the water."},
							{text: "Hurt me plenty"},
							{text: "folga wooga imoga womp"},
							{text: "502 Bad Gateway\n---------------------\nopenresty"},
							{text: "So rot in me\nSo rot in me\nSo rot in me\nSo rot in me\nI wither, sink\nI wither, sink\nI wither, sink\nI wither, sink"},
							{text: "Let's just ping everyone all at once."},
							{text: "ROCK FOR YOU"},
							{text: "cheers mate if you need anything else just message me or something i don't kno"},
							{
								text: "MIND IS SOFTWARE.\n\nBODIES ARE DISPOSABLE.\n\nTHE SYSTEM WILL SET YOU FREE.",
								effects: [
									new TypeoutQuoteEffect({
										commands: [
											{command: "typeout", overtype: false, count: 17, speed: 48.0},
											{command: "wait", time: 0.4},
											{command: "typeout", overtype: false, count: 22, speed: 48.0},
											{command: "wait", time: 0.4},
											{command: "typeout", overtype: false, count: 29, speed: 48.0},
										]}
									),
								],
							},
							{text: "I been hacked.\nall my pixels gone. this just placed please help me"},
							{image: {name: "google"}},
							{image: {name: "wo_hier"}},
						])],
					},
				],
				0xAA0000,
				["https://github.com/Square789"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"EmolgaGamer",
				[Role.ARTIST, Role.CONCEPT_ARTIST],
				Representation.PORTRAIT,
				"emolga",
				[
					{image: {name: "emolga0"}, postPadding: 4},
					{image: {name: "emolga1"}, postPadding: 4},
					{image: {name: "emolga2"}, postPadding: 4},
					{image: {name: "emolga3"}},
					{image: {name: "emolga4"}, postPadding: 4},
					// Turns out trying to shoehorn bitmap fonts into all of this is a pain not worth it,
					// so just typed it out in GIMP with font size 32 ez
					// {
					// 	text: (
					// 		"See, I am doing a new thing!\n" +
					// 		"Now it springs up; do you not perceive it?\n" +
					// 		"I am making a way in the wilderness\n" +
					// 		"and streams in the wasteland."
					// 	),
					// 	font: "pokemon-dp-pro",
					// 	isBitmapFont: true,
					// 	postPadding: 12,
					// },
					// {text: "    - Isaiah 43:19, NIV", font: "pokemon-dp-pro", isBitmapFont: true},
				],
				0xFAFF00,
				["https://reddit.com/user/dz0907"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Lunsar",
				[Role.ANIMATOR],
				Representation.PORTRAIT,
				"lunsar",
				[{"text": "professional representative from the hyuns dojo community"}],
				0x0044FF,
				["https://youtube.com/@Lunsar", "https://twitter.com/LunsarXD"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"remagic",
				[Role.CHARTER],
				Representation.PORTRAIT,
				"remagic",
				[
					{
						text: (
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n"
						),
					}
				],
				0x00FF00,
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Jospi",
				[Role.COMPOSER, Role.CHARTER],
				Representation.PORTRAIT,
				"jospi",
				[
					{
						text: (
							"I don't know where I'd be without this mod team. It's been an incredible experience " +
							"working with all of these amazing people, being able to make friends, and having some " +
							"funny experiences along the way. I'd like to thank everyone here for all the fun " +
							"times, and you for playing the mod. :]"
						),
						effects: [new TweenQuoteEffect({values: {alpha: 0.5}, duration: 2.6, type: FlxTweenType.PINGPONG})],
					},
				],
				0xC905FF,
				["https://www.youtube.com/@JospiMusic"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"ThaumcraftMC",
				[Role.PROGRAMMER],
				Representation.PORTRAIT,
				"thaumcraft",
				[
					{text: "Shout-out to everyone who supported us during r/place, y'all are the real ones."},
					{text: "No Lua, HTML5 sucks."},
				],
				0x00FF00,
				["https://twitter.com/ThaumcraftMC"],
				{x: 86, y: 162}
			),
			new CreditBlob(
				"Maurii",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"maurii",
				[
					{text: "funniguy"},
					{text: "Sexy music guy although I didn't do shit for this mod"},
					{text: "hey you should play Marlo..."},
				],
				0xFF5757,
				["https://twitter.com/TheMaurii64"],
				{x: 86, y: 162},
				new MauriiNameSpriteProducer()
			),
			new CreditBlob(
				"GoddessAwe",
				[Role.COMPOSER],
				Representation.ICON,
				"goddessawe",
				[{text: "Menu music and co-created Enough"}],
				0xE9338F,
				["https://www.youtube.com/@awe9037", "https://twitter.com/GoddessAwe"],
				{x: 0, y: 0}
			),
			new CreditBlob(
				"Ronezkj15",
				[Role.COMPOSER],
				Representation.ICON,
				"ronez",
				[{text: "Helped out with Malder Gold"}],
				0x1B4BBE,
				["https://www.youtube.com/@Ronezkj15"]
			),
			new CreditBlob(
				"Churgney Gurgney",
				[Role.COMPOSER],
				Representation.ICON,
				"churgney",
				[{text: "Mixing Assistance"}],
				0x605F5A,
				["https://twitter.com/gurgney"]
			),
			new CreditBlob(
				"Kide",
				[Role.ANIMATOR],
				Representation.ICON,
				"kidemon",
				[{text: "Animator"}],
				0xFF6633,
				["https://twitter.com/OfficialKidemon"]
			),
			new CreditBlob(
				"SpaceNautica",
				[Role.CONCEPT_ARTIST],
				Representation.ICON,
				"spacenautica",
				[{text: "Concept Artist for Malder"}],
				0x6D3293,
				["https://twitter.com/spacenautica"]
			),
			new CreditBlob(
				"Daniel",
				[Role.ARTIST, Role.PROGRAMMER],
				Representation.PORTRAIT,
				"daniel",
				[
					{
						text: "please let me out of here, it's so cold",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({initialStates: {c:[SHOWN]}, initialTime: {standard: 1.0}})],
					},
					{
						text: "they do not feed me, just get me out",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 2.0, b: 6.0}},
							showTime: {randomOffset: {a: -0.3, b: 0.3}},
						})],
					},
					{
						text: "i dont know how much longer i can stay here, please",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 2.0, b: 5.0}},
							showTime: {randomOffset: {a: 0.0, b: 1.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "they all forgot",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 0.0, b: 3.0}},
							showTime: {randomOffset: {a: 0.0, b: 2.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "close the game now i cant take it anymore",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 3.0, b: 7.0}},
							showTime: {randomOffset: {a: 0.0, b: 3.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "can you hear me?",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 7.0, b: 8.0}},
							showTime: {standard: 6.0},
							hideTime: {standard: 4.0, randomOffset: {a: 0.0, b: 3.0}},
						})],
					},
				],
				0x000000
			),
		],
	},
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Special Thanks",
		members: [
			new CreditBlob(
				"Saruky",
				[Role.COMPOSER],
				Representation.ICON,
				"saruky",
				[{text: "BF Chromatic in Enough"}],
				0x4800FF,
				["https://linktr.ee/Saruky"],
			),
			new CreditBlob(
				"Philliplol",
				[Role.COMPOSER],
				Representation.ICON,
				"philliplol",
				[{text: "Eduardo Chromatic"}],
				0x2141E4,
				["https://twitter.com/philiplolz"],
			),
			new CreditBlob(
				"Esther Christo",
				[Role.VOICE_ACTOR],
				Representation.ICON,
				"esther_christo",
				[{text: "Monika Chromatic"}], //I don't know where this is used, but I don't want to remove credit
				0xAF5CAC,
				["https://twitter.com/carimellevo"],
			),
			new CreditBlob(
				"Ninjamuffin",
				[Role.PROGRAMMER],
				Representation.ICON,
				"ninjamuffin99",
				[{text: "Supported our mission on r/place"}],
				0xCF2D2D,
				["https://twitter.com/ninja_muffin99"]
			),
			new CreditBlob(
				"Flarewire",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"flarewire",
				[{text: "Funk Mix BF / 8BF Permission"}],
				0xD13236,
				["https://www.youtube.com/@Flarewire"]
			),
			new CreditBlob(
				"Big Man!",
				[Role.COMPOSER],
				Representation.ICON,
				"big_man",
				[{text: "Bubbo Permission"}],
				0xFFC90E,
				{x: -18, y: 0}
			),
			new CreditBlob(
				"RubberRoss",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"rubberross",
				[{text: "Supported our mission on r/place"}],
				0xFF293A,
				["https://www.youtube.com/@RubberRoss"]
			),
			new CreditBlob(
				"MagianFellow",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"magianfellow",
				[{text: "Original Newgrounds 2019 pixel logo"}],
				0xFFFFFF,
				["https://magianfellow.newgrounds.com/"]
			),
			new CreditBlob(
				"The r/place 2022 Atlas / Catalog",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"placeatlas_catalog",
				[{text: "Used for Lorebook Images"}],
				0xFF4500,
				["https://place-atlas.stefanocoding.me/"]
			),
			new CreditBlob(
				"Indie Alliance",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"indie_alliance",
				[{text: "Supported our mission on r/place"}],
				0xFE0000
			),
			new CreditBlob(
				"DJ Grooves",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"djgrooves",
				[{text: "Assembled the original group DM after Sir Sins made the original post."}],
				0xFAA218,
			),
			// NOTE: CARDHOUSE CODE GALORE THIS NEEDS TO BE IN THE 3RD POSITION ELSE THE LINK PILLAR WILL BE TOO SHORT
			// AND THE TEXT TOO LONG
			new CreditBlob(
				"Various sources",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"various_sources",
				[
					{
						text: (
							"Code snippets, help threads and resources that were used or built on for some shaders and effects!\n" +
							"Stack Overflow & Co.: user128511, Alex B, wondra, Gama11 | shadertoy.net: Rabbid76 | " +
							"GitHub: mairod, viruseg | u/lucasvb | Inigo Quilez | Shadertoy | Graphtoy | The Book of Shaders")
						,
						textSize: 20,
					},
				],
				0x0FB979,
				[
					"https://stackoverflow.com/questions/47376499/creating-a-gradient-color-in-fragment-shader",
					"https://stackoverflow.com/questions/1907565/c-and-python-different-behaviour-of-the-modulo-operation",
					"https://gamedev.stackexchange.com/questions/125218/linear-gradient-with-angle-formula",
					"https://stackoverflow.com/questions/48075991/is-there-a-way-to-apply-an-alpha-mask-to-a-flxcamera",
					"https://www.shadertoy.com/view/7tsXRN",
					"https://gist.github.com/mairod/a75e7b44f68110e1576d77419d608786",
					"https://old.reddit.com/r/Physics/comments/30royq/whats_the_equation_of_a_human_heart_beat/cpw81wj/",
					"https://iquilezles.org/articles/distfunctions2d/",
					"https://shadertoy.com/",
					"https://graphtoy.com/",
					"https://thebookofshaders.com/13/",
				]
			),
			new CreditBlob(
				"DeonDahlia",
				[Role.ARTIST],
				Representation.ICON,
				"deondahlia",
				[
					{text: "Helped with adding Pheonix and Edgeworth to Enough's Background.\n"},
					{text: "also Moral Support", offset: {x: 0, y: -15}},

				],
				0x9999FF,
			),
			new CreditBlob(
				"Asheishere",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"asheishere",
				[{text: "Moral Support"}],
				0xFF9933,
			),
			new CreditBlob(
				"The Spectators",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"spectators",
				[
					{text: "Spook, Macaroni Boi, Hunter, Sugar, Mango, Ara-Fox, Lespede, Memermaster, Amelia"},
					{
						text: (
							"Thanks for watching the mod dev! Your presence in the server is greatly appreciated, " +
							"we love you guys lol."
						)
					}
				],
				0xFFFFFF
			),
		],
	},
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Former Team",
		members: [
			new CreditBlob(
				"MunchiMango",
				[Role.PROGRAMMER],
				Representation.ICON,
				"munchimango",
				[{text: "Ex-Coder"}],
				0xF59F33,
				["https://www.reddit.com/user/MunchiMango/"]
			),
			new CreditBlob(
				"StellarKirbo",
				[Role.EX_DIRECTOR],
				Representation.ICON,
				"stellarkirbo",
				[{text: "Ex-Director"}],
				0x66FF66
			),
			new CreditBlob(
				"CoolingTool",
				[Role.PROGRAMMER],
				Representation.ICON,
				"blank",
				[{text: ""}],
				0xFFFFFF
			),
		],
	},
	//changed icons to blank due to the fact I don't think we're making icons for them
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Psych Engine Extra",
		members: [
			new CreditBlob(
				"Starmapo",
				[Role.PROGRAMMER, Role.ARTIST],
				Representation.ICON,
				"star",
				[{text: "Main Programmer/Artist of Psych Engine Extra"}],
				0xFFDE46,
				["https://github.com/Starmapo"]
			),
			new CreditBlob(
				"KadeDev",
				[Role.PROGRAMMER],
				Representation.ICON,
				"kade",
				[{text: "Kade Engine Creator (Some code taken from there) [NON-AFFILIATED]"}],
				0x64A250,
				["https://twitter.com/kade0912"]
			),
			new CreditBlob(
				"Leather128",
				[Role.PROGRAMMER],
				Representation.ICON,
				"leather",
				[{text: "Leather Engine Creator (Some code taken from there) [NON-AFFILIATED]"}],
				0x01A1FF,
				["https://www.youtube.com/channel/UCbCtO-ghipZessWaOBx8u1g"]
			),
			new CreditBlob(
				"srPerez",
				[Role.PROGRAMMER], // taken from twitter bio
				Representation.ICON,
				"perez",
				[{text: "Original 6K+ designs [NON-AFFILIATED]"}],
				0xFBCA20,
				["https://twitter.com/NewSrPerez"]
			),
			new CreditBlob(
				"GitHub Contributors",
				[Role.PROGRAMMER],
				Representation.ICON,
				"github",
				[{text: "Pull Requests to Psych Engine [NON-AFFILIATED]"}],
				0x546782,
				["https://github.com/ShadowMario/FNF-PsychEngine/pulls"]
			),
		],
	},
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Psych Engine Team",
		members: [
			new CreditBlob("Shadow Mario", [Role.PROGRAMMER], Representation.ICON, "shadowmario", [{text: "Main Programmer of Psych Engine"}], 0x444444, ["https://twitter.com/Shadow_Mario_"]),
			new CreditBlob("RiverOaken", [Role.ANIMATOR, Role.ARTIST], Representation.ICON, "river", [{text: "Main Artist/Animator of Psych Engine"}], 0xB42F71, ["https://twitter.com/RiverOaken"]),
			new CreditBlob("shubs", [Role.PROGRAMMER], Representation.ICON, "shubs", [{text: "Additional Programmer of Psych Engine"}], 0x5E99DF, ["https://twitter.com/yoshubs"]),
			// Originally bbp sat in an explicit ex-programmer category, but i mean the flavor text should be enough to signal that
			new CreditBlob("bb-panzu", [Role.PROGRAMMER], Representation.ICON, "bb", [{text: "Ex-Programmer of Psych Engine"}], 0x3E813A, ["https://twitter.com/bbsub3"]),
		],
	},
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Engine Contributors",
		members: [
			new CreditBlob("iFlicky", [Role.COMPOSER], Representation.ICON, "flicky", [{text: "Composer of Psync and Tea Time; made the dialog sounds"}], 0x9E29CF, ["https://twitter.com/flicky_i"]),
			new CreditBlob("SqirraRNG", [Role.PROGRAMMER], Representation.ICON, "sqirra", [{text: "Crash handler and base code for the chart editor's waveform"}], 0xE1843A, ["https://twitter.com/gedehari"]),
			new CreditBlob("PolybiusProxy", [Role.PROGRAMMER], Representation.ICON, "proxy", [{text: ".mp4 video loader extension"}], 0xDCD294, ["https://twitter.com/polybiusproxy"]),
			new CreditBlob("KadeDev", [Role.PROGRAMMER], Representation.ICON, "kade", [{text: "Fixed some cool stuff in the chart editor and other PRs"}], 0x64A250, ["https://twitter.com/kade0912"]),
			new CreditBlob("Keoiki", [Role.ARTIST], Representation.ICON, "keoiki", [{text: "Note splash animations"}], 0xD2D2D2, ["https://twitter.com/Keoiki_"]),
			new CreditBlob("Nebula the Zorua", [Role.PROGRAMMER], Representation.ICON, "nebula", [{text: "LuaJIT fork and some Lua reworks"}], 0x7D40B2, ["https://twitter.com/Nebula_Zorua"]),
			new CreditBlob("Smokey", [Role.PROGRAMMER], Representation.ICON, "smokey", [{text: "Spritemap texture support"}], 0x483D92, ["https://twitter.com/Smokey_5_"]),
		],
	},
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		name: "Funkin' Crew",
		members: [
			new CreditBlob("ninjamuffin99", [Role.PROGRAMMER], Representation.ICON, "ninjamuffin99", [{text: "Programmer of Friday Night Funkin'"}], 0xCF2D2D, ["https://twitter.com/ninja_muffin99"]),
			new CreditBlob("PhantomArcade", [Role.ANIMATOR, Role.ARTIST], Representation.ICON, "phantomarcade", [{text: "Animator of Friday Night Funkin'"}], 0xFADC45, ["https://twitter.com/PhantomArcade3K"]),
			new CreditBlob("evilsk8r", [Role.ARTIST], Representation.ICON, "evilsk8r", [{text: "Artist of Friday Night Funkin'"}], 0x5ABD4B, ["https://twitter.com/evilsk8r"]),
			new CreditBlob("Kawai Sprite", [Role.COMPOSER], Representation.ICON, "kawaisprite", [{text: "Composer of Friday Night Funkin'"}], 0x378FC7, ["https://twitter.com/kawaisprite"]),
		],
	}
]; }


typedef RepresentationGroup = {
	/**
	 * Representation mode. Representation.PORTRAIT Implies members.length == 1. Implies. Not the other way round.
	 */
	representation:Representation,

	/**
	 * RepresentationGroups always exist as part of a PackedCreditGroup array. The element at this
	 * position in the flattened variant of this structure is equal to members[0], and this increasingly goes
	 * for all other members of the RepresentationGroup too.
	 */
	absIdxStart:Int,

	/**
	 * The people in this RepresentationGroup.
	 */
	members:Array<CreditBlob>,
}

typedef PackedCreditGroup = {
	/**
	 * Name of the credit group.
	 */
	name:String,
	/**
	 * The representation groups in this packed credit group.
	 */
	reprGroups:Array<RepresentationGroup>,
}

typedef PCGIndexStruct = {pcgIdx:Int, repgIdx:Int, memIdx:Int}


private class SidebarMemberData {
	public var yPaddingBelow:Float;
	public var yPaddingAbove:Float;
	public var finishableTweens:Array<FinishableVarTween>;

	public function new(yPaddingBelow:Float = 0.0, yPaddingAbove:Float = 0.0) {
		this.yPaddingBelow = yPaddingBelow;
		this.yPaddingAbove = yPaddingAbove;
		this.finishableTweens = [];
	}
}

typedef FinishableTweenOptions = {
	var ?onStart:Null<FlxTween->Void>;
	var ?onUpdate:Null<FlxTween->Void>;
	var ?onComplete:Null<FlxTween->Void>;
	var ?onlyUpdateOnComplete:Null<Bool>;
	var ?duration:Null<Float>;
	var ?ease:Null<EaseFunction>;
}

typedef FinishableTweenSetupInfo = {
	propStruct:Dynamic,
	?options:FinishableTweenOptions,
}


class CreditsSidebarMember extends FlxBasic {
	public var yPaddingBelow:Float;
	public var yPaddingAbove:Float;
	public var finishableTweens:Array<FinishableVarTween>;
	public var obj(default, null):FlxSprite;

	public function new(object:FlxSprite, yPaddingBelow:Float = 0.0, yPaddingAbove:Float = 0.0) {
		super();
		this.yPaddingBelow = yPaddingBelow;
		this.yPaddingAbove = yPaddingAbove;
		this.finishableTweens = [];
		this.obj = object;
	}

	public override function update(dt:Float) {
		obj.update(dt);
	}

	public override function draw() {
		obj.draw();
	}

	public override function destroy() {
		obj.destroy(); obj = null;
		finishableTweens.resize(0); finishableTweens = null;
	}
}

class CreditsSidebar extends FlxTypedGroup<CreditsSidebarMember> {
	private final SLIM_ENTRY_HEIGHT = 8;
	private final EXTENDED_ENTRY_HEIGHT = 38;
	private final ENTRY_PADDING_BELOW = 2.0;
	private final HIDDEN_ENTRY_X = -58;
	private final CO_PACKGROUP_ENTRY_X = -50;
	private final CO_REPGROUP_ENTRY_X = -42;
	private final ENTRY_SLIDE_DURATION:Float = 0.22;
	private final ENTRY_EXPAND_DURATION:Float = 0.08; // Also Contract duration
	private final ENTRY_ANIMATION_NAMES = [for (role in ROLES) role.animationName].concat(["unknown", "slim"]);

	private var selectedEntry:Int = -1;

	/**
	 * Not all elements in the sidebar correspond to a selectable person.
	 * This array has as many elements as there are people and maps them to their actual index in `members`.
	 */
	private var entryIdxToMemberIdxArray:Array<Int>;

	/**
	 * The member others should orient around.
	 */
	private var anchorMemberIdx:Int;

	private var owner:CreditsState;

	public override function new(owner:CreditsState) {
		super(0);

		this.owner = owner;

		entryIdxToMemberIdxArray = [];

		var frames = Paths.getSparrowAtlas("credits/sidebar");
		var curY:Float = SLIM_ENTRY_HEIGHT;
		for (group in owner.packedCreditGroups) {
			var text = new FlxText(-128, curY, 128, group.name, 12);
			add(new CreditsSidebarMember(text, 0, SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW));

			for (repGroup in group.reprGroups) {
				for (mem in repGroup.members) {
					var entry = new FlxSprite(HIDDEN_ENTRY_X, curY);
					entry.frames = frames;
					for (a in ENTRY_ANIMATION_NAMES) {
						entry.animation.addByNames(a, [a], 1, false);
					}
					entry.animation.play("slim");
					entry.color = mem.color;
					entry.origin.set(0, 0);

					entryIdxToMemberIdxArray.push(this.length);
					add(new CreditsSidebarMember(entry, SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW));

					curY += SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW;
				}
			}
			curY += 12;
		}

		anchorMemberIdx = 0;
	}

	public override function update(dt:Float) {
		// Each element has a vertical pushdown and pushup factor.
		super.update(dt);
		if (members.length == 0) {
			return;
		}

		for (i in new RevRange(anchorMemberIdx - 1, -1)) {
			var mem = members[i];
			var nxtMem = members[i + 1];
			mem.obj.y = nxtMem.obj.y - (mem.yPaddingBelow + nxtMem.yPaddingAbove);
		}
		for (i in (anchorMemberIdx + 1)...members.length) {
			var mem = members[i];
			var prvMem = members[i - 1];
			mem.obj.y = prvMem.obj.y + prvMem.yPaddingBelow + mem.yPaddingAbove;
		}
	}

	private function startEntryTweenlikes(entryIdx:Int, tweenlikeSetup:Array<FinishableTweenSetupInfo>) {
		startMemberTweenlikes(entryIdxToMemberIdxArray[entryIdx], tweenlikeSetup);
	}

	private function startMemberTweenlikes(memberIdx:Int, tweenlikeSetup:Array<FinishableTweenSetupInfo>) {
		var tarr = members[memberIdx].finishableTweens;
		for (t in tarr) {
			t.instaFinishAndCancel();
			//t.cancel(); // cancel alone breaks some stuff
		}
		tarr.resize(0);

		for (tsd in tweenlikeSetup) {
			var options:FinishableTweenOptions = tsd.options == null ? {} : tsd.options;
			// == true cause it can be null?
			var onComplete = options.onlyUpdateOnComplete == true ? options.onUpdate : options.onComplete;

			var t = FinishableVarTween.finTween(
				members[memberIdx],
				tsd.propStruct,
				options.duration == null ? ENTRY_SLIDE_DURATION : options.duration,
				{
					onStart: options.onStart,
					onUpdate: options.onUpdate,
					onComplete: onComplete,
					ease: options.ease,
				}
			);
			tarr.push(t);
		}
	}

	public function instantlyFinishTweens() {
		for (m in members) {
			for (t in m.finishableTweens) {
				t.instaFinishAndCancel();
			}
			m.finishableTweens.resize(0);
		}
	}

	public function setSelectedIndex(newIdx:Int) {
		var reprGroupChanged = false;
		var packedGroupChanged = false;
		// Remember: packedGroupChanged implies reprGroupChanged
		var initializing = selectedEntry == -1;

		var nloc = owner.memberIdxToPackedGroupIdx[newIdx];

		if (!initializing) {
			var oloc = owner.memberIdxToPackedGroupIdx[selectedEntry];
			packedGroupChanged = oloc.pcgIdx != nloc.pcgIdx;
			reprGroupChanged = packedGroupChanged || oloc.repgIdx != nloc.repgIdx;

			var entriesToRetreat:Array<Int> = [];
			var retreatX:Int = CO_REPGROUP_ENTRY_X;
			if (packedGroupChanged) {
				var oldPcg = owner.packedCreditGroups[oloc.pcgIdx];
				var _oldPcgLastReprGroup = oldPcg.reprGroups[oldPcg.reprGroups.length - 1];
				var oldPcgAbsStart = oldPcg.reprGroups[0].absIdxStart;
				var oldPcgAbsEnd = _oldPcgLastReprGroup.absIdxStart + _oldPcgLastReprGroup.members.length;

				// Make text of old pcg disappear
				var pcgTextIdx = entryIdxToMemberIdxArray[oldPcgAbsStart] - 1;
				members[pcgTextIdx].yPaddingBelow = members[pcgTextIdx].obj.height + 2;
				startMemberTweenlikes(
					pcgTextIdx,
					[
						{propStruct: {"obj.x": -128}},
						{propStruct: {yPaddingBelow: 0}, options: {ease: FlxEase.quadOut}},
					]
				);

				// Retreat all entries of old pcg
				retreatX = HIDDEN_ENTRY_X;
				entriesToRetreat = [for (i in oldPcgAbsStart...oldPcgAbsEnd) i];
			} else if (reprGroupChanged) {
				var oldRepg = owner.packedCreditGroups[oloc.pcgIdx].reprGroups[oloc.repgIdx];
				// Retreat entries of old repr group go to common packgroup level
				retreatX = CO_PACKGROUP_ENTRY_X;
				entriesToRetreat = [for (i in (oldRepg.absIdxStart)...(oldRepg.absIdxStart + oldRepg.members.length)) i];
			}
			for (i in entriesToRetreat) {
				if (i != selectedEntry) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": retreatX}}]);
				}
			}

			// Move old entry back more complicatedly
			var prevMember = members[entryIdxToMemberIdxArray[selectedEntry]];
			prevMember.yPaddingBelow = EXTENDED_ENTRY_HEIGHT + ENTRY_PADDING_BELOW;
			prevMember.obj.animation.play("slim");
			prevMember.obj.scale.y = (cast(EXTENDED_ENTRY_HEIGHT, Float) / SLIM_ENTRY_HEIGHT);
			startEntryTweenlikes(
				selectedEntry,
				[
					{propStruct: {"obj.x": retreatX}, options:    {ease: FlxEase.quartOut}},
					{
						propStruct: {"obj.scale.y": 1.0, yPaddingBelow: SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW},
						options:    {duration: ENTRY_EXPAND_DURATION}
					},
				]
			);
		} else {
			reprGroupChanged = true;
			packedGroupChanged = true;
		}

		var newPcg = owner.packedCreditGroups[nloc.pcgIdx];
		var newRepg = newPcg.reprGroups[nloc.repgIdx];
		var firstNewRepg = newPcg.reprGroups[0];
		var lastNewRepg = newPcg.reprGroups[newPcg.reprGroups.length - 1];
		if (packedGroupChanged) {
			// Index hackery; this is the group name text of the new packed group.
			// Make text slide in
			var pcgTextIdx = entryIdxToMemberIdxArray[firstNewRepg.absIdxStart] - 1;
			var slidingTextMem = members[pcgTextIdx];
			slidingTextMem.yPaddingBelow = 0.0;
			startMemberTweenlikes(
				pcgTextIdx,
				[
					{propStruct: {"obj.x": 0}},
					{propStruct: {yPaddingBelow: slidingTextMem.obj.height + 2}, options: {ease: FlxEase.quadIn}},
				]
			);

			// Get all entries that should be at the common packgroup level on it
			for (i in (firstNewRepg.absIdxStart)...(lastNewRepg.absIdxStart + lastNewRepg.members.length)) {
				if (i < newRepg.absIdxStart || i >= (newRepg.absIdxStart + newRepg.members.length)) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": CO_PACKGROUP_ENTRY_X}}]);
				}
			}
		}
		if (reprGroupChanged) {
			// Tween all entries in the current reprgroup that aren't the selected entry onto the reprgroup level
			for (i in (newRepg.absIdxStart)...(newRepg.absIdxStart + newRepg.members.length)) {
				if (i != newIdx) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": CO_REPGROUP_ENTRY_X}}]);
				}
			}
		}

		// Finally, tween the grand star of the show to 0, have its animation pop up and make it flow to the absolute y
		var newAnimation = (
			newRepg.members[nloc.memIdx].roles.length > 0 ?
				newRepg.members[nloc.memIdx].roles[0].animationName :
				"unknown"
		);
		var member = members[entryIdxToMemberIdxArray[newIdx]];
		member.obj.animation.play(newAnimation);
		member.obj.scale.y = cast(SLIM_ENTRY_HEIGHT, Float) / EXTENDED_ENTRY_HEIGHT;
		member.yPaddingBelow = ENTRY_PADDING_BELOW + SLIM_ENTRY_HEIGHT;
		startEntryTweenlikes(
			newIdx,
			[
				{propStruct: {"obj.x": 0}, options:    {ease: FlxEase.quartOut}},
				{
					propStruct: {
						"obj.y": FlxG.height / 4,
						"obj.scale.y": 1.0,
						yPaddingBelow: EXTENDED_ENTRY_HEIGHT + ENTRY_PADDING_BELOW,
					},
					options:    {duration: ENTRY_EXPAND_DURATION}
				},
			]
		);

		selectedEntry = newIdx;
		anchorMemberIdx = entryIdxToMemberIdxArray[newIdx];

		if (initializing) {
			instantlyFinishTweens();
		}
	}
}


abstract class RepresentationSpriteGroup extends FlxSpriteGroup {
	private var owner:CreditsState;
	private var effectUpdaters:Array<QuoteEffectUpdater>;
	var quotePlacer:QuotePlacer;

	public function new(owner:CreditsState) {
		super();

		this.effectUpdaters = [];
		this.owner = owner;

		var quoteSlots:Map<QuoteLocation, QuoteSlot> = [
			QUOTE_FIELD => new QuoteFieldQuoteSlot(owner),
			BEHIND_NAME => new BehindNameQuoteSlot(owner),
		];
		this.quotePlacer = new QuotePlacer(owner.measurerCache, quoteSlots, "credits/quote_images/");
	}

	private function addSpritesForName(
		name:String, producer:NameSpriteProducer, slot:CreditsQuoteLocation = CreditsQuoteLocation.BEHIND_NAME
	) {
		var slot = quotePlacer.quoteSlots[slot];
		// var tmp = new FlxSprite(slot.currentPosition.x, slot.currentPosition.y);
		if (slot.shouldContinue()) {
			var nameSprite = producer.makeName(slot.currentPosition.x, slot.currentPosition.y, name);
			add(nameSprite);
			slot.advanceBySprite(nameSprite);
		}
		// CoolUtil.InflatedPixelSpriteExt.makeInflatedPixelGraphic(tmp, 0xFFFF0000, 256, 2);
		// add(tmp);
	}

	public override function destroy() {
		forEach((spr) -> { FlxTween.cancelTweensOf(spr); });
		effectUpdaters = null;
		super.destroy();
	}

	public override function update(dt:Float) {
		super.update(dt);
		for (u in effectUpdaters) {
			u.update(dt);
		}
	}

	/**
	 * Re-and dehighlights a repgroup's members when he representation group has
	 * not changed, but the selected member has.
	 * `oldIdx` may be -1.
	 */
	public abstract function newIndex(oldIdx:Int, newIdx:Int):Void;
	public abstract function getPillarY(memberIdx:Int):Float;
}

class PortraitRepresentationSpriteGroup extends RepresentationSpriteGroup {
	public function new(rg:RepresentationGroup, owner:CreditsState) {
		super(owner);

		var person = rg.members[0];
		var portrait = new FlxSprite(person.offset.x, person.offset.y, person.image);
		portrait.antialiasing = true;
		portrait.pixelPerfectRender = true;
		add(portrait);

		quotePlacer.quoteSlots[QUOTE_FIELD].setInitial(520, 148);
		quotePlacer.quoteSlots[BEHIND_NAME].setInitial(526, 128);
		addSpritesForName(person.name, person.nameSpriteProducer);
		this.effectUpdaters = quotePlacer.addSpritesFromQuotes(person.quotes, this, FlxG.width - 520 - 32);
	}

	// Getting a new index in portrait groups makes no sense, ignore.
	public function newIndex(oldIdx:Int, newIdx:Int) {}
	public function getPillarY(_:Int):Float {
		return 128;
	}
}

class IconRepresentationSpriteGroup extends RepresentationSpriteGroup {
	private var memberStart:Map<Int, Int>;
	// We found it: The worst variable name.
	// "creditsMemberIdxAsInTeamMemberToActualSpriteGroupMemberMapIdx" would probably be
	// better but i dont care

	public function new(rg:RepresentationGroup, owner:CreditsState) {
		super(owner);

		memberStart = new Map<Int, Int>();
		for (i => person in rg.members) {
			memberStart[i] = length;
			var yHeadstart = i * 180;
			var leftStart = 164 - owner.getXDifferenceOnSlope(yHeadstart);

			var icon:FlxSprite = new FlxSprite(
				leftStart + person.offset.x, 96 + yHeadstart + person.offset.y, person.image
			);
			icon.alpha = 0.4;
			add(icon);

			var textX = 180 + leftStart - owner.getXDifferenceOnSlope(64);
			var nameX = 180 + leftStart;
			quotePlacer.quoteSlots[QUOTE_FIELD].setInitial(textX, 160 + yHeadstart);
			quotePlacer.quoteSlots[BEHIND_NAME].setInitial(nameX, 144 + yHeadstart);
			addSpritesForName(person.name, person.nameSpriteProducer);
			this.effectUpdaters = quotePlacer.addSpritesFromQuotes(person.quotes, this, Math.max(100, FlxG.width - textX - 20), 5);
		}
	}

	public function newIndex(oldIdx:Int, newIdx:Int) {
		if (oldIdx != -1) {
			members[memberStart[owner.memberIdxToPackedGroupIdx[oldIdx].memIdx]].alpha = 0.4;
		}
		members[memberStart[owner.memberIdxToPackedGroupIdx[newIdx].memIdx]].alpha = 1.0;
	}

	public function getPillarY(localMemberIdx:Int):Float {
		return 144 + localMemberIdx * 180;
	}
}

class EdgeCutoffShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		#define uv openfl_TextureCoordv

		uniform float angle;

		// Imagine simple slopes in the end parts of the sprite with the classic
		// formula m*x + b;
		// Simply calculate whether this pixel is under/over that slope, and alpha
		// out accordingly.
		// This only works when the sprite is rotated in a 0..90 or 180..270 deg angle
		// Too bad!

		void main() {
			float ar_correction = openfl_TextureSize.x / openfl_TextureSize.y;
			float m = tan(radians(angle)) * ar_correction;
			if (
				( (uv.x * m)              > (1.0 - uv.y)) ||
				(((uv.x * m) + (1.0 - m)) < (1.0 - uv.y))
			) {
				gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
			} else {
				gl_FragColor = flixel_texture2D(bitmap, uv);
			}
		}
	')

	public function new(angle:Float) {
		super();
		this.angle.value = [angle];
	}
}

/**
 * The slanted text things displaying links and member roles.
 */
class Pillar extends FlxSpriteGroup {
	public var bg:FlxSprite;
	public var evenedY(default, null):Float;

	public function new(width:Int, height:Int, angle:Float) {
		super();

		bg = new FlxSprite(0, 0).makeGraphic(width, height, FlxColor.BLACK);
		bg.origin.set(0, 0);
		bg.angle = angle;
		bg.shader = new EdgeCutoffShader(angle);
		add(bg);

		evenedY = Math.cos(d2r(angle)) * bg.height;
	}

	public function clearContents() {
		for (i in 1...members.length) {
			if (members[i] != null) {
				members[i].destroy();
				members[i] = null;
			}
		}
	}
}


class CreditsState extends MusicBeatState {
	private final HOLD_SCROLL_TRIGGER_TIME = 0.4;
	private final HOLD_TIME_INI = 0.18;
	private final HOLD_TIME_HORIZON = 0.09;
	private final ELEMENT_ANGLE = 5.625;
	private final ROLE_PILLAR_WIDTH = 186;
	private final LINK_PILLAR_WIDTH = 50;
	private final PILLAR_HEIGHT = 768;

	/**
	 * Index of selected member. If -1, state has just been created.
	 */
	var selectedMemberIdx:Int;

	/**
	 * Index of selectected link.
	 */
	var selectedLinkIdx:Int;
	var availableLinks:Array<{link:String, screenLocation:PointStruct}>;
	var linkSelectorStripeTopYLoss:Int;
	var linkSelectorStripe:FlxSprite;
	var linkSelectorStripeDissipator:SpriteDissipator;

	/**
	 * Group to place the custom representation sprite groups in.
	 */
	var representationSpriteGroupContainer:FlxGroup;

	/**
	 * Sprite group containing sprites for the displayed people.
	 */
	var representationSpriteGroup:Null<RepresentationSpriteGroup>;

	/**
	 * Slightly translucent black sprite to make text better readable.
	 */
	var backgroundDarkener:FlxSprite;

	/**
	 * Group containing the role pillar thing. First element is the background sprite,
	 * the rest is dynamic and based on the selected person's roles.
	 */
	var rolePillar:Pillar;

	/**
	 * Like the role pillar, just for the link icons.
	 */
	var linkPillar:Pillar;

	var sidebar:CreditsSidebar;

	public var measurerCache:TextMeasurerCache;

	public var packedCreditGroups:Array<PackedCreditGroup>;

	/**
	 * Maps a specific person to their packed credits group's index and sub-index therein.
	 */
	public var memberIdxToPackedGroupIdx:Array<PCGIndexStruct>;

	private var holdTimer:HoldTimer;

	// This all could be a substate but that comes with its own annoyances.
	// Both of these are just spritegroups so i can run .visible on them with ease lol
	private var linkOpenerOverlay:FlxSpriteGroup;
	private var linkOpenerOverlayArrows:FlxSpriteGroup;
	private var linkOpenerOverlayShown:Bool;
	private var linkOpenerOverlayText:FlxText;

	public override function create() {
		super.create();

		selectedMemberIdx = -1;
		selectedLinkIdx = -1;
		availableLinks = [];

		packedCreditGroups = [];
		memberIdxToPackedGroupIdx = [];
		var absIdx = 0;
		for (cgIdx => group in makeCredits()) {
			var curReprGroups:Array<RepresentationGroup> = [];
			var membCopy = group.members.copy();
			// ArraySort.sort(membCopy, (a, b) -> a.representation.priority - b.representation.priority);
			var memIdx = 0;
			while (memIdx < membCopy.length) {
				var representation = membCopy[memIdx].representation;
				var slc:Array<CreditBlob> = [];
				for (i in 0...representation.memberDisplayCount) {
					if ((memIdx >= membCopy.length) || (membCopy[memIdx].representation != representation)) {
						break;
					}
					slc.push(membCopy[memIdx]);
					memberIdxToPackedGroupIdx.push({pcgIdx: cgIdx, repgIdx: curReprGroups.length, memIdx: i});
					memIdx += 1;
				}
				curReprGroups.push({representation: representation, absIdxStart: absIdx, members: slc});
				absIdx += slc.length;
			}
			packedCreditGroups.push({name: group.name, reprGroups: curReprGroups});
		}

		var bg = new FlxSprite(0, 0).loadGraphic(Paths.image("credits/background"));
		add(bg);

		var topLetterbox = new FlxSprite().makeGraphic(1536, 384, FlxColor.BLACK, false);
		var bottomLetterbox = new FlxSprite().makeGraphic(1536, 384, FlxColor.BLACK, false);
		backgroundDarkener = new FlxSprite().makeGraphic(1024, 1024, FlxColor.BLACK, false);

		for (thing in [topLetterbox, bottomLetterbox, backgroundDarkener]) {
			thing.antialiasing = true;
			thing.angle = ELEMENT_ANGLE;
		}
		topLetterbox.y = -320;
		bottomLetterbox.setPosition(-24, 658);

		backgroundDarkener.alpha = 0.8;

		representationSpriteGroupContainer = new FlxGroup(1);
		representationSpriteGroup = null;
		measurerCache = new TextMeasurerCache();
		sidebar = new CreditsSidebar(this);

		var linkOpenerOverlayDimmer = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		linkOpenerOverlayDimmer.alpha = 0.64;
		linkOpenerOverlayDimmer.visible = false;

		var linkOpenerOverlayBackground = new FlxSprite().makeGraphic(960, 420, FlxColor.BLACK);
		linkOpenerOverlayBackground.angle = 8;
		linkOpenerOverlayBackground.shader = new EdgeCutoffShader(8);
		linkOpenerOverlayBackground.screenCenter();

		linkOpenerOverlayArrows = new FlxSpriteGroup(2);
		for (o in [
			{n: "left",  x: linkOpenerOverlayBackground.x - 24},
			{n: "right", x: linkOpenerOverlayBackground.x + linkOpenerOverlayBackground.width - 16},
		]) {
			var f = new FlxSprite(o.x);
			f.frames = Paths.getSparrowAtlas("menu_arrows");
			f.frame = f.frames.getByName('long_${o.n}');
			f.screenCenter(Y);
			linkOpenerOverlayArrows.add(f);
		}

		linkOpenerOverlayText = new FlxText(0, 0, 720);
		linkOpenerOverlayText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, FlxTextAlign.CENTER);
		linkOpenerOverlayText.visible = false;

		linkOpenerOverlay = new FlxSpriteGroup();
		linkOpenerOverlay.add(linkOpenerOverlayDimmer);
		linkOpenerOverlay.add(linkOpenerOverlayBackground);
		linkOpenerOverlay.add(linkOpenerOverlayArrows);
		linkOpenerOverlay.add(linkOpenerOverlayText);
		linkOpenerOverlay.visible = false;

		rolePillar = new Pillar(ROLE_PILLAR_WIDTH, PILLAR_HEIGHT, ELEMENT_ANGLE);
		linkPillar = new Pillar(LINK_PILLAR_WIDTH, PILLAR_HEIGHT, ELEMENT_ANGLE);

		linkSelectorStripeTopYLoss = 1; // Whatever, hardcoded. I am overengineering this 32px strip shut uuuuuup
		// Math.floor(Math.sin(d2r(ELEMENT_ANGLE)) * 32);
		linkSelectorStripe = new FlxSprite().makeGraphic(6, 32 + linkSelectorStripeTopYLoss, FlxColor.WHITE);
		linkSelectorStripe.origin.set(0, 0);
		linkSelectorStripe.angle = ELEMENT_ANGLE;
		linkSelectorStripe.alpha = 0.4;
		linkSelectorStripe.visible = false;
		linkSelectorStripe.shader = new EdgeCutoffShader(ELEMENT_ANGLE);

		linkSelectorStripeDissipator = new SpriteDissipator(linkSelectorStripe, 0.48, 0.32, 4);
		linkSelectorStripeDissipator.direction = 270;
		linkSelectorStripeDissipator.velocity = 22.0;
		linkSelectorStripeDissipator.initialDisplacement = 4;
		for (sprite in linkSelectorStripeDissipator.group.members) {
			sprite.shader = new EdgeCutoffShader(ELEMENT_ANGLE);
		}

		add(backgroundDarkener);
		add(bottomLetterbox);
		add(topLetterbox);
		add(representationSpriteGroupContainer);
		add(sidebar);
		add(rolePillar);
		add(linkPillar);
		add(linkSelectorStripeDissipator.group);
		add(linkSelectorStripe);
		add(linkOpenerOverlay);

		holdTimer = new HoldTimer(HOLD_SCROLL_TRIGGER_TIME, HOLD_TIME_INI, HOLD_TIME_HORIZON, 0.5);
		holdTimer.listen(controls.ui_downP, controls.ui_down, changeDisplayedEntry, 1);
		holdTimer.listen(controls.ui_upP, controls.ui_up, changeDisplayedEntry, -1);
		linkOpenerOverlayShown = false;

		// initial display. Cheaty since -1 + 1 = 0 so the first entry is displayed
		changeDisplayedEntry(1);
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (FlxG.sound.music.volume < 0.7) {
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		linkSelectorStripeDissipator.update(elapsed);

		if (linkOpenerOverlayShown) {
			if (controls.ACCEPT) {
				CoolUtil.browserLoad(availableLinks[selectedLinkIdx].link);
				linkOpenerOverlayShown = false;
				linkOpenerOverlay.visible = false;
				return;
			} else if (controls.BACK) {
				linkOpenerOverlayShown = false;
				linkOpenerOverlay.visible = false;
				return;
			}

			if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
				changeSelectedLink(controls.UI_LEFT_P ? -1 : 1);
				setLinkOpenerOverlayText();
			}

			return;
		}

		if (controls.ACCEPT) {
			if (selectedLinkIdx >= 0 && selectedLinkIdx < availableLinks.length) {
				linkOpenerOverlayShown = true;
				setLinkOpenerOverlayText();
				linkOpenerOverlay.visible = true;
				linkOpenerOverlayArrows.visible = availableLinks.length > 1;
				return;
			}
		}
		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		holdTimer.update(elapsed);

		if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
			changeSelectedLink(controls.UI_LEFT_P ? -1 : 1);
		}

	}

	private function reloadRepresentationSpriteGroup(rg:RepresentationGroup) {
		// Not doing this will leak memory terrifyingly fast
		if (representationSpriteGroupContainer.length > 0) {
			representationSpriteGroupContainer.members[0].destroy();
			representationSpriteGroupContainer.clear();
		}

		representationSpriteGroup = Type.createInstance(rg.representation.representationGroupClass, [rg, this]);
		representationSpriteGroupContainer.add(representationSpriteGroup);
	}

	private function changeDisplayedEntry(by:Int) {
		var newSelectedMemberIdx = CoolUtil.wrapModulo(selectedMemberIdx + by, memberIdxToPackedGroupIdx.length);
		var shouldReloadRepresentationGroup = false;
		var shouldChangeRepresentationMode = false;
		var oldSelectedMemberidx = selectedMemberIdx;

		var newLocation:PCGIndexStruct = memberIdxToPackedGroupIdx[newSelectedMemberIdx];
		var newPCG:PackedCreditGroup = packedCreditGroups[newLocation.pcgIdx];
		var newRG:RepresentationGroup = newPCG.reprGroups[newLocation.repgIdx];
		var oldLocation:Null<PCGIndexStruct> = null;
		var oldPCG:Null<PackedCreditGroup> = null;
		var oldRG:Null<RepresentationGroup> = null;

		if (oldSelectedMemberidx != -1) {
			oldLocation = memberIdxToPackedGroupIdx[oldSelectedMemberidx];
			oldPCG = packedCreditGroups[oldLocation.pcgIdx];
			oldRG = oldPCG.reprGroups[oldLocation.repgIdx];

			shouldReloadRepresentationGroup = (
				oldLocation.pcgIdx != newLocation.pcgIdx || oldLocation.repgIdx != newLocation.repgIdx
			);
			shouldChangeRepresentationMode = oldRG.representation != newRG.representation;
		} else {
			shouldReloadRepresentationGroup = true;
			shouldChangeRepresentationMode = true;
		}

		sidebar.setSelectedIndex(newSelectedMemberIdx);

		if (shouldChangeRepresentationMode) {
			changeRepresentationMode(newRG.representation);
		}
		if (shouldReloadRepresentationGroup) {
			reloadRepresentationSpriteGroup(newRG);
			representationSpriteGroup.newIndex(-1, newSelectedMemberIdx);
		} else {
			representationSpriteGroup.newIndex(selectedMemberIdx, newSelectedMemberIdx);
		}

		updatePillarsAndLinks(newSelectedMemberIdx);

		selectedMemberIdx = newSelectedMemberIdx;
	}

	private function changeRepresentationMode(newMode:Representation) {
		switch (newMode) {
		// For the backgroundDarkener i could certainly do trigonometry and find the perfect
		// new position considering its angle but nah
		case Representation.ICON:
			backgroundDarkener.setPosition(284, -40);
		case Representation.PORTRAIT:
			backgroundDarkener.setPosition(460, -20);
		}
	}

	private function updatePillarsAndLinks(newMemberIndex:Int) {
		// Logic kinda breaks down here again. Oh well.
		var mem = getMemberByIndex(newMemberIndex);

		var desiredY = representationSpriteGroup.getPillarY(memberIdxToPackedGroupIdx[newMemberIndex].memIdx);
		var linkY = mem.links.length > 0 ? desiredY : -1;
		rolePillar.clearContents();
		linkPillar.clearContents();
		rolePillar.setPosition(1152 - getXDifferenceOnSlope(desiredY), desiredY - rolePillar.evenedY);
		linkPillar.setPosition(1152 - LINK_PILLAR_WIDTH - 8 - getXDifferenceOnSlope(linkY), linkY - linkPillar.evenedY);

		var lastY:Float = rolePillar.evenedY;
		var estimatedAvailableSpace = Std.int((rolePillar.evenedY - 4.0) / (32.0 + 4.0));
		for (i in new RevRange(FlxMath.minInt(estimatedAvailableSpace, mem.roles.length - 1), -1)) {
			// 1st role tends to be the most important one and people read from top-to-bottom 99%
			// of the time, so reverse these
			var role = mem.roles[i];
			var icon = new FlxSprite(4, lastY - (4.0 + 32.0));
			icon.x = -getXDifferenceOnSlope(icon.y);
			icon.frames = Paths.getSparrowAtlas("credits/role_icons");
			icon.frame = icon.frames.getByName(role.animationName);

			var text = new FlxText(0, 0, 0, role.displayString, 16);
			text.y = icon.y + ((icon.height - text.height) / 2);
			text.x = (4 + icon.width) - getXDifferenceOnSlope(text.y);

			lastY = icon.y; // gotta do this before as FlxSpriteGroup modifies its members' positions
			rolePillar.add(icon);
			rolePillar.add(text);
		}

		availableLinks.resize(0);
		lastY = linkPillar.evenedY;
		for (i in 0...FlxMath.minInt(estimatedAvailableSpace, mem.links.length)) {
			var linkInfo = mem.links[i];
			var y = lastY - (4.0 + 32.0);
			lastY = y;
			var icon = new FlxSprite((LINK_PILLAR_WIDTH - 32 - 6) - getXDifferenceOnSlope(y), y);
			icon.frames = Paths.getSparrowAtlas("credits/link_icons");
			icon.frame = icon.frames.getByName(linkInfo.iconName);
			linkPillar.add(icon);
			availableLinks.push(
				{link: linkInfo.link, screenLocation: {x: icon.x, y: icon.y}}
			);
		}

		setSelectedLink(availableLinks.length > 0 ? 0 : -1);
	}

	private function setSelectedLink(idx:Int) {
		if (idx < 0) {
			selectedLinkIdx = -1;
			linkSelectorStripe.visible = linkSelectorStripeDissipator.active = false;
			return;
		}

		selectedLinkIdx = idx;
		var link = availableLinks[idx];
		linkSelectorStripe.setPosition(
			link.screenLocation.x - linkSelectorStripe.width - 2.0,
			link.screenLocation.y - linkSelectorStripeTopYLoss
		);
		linkSelectorStripe.visible = linkSelectorStripeDissipator.active = true;
	}

	private function changeSelectedLink(by:Int) {
		if (availableLinks.length == 0) {
			setSelectedLink(-1);
		} else {
			setSelectedLink(CoolUtil.wrapModulo(selectedLinkIdx + by, availableLinks.length));
		}
	}

	private function setLinkOpenerOverlayText() {
		var visit = controls.getFirstFormattedInputName(Controls.Control.ACCEPT);
		var cancel = controls.getFirstFormattedInputName(Controls.Control.BACK);
		linkOpenerOverlayText.text = (
			'Visit?:\n${availableLinks[selectedLinkIdx].link}\n\n[$visit] Yes - [$cancel] Cancel'
		);
		linkOpenerOverlayText.screenCenter();
	}

	/**
	 * Object movement on the X axis for keeping it aligned with that tilted
	 * text background view thing
	 */
	public function getXDifferenceOnSlope(distance:Float) {
		return (distance * Math.sin(d2r(ELEMENT_ANGLE))) / Math.cos(d2r(ELEMENT_ANGLE));
	}

	/**
	 * Returns a member's CreditBlob by absolute index, no hassle with the index struct.
	 */
	public inline function getMemberByIndex(idx:Int):Null<CreditBlob> {
		var idxStruct = memberIdxToPackedGroupIdx[idx];
		return packedCreditGroups[idxStruct.pcgIdx].reprGroups[idxStruct.repgIdx].members[idxStruct.memIdx];
	}
}
