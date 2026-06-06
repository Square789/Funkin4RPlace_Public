
import Quotes.TypeoutQuoteEffect;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.NumTween;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.Assets;
import openfl.media.Sound;

import CoolUtil.PointStruct;
import Quotes.FlickerQuoteEffect;
import Quotes.Quote;
import Quotes.QuoteArgs;
import Quotes.QuoteEffectUpdater;
import Quotes.QuotePlacer;
import Quotes.QuoteSlot;
import Quotes.convertQuoteArgsFromJson;
import TextHelper.TextMeasurerCache;

using CoolUtil.InflatedPixelSpriteExt;


final LETTERBOX_HEIGHT = 92;
final LOREBOOK_SCALE = 2;
final PAGE_WIDTH = 180 * LOREBOOK_SCALE;
final PAGE_HEIGHT = 220 * LOREBOOK_SCALE;
final PAGE_START_OFFSET_X = 53.0 * LOREBOOK_SCALE;
final PAGE_START_OFFSET_Y = 24.0 * LOREBOOK_SCALE;

final CONTENT_FADE_FRAME_COUNT = 3;
final CONTENT_FADE_HEADSTART_FRAMES = 1;
final ANIMATION_FRAME_COUNT_OPENING = 10;
final ANIMATION_FRAME_COUNT_CLOSING = 10;
final ANIMATION_FRAME_COUNT_PAGEFLIP_FORWARD = 7;
final ANIMATION_FRAME_COUNT_PAGEFLIP_BACKWARD = 7;
final FASTFLIP_COOLDOWN = 0.21;
final SPOILER_COOLDOWN = 3.2;

var SPREADS:Array<Array<QuoteArgs>> = [
	
	// test text made by square, keeping this literally only for copy and paste purposes
	// [
	// 	{text: "Hello world", color: 0xAA0000FF},
	// 	{text: "And so on", color: 0xAA0000FF},
	// 	{text: "And so forth", color: 0xAA0000FF},
	// 	{image: {name: "scrooge"}},
	// ],
	// [
	// 	{text: "Second spread real", color: 0xAA0000FF},
	// 	{text: "\n\n\n\n\n\n\n\n\n\n\n\n\n\n"},
	// 	{text: "This meme is pretty infamous for being one of the scariest memes of the Internet (which is true), along with the Trollge meme, due to an illustration of the beloved The Incredibles character turning bizarre and the disturbing topics that appear in the meme (depending on the meme). The \"extended\" versions are even scarier with more disturbing images(which, for some reason, does have nothing to do with Mr. Incredible at all. The scare factor is lower if you're used to some horror content for some time.", color: 0xFFA0002F},
	// ],
	// [
	// 	{text: "and more and more and more and more", color: 0xFF0000AA},
	// 	{textSize: 16, text: "Lorem impsum dolor sit amet, consecitur issum dingens irgendwas\nThe quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. Is the lazy dog stupid why does it just let that happen to him show some spine man unbelievable. GNU General public license version -3.141592 Permission is hereby granted, to any person obtaining a copy of the software, to act in the spirit of my late grandmother to do with the software as they please or not please any and all rights reserved to nobody and also you cannot use the software to be mean on the internet okay that's just not cool thanks.\nWe really need some more text in here to get to the other side. Like the chicken, you know from uuuh Crossy Road do you remember that? were you alive for that? I am a fossil holy shit like actually turning 24 later this year man i should be booking my retirement home reservations already.", color: 0xAA0000FF}
	// ],
	// [
	// 	{text: "Hi, i forcibly break the page!", slotControl: ["PAGEBREAK"], color: 0xFF030303},
	// 	{text: "And I am on the next one (hopefully)", postPadding: 16, color: 0xFF030303},
	// 	{text: "Hi, the following line is tagged with IGNORE_ADVANCE", color: 0xFF030303},
	// 	{text: "_______________", slotControl: ["IGNORE_ADVANCE"], color: 0xFF030303},
	// 	{text: "and i'm on that line!", textSize: 12, color: 0xAA0004FF},
	// 	{image: {name: "scrooge", scale: 0.5}, offset: {x: -320.0, y: -100.0}},
	// 	{text: "fucking badass teal-palette image of scrooge mcduck", offset: {x: -320.0, y: 0.0}, textSize: 16, color: 0xFF1F9FBF, widthOverride: 260.0},
	// 	{text: "end of page. note how y still shifted down over here, and up with the image's negative y offset!", textSize: 16, bold: true, color: 0xAA0000FF}
	// ],
	// [
	// 	{text: "offset+slotControl behavior", textSize: 20, color: 0xAAA01F04, postPadding: 6},
	// 	{text: "One", color: 0xAA0004FF},
	// 	{text: "Two", color: 0xAA0004FF},
	// 	{text: "Three", color: 0xAA0004FF},
	// 	{text: "Four", color: 0xAA0004FF},
	// 	{text: "4.5 IGNORE_ADVANCE", textSize: 14, color: 0xAA0004FF, offset: {x: 80.0, y: -60.0}, slotControl: ["IGNORE_ADVANCE"]},
	// 	{text: "Five", color: 0xAA0004FF},
	// 	{text: "Six", color: 0xAA0004FF},
	// 	{text: "Seven", color: 0xAA0004FF},
	// 	{text: "7.5 IGNORE_OFFSET_Y", textSize: 12, color: 0xAA0004FF, offset: {x: 80.0, y: -60.0}, slotControl: ["IGNORE_OFFSET_Y"]},
	// 	{text: "Eight", color: 0xAA0004FF},
	// 	{text: "Nine", color: 0xAA0004FF},
	// 	{text: "Ten", color: 0xAA0004FF},
	// 	{text: "Eleven", color: 0xAA0004FF},
	// 	{text: "11.5, slotControl empty", textSize: 12, color: 0xAA0004FF, offset: {x: 80.0, y: -60.0}},
	// 	{text: "Twelve", color: 0xAA0004FF},
	// 	{text: "Thirteen", color: 0xAA0004FF},
	// 	{text: "Fourteen", color: 0xAA0004FF},
	// ],
];

// I am once again making my disdain for calling scenes/stages "states" known
private enum LBState {
	IDLE;
	FLIPPING_FORWARD;
	FLIPPING_BACKWARD;
	OPENING;
	CLOSING;
}


class LorebookQuoteSlot extends QuoteSlot {
	private var pageOffset:PointStruct;
	private var currentPage:Int;
	private var exhausted:Bool;
	private var pageHeight:Float;
	private var currentPageOnQuoteBegin:Int;
	private var currentQuoteNoAutoPagebreak:Bool;

	public override function new(pageHeight:Float) {
		super();

		this.pageHeight = pageHeight;
		pageOffset = {x: PAGE_WIDTH + 24.0, y: 0.0};
		currentPage = 0;
		exhausted = false;
		currentPageOnQuoteBegin = 0;
		currentQuoteNoAutoPagebreak = false;
	}

	override function onQuotePlacementBegin() {
		// needs to be done before super, an offset advance could cause a pagebreak already!
		currentPageOnQuoteBegin = currentPage;
		currentQuoteNoAutoPagebreak = currentQuoteControlParameters.contains("NO_AUTO_PAGEBREAK");
		super.onQuotePlacementBegin();
	}

	override function onQuotePlacementDone() {
		super.onQuotePlacementDone();
		if (currentQuoteControlParameters.contains("IGNORE_ADVANCE")) {
			currentPage = currentPageOnQuoteBegin;
		}
		currentQuoteNoAutoPagebreak = false;
		if (currentQuoteControlParameters.contains("PAGEBREAK")) {
			breakPage();
		}
	}

	private inline function _overrunsPage(y:Float):Bool {
		return y - initialPosition.y > pageHeight;
	}

	private function breakPage() {
		currentPage += 1;
		currentPosition.x = initialPosition.x + currentPage * pageOffset.x;
		currentPosition.y = initialPosition.y + currentPage * pageOffset.y;
	}

	public override function tryFit(sprite:FlxSprite):Bool {
		if (_overrunsPage(currentPosition.y + sprite.height) && !currentQuoteNoAutoPagebreak) {
			advance(sprite.height);
			return false;
		}
		return true;
	}

	public override function advance(by:Float):Bool {
		currentPosition.y += by;
		if (_overrunsPage(currentPosition.y)) {
			breakPage();
		}
		return shouldContinue();
	}

	public override function shouldContinue():Bool {
		return currentPage < 2;
	}
}


class SpoilerWarningQuoteSlot extends QuoteSlot {
	var slotWidth:Float;

	public override function new(slotWidth:Float) {
		super();
		this.slotWidth = slotWidth;
	}

	public override function advanceBySprite(sprite:FlxSprite) {
		sprite.x += (slotWidth - sprite.width) * 0.5;
		return advance(sprite.height);
	}
}


// This was an experiment, but alas it went unused.
/**
#define PI 3.14159265359
#define HALFPI (3.14159265359*0.5)

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    float m = radians(mod(iTime*20.0, 89.0));

    if (uv.x < 0.5) {
        uv.x = 0.5 - ((-tan(((m+HALFPI)*.5))) * ((uv.x * 1.0) - 0.5));
        uv.y = (uv.y * 1.0) - sin(m)*.6 * (1.0 - (uv.x * 2.0));
    }

    // Output to screen
    fragColor = texture(iChannel0, vec2(clamp(uv.x, 0.0, 1.0), clamp(uv.y, 0.0, 1.0)));
}
**/
// class PageTurnShader extends FlxShader {
// 	@:glFragmentSource('
// 		#pragma header
// 
// 		#define PI 3.14159265359
// 		#define HALFPI (3.14159265359*0.5)
// 		#define PAGE_ZENITH 0.4
// 
// 		uniform float angle_left;
// 
// 		void main() {
// 			vec2 uv = openfl_TextureCoordv;
// 			float al_rad = radians(angle_left);
// 
// 			if (uv.x < 0.5) {
// 				uv.x = 0.5 - (
// 					(-tan((al_rad + HALFPI)*.5)) *
// 					((uv.x * 1.0) - 0.5)
// 				);
// 				uv.y = (uv.y * 1.0) + (sin(al_rad) * PAGE_ZENITH * (1.0 - (uv.x * 2.0)));
// 			}
// 
// 			gl_FragColor = flixel_texture2D(bitmap, uv).rgba;
// 		}
// 	')
// 
// 	public function new() {
// 		super();
// 		angle_left.value = [0.0];
// 	}
// }

function linearStepped3(x:Float) {
	return Math.floor(x * 3.0) * 0.3333;
}

class LorebookState extends MusicBeatState {
	var lorebookBackLayer:FlxSprite;
	var lorebookActionLayer:FlxSprite;

	var spreadContents:FlxSpriteGroup;
	var spreadContentsTween:FlxTween;

	var spoilerGroup:FlxSpriteGroup;

	// The pageflip is a number of pseudo-animation frames.
	// During the first ones, the page contents fade out, then the page starts actually flipping
	// then the contents fade back in again.
	// They can be reversed at will.
	var pageflipFrame:Int;
	var pageflipFrameTween:NumTween;
	var pageflipContentsRegenerated:Bool;
	var pageflipJustStarted:Bool;
	var fastflipCooldown:Float;
	var spoilerCooldown:Float;

	// var pageTurnCamera:FlxCamera;
	// var pageTurnShader:PageTurnShader;
	// var pageTurnFilter:ShaderFilter;

	var spreads:Array<Array<QuoteArgs>>;

	var displayedSpreadIdx:Int;
	var spreadCount:Int;
	var bookState:LBState;
	var quoteEffectUpdaters:Array<QuoteEffectUpdater>;

	var textMeasurerCache:TextMeasurerCache;

	var openSounds:Array<Sound>;
	var closeSounds:Array<Sound>;
	var pageflipSounds:Array<Sound>;

	static final OPENING_ANIM_FRAME_IDX_TO_ANGLE:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 27.0, 16.0, 7.0, 1.8, 0.4];
	static final CLOSING_ANIM_FRAME_IDX_TO_ANGLE:Array<Float> = [0.0, 0.0, 7.0, 13.0, 23.0, 0.0, 0.0, 0.0, 0.0, 0.0];

	public override function create() {
		super.create();

		FlxG.sound.playMusic(Paths.music("promise_kept"), 0.0, true);
		FlxG.sound.music.fadeIn(2, 0, 1);

		pageflipSounds = [for (i in 1...8) Paths.sound('lorebook/pageflip$i')];
		openSounds = [Paths.sound('lorebook/bookopen')];
		closeSounds = [Paths.sound('lorebook/bookclose')];

		var ohYeahTotally:Array<Array<Dynamic>> = Json.parse(Assets.getText(Paths.json("lorebook_quotes")));
		spreads = [for (a in ohYeahTotally) [for (b in a) convertQuoteArgsFromJson(b)]];
		spreadCount = spreads.length;
		displayedSpreadIdx = -1;
		bookState = IDLE;
		quoteEffectUpdaters = [];

		pageflipFrame = 0;
		pageflipContentsRegenerated = false;
		pageflipJustStarted = false;
		fastflipCooldown = 0.0;

		textMeasurerCache = new TextMeasurerCache();

		spreadContents = new FlxSpriteGroup();

		// pageTurnCamera = new FlxCamera();
		// pageTurnCamera.bgColor.alpha = 0;
		// pageTurnShader = new PageTurnShader();
		// pageTurnFilter = new ShaderFilter(pageTurnShader);
		// pageTurnCamera.setFilters([pageTurnFilter]);

		// // camera kung-fu, remove them all non-destructively, reset to first default one or
		// // new one if default one didnt exist (?) and add in page turn camera and achievement popup camera again
		// FlxG.cameras.remove(achievementNotificationCamera, false);
		// var cams = FlxG.cameras.list.copy();
		// for (c in cams) {
		// 	FlxG.cameras.remove(c, false);
		// }
		// if (cams.length == 0) {
		// 	cams.push(new FlxCamera());
		// }
		// cams.push(pageTurnCamera);
		// FlxG.cameras.reset(cams[0]);
		// for (i in 1...cams.length) {
		// 	FlxG.cameras.add(cams[i], false);
		// }
		// readdOrSetAchievementNotificationBoxCamera(achievementNotificationCamera);

		var table = new FlxSprite(0.0, 0.0).loadGraphic(Paths.image("lorebook/table"));

		lorebookBackLayer = new FlxSprite();
		lorebookActionLayer = new FlxSprite();

		for (lbl in [lorebookBackLayer, lorebookActionLayer]) {
			lbl.frames = Paths.getTexturePackerAtlas("lorebook/lorebook");
			lbl.antialiasing = false;
			lbl.scale.set(LOREBOOK_SCALE, LOREBOOK_SCALE);
			lbl.updateHitbox();
			lbl.screenCenter();
		}

		lorebookBackLayer.animation.addByPrefix("closed", "ClosedFront", 12, false);
		lorebookBackLayer.animation.addByPrefix("opening", "OpeningUp", 12, false);
		lorebookBackLayer.animation.addByPrefix("opened", "Opened", 12, false);
		lorebookBackLayer.animation.addByPrefix("closing", "ClosingBack", 12, false);
		lorebookBackLayer.animation.addByPrefix("pageflip_fw", "PageFlipForward", 18, false);
		lorebookBackLayer.animation.addByPrefix("pageflip_bw", "PageFlipBack", 18, false);

		lorebookActionLayer.animation.addByPrefix("opening", "ActionOpeningUp", 12, false);
		lorebookActionLayer.animation.addByPrefix("closing", "ActionClosingBack", 12, false);
		lorebookActionLayer.animation.addByPrefix("pageflip_fw", "ActionPageFlipForward", 18, false);
		lorebookActionLayer.animation.addByPrefix("pageflip_bw", "ActionPageFlipBack", 18, false);

		lorebookBackLayer.animation.play("closed");
		lorebookActionLayer.visible = false;

		var letterboxTop = new FlxSprite(0.0, 0.0)
			.makeInflatedPixelGraphic(FlxColor.BLACK, FlxG.width, LETTERBOX_HEIGHT);
		var letterboxBottom = new FlxSprite(0.0, FlxG.height - LETTERBOX_HEIGHT)
			.makeInflatedPixelGraphic(FlxColor.BLACK, FlxG.width, LETTERBOX_HEIGHT);

		spoilerCooldown = 0.0;
		spoilerGroup = null;

		for (ach in AchievementManager.getAchievements(["swarm", "consume", "enough", "freeplay_complete"])) {
			if (ach.isLocked()) {
				spoilerCooldown = SPOILER_COOLDOWN;
				spoilerGroup = new FlxSpriteGroup();

				// This is so over the top
				var swqs = new SpoilerWarningQuoteSlot(PAGE_WIDTH);
				swqs.setInitial(
					lorebookBackLayer.x + PAGE_START_OFFSET_X,
					0
				);
				var qp = new QuotePlacer(textMeasurerCache, [0 => swqs]);
				for (i in 0...4) {
					quoteEffectUpdaters = quoteEffectUpdaters.concat(qp.addSpritesFromQuote(
						new Quote({
							text: "SPOILERS AHEAD!",
							textSize: 36,
							postPadding: 17,
							color: 0xFFD71F32,
							font: "Courier New",
							bold: true,
							effects: [
								new FlickerQuoteEffect({
									initialStates: {c: [i == 0 ? FLICKER_IN : HIDDEN]},
									limit: i == 0 ? 1 : 4,
									hideTime: {standard: i * 0.2},
									transitionTime: {standard: 0.3, randomOffset: {a: -0.08, b: 0.08}},
									showTime: {standard: 0.8 - i * 0.16}
								})
							],
							offset: i == 0 ? null : {x: 0, y: (i - 1) * 62},
							slotControl: i == 0 ? [] : ["IGNORE_ADVANCE", "IGNORE_OFFSET_X", "IGNORE_OFFSET_Y"],
						}),
						spoilerGroup,
						PAGE_WIDTH,
						16
					));
				}
				quoteEffectUpdaters = quoteEffectUpdaters.concat(qp.addSpritesFromQuote(
					new Quote({
						text: "We recommend playing through all the songs before checking out the Lorebook!",
						textSize: 28,
						color: 0xFFD71F32,
						font: "Courier New",
						bold: true,
						effects: [
							new TypeoutQuoteEffect({
								commands: [
									{command: "wait", time: 1.6},
									{command: "typeout", overtype: false, speed: 75.0},
								],
								startTypedOut: false,
								loopCommands: false,
							}),
							// new FlickerQuoteEffect({initialStates: {c: [HIDDEN]}, limit: 2, hideTime: {standard: 1.6}, transitionTime: {standard: 0.2}})
						],
						offset: {x: 0.0, y: 10.0},
					}),
					spoilerGroup,
					PAGE_WIDTH,
					16
				));

				// Bit ugly but alright, the updaters don't move the sprites after all
				var rect:FlxRect = null;
				for (s in spoilerGroup.members) {
					if (rect == null) {
						rect = s.getScreenBounds();
					} else {
						rect.union(s.getScreenBounds());
					}
				}
				rect = rect ?? new FlxRect();

				var spoilerBg = new FlxSprite(Std.int(rect.x - 14), Std.int(rect.y - PAGE_START_OFFSET_Y / 2));
				spoilerBg.makeInflatedPixelGraphic(0xCF000000, rect.width + 28, rect.height + PAGE_START_OFFSET_Y);
				spoilerGroup.insert(0, spoilerBg);

				// center on Y axis
				var diff = (FlxG.height - rect.height) * 0.5 - rect.y;
				for (s in spoilerGroup.members) {
					s.y += diff;
				}

				break;
			}
		}

		add(table);
		if (spoilerGroup != null) {
			add(spoilerGroup);
		}
		add(lorebookBackLayer);
		add(lorebookActionLayer);
		add(spreadContents);
		add(letterboxTop);
		add(letterboxBottom);
	}

	public override function update(dt:Float) {
		super.update(dt);

		var pressedBack = controls.BACK;

		if (pressedBack) {
			CoolUtil.playMenuMusic();
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		fastflipCooldown = Math.max(fastflipCooldown - dt, 0.0);
		spoilerCooldown = Math.max(spoilerCooldown - dt, 0.0);

		var dir = 0;
		if (controls.UI_LEFT != controls.UI_RIGHT) {
			dir = controls.UI_LEFT ? -1 : 1;
		}

		var flipAnim:Null<{a:String, s:LBState, fps:Float}> = null;
		if (spoilerCooldown == 0.0) {
			if (dir == 1) {
				if (_isClosed() && _isPageflipForwardOk()) {
					flipAnim = {a: "opening", s: OPENING, fps: 12.0};
				} else if (_isPageflipForwardOk()) {
					flipAnim = {a: "pageflip_fw", s: FLIPPING_FORWARD, fps: 18.0};
				}
			} else if (dir == -1) {
				if (_isOnFirstSpread()) {
					flipAnim = {a: "closing", s: CLOSING, fps: 12.0};
				} else if (_isPageflipBackwardOk()) {
					flipAnim = {a: "pageflip_bw", s: FLIPPING_BACKWARD, fps: 18.0};
				}
			}
		} else {
			if (controls.UI_LEFT_P != controls.UI_RIGHT_P) { // check for pressed here for immediate feedback
				FlxTween.cancelTweensOf(spoilerGroup);
				FlxTween.shake(spoilerGroup, 0.08, 0.16, X);
			}
		}

		_updatePageflipFrame();

		if (pageflipFrameTween != null && pageflipFrameTween.finished) {
			switch (bookState) {
				case IDLE:

				case FLIPPING_FORWARD | FLIPPING_BACKWARD:
					spreadContents.alpha = 1.0;
					lorebookActionLayer.visible = false;

				case OPENING:
					spreadContents.alpha = 1.0;
					lorebookBackLayer.animation.play("opened");
					lorebookActionLayer.visible = false;
					if (spoilerGroup != null) {
						spoilerGroup.visible = false;
					}

				case CLOSING:
					lorebookBackLayer.animation.play("closed");
					lorebookActionLayer.visible = false;
			}
			bookState = IDLE;
		}

		if (flipAnim != null) {
			// Have the pageflip tween run to the amount of animation frames + 2
			// Tween value          0 1 2 3 4 5 6 7 8
			// Spread fade state  █ ▛ ▞ ▖       ▖ ▞ ▛ █
			// Pageflip ani frame     0 1 2 3 4 5 6
			// For opening/closing only 1 extra frame is needed.
			var pageflipPseudoAnimationFrameCount = getPseudoAnimationFrameCount(flipAnim.s);
			var start = -1.0;
			var newPageflipContentsRegenerated = false;
			if (pageflipPseudoAnimationFrameCount > 0) {
				switch (bookState) {
				case IDLE:
					start = 0.0;
				case FLIPPING_FORWARD:
					// NOTE: Following logic only works because pseudo animation frame count for the flipping
					//       animations is the same!

					if (dir == 1) { // allow fast new flip into same direction once we're in the last two frames
						if (pageflipFrame >= (pageflipPseudoAnimationFrameCount - 2) && fastflipCooldown == 0.0) {
							start = pageflipPseudoAnimationFrameCount - pageflipFrame - 1;
						}
					} else if (dir == -1) { // allow flip into opposite direction at all times. adjust start.
						start = pageflipPseudoAnimationFrameCount - pageflipFrame - 1;
						fastflipCooldown = FASTFLIP_COOLDOWN;
						newPageflipContentsRegenerated = !pageflipContentsRegenerated;
					}
				case FLIPPING_BACKWARD:
					if (dir == -1) {
						if (pageflipFrame >= (pageflipPseudoAnimationFrameCount - 2) && fastflipCooldown == 0.0) {
							start = pageflipPseudoAnimationFrameCount - pageflipFrame - 1;
						}
					} else if (dir == 1) {
						start = pageflipPseudoAnimationFrameCount - pageflipFrame - 1;
						fastflipCooldown = FASTFLIP_COOLDOWN;
						newPageflipContentsRegenerated = !pageflipContentsRegenerated;
					}
				case OPENING:
				case CLOSING: // Disallow interruption for open/close. too annoying with sounds and the closing animation delay.
				}
			}

			if (start >= 0.0) {
				displayedSpreadIdx += dir;

				if (pageflipFrameTween != null) {
					pageflipFrameTween.cancel();
				}

				pageflipFrameTween = FlxTween.num(
					start,
					pageflipPseudoAnimationFrameCount,
					(1.0/flipAnim.fps) * (pageflipPseudoAnimationFrameCount - start)
				);
				pageflipContentsRegenerated = newPageflipContentsRegenerated;
				pageflipJustStarted = true;
				_updatePageflipFrame();
				bookState = flipAnim.s;

				// trace(
				// 	'New flip tween started ($start...$pageflipPseudoAnimationFrameCount). bookState=$bookState, ' +
				// 	'pageflipFrame=$pageflipFrame, displayedSpreadIdx=$displayedSpreadIdx'
				// );
			}
		}

		switch (bookState) {
			case IDLE:
				for (qeu in quoteEffectUpdaters) {
					qeu.update(dt);
				}

			case FLIPPING_FORWARD | FLIPPING_BACKWARD:
				var fc = getPseudoAnimationFrameCount(bookState);
				if (pageflipFrame >= CONTENT_FADE_HEADSTART_FRAMES && pageflipFrame <= (fc - CONTENT_FADE_HEADSTART_FRAMES)) {
					startAnimationAndPlaySound(bookState == FLIPPING_BACKWARD ? "pageflip_bw" : "pageflip_fw", pageflipJustStarted);
					pageflipJustStarted = false;
					lorebookActionLayer.animation.curAnim.curFrame = pageflipFrame - 1;
				} else {
					lorebookActionLayer.visible = false;
				}
				if (pageflipFrame >= (fc - CONTENT_FADE_FRAME_COUNT) && !pageflipContentsRegenerated) {
					placeQuotes(spreads[displayedSpreadIdx]);
					pageflipContentsRegenerated = true;
				}
				spreadContents.alpha = getSpreadContentsAlpha(pageflipFrame, fc, CONTENT_FADE_FRAME_COUNT);

			case OPENING:
				var fc = getPseudoAnimationFrameCount(OPENING);
				if (pageflipFrame <= (fc - CONTENT_FADE_HEADSTART_FRAMES)) {
					startAnimationAndPlaySound("opening");
					lorebookActionLayer.animation.curAnim.curFrame = pageflipFrame;
					lorebookBackLayer.animation.curAnim.curFrame = pageflipFrame;
				} else {
					startAnimationAndPlaySound("opened");
				}
				if (pageflipFrame >= (fc - CONTENT_FADE_FRAME_COUNT) && !pageflipContentsRegenerated) {
					placeQuotes(spreads[displayedSpreadIdx]);
					pageflipContentsRegenerated = true;
				}
				spreadContents.alpha = getSpreadContentsAlpha(pageflipFrame, fc, CONTENT_FADE_FRAME_COUNT, 1.0);

			case CLOSING:
				if (pageflipFrame >= CONTENT_FADE_HEADSTART_FRAMES) {
					startAnimationAndPlaySound("closing");
					lorebookActionLayer.animation.curAnim.curFrame = pageflipFrame - 1;
					lorebookBackLayer.animation.curAnim.curFrame = pageflipFrame - 1;
				}
				spreadContents.alpha = getSpreadContentsAlpha(pageflipFrame, getPseudoAnimationFrameCount(CLOSING), CONTENT_FADE_FRAME_COUNT, -1.0);
		}
	}

	private function getSpreadContentsAlpha(frameNumber:Int, frameCount:Int, transparencyFrameCount:Int, fadeDir:Float = 0) {
		// fc is going to be, say 10. we want three frames of transparency (tc)
		// so, page index will run through 0,1,2,3,4,5,6,7,8,9 (10 is invalid)
		//    0    1    2    3    4    5    6    7    8    9 | -(fc-1)/2
		// -4.5 -3.5 -2.5 -1.5 -0.5  0.5  1.5  2.5  3.5  4.5 | abs(_) for both sides, noop for fadein, *-1 for fadeout
		//  4.5  3.5  2.5  1.5  0.5  0.5  1.5  2.5  3.5  4.5 | -((fc-1)/2 - tc)
		//    3    2    1    0   -1   -1    0    1    2    3 | min(0,_)
		//    3    2    1    0    0    0    0    1    2    3 | /(tc+1)
		//  .75   .5  .25   .0   .0   .0   .0  .25   .5  .75 |

		var halfpoint = (frameCount - 1) * 0.5;
		var v = frameNumber - halfpoint;
		if (fadeDir == 0.0) {
			v = Math.abs(v);
		} else {
			v *= fadeDir;
		}
		return FlxMath.bound(
			(v - (halfpoint - transparencyFrameCount)) / (transparencyFrameCount + 1),
			0.0,
			1.0
		);
	}

	private function getPseudoAnimationFrameCount(s:LBState) {
		return switch(s) {
			case IDLE: 0;
			case FLIPPING_FORWARD: ANIMATION_FRAME_COUNT_PAGEFLIP_FORWARD + CONTENT_FADE_HEADSTART_FRAMES * 2;
			case FLIPPING_BACKWARD: ANIMATION_FRAME_COUNT_PAGEFLIP_BACKWARD + CONTENT_FADE_HEADSTART_FRAMES * 2;
			case OPENING: ANIMATION_FRAME_COUNT_OPENING + CONTENT_FADE_HEADSTART_FRAMES;
			case CLOSING: ANIMATION_FRAME_COUNT_CLOSING + CONTENT_FADE_HEADSTART_FRAMES;
		}
	}

	private inline function _updatePageflipFrame() {
		if (pageflipFrameTween != null && !pageflipFrameTween.finished) {
			pageflipFrame = Std.int(pageflipFrameTween.value);
		} else {
			pageflipFrame = 0;
		}
	}

	private function startAnimationAndPlaySound(animName:String, playAlways:Bool = false) {
		if (lorebookBackLayer.animation.name != null && lorebookBackLayer.animation.name == animName && !playAlways) {
			return;
		}

		lorebookBackLayer.animation.play(animName, true);
		lorebookActionLayer.animation.play(animName, true);
		lorebookActionLayer.visible = true;

		if (animName == "opening") {
			FlxG.sound.play(FlxG.random.getObject(openSounds));
		} else if (animName == "closing") {
			FlxG.sound.play(FlxG.random.getObject(closeSounds));
		} else {
			FlxG.sound.play(FlxG.random.getObject(pageflipSounds));
		}
	}

	private function placeQuotes(args:Array<QuoteArgs>) {
		spreadContents.clear();
		quoteEffectUpdaters.resize(0);
		var placer = new QuotePlacer(textMeasurerCache, [0 => new LorebookQuoteSlot(PAGE_HEIGHT)], "lorebook/");
		placer.quoteSlots[0].setInitial(lorebookBackLayer.x + PAGE_START_OFFSET_X, lorebookBackLayer.y + PAGE_START_OFFSET_Y);
		for (a in args) {
			quoteEffectUpdaters = quoteEffectUpdaters.concat(placer.addSpritesFromQuote(new Quote(a), spreadContents, PAGE_WIDTH, 96));
		}
	}

	private inline function _isClosed() {
		return displayedSpreadIdx == -1;
	}

	private inline function _isPageflipBackwardOk() {
		return displayedSpreadIdx > 0;
	}

	private inline function _isPageflipForwardOk() {
		return displayedSpreadIdx < spreadCount - 1;
	}

	private inline function _isOnFirstSpread() {
		return displayedSpreadIdx == 0;
	}
}
