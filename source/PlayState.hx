package;

import flixel.util.FlxStringUtil;
#if cpp
import lime.media.openal.AL;
#end
import flixel.FlxBasic;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import editors.ChartingState;
import editors.CharacterEditorState;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.effects.FlxTrail;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.system.FlxAssets.FlxSoundAsset;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.display.BitmapData;
import flixel.system.FlxSoundGroup;
#if HSCRIPT_ALLOWED
import hscript.ParserEx;
#end
import lime.app.Application;
import lime.graphics.Image;
import openfl.events.KeyboardEvent;
import openfl.utils.Assets as OpenFlAssets;

import Character;
import Conductor.Rating;
import DialogueBoxPsych;
import FunkinLua;
import Note.EventNote;
import StageData;
import SkinData;
import TendrilOverlay;
import OrganicPixelErasureShader.AnotherFuckingOrganicPixelErasureShader;
import PlaceTextBG.AttachedPlaceTextBG;
import PlaceTextBG.AttachedCheapPlaceTextBG;
import WiggleEffect.WiggleEffectType;
import WorldShakeCamera;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

#if VIDEOS_ALLOWED
import vlc.MP4Handler;
#end

using StringTools;


final GC_CONTROL_TIMEOUT = 2000;
final GC_CONTROL_COOLDOWN_TIMEOUT = 30;


// @Square789: actual piece of trash, i am sorry
private class MultiDissolver {
	public var shaders:Array<PixelErasureShader>;
	public var pixel_health_direct(default, set):Float;

	public function new(shaders:Array<PixelErasureShader>) {
		this.shaders = shaders;
		this.pixel_health_direct = 0.0;
	}

	public function set_pixel_health_direct(v:Float):Float {
		for (s in shaders) {
			s.pixel_health_direct = v;
		}
		return this.pixel_health_direct = v;
	}
}


/**
 * Camera subclass which, when drawn to, copies its buffer to the supplied target sprite.
 * Requires tile rendering mode.
 * Naturally, for avoiding a 1-frame delay, the camera must be inserted before the camera
 * the target sprite is rendered on has its `render` method called.
 * Flixel's update-draw cycle goes something like this (Note: taken from GH dev in 2026
 * which is probably ahead of the HF version in use by f4rp by 4 years, but who cares):
 * updateElapsed()
 * updateInput()
 * <dispatch preUpdate signals>
 * sound.update()
 * cameras.update()
 * _state.tryUpdate()
 * <dispatch postUpdate signals>
 * (done multiple times for fixed timestep)
 * 
 * if _state.visible && _state.exists:
 *   <dispatch preDraw signals>
 *   cameras.lock()
 *   _state.draw() >>>
 *     <for each basic that exists and is not invisible basic.draw(). for sprites, ends up in camera.drawPixels or camera.copyPixels>
 *     subState.draw()
 *   <<<
 *   if renderTile:
 *     cameras.render() >>>
 *       <for each camera in FlxG.cameras camera.render()> >>>
 *         flashSprite.filters = filtersEnabled ? filters : null;
 *         <go through draw stack LL and call render(this) on each FlxDrawBaseItem>
 *       <<<
 *     <<<
 *   cameras.unlock()
 *   <dispatch postDraw signals>
 * Thus: Make sure this camera's `render` runs before the main game's one (it's in front of the
 * camera in the camera list and uuh it'll work from there trust)
 */
private class ChatboxCamera extends FlxCamera {
	var targetSprite:FlxSprite;
	var drawMatrix:Matrix;
	var fillRect:Rectangle;

	public override function new(targetSprite:FlxSprite, x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0) {
		super(x, y, width, height);
		this.targetSprite = targetSprite;
		drawMatrix = new Matrix();
		fillRect = new Rectangle(0, 0, this.width, this.height);
	}

	override function render() {
		super.render();

		targetSprite.graphic.bitmap.fillRect(fillRect, 0x00000000);
		targetSprite.graphic.bitmap.draw(canvas, drawMatrix);
	}

	public override function destroy() {
		targetSprite = null;

		super.destroy();
	}
}


// NOTE: This shader is a reduced crappy copypaste hack (probably the 3rd one) of the
// GradientPixelErasureShader.
// If you seriously want to study this, check out the Pixel Erasure Shader templates instead!
private class ChatboxWarpShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float seed;
		// uniform vec2 pixel_dimensions;
		#define pixel_dimensions (vec2(1.0, 1.0))
		uniform float fadein_progress;

		float random2D(vec2 co) {
			float a = 12.9898;
			float b = 78.233;
			float c = 43758.5453;
			float dt = dot(co.xy, vec2(a, b));
			float sn = mod(dt, 3.14);
			return fract(sin(sn) * c);
		}

		vec2 do_chatbox_warp(vec2 uv) {
			float y_horizon = 0.9;
			float uuuh = y_horizon - 0.05;
			float incline = (uv.y - y_horizon) * 0.35;
			// Tiny dent on top, because the slanting logic is actually broken and produces
			// curves. cant be assed to fix any more tbh
			incline *= (1.0 + pow(abs(uv.x - uuuh), 2.0)*0.333);
			return vec2(
				0.2 + (uv.x - 0.2) * (1.04 - pow(abs(uv.y - uuuh) * 0.4, 2.0)), // bulge "forwards" to the top
				uv.y + incline*uv.x
			);
		}

		void main() {
			float alpha = flixel_texture2D(bitmap, openfl_TextureCoordv).a;
			float rando = random2D(openfl_TextureCoordv * seed);

			vec3 gradient_start = vec3(do_chatbox_warp(vec2(0.5, 1.0 - fadein_progress - 0.04)), 0.0);
			vec3 gradient_stop =  vec3(do_chatbox_warp(vec2(0.5, 1.0 - fadein_progress)),        1.0);
			vec2 warped_uv = do_chatbox_warp(openfl_TextureCoordv);
			vec2 diff = gradient_start.xy - gradient_stop.xy;
			float gradient_progress = (
				dot(warped_uv - gradient_stop.xy, diff) /
				dot(diff, diff)
			);
			float pixel_health = clamp(
				mix(gradient_stop.z, gradient_start.z, gradient_progress),
				gradient_start.z,
				gradient_stop.z
			);

			if (rando >= pixel_health) {
				gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0) * alpha;
			} else {
				gl_FragColor = flixel_texture2D(bitmap, warped_uv);
			}
		}
	')

	public var fadein_progress_direct(get, set):Float;

	public function new() {
		super();
		seed.value = [382746.298];
		fadein_progress.value = [1.0];
	}

	public function get_fadein_progress_direct():Float {
		return fadein_progress.value[0];
	}
	public function set_fadein_progress_direct(v:Float):Float {
		return fadein_progress.value[0] = v;
	}
}


class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Array<Dynamic>> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	public var soundGroup = new FlxSoundGroup(1);

	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, ModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();

	//event variables
	private var isCameraOnForcedPos:Bool = false;
	public var boyfriendMap:Map<String, Character> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var variables:Map<String, Dynamic> = new Map();

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	
	public var boyfriendGroup:FlxTypedSpriteGroup<Character>;
	public var dadGroup:FlxTypedSpriteGroup<Character>;
	public var gfGroup:FlxTypedSpriteGroup<Character>;
	// @CoolingTool: arrays to make the character groups thing more flexable
	public var boyfriendMembers:Array<Character>;
	public var dadMembers:Array<Character>;
	public var gfMembers:Array<Character>;
	public var boppers:Array<BGSprite> = [];

	public static var curStage:String = '';
	public static var isPixelStage:Bool = false;
	public static var SONG:SwagSong = null;
	public static var originalSong:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var noteKillOffset:Float = 350;
	public var spawnTime:Float = 2000;

	public var vocals:FlxSound;
	public var vocalsDad:FlxSound;
	public var introNames:Array<String> = ['3', '2', '1', 'Go'];
	public var songIntros:Array<FlxSoundAsset> = [];
	var foundDadVocals:Bool = false;

	public var dad(get, never):Character;
	public var gf(get, never):Character;
	public var boyfriend(get, never):Character;
	public var playerGroup(get, never):FlxTypedSpriteGroup<Character>;
	public var opponentGroup(get, never):FlxTypedSpriteGroup<Character>;
	public var playerMembers(get, never):Array<Character>;
	public var opponentMembers(get, never):Array<Character>;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	// @CoolingTool: The tendril overlays
	public var tendrils:FlxTypedGroup<TendrilOverlay>;
	public var unspawnTendrils:Array<TendrilOverlay> = [];

	private var strumLine:FlxSprite;

	//Handles the new epic mega sexy cam code that i've done
	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;
	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	public var keybindGroup:FlxTypedGroup<AttachedFlxText>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	public var camBop:Bool = false;
	public var curSong:String = "";
	public var curSongDisplayName:String = "";

	public var health:Float = 1;
	public var maxHealth:Float = 2; // @ThaumcraftMC: Max health value so I can reduce it when a Void Note is hit.
	public var minHealth:Float = 0; // @CoolingTool: Min health value.
	public var voidedHealth(get, never):Float; // @CoolingTool: The amount of health taken away by max and min health.
	public var shownHealth:Float = 1;
	public var combo:Int = 0;

	private var healthBarBG:AttachedSprite;
	private var maxhealthBarBG:AttachedSprite;
	private var minhealthBarBG:AttachedSprite;
	private var minhealthBarFG:AttachedSprite;
	public var healthBar:FlxBar;
	var songPercent:Float = 0;

	private var timeIcon:AttachedSprite;
	private var timeBarBG:AttachedPlaceTextBG;

	var underlayPlayer:FlxSprite;
	var underlayOpponent:FlxSprite;

	public var ratingsData:Array<Rating> = [];
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = true;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var opponentChart:Bool = false;
	public var playbackRate:Float = 1;
	public var demoMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;
	public var practiceFailedSine:Float = 0;
	public var practiceFailed:Bool = false;
	public var practiceFailedTxt:FlxText;

	public var healthIconsP1:FlxTypedGroup<HealthIcon>;
	public var healthIconsP2:FlxTypedGroup<HealthIcon>;
	public var iconP1(get, null):HealthIcon;
	public var iconP2(get, null):HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var camButtons:FlxCamera;
	public var cameraSpeed:Float = 1;
	public var iconBopSpeed:Int = 1;

	var dialogue:Array<String> = null;
	var dialogueJson:DialogueFile = null;

	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleSmokes:FlxSpriteGroup;

	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;

	var phillyLightsColors:Array<FlxColor>;
	var phillyWindow:BGSprite;
	var phillyStreet:BGSprite;
	var phillyTrain:BGSprite;
	var blammedLightsBlack:FlxSprite;
	var phillyWindowEvent:BGSprite;
	var trainSound:FlxSound;

	var phillyGlowGradient:PhillyGlow.PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle>;

	var bgGirls:BackgroundGirls;
	var bgGhouls:BGSprite;

	var foregroundSprites:FlxTypedGroup<BGSprite>;

	var bubboDrugs:WiggleEffect;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	public var scoreBG:AttachedCheapPlaceTextBG;
	var timeTxt:FlxText;
	var songTxt:FlxText;
	var scoreTxtTween:FlxTween;
	var stepTxt:FlxText;
	var beatTxt:FlxText;
	var sectionTxt:FlxText;

	public var ratingTxtGroup:FlxTypedGroup<FlxText>;
	public var ratingTxtTweens:Array<FlxTween> = [null];

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var bopCamZoom:Float = 0;
	public var currentCamZoom:Float = 1.05;
	public var targetCamZoom:Float = 1.05;
	public var playerCamZoom:Float = 1.05;
	public var opponentCamZoom:Float = 1.05;
	public var defaultCamHudZoom:Float = 1;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	var playerSingAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	var opponentSingAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	// @CoolingTool: variable that stores the position of between the strums
	var betweenStrum:Float = FlxG.width / 2;
	var betweenStrumOffset:Float;

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	public var songLength:Float = 0;
	public var showSongText:Bool = true;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	public var boyfriendCameraFixed:Bool = false;
	public var opponentCameraFixed:Bool = false;
	public var girlfriendCameraFixed:Bool = false;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	public var storyDifficultyText:String = "";
	public var detailsText:String = "";
	public var detailsPausedText:String = "";
	public var detailsGameOverText:String = "";
	#end

	// @CoolingTool: misses per second (mash detector) for twitch chat
	// ghost tapping is not ignored
	public var recentMisses:Array<Float> = [];

	// Lua shit
	public static var instance:PlayState;
	public var luaArray:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;
	
	// Less laggy controls
	private var keysArray:Array<Array<FlxKey>>;

	/**
	 * A special camera whose render method modifies the underlying `BitmapData` of
	 * `chatboxTargetSprite` just in time for it to contain a simple graphic of the chatbox.
	 * The entire chatbox effect will not be active in blit render mode.
	 */
	var camChatboxes:Null<ChatboxCamera>;
	var chatboxTargetSprite:Null<FlxSprite>;
	var twitchChatboxes:Array<TwitchChatbox>;
	var twitchChatboxStateStorage:Map<String, Int>;

	// @Square789: shader experiments
	var pixelErasureShaders:Array<AnotherFuckingOrganicPixelErasureShader>;

	// @Square789: Single-handed smackdown. Resurrected from OG psych's "just the two of us" achievement.
	// Sorry for bringing this public static garbage in this way.
	public static var pressedKeysThisStoryRun:Map<FlxKey, Bool>;

	// @Square789: Same as above, mostly
	/**
	 * Records the lowest difficulty that a song has been sucessfully beaten with during a playthrough
	 * of story mode. WARNING: This requires all songs in story mode weeks to have an equal amount of
	 * difficulties where logically the difficulties should be somewhat equally difficult and in the
	 * same order.
	 * Value undefined in freeplay mode or when a week was not just beaten.
	 */
	public static var lowestDifficultyThisStoryRun:Int;

	private var gcControlLastGameplayState:Bool;
	private var gcControlRequestedState:Bool;
	private var gcControlTimeout:Int;
	private var gcControlCooldownActive:Bool;
	private var gcControlCooldownTimeout:Int;

	public var bfKeys:Int = 4;
	public var dadKeys:Int = 4;
	public var playerKeys(get, never):Int;
	public var opponentKeys(get, never):Int;

	var playerColors:Array<String> = [];
	var opponentColors:Array<String> = [];

	var bfGroupFile:CharacterGroupFile = null;
	var dadGroupFile:CharacterGroupFile = null;
	var gfGroupFile:CharacterGroupFile = null;

	public var inEditor:Bool = false;
	var startPos:Float = 0;
	var timerToStart:Float = 0;

	public var playerStrumMap:Map<Int, FlxTypedGroup<StrumNote>> = new Map();
	public var opponentStrumMap:Map<Int, FlxTypedGroup<StrumNote>> = new Map();

	var lastTitle = '';

	public var hideInDemoMode:Array<FlxBasic> = [];

	#if mobile
	var grpNoteButtons:FlxTypedGroup<NoteButton> = new FlxTypedGroup();
	var grpButtons:FlxTypedGroup<Button> = new FlxTypedGroup();
	var buttonPAUSE:Button;
	var buttonRESET:Button;
	#end

	function get_boyfriend():Character {
		return boyfriendMembers[0];
	}

	function get_dad():Character {
		return dadMembers[0];
	}

	function get_gf():Character {
		return gfMembers[0];
	}

	function get_playerGroup():FlxTypedSpriteGroup<Character> {
		return opponentChart ? dadGroup : boyfriendGroup;
	}

	function get_opponentGroup():FlxTypedSpriteGroup<Character> {
		return !opponentChart ? dadGroup : boyfriendGroup;
	}

	function get_playerMembers():Array<Character> {
		return opponentChart ? dadMembers : boyfriendMembers;
	}

	function get_opponentMembers():Array<Character> {
		return !opponentChart ? dadMembers : boyfriendMembers;
	}

	function get_playerKeys():Int {
		return opponentChart ? dadKeys : bfKeys;
	}

	function get_opponentKeys():Int {
		return !opponentChart ? dadKeys : bfKeys;
	}

	function get_iconP1():Null<HealthIcon> {
		return healthIconsP1.length > 0 ? healthIconsP1.members[healthIconsP1.length - 1] : null;
	}

	function get_iconP2():Null<HealthIcon> {
		return healthIconsP2.length > 0 ? healthIconsP2.members[healthIconsP2.length - 1] : null;
	}

	public function new(?inEditor:Bool = false, ?startPos:Float = 0) {
		this.inEditor = inEditor;
		if (inEditor) {
			this.startPos = startPos;
			Conductor.songPosition = startPos;
			timerToStart = Conductor.normalizedCrochet;
		}
		super();
		gcControlLastGameplayState = true;
		gcControlRequestedState = true;
		gcControlTimeout = GC_CONTROL_TIMEOUT;
		gcControlCooldownActive = false;
		gcControlCooldownTimeout = GC_CONTROL_COOLDOWN_TIMEOUT;
	}

	var precacheList:Map<String, String> = new Map<String, String>();

	override public function create()
	{
		Paths.clearStoredMemory();
		lastTitle = Application.current.window.title;
		FlxG.mouse.visible = false;
		FlxG.timeScale = 1;

		// for lua
		instance = this;

		pixelErasureShaders = [];
		twitchChatboxes = [];
		twitchChatboxStateStorage = null;

		// @Square789: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
		// Is this infallible? Highly unlikely, but this is what's there and it seems to run the
		// achievement somewhat well
		if (pressedKeysThisStoryRun == null) {
			pressedKeysThisStoryRun = new Map<FlxKey, Bool>();
		}
		if (isStoryMode) {
			if (storyPlaylist == null || storyPlaylist.length == 0) {
				FlxG.log.warn("Story mode but empty story playlist?");
			} else {
				var week = WeekData.weeksLoaded[WeekData.weeksList[storyWeek]];
				if (storyPlaylist.length == week.songs.length && cast(week.songs[0][0], String) == SONG.song) {
					// Story mode just began; reset this
					trace("story mode just began");
					pressedKeysThisStoryRun = new Map<FlxKey, Bool>();
					lowestDifficultyThisStoryRun = FlxMath.MAX_VALUE_INT;
				}
			}
		}

		debugKeysChart = ClientPrefs.copyNonNoneKeys('debug_1');
		debugKeysCharacter = ClientPrefs.copyNonNoneKeys('debug_2');
		PauseSubState.songName = null; //Reset to default

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (!inEditor) {
			// Gameplay settings
			healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
			healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
			instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
			practiceMode = ClientPrefs.getGameplaySetting('practice', false);
			cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
			opponentChart = ClientPrefs.getGameplaySetting('opponentplay', false);
			playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);
			demoMode = ClientPrefs.getGameplaySetting('demomode', false);
			if (demoMode) {
				cpuControlled = true;
			}
			Conductor.playbackRate = playbackRate;

			camGame = new WorldShakeCamera();
			camHUD = new WorldShakeCamera();
			camOther = new FlxCamera();
			camButtons = new FlxCamera();
			camHUD.bgColor.alpha = 0;
			camOther.bgColor.alpha = 0;
			camButtons.bgColor.alpha = 0;

			FlxG.cameras.reset(camGame);
			FlxG.cameras.add(camHUD, false);
			FlxG.cameras.add(camOther, false);
			FlxG.cameras.add(camButtons, false);
		} else {
			var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
			bg.scrollFactor.set();
			bg.color = FlxColor.fromHSB(FlxG.random.int(0, 359), FlxG.random.float(0, 0.8), FlxG.random.float(0.3, 1));
			add(bg);
		}

		grpNoteSplashes = new FlxTypedGroup();

		if (!inEditor) {
			CustomFadeTransition.nextCamera = camOther;
			persistentUpdate = true;
		}
		
		if (SONG == null)
			SONG = Song.loadFromJson('test', 'test');

		originalSong = Reflect.copy(SONG);

		if (practiceMode || cpuControlled || opponentChart) SONG.validScore = false;

		curSong = Paths.formatToSongPath(SONG.song);
		curSongDisplayName = SONG?.meta?.displayName ?? Song.getDisplayName(SONG.song);
		showSongText = (ClientPrefs.timeBarType != 'Song Name' && deathCounter < 1);

		//Ratings
		ratingsData.push(new Rating('sick')); //default rating

		var rating:Rating = new Rating('good');
		rating.displayName = 'Good!';
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.displayName = 'Bad';
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.displayName = 'Shit';
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		rating.causesMiss = ClientPrefs.shitMisses;
		ratingsData.push(rating);

		for (i in ratingsData) {
			ratingTxtTweens.push(null);
		}

		#if MULTI_KEY_ALLOWED
		bfKeys = SONG.playerKeyAmount;
		dadKeys = SONG.opponentKeyAmount;
		#end
		setKeysArray(playerKeys);

		Conductor.mapBPMChanges(SONG);

		if (storyDifficulty > CoolUtil.difficulties.length - 1) {
			storyDifficulty = CoolUtil.difficulties.indexOf('Normal');
			if (storyDifficulty == -1) storyDifficulty = 0;
		}

		#if DISCORD_ALLOWED
		if (!inEditor) {
			storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

			// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
			if (isStoryMode) {
				detailsText = 'Story Mode: ${WeekData.getCurrentWeek().weekName}';
			} else {
				detailsText = "Freeplay";
			}

			// String for when the game is paused
			detailsPausedText = 'Paused - $detailsText';

			// String for when the Game Over screen appears
			detailsGameOverText = 'Game Over - $detailsText';
		}
		#end

		GameOverSubState.resetVariables();

		curStage = SONG.stage;
		if (SONG.stage == null || SONG.stage.length < 1) {
			switch (curSong) {
			default:
				curStage = 'stage';
			}
		}
		SONG.stage = curStage;

		var camPos:FlxPoint = null;
		if (!inEditor) {
			var stageData:StageFile = StageData.getStageFile(curStage);
			if (stageData == null) { //Stage couldn't be found, create a dummy stage for preventing a crash
				stageData = {
					directory: "",
					defaultZoom: 0.9,
					opponentZoom: 0.9,
					isPixelStage: false,

					boyfriend: [770, 100],
					girlfriend: [400, 130],
					opponent: [100, 100],
					hide_girlfriend: false,

					camera_boyfriend: [0, 0],
					camera_opponent: [0, 0],
					camera_girlfriend: [0, 0],
					camera_boyfriend_fixed: false,
					camera_opponent_fixed: false,
					camera_girlfriend_fixed: false,
					camera_speed: 1,
					camera_ease: 'expoOut'
				};
			}

			targetCamZoom = stageData.defaultZoom;
			playerCamZoom = stageData.defaultZoom;
			opponentCamZoom = stageData.opponentZoom;
			isPixelStage = stageData.isPixelStage;
			BF_X = stageData.boyfriend[0];
			BF_Y = stageData.boyfriend[1];
			GF_X = stageData.girlfriend[0];
			GF_Y = stageData.girlfriend[1];
			DAD_X = stageData.opponent[0];
			DAD_Y = stageData.opponent[1];

			cameraSpeed = stageData.camera_speed;
			// @CoolingTool: my cool camera tweening thing
			cameraEase = FunkinLua.getFlxEaseByString(stageData.camera_ease);
			boyfriendCameraOffset = stageData.camera_boyfriend;
			opponentCameraOffset = stageData.camera_opponent;
			girlfriendCameraOffset = stageData.camera_girlfriend;
			boyfriendCameraFixed = stageData.camera_boyfriend_fixed;
			opponentCameraFixed = stageData.camera_opponent_fixed;
			girlfriendCameraFixed = stageData.camera_girlfriend_fixed;

			GameOverSubState.defaultCamZoom = playerCamZoom;

			boyfriendGroup = new FlxTypedSpriteGroup(BF_X, BF_Y);
			dadGroup = new FlxTypedSpriteGroup(DAD_X, DAD_Y);
			gfGroup = new FlxTypedSpriteGroup(GF_X, GF_Y);
			boyfriendMembers = [];
			dadMembers = [];
			gfMembers = [];

			var gfVersion:String = SONG.gfVersion;
			if (gfVersion == null || gfVersion.length < 1) {
				switch (curStage) {
					// Custom grillfriend here if plans for one ever come up ig
					default:
						gfVersion = 'gf';
				}
				SONG.gfVersion = gfVersion; //Fix for the Chart Editor
			}

			gfGroupFile = Character.getFile(gfVersion);
			dadGroupFile = Character.getFile(SONG.player2);
			bfGroupFile = Character.getFile(SONG.player1);

			if (ClientPrefs.gameQuality != 'Crappy') {
				switch (curStage) { // Stage background setup
				case 'stage': //Week 1
					var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
					add(bg);

					var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
					stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
					stageFront.updateHitbox();
					add(stageFront);

					if (ClientPrefs.gameQuality == 'Normal') {
						var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
						stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
						stageLight.updateHitbox();
						add(stageLight);
						var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
						stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
						stageLight.updateHitbox();
						stageLight.flipX = true;
						add(stageLight);

						var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
						stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
						stageCurtains.updateHitbox();
						add(stageCurtains);
					}
				case 'bubbo': //Bubbo
					var bg = new BGSprite('bubboBG', -300, -50, 0.1, 0.1);
					bg.setGraphicSize(Std.int(bg.width * daPixelZoom));
					bg.updateHitbox();
					add(bg);
					bg.antialiasing = false;
					if (ClientPrefs.gameQuality == 'Normal') {
						bubboDrugs = new WiggleEffect();

						bubboDrugs.effectType = WiggleEffectType.GLITCH;
						bubboDrugs.waveAmplitude = 0.01;
						bubboDrugs.waveFrequency = 5;
						bubboDrugs.waveSpeed = 1;
						bg.shader = bubboDrugs.shader;
					}
				case 'school': //Week 6 - Senpai, Roses
					if(SkinData.getSkinModifier().endsWith('week6')) introSoundsSuffix = '-pixel';

					var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1);
					add(bgSky);
					bgSky.antialiasing = false;

					var repositionShit = -200;

					var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, 0, 0.6, 0.90);
					add(bgSchool);
					bgSchool.antialiasing = false;

					var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, 0, 0.95, 0.95);
					add(bgStreet);
					bgStreet.antialiasing = false;

					var widShit = Std.int(bgSky.width * 6);
					if (ClientPrefs.gameQuality == 'Normal') {
						var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', repositionShit + 170, 130, 0.9, 0.9);
						fgTrees.setGraphicSize(Std.int(widShit * 0.8));
						fgTrees.updateHitbox();
						add(fgTrees);
						fgTrees.antialiasing = false;
					}

					var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800);
					bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
					bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
					bgTrees.animation.play('treeLoop');
					bgTrees.scrollFactor.set(0.85, 0.85);
					add(bgTrees);
					bgTrees.antialiasing = false;

					if (ClientPrefs.gameQuality == 'Normal') {
						var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionShit, -40, 0.85, 0.85, ['PETALS ALL'], true);
						treeLeaves.setGraphicSize(widShit);
						treeLeaves.updateHitbox();
						add(treeLeaves);
						treeLeaves.antialiasing = false;
					}

					bgSky.setGraphicSize(widShit);
					bgSchool.setGraphicSize(widShit);
					bgStreet.setGraphicSize(widShit);
					bgTrees.setGraphicSize(Std.int(widShit * 1.4));

					bgSky.updateHitbox();
					bgSchool.updateHitbox();
					bgStreet.updateHitbox();
					bgTrees.updateHitbox();

					if (ClientPrefs.gameQuality == 'Normal') {
						bgGirls = new BackgroundGirls(-100, 190);
						bgGirls.scrollFactor.set(0.9, 0.9);

						bgGirls.setGraphicSize(Std.int(bgGirls.width * daPixelZoom));
						bgGirls.updateHitbox();
						add(bgGirls);
					}
				case 'schoolEvil': //Week 6 - Thorns
					if(SkinData.getSkinModifier().endsWith('week6')) introSoundsSuffix = '-pixel';

					var posX = 400;
					var posY = 200;
					if (ClientPrefs.gameQuality == 'Normal') {
						var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool', posX, posY, 0.8, 0.9, ['background 2'], true);
						bg.scale.set(6, 6);
						bg.antialiasing = false;
						add(bg);

						bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
						bgGhouls.setGraphicSize(Std.int(bgGhouls.width * daPixelZoom));
						bgGhouls.updateHitbox();
						bgGhouls.visible = false;
						bgGhouls.antialiasing = false;
						add(bgGhouls);
					} else {
						var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool_low', posX, posY, 0.8, 0.9);
						bg.scale.set(6, 6);
						bg.antialiasing = false;
						add(bg);
					}
				}
			}

			add(gfGroup); //Needed for blammed lights
			add(dadGroup);
			add(boyfriendGroup);

			if (ClientPrefs.gameQuality != 'Crappy') {
				switch(curStage)
				{
					default: // @CoolingTool: week 7 tank stage uses very generic sounding `foregroundSprites` and i think thats very smart so default behavior now
						if (foregroundSprites != null) add(foregroundSprites);
				}
			}

			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
			luaDebugGroup.cameras = [camOther];
			add(luaDebugGroup);

			// "GLOBAL" SCRIPTS
			var filesPushed:Array<String> = [];
			var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];
			#if MODS_ALLOWED
			foldersToCheck.insert(0, Paths.mods('scripts/'));
			if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
				foldersToCheck.insert(0, Paths.mods('${Paths.currentModDirectory}/scripts/'));

			for(mod in Paths.getGlobalMods())
				foldersToCheck.insert(0, Paths.mods(mod + '/scripts/'));
			#end

			#if !html5
			for (folder in foldersToCheck)
			{
				if (FileSystem.exists(folder))
				{
					for (file in FileSystem.readDirectory(folder))
					{
						#if LUA_ALLOWED
						if (file.endsWith('.lua') && !filesPushed.contains(file))
						{
							luaArray.push(new FunkinLua(folder + file));
							filesPushed.push(file);
						}
						#end
						#if HSCRIPT_ALLOWED
						if (file.endsWith('.hscript') && !filesPushed.contains(file))
						{
							addHscript(folder + file);
							filesPushed.push(file);
						}
						#end
					}
				}
			}
			#end
			#end
			
			// STAGE SCRIPTS
			if (ClientPrefs.gameQuality != 'Crappy') {
				#if LUA_ALLOWED
				var doPush:Bool = false;
				var luaFile:String = 'stages/$curStage.lua';
				#if MODS_ALLOWED
				if (FileSystem.exists(Paths.modFolders(luaFile))) {
					luaFile = Paths.modFolders(luaFile);
					doPush = true;
				} else {
				#end
					luaFile = Paths.getPreloadPath(luaFile);
					if (OpenFlAssets.exists(luaFile)) {
						doPush = true;
					}
				#if MODS_ALLOWED
				}
				#end

				if (doPush) 
					luaArray.push(new FunkinLua(luaFile));
				#end

				#if HSCRIPT_ALLOWED
				var doPush:Bool = false;
				var hscriptFile:String = 'stages/$curStage.hscript';
				#if MODS_ALLOWED
				if (FileSystem.exists(Paths.modFolders(hscriptFile))) {
					hscriptFile = Paths.modFolders(hscriptFile);
					doPush = true;
				} else {
				#end
					hscriptFile = Paths.getPreloadPath(hscriptFile);
					if (OpenFlAssets.exists(hscriptFile)) {
						doPush = true;
					}
				#if MODS_ALLOWED
				}
				#end

				if (doPush) 
					addHscript(hscriptFile);
				#end
			}

			if (stageData.hide_girlfriend == false)
			{
				if (gfGroupFile != null && gfGroupFile.characters != null && gfGroupFile.characters.length > 0) {
					for (i in 0...gfGroupFile.characters.length) {
						addCharacter(gfGroupFile.characters[i].name, i, gfGroupFile.characters[i].insert, false, false, gfGroupFile.reversed_layers, gfGroup, gfMembers, gfGroupFile.characters[i].position[0] + gfGroupFile.position[0], gfGroupFile.characters[i].position[1] + gfGroupFile.position[1], 0.95, 0.95);
					}
				} else {
					gfGroupFile = null;
					addCharacter(gfVersion, 0, false, false, false, gfGroup, gfMembers, 0, 0, 0.95, 0.95);
				}
				for (i in gfMembers) {
					startCharacterScripts(i.curCharacter);
				}
			}

			if (dadGroupFile != null && dadGroupFile.characters != null && dadGroupFile.characters.length > 0) {
				for (i in 0...dadGroupFile.characters.length) {
					addCharacter(dadGroupFile.characters[i].name, i, dadGroupFile.characters[i].insert, false, opponentChart, dadGroupFile.reversed_layers, dadGroup, dadMembers, dadGroupFile.characters[i].position[0] + dadGroupFile.position[0], dadGroupFile.characters[i].position[1] + dadGroupFile.position[1]);
				}
			} else {
				dadGroupFile = null;
				addCharacter(SONG.player2, 0, false, opponentChart, false, dadGroup, dadMembers);
			}
			for (i in dadMembers) {
				startCharacterScripts(i.curCharacter);
			}

			if (bfGroupFile != null && bfGroupFile.characters != null && bfGroupFile.characters.length > 0) {
				for (i in 0...bfGroupFile.characters.length) {
					addCharacter(bfGroupFile.characters[i].name, i, bfGroupFile.characters[i].insert, true, !opponentChart, bfGroupFile.reversed_layers, boyfriendGroup, boyfriendMembers, bfGroupFile.characters[i].position[0] + bfGroupFile.position[0], bfGroupFile.characters[i].position[1] + bfGroupFile.position[1]);
				}
			} else {
				bfGroupFile = null;
				addCharacter(SONG.player1, 0, true, !opponentChart, false, boyfriendGroup, boyfriendMembers);
			}
			for (i in boyfriendMembers) {
				startCharacterScripts(i.curCharacter);
			}

			GameOverSubState.selfAssignVariables(SONG.player1, voidedHealth);

			if (curSong.startsWith('malder')) {
				var tx:Float = dad.x - 28;
				var ty:Float = dad.y + 260;
				var enableChatboxEffect = FlxG.renderTile && ClientPrefs.gameQuality == "Normal";

				var chatbox:TwitchChatbox;
				var chatboxInsIdx:Int;
				if (enableChatboxEffect) {
					// chatboxTargetSprite = new FlxSprite(tx - 200, ty - 50);
					chatboxTargetSprite = new FlxSprite(tx + 205, ty + 90);
					tx = 240;
					ty = 10;

					// since malder is actually zoomed at a factor of 0.75, add some height, it'll be fiiiiine
					// https://stackoverflow.com/questions/48075991/is-there-a-way-to-apply-an-alpha-mask-to-a-flxcamera
					camChatboxes = new ChatboxCamera(chatboxTargetSprite, 0, 0, FlxG.width, FlxG.height + 200);
					camChatboxes.bgColor.alpha = 0;

					// forward-copypaste CameraFrontEnd.insert from a far later flixel version because what is updating
					var cgIdx = FlxMath.maxInt(0, FlxG.cameras.list.indexOf(camGame));
					FlxG.game.addChildAt(camChatboxes.flashSprite, FlxG.game.getChildIndex(FlxG.cameras.list[cgIdx].flashSprite));
					FlxG.cameras.list.insert(cgIdx, camChatboxes);
					for (i in cgIdx...FlxG.cameras.list.length) {
						FlxG.cameras.list[i].ID = i;
					}
					FlxG.cameras.cameraAdded.dispatch(camChatboxes);
					// forward-copypaste end

					chatboxTargetSprite.frames = FlxG.bitmap.create(camChatboxes.width, camChatboxes.height + 200, 0x42FF0000, true).imageFrame;
					chatboxTargetSprite.shader = new ChatboxWarpShader();

					chatbox = new TwitchChatbox(tx, ty, 460, 720 - 10 + 200);
					chatbox.cameras = [camChatboxes];
					// Completely hardcoded to malder stage hscript!
					chatboxInsIdx = members.indexOf(gfGroup) - 54;
					insert(chatboxInsIdx, chatboxTargetSprite);
					chatboxTargetSprite.scrollFactor.set(0.15, 0.2);
				} else {
					chatbox = new TwitchChatbox(tx, ty);
					chatbox.cameras = [camGame];
					chatboxInsIdx = members.indexOf(gfGroup) - 45;
				}
				insert(chatboxInsIdx, chatbox);
				//dad.alpha = 0.5;

				chatbox.setSpewerChance("player_winning", 0);
				chatbox.setSpewerChance("player_losing", 0);
				chatbox.setSpewerChance("rare", 10);
				chatbox.setSpewerChance("highlight", 5);
				chatbox.setSpewerChance("before_voices", 1000);
				chatbox.setSpewerChance("botplay", cpuControlled ? 400 : 0);
				chatbox.setSpewerChance("mashing", 0);

				for (_ in 0...8) {
					chatbox.generateMessage();
				}
				twitchChatboxes.push(chatbox);
			}

			camPos = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
			if(girlfriendCameraFixed)
			{
				camPos.x += FlxG.camera.width / 2;
				camPos.y += FlxG.camera.height / 2;
			} 
			else if(gf != null)
			{
				camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
				camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
			}

			if (dad.curCharacter.startsWith('gf')) {
				dad.setPosition(GF_X, GF_Y);
				if(gf != null)
					gf.visible = false;
			}

			if (ClientPrefs.gameQuality != 'Crappy') {
				switch(curStage)
				{
					case 'schoolEvil':
						var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069); //nice
						addBehindDad(evilTrail);
				}
			}
		}

		underlayPlayer = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		underlayPlayer.scrollFactor.set();
		underlayPlayer.alpha = ClientPrefs.underlayAlpha;
		underlayPlayer.visible = false;
		add(underlayPlayer);
		hideInDemoMode.push(underlayPlayer);

		underlayOpponent = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		underlayOpponent.scrollFactor.set();
		underlayOpponent.alpha = ClientPrefs.underlayAlpha;
		underlayOpponent.visible = false;
		add(underlayOpponent);
		hideInDemoMode.push(underlayOpponent);

		Conductor.songPosition = -5000;

		//PRECACHING UI IMAGES
		var imagesToCheck = ['combo', 'ready', 'set', 'set_alt', 'go'].concat(
			[for (i in ratingsData) i.image]
		).concat(
			[for (i in (0...10)) 'num$i']
		);

		for (img in imagesToCheck) {
			precacheList.set(SkinData.getSkinFile(UISkin, img).image, 'image');
		}

		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if (ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		{ // @CoolingTool: try to get the position between p1 and p2 strums (this is awful)
			if (!ClientPrefs.middleScroll) {
				var _strum1 = new StrumNote(0, 0, bfKeys-1, 0, bfKeys, SkinData.getSkinModifier(false));
				var _strum2 = new StrumNote(0, 0, 0, 1, dadKeys, SkinData.getSkinModifier(true));

				var left = STRUM_X + _strum1.xOff + (_strum1.swagWidth * (bfKeys-1) + _strum1.width);
				var right = STRUM_X + _strum2.xOff + (FlxG.width / 2);

				_strum1.destroy();
				_strum2.destroy();
				_strum1 = null;
				_strum2 = null;

				betweenStrumOffset = FlxMath.lerp(left, right, 0.5) - FlxG.width / 2;
			} else {
				var _strum = new StrumNote(0, 0, playerKeys-1, 0, playerKeys, SkinData.getSkinModifier());

				var left = STRUM_X_MIDDLESCROLL + _strum.xOff + (FlxG.width / 2);
				var right = left + (_strum.swagWidth * (playerKeys-1) + _strum.width);

				_strum.destroy();
				_strum = null;

				betweenStrumOffset = FlxMath.lerp(left, right, 0.5) - FlxG.width / 2;
			}
		}

		if (!inEditor) {
			timeIcon = new AttachedSprite('placeHud/history');
			timeIcon.yAdd = 1;
			timeIcon.alpha = 0;

			var offset = (-timeIcon.width - 3) / 2;
			if (ClientPrefs.timeBarType == 'Song Name') offset = 0;

			var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
			timeTxt = new FlxText(0, 25, 400, "00:00:00", 20);
			timeTxt.setFormat("Reddit Mono Bold", 20, FlxColor.BLACK, CENTER);
			if (ClientPrefs.timeBarType == 'Song Name') timeTxt.text = curSongDisplayName;
			timeTxt.scrollFactor.set();
			timeTxt.x = betweenStrum - timeTxt.width / 2 - offset;
			timeTxt.antialiasing = ClientPrefs.globalAntialiasing;
			timeTxt.alpha = 0;
			timeTxt.visible = showTime;
			if (!ClientPrefs.middleScroll) {
				if (ClientPrefs.downScroll) timeTxt.y = FlxG.height - timeTxt.height - timeTxt.y;
			} else {
				timeTxt.y = 10;
				if (ClientPrefs.downScroll) timeTxt.y = FlxG.height - 34;
			}

			timeIcon.sprTracker = timeTxt;
			timeIcon.xAdd = offset * 2 + (timeTxt.frameWidth - timeTxt.textField.textWidth) / 2;

			updateTime = showTime;

			timeBarBG = new AttachedPlaceTextBG();
			timeBarBG.scrollFactor.set();
			timeBarBG.alpha = 0;
			timeBarBG.visible = showTime;
			timeBarBG.xAdd = offset;
			timeBarBG.yAdd = 0;
			timeBarBG.sprTracker = timeTxt;
			add(timeBarBG);
			add(timeTxt);
			hideInDemoMode.push(timeTxt);
			hideInDemoMode.push(timeBarBG);

			if (ClientPrefs.timeBarType != 'Song Name') {
				add(timeIcon);
				hideInDemoMode.push(timeIcon);
				if (deathCounter < 1) {
					songTxt = new FlxText(0, timeTxt.y, timeTxt.fieldWidth, curSongDisplayName, 20);
					songTxt.setFormat("Reddit Mono Bold", 20, FlxColor.BLACK, CENTER);
					songTxt.x = betweenStrum - songTxt.width / 2 ;
					songTxt.antialiasing = ClientPrefs.globalAntialiasing;
					songTxt.scrollFactor.set();
					songTxt.alpha = timeTxt.alpha;
					songTxt.borderSize = timeTxt.borderSize;
					songTxt.visible = timeTxt.visible;
					if (showSongText) add(songTxt);
					hideInDemoMode.push(songTxt);
				}	
			}
		} else {
			updateTime = false;
		}

		strumLineNotes = new FlxTypedGroup();
		add(strumLineNotes);
		add(grpNoteSplashes);
		keybindGroup = new FlxTypedGroup();
		hideInDemoMode.push(strumLineNotes);
		hideInDemoMode.push(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100, null);
		grpNoteSplashes.add(splash);
		splash.alphaMult = 0;

		opponentStrums = new FlxTypedGroup();
		playerStrums = new FlxTypedGroup();

		notes = new FlxTypedGroup<Note>();
		add(notes);
		hideInDemoMode.push(notes);
		add(keybindGroup);
		hideInDemoMode.push(keybindGroup);

		generateSong();
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		if (!inEditor) {
			for (notetype in noteTypeMap.keys())
			{
				#if LUA_ALLOWED
				var luaToLoad:String = '';
				#if MODS_ALLOWED
				luaToLoad = Paths.modFolders('custom_notetypes/$notetype.lua');
				if (FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
				else
				{
				#end
					luaToLoad = Paths.getPreloadPath('custom_notetypes/$notetype.lua');
					if (OpenFlAssets.exists(luaToLoad))
					{
						luaArray.push(new FunkinLua(luaToLoad));
					}
				#if MODS_ALLOWED
				}
				#end
				#end

				#if HSCRIPT_ALLOWED
				var hscriptToLoad:String = #if MODS_ALLOWED Paths.modFolders('custom_notetypes/$notetype.hscript') #else '' #end;
				#if MODS_ALLOWED
				if (FileSystem.exists(hscriptToLoad))
				{
					addHscript(hscriptToLoad);
				}
				else
				{
				#end
					hscriptToLoad = Paths.getPreloadPath('custom_notetypes/$notetype.hscript');
					if (OpenFlAssets.exists(hscriptToLoad))
					{
						addHscript(hscriptToLoad);
					}
				#if MODS_ALLOWED
				}
				#end
				#end
			}
			for (event in eventPushedMap.keys())
			{
				#if LUA_ALLOWED
				var luaToLoad:String = '';
				#if MODS_ALLOWED
				luaToLoad = Paths.modFolders('custom_events/$event.lua');
				if (FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
				else
				{
				#end
					luaToLoad = Paths.getPreloadPath('custom_events/$event.lua');
					if (OpenFlAssets.exists(luaToLoad))
					{
						luaArray.push(new FunkinLua(luaToLoad));
					}
				#if MODS_ALLOWED
				}
				#end
				#end

				#if HSCRIPT_ALLOWED
				var hscriptToLoad:String = #if MODS_ALLOWED Paths.modFolders('custom_events/$event.hscript') #else '' #end;
				#if MODS_ALLOWED
				if (FileSystem.exists(hscriptToLoad))
				{
					addHscript(hscriptToLoad);
				}
				else
				{
				#end
					hscriptToLoad = Paths.getPreloadPath('custom_events/$event.hscript');
					if (OpenFlAssets.exists(hscriptToLoad))
					{
						addHscript(hscriptToLoad);
					}
				#if MODS_ALLOWED	
				}
				#end
				#end
			}
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		var doof:DialogueBox = null;
		if (!inEditor) {
			#if MODS_ALLOWED
			var file:String = Paths.modsData('$curSong/dialogue'); //Checks for json/Psych Engine dialogue
			if (FileSystem.exists(file)) {
				dialogueJson = DialogueBoxPsych.parseDialogue(file);
			}

			var file:String = Paths.modsDataTxt('$curSong/${curSong}Dialogue'); //Checks for vanilla/Senpai dialogue
			if (FileSystem.exists(file)) {
				dialogue = CoolUtil.coolTextFile(file);
			}
			#end

			var file:String = Paths.json('$curSong/dialogue'); //Checks for json/Psych Engine dialogue
			if (OpenFlAssets.exists(file) && dialogueJson == null) {
				dialogueJson = DialogueBoxPsych.parseDialogue(file);
			}

			var file:String = Paths.txt('$curSong/${curSong}Dialogue'); //Checks for vanilla/Senpai dialogue
			if (OpenFlAssets.exists(file) && dialogue == null) {
				dialogue = CoolUtil.coolTextFile(file);
			}
			doof = new DialogueBox(dialogue);
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
			doof.nextDialogueThing = startNextDialogue;
			doof.skipDialogueThing = skipDialogue;

			camFollow = new FlxPoint();
			camFollowPos = new FlxObject(0, 0, 1, 1);

			snapCamFollowToPos(camPos.x, camPos.y);
			if (prevCamFollow != null)
			{
				camFollow = prevCamFollow;
				prevCamFollow = null;
			}
			if (prevCamFollowPos != null)
			{
				camFollowPos = prevCamFollowPos;
				prevCamFollowPos = null;
			}
			add(camFollowPos);

			FlxG.camera.follow(camFollowPos, LOCKON, 1);
			currentCamZoom = targetCamZoom;
			FlxG.camera.zoom = currentCamZoom;
			camHUD.zoom = defaultCamHudZoom;
			FlxG.camera.focusOn(camFollow);

			FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

			FlxG.fixedTimestep = false;
			moveCameraSection();

			// health bar zone (internal screaming)
			healthBarBG = new AttachedSprite().makeGraphic(Std.int(100 * daPixelZoom), Std.int(4 * daPixelZoom), FlxColor.BLACK);
			healthBarBG.y = FlxG.height * 0.89;
			healthBarBG.antialiasing = true;
			healthBarBG.x = betweenStrum - healthBarBG.width / 2;
			healthBarBG.scrollFactor.set();
			healthBarBG.visible = !ClientPrefs.hideHud;
			healthBarBG.xAdd = -daPixelZoom;
			healthBarBG.yAdd = -daPixelZoom;
			add(healthBarBG);
			if (ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

			maxhealthBarBG = new AttachedSprite().makeGraphic(1, Std.int(4 * daPixelZoom), 0xff811e9f);
			maxhealthBarBG.antialiasing = true;
			maxhealthBarBG.scrollFactor.set();
			maxhealthBarBG.visible = false;
			maxhealthBarBG.alpha = ClientPrefs.healthBarAlpha;
			maxhealthBarBG.xAdd = -daPixelZoom;
			maxhealthBarBG.yAdd = -daPixelZoom;
			add(maxhealthBarBG);

			minhealthBarBG = new AttachedSprite().makeGraphic(1, Std.int(4 * daPixelZoom), 0xffff4500);
			minhealthBarBG.antialiasing = true;
			minhealthBarBG.scrollFactor.set();
			minhealthBarBG.visible = false;
			minhealthBarBG.alpha = ClientPrefs.healthBarAlpha;
			minhealthBarBG.xAdd = -daPixelZoom;
			minhealthBarBG.yAdd = -daPixelZoom;
			add(minhealthBarBG);

			minhealthBarFG = new AttachedSprite().makeGraphic(1, Std.int(2 * daPixelZoom), 0xff000000);
			minhealthBarFG.antialiasing = true;
			minhealthBarFG.scrollFactor.set();
			minhealthBarFG.visible = false;
			minhealthBarFG.alpha = ClientPrefs.healthBarAlpha;

			healthBar = new FlxBar(healthBarBG.x + daPixelZoom, healthBarBG.y + daPixelZoom, (opponentChart ? LEFT_TO_RIGHT : RIGHT_TO_LEFT), Std.int(healthBarBG.width - daPixelZoom * 2), Std.int(healthBarBG.height - daPixelZoom * 2), this,
				'shownHealth', 0, 2);
			healthBar.antialiasing = true;
			healthBar.scrollFactor.set();
			healthBar.visible = !ClientPrefs.hideHud;
			healthBar.alpha = ClientPrefs.healthBarAlpha;
			if (ClientPrefs.smoothHealth)
				healthBar.numDivisions = Std.int(healthBar.width);
			else
				healthBar.numDivisions = 100;
			add(healthBar);

			healthBarBG.sprTracker = healthBar;
			maxhealthBarBG.sprTracker = healthBar;
			minhealthBarBG.sprTracker = healthBar;
			minhealthBarFG.sprTracker = healthBar;

			add(minhealthBarFG);

			healthIconsP1 = new FlxTypedGroup<HealthIcon>();
			if (bfGroupFile != null) {
				healthIconsP1.add(new HealthIcon(bfGroupFile.healthicon, true));
			} else {
				healthIconsP1.add(new HealthIcon(boyfriend.healthIcon, true));
			}
			iconP1.visible = !ClientPrefs.hideHud;
			iconP1.alpha = ClientPrefs.healthBarAlpha;
			add(healthIconsP1);

			healthIconsP2 = new FlxTypedGroup<HealthIcon>();
			if (dadGroupFile != null) {
				healthIconsP2.add(new HealthIcon(dadGroupFile.healthicon));
			} else {
				healthIconsP2.add(new HealthIcon(dad.healthIcon));
			}
			iconP2.visible = !ClientPrefs.hideHud;
			iconP2.alpha = ClientPrefs.healthBarAlpha;
			add(healthIconsP2);
			reloadHealthBarColors();
			hideInDemoMode = hideInDemoMode.concat([
				healthBarBG, maxhealthBarBG, minhealthBarBG, minhealthBarFG, healthBar, healthIconsP1, healthIconsP2
			]);
		}

		if (!inEditor) {
			#if BOTPLAY_HIDDEN
			var bot = false;
			#else
			var bot = cpuControlled;
			#end

			scoreTxt = new FlxText(0, FlxG.height * 0.89 + 36, FlxG.width - 20, "", 20);
			if (ClientPrefs.downScroll) {
				scoreTxt.y = 0.11 * FlxG.height + 36;
			}
			scoreTxt.setFormat("Reddit Mono Bold", 20, FlxColor.BLACK, CENTER);
			scoreTxt.antialiasing = ClientPrefs.globalAntialiasing;
			scoreTxt.scrollFactor.set();
			scoreTxt.x = betweenStrum - scoreTxt.width / 2;
			scoreTxt.visible = !ClientPrefs.hideHud && !bot;
			scoreBG = new AttachedCheapPlaceTextBG();
			scoreBG.visible = !ClientPrefs.hideHud && !bot;
			scoreBG.copyScale = true;
			scoreBG.copyWidth = true;
			scoreBG.sprTracker = scoreTxt;
			add(scoreBG);
			add(scoreTxt);
			hideInDemoMode.push(scoreTxt);

			var offset = 78;
			botplayTxt = new FlxText(400, timeTxt.y + offset, FlxG.width - 800, "BOTPLAY", 32);
			botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			botplayTxt.x = betweenStrum - botplayTxt.width / 2;
			botplayTxt.scrollFactor.set();
			botplayTxt.borderSize = 1.25;
			botplayTxt.visible = bot;
			add(botplayTxt);
			if (ClientPrefs.downScroll) {
				botplayTxt.y = timeTxt.y - offset - botplayTxt.height + timeTxt.height;
			}
			hideInDemoMode.push(botplayTxt);

			practiceFailedTxt = new FlxText(400, timeBarBG.y + 105, FlxG.width - 800, "Failed!", 32);
			practiceFailedTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			practiceFailedTxt.scrollFactor.set();
			practiceFailedTxt.borderSize = 1.25;
			practiceFailedTxt.visible = practiceMode;
			practiceFailedTxt.alpha = 0;
			add(practiceFailedTxt);
			if (ClientPrefs.downScroll) {
				practiceFailedTxt.y = timeBarBG.y - 128;
			}
			hideInDemoMode.push(practiceFailedTxt);
		} else {
			scoreTxt = new FlxText(0, FlxG.height * 0.89 + 36, FlxG.width - 20, "", 20);
			scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			scoreTxt.scrollFactor.set();
			scoreTxt.borderSize = 1.25;
			add(scoreTxt);

			sectionTxt = new FlxText(10, 580, FlxG.width - 20, "Section: 0", 20);
			sectionTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			sectionTxt.scrollFactor.set();
			sectionTxt.borderSize = 1.25;
			add(sectionTxt);

			beatTxt = new FlxText(10, sectionTxt.y + 30, FlxG.width - 20, "Beat: 0", 20);
			beatTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			beatTxt.scrollFactor.set();
			beatTxt.borderSize = 1.25;
			add(beatTxt);

			stepTxt = new FlxText(10, beatTxt.y + 30, FlxG.width - 20, "Step: 0", 20);
			stepTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			stepTxt.scrollFactor.set();
			stepTxt.borderSize = 1.25;
			add(stepTxt);
			
			var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
			tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tipText.borderSize = 2;
			tipText.scrollFactor.set();
			add(tipText);
		}

		ratingTxtGroup = new FlxTypedGroup<FlxText>();
		ratingTxtGroup.visible = !ClientPrefs.hideHud && ClientPrefs.showRatings;
		hideInDemoMode.push(ratingTxtGroup);
		for (i in 0...5) {
			var ratingTxt = new FlxText(20, FlxG.height * 0.5 - 8 + (16 * (i - 2)), FlxG.width, "", 16);
			ratingTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			ratingTxt.scrollFactor.set();
			ratingTxtGroup.add(ratingTxt);
		}
		add(ratingTxtGroup);

		if (!inEditor) {
			strumLineNotes.cameras = [camHUD];
			grpNoteSplashes.cameras = [camHUD];
			notes.cameras = [camHUD];
			tendrils.cameras = [camHUD];
			underlayPlayer.cameras = [camHUD];
			underlayOpponent.cameras = [camHUD];
			scoreTxt.cameras = [camHUD];
			scoreBG.cameras = [camHUD];
			ratingTxtGroup.cameras = [camHUD];
			healthBar.cameras = [camHUD];
			healthBarBG.cameras = [camHUD];
			maxhealthBarBG.cameras = [camHUD];
			minhealthBarBG.cameras = [camHUD];
			minhealthBarFG.cameras = [camHUD];
			healthIconsP1.cameras = [camHUD];
			healthIconsP2.cameras = [camHUD];
			botplayTxt.cameras = [camHUD];
			timeBarBG.cameras = [camHUD];
			timeTxt.cameras = [camHUD];
			timeIcon.cameras = [camHUD];
			practiceFailedTxt.cameras = [camHUD];
			timeBarBG.cameras = [camHUD];
			timeTxt.cameras = [camHUD];
			if (showSongText && songTxt != null) songTxt.cameras = [camHUD];
			doof.cameras = [camHUD];
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// SONG SPECIFIC SCRIPTS
		if (!inEditor) {
			var filesPushed:Array<String> = [];
			var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/$curSong/')];

			#if MODS_ALLOWED
			foldersToCheck.insert(0, Paths.mods('data/$curSong/'));
			if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
				foldersToCheck.insert(0, Paths.mods('${Paths.currentModDirectory}/data/$curSong/'));
			for(mod in Paths.getGlobalMods())
				foldersToCheck.insert(0, Paths.mods(mod + '/data/' + Paths.formatToSongPath(SONG.song) + '/' ));

			for (folder in foldersToCheck)
			{
				if (FileSystem.exists(folder))
				{
					for (file in FileSystem.readDirectory(folder))
					{
						#if LUA_ALLOWED
						if (file.endsWith('.lua') && !filesPushed.contains(file))
						{
							luaArray.push(new FunkinLua(folder + file));
							filesPushed.push(file);
						}
						#end

						#if HSCRIPT_ALLOWED
						if (file.endsWith('.hscript') && !filesPushed.contains(file))
						{
							addHscript(folder + file);
							filesPushed.push(file);
						}
						#end
					}
				}
			}
			#end

			#if HSCRIPT_ALLOWED
			if (OpenFlAssets.exists(Paths.getPreloadPath('data/$curSong/$curSong.hscript')) && !filesPushed.contains('$curSong.hscript')) {
				addHscript(Paths.getPreloadPath('data/$curSong/$curSong.hscript'));
				filesPushed.push('$curSong.hscript');
			}
			#end
		}
		#end
		
		if (!inEditor && isStoryMode && !seenCutscene) {
			switch (curSong) {
				// Starter cutscenes here, apparently
				default:
					startCountdown();
			}
			seenCutscene = true;
		} else {
			startCountdown();
		}
		recalculateRating();

		//PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if(ClientPrefs.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');
		
		if (PauseSubState.songName != null) {
			precacheList.set(PauseSubState.songName, 'music');
		} else if(ClientPrefs.pauseMusic != 'None') {
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}

		#if DISCORD_ALLOWED
		if (!inEditor) {
			// Updating Discord Rich Presence.
			DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter());
		}
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * playbackRate;

		#if HSCRIPT_ALLOWED
		postSetHscript();
		#end
		callOnScripts('onCreatePost', []);

		//cache note splashes
		var textureMap:Map<String, Bool> = new Map();
		precacheList.set('noteskins/default/base/noteSplashes', 'image');
		textureMap.set('noteskins/default/base/noteSplashes', true);
		for (note in unspawnNotes) {
			if (note.noteSplashTexture != null && note.noteSplashTexture.length > 0 && !note.noteSplashDisabled && !textureMap.exists(note.noteSplashTexture)) {
				var skin = SkinData.getSkinFile(Noteskin, note.noteSplashTexture).image;
				precacheList.set(skin, 'image');
				textureMap.set(skin, true);
			}
		}

		#if mobile
		grpNoteButtons.cameras = [camButtons];
		if (!ClientPrefs.controllerMode)
			add(grpNoteButtons);

		grpButtons.cameras = [camButtons];
		add(grpButtons);
		#end

		super.create();

		Paths.clearUnusedMemory();

		for (key => type in precacheList)
		{
			switch(type)
			{
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}

		if (!inEditor) {
			CustomFadeTransition.nextCamera = camOther;
			// @Square789: super.create() call at the very end of functions, why?
			// Well, whatever, this needs to go here.
			readdOrSetAchievementNotificationBoxCamera(camHUD);
		}
	}

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			for (note in notes) note.resizeByRatio(ratio);
			for (note in unspawnNotes) note.resizeByRatio(ratio);
		}
		songSpeed = value;
		setOnScripts('scrollSpeed', songSpeed);
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor = FlxColor.WHITE) {
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if (luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
		#end
	}

	public function reloadHealthBarColors() {
		var healthColors = [dad.healthColorArray, boyfriend.healthColorArray];
		if (dadGroupFile != null) {
			healthColors[0] = dadGroupFile.healthbar_colors;
		}
		if (bfGroupFile != null) {
			healthColors[1] = bfGroupFile.healthbar_colors;
		}
		if (!opponentChart) {
			healthBar.createFilledBar(FlxColor.fromRGB(healthColors[0][0], healthColors[0][1], healthColors[0][2]),
			FlxColor.fromRGB(healthColors[1][0], healthColors[1][1], healthColors[1][2]));
		} else {
			healthBar.createFilledBar(FlxColor.fromRGB(healthColors[1][0], healthColors[1][1], healthColors[1][2]),
			FlxColor.fromRGB(healthColors[0][0], healthColors[0][1], healthColors[0][2]));
		}
		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int, ?index:Int = 0) {
		switch(type) {
			case 0:
				if (!boyfriendMap.exists(newCharacter)) {
					var xOffset = 0.0;
					var yOffset = 0.0;
					if (bfGroupFile != null) {
						xOffset = (bfGroupFile.characters[index] != null ? bfGroupFile.characters[index].position[0] : 0);
						yOffset = (bfGroupFile.characters[index] != null ? bfGroupFile.characters[index].position[1] : 0);
					}
					var newBoyfriend = addCharacter(newCharacter, index, true, !opponentChart, false, null, null, xOffset, yOffset);
					boyfriendMap.set(newCharacter, newBoyfriend);
					//newBoyfriend.alpha = 0.00001;
					//add(newBoyfriend); FUCK YOU!!!!!
					startCharacterScripts(newCharacter);
				}

			case 1:
				if (!dadMap.exists(newCharacter)) {
					var xOffset = 0.0;
					var yOffset = 0.0;
					if (dadGroupFile != null) {
						xOffset = (dadGroupFile.characters[index] != null ? dadGroupFile.characters[index].position[0] : 0);
						yOffset = (dadGroupFile.characters[index] != null ? dadGroupFile.characters[index].position[1] : 0);
					}
					var newDad = addCharacter(newCharacter, index, false, opponentChart, false, null, null, xOffset, yOffset);
					dadMap.set(newCharacter, newDad);
					//newDad.alpha = 0.00001;
					//add(newDad); FUCK YOU!!!!!
					startCharacterScripts(newCharacter);
				}

			case 2:
				if (!gfMap.exists(newCharacter)) {
					var xOffset = 0.0;
					var yOffset = 0.0;
					if (gfGroupFile != null) {
						xOffset = (gfGroupFile.characters[index] != null ? gfGroupFile.characters[index].position[0] : 0);
						yOffset = (gfGroupFile.characters[index] != null ? gfGroupFile.characters[index].position[1] : 0);
					}
					var newGf = addCharacter(newCharacter, index, false, false, false, null, null, xOffset, yOffset, 0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					//newGf.alpha = 0.00001;
					//add(newGf); FUCK YOU!!!!!
					startCharacterScripts(newCharacter);
				}
		}
	}

	#if HSCRIPT_ALLOWED
	var hscriptMap:Map<String, FunkinHscript> = new Map();
	public function addHscript(path:String) {
		var parser = new ParserEx();
		try {
			var program = parser.parseString(Paths.getContent(path));
			var interp = new FunkinHscript(path);

			//FUNCTIONS
			interp.variables.set("addHaxeLibrary", function(libName:String, ?libFolder:String = '') {
				try {
					var str:String = '';
					if(libFolder.length > 0)
						str = libFolder + '.';
	
					interp.variables.set(libName, Type.resolveClass(str + libName));
				}
				catch (e:Dynamic) {
					addTextToDebug(interp.scriptName + ":" + interp.lastCalledFunction + " - " + e, FlxColor.RED);
				}
			});
			interp.variables.set('addBehindChars', function(obj:FlxBasic) {
				var index = members.indexOf(gfGroup);
				if (members.indexOf(dadGroup) < index) {
					index = members.indexOf(dadGroup);
				}
				if (members.indexOf(boyfriendGroup) < index) {
					index = members.indexOf(boyfriendGroup);
				}
				insert(index, obj);
			});
			interp.variables.set('addOverChars', function(obj:FlxBasic) {
				var index = members.indexOf(boyfriendGroup);
				if (members.indexOf(dadGroup) > index) {
					index = members.indexOf(dadGroup);
				}
				if (members.indexOf(gfGroup) > index) {
					index = members.indexOf(gfGroup);
				}
				insert(index + 1, obj);
			});
			interp.variables.set('getObjectOrder', function(obj:Dynamic) {
				if ((obj is String)) {
					var basic:FlxBasic = Reflect.getProperty(this, obj);
					if (basic != null) {
						return members.indexOf(basic);
					}
					return -1;
				} else {
					return members.indexOf(obj);
				}
			});
			interp.variables.set('setObjectOrder', function(obj:Dynamic, pos:Int = 0) {
				if ((obj is String)) {
					var basic:FlxBasic = Reflect.getProperty(this, obj);
					if (basic != null) {
						if (members.indexOf(basic) > -1) {
							remove(basic);
						}
						insert(pos, basic);
					}
				} else {
					if (members.indexOf(obj) > -1) {
						remove(obj);
					}
					insert(pos, obj);
				}
			});
			interp.variables.set('getProperty', function(variable:String) {
				return Reflect.getProperty(this, variable);
			});
			interp.variables.set('setProperty', function(variable:String, value:Dynamic) {
				Reflect.setProperty(this, variable, value);
			});
			interp.variables.set('getPropertyFromClass', function(classVar:String, variable:String) {
				return Reflect.getProperty(Type.resolveClass(classVar), variable);
			});
			interp.variables.set('setPropertyFromClass', function(classVar:String, variable:String, value:Dynamic) {
				Reflect.setProperty(Type.resolveClass(classVar), variable, value);
			});
			interp.variables.set('loadSong', function(name:String = null, ?difficultyNum:Int = -1, ?skipTransition:Bool = false) {
				if (name == null) name = SONG.song;
				if (difficultyNum < 0) difficultyNum = storyDifficulty;
				FlxG.timeScale = 1;
	
				if (skipTransition)
				{
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
				}
	
				if (isStoryMode && !transitioning) {
					campaignScore += songScore;
					campaignMisses += songMisses;
					storyPlaylist.remove(storyPlaylist[0]);
					storyPlaylist.insert(0, name);
				}
	
				CoolUtil.getDifficulties(name, true);
				if (difficultyNum >= CoolUtil.difficulties.length) {
					difficultyNum = CoolUtil.difficulties.length - 1;
				}
				var poop = Highscore.formatSong(name, difficultyNum, false);
				SONG = Song.loadFromJson(poop, name);
				storyDifficulty = difficultyNum;
				instance.persistentUpdate = false;
				cancelMusicFadeTween();
				deathCounter = 0;
				FlxG.sound.music.pause();
				FlxG.sound.music.volume = 0;
				if(vocals != null)
				{
					vocals.pause();
					vocals.volume = 0;
				}
				if(vocalsDad != null)
				{
					vocalsDad.pause();
					vocalsDad.volume = 0;
				}
				LoadingState.loadAndResetState();
			});
			interp.variables.set("endSong", function() {
				killNotes();
				finishSong(true);
			});
			interp.variables.set("restartSong", function(skipTransition:Bool = false) {
				persistentUpdate = false;
				PauseSubState.restartSong(skipTransition);
			});
			interp.variables.set("exitSong", function(skipTransition:Bool = false) {
				if (skipTransition)
				{
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
				}
				FlxG.timeScale = 1;
	
				WeekData.loadTheFirstEnabledMod();
				cancelMusicFadeTween();
				CustomFadeTransition.nextCamera = camOther;
				if (FlxTransitionableState.skipNextTransIn)
					CustomFadeTransition.nextCamera = null;
	
				if (isStoryMode)
					MusicBeatState.switchState(new MainMenuF4rpState(true));
				else
					MusicBeatState.switchState(new FreeplayPlaceState());
	
				CoolUtil.playMenuMusic();
				#if cpp
				@:privateAccess
				AL.sourcef(FlxG.sound.music._channel.__source.__backend.handle, AL.PITCH, 1);
				#end
				changedDifficulty = false;
				chartingMode = false;
				instance.transitioning = true;
				deathCounter = 0;
			});
			interp.variables.set('openCredits', function(playMusic:Bool = true) {
				FlxG.timeScale = 1;
				WeekData.loadTheFirstEnabledMod();
				cancelMusicFadeTween();
				CustomFadeTransition.nextCamera = camOther;
				if (FlxTransitionableState.skipNextTransIn)
					CustomFadeTransition.nextCamera = null;

				MusicBeatState.switchState(new CreditsState());

				FlxG.sound.music.stop();
				if (playMusic) {
					CoolUtil.playMenuMusic();
					#if cpp
					@:privateAccess
					AL.sourcef(FlxG.sound.music._channel.__source.__backend.handle, AL.PITCH, 1);
					#end
				}
				changedDifficulty = false;
				chartingMode = false;
				transitioning = true;
				deathCounter = 0;
			});
			interp.variables.set("setHealthBarColors", function(left:String = '0xFFFF0000', right:String = '0xFF66FF33') {
				var leftColorNum:Int = Std.parseInt(left);
				if (!left.startsWith('0x')) leftColorNum = Std.parseInt('0xff$left');
				var rightColorNum:Int = Std.parseInt(right);
				if (!right.startsWith('0x')) rightColorNum = Std.parseInt('0xff$right');
	
				healthBar.createFilledBar(leftColorNum, rightColorNum);
				healthBar.updateBar();
			});
			interp.variables.set("startDialogue", function(dialogueFile:String, music:String = null) {
				#if MODS_ALLOWED
				var path:String = Paths.modsData('${Paths.formatToSongPath(SONG.song)}/$dialogueFile');
				if (!FileSystem.exists(path)) {
					path = Paths.json('${Paths.formatToSongPath(SONG.song)}/$dialogueFile');
				}
				#else
				var path:String = Paths.json('${Paths.formatToSongPath(SONG.song)}/$dialogueFile');
				#end
				addTextToDebug('Trying to load dialogue: $path');
	
				if (#if MODS_ALLOWED FileSystem.exists(path) || #end OpenFlAssets.exists(path)) {
					var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
					if (shit.dialogue.length > 0) {
						startDialogue(shit, music);
						addTextToDebug('Successfully loaded dialogue');
					} else {
						addTextToDebug('Your dialogue file is badly formatted!');
					}
				} else {
					addTextToDebug('Dialogue file not found');
					startAndEnd();
				}
			});
			interp.variables.set("setWeekCompleted", function(name:String = '') {
				if(name.length > 0)
				{
					var weekName = WeekData.formatWeek(name);
					FlxG.save.data.weekCompleted.set(weekName, true);
					FlxG.save.flush();
				}
			});
			interp.variables.set("close", function() {
				interp.closed = true;
				return interp.closed;
			});
			interp.variables.set('addScript', function(name:String, ?ignoreAlreadyRunning:Bool = false) {
				var cervix = '$name.hscript';
				var doPush = false;
				#if MODS_ALLOWED
				if (FileSystem.exists(Paths.modFolders(cervix))) {
					cervix = Paths.modFolders(cervix);
					doPush = true;
				} else {
					cervix = Paths.getPreloadPath(cervix);
					if (OpenFlAssets.exists(cervix)) {
						doPush = true;
					}	
				}
				#else
				cervix = Paths.getPreloadPath(cervix);
				if (OpenFlAssets.exists(cervix)) {
					doPush = true;
				}
				#end
	
				if (doPush)
				{
					if (!ignoreAlreadyRunning && hscriptMap.exists(cervix))
					{
						addTextToDebug('The script "$cervix" is already running!');
						return;
					}
					addHscript(cervix);
					return;
				}
				addTextToDebug("Script doesn't exist!");
			});
			interp.variables.set('removeScript', function(name:String) {
				var cervix = '$name.hscript';
				var doPush = false;
				#if MODS_ALLOWED
				if (FileSystem.exists(Paths.modFolders(cervix))) {
					cervix = Paths.modFolders(cervix);
					doPush = true;
				} else {
					cervix = Paths.getPreloadPath(cervix);
					if (OpenFlAssets.exists(cervix)) {
						doPush = true;
					}	
				}
				#else
				cervix = Paths.getPreloadPath(cervix);
				if (OpenFlAssets.exists(cervix)) {
					doPush = true;
				}
				#end
	
				if (doPush)
				{
					if (hscriptMap.exists(cervix))
					{
						var hscript = hscriptMap.get(cervix);
						hscriptMap.remove(cervix);
						hscript = null;
						return;
					}
					return;
				}
				addTextToDebug("Script doesn't exist!");
			});
			interp.variables.set('debugPrint', function(text:Dynamic) {
				addTextToDebug('$text');
				trace(text);
			});
			interp.variables.set('makeInflatedPixelGraphic', function(s:FlxSprite, color:FlxColor, width:Int, height:Int) {
				s.makeGraphic(1, 1, color);
				s.origin.set(0, 0);
				s.scale.set(width, height);
				// updateHitbox also screws with offset and origin which i do not want. Set these manually.
				s.width = width;
				s.height = height;
				return s;
			});

			//EVENTS
			var funcs = [
				'onStepHit',
				'onBeatHit',
				'onStartCountdown',
				'onSongStart',
				'onEndSong',
				'onSkipCutscene',
				'onBPMChange',
				'onSignatureChange',
				'onKeyChange',
				'onOpenChartEditor',
				'onOpenCharacterEditor',
				'onPause',
				'onResume',
				'onGameOver',
				'onRecalculateRating'
			];
			for (i in funcs)
				interp.variables.set(i, function() {});
			interp.variables.set('onCountdownTick', function(counter) {});
			interp.variables.set('onGameOverConfirm', function(retry) {});
			interp.variables.set('onNextDialogue', function(line) {});
			interp.variables.set('onSkipDialogue', function(line) {});
			interp.variables.set('goodNoteHit', function(index, direction, noteType, isSustainNote, characters) {});
			interp.variables.set('opponentNoteHit', function(index, direction, noteType, isSustainNote, characters) {});
			interp.variables.set('noteMissPress', function(direction) {});
			interp.variables.set('noteMiss', function(index, direction, noteType, isSustainNote, characters) {});
			interp.variables.set('onMoveCamera', function(focus) {});
			interp.variables.set('onEvent', function(name, value1, value2) {});
			interp.variables.set('eventPushed', function(name, strumTime, value1, value2) {});
			interp.variables.set('eventEarlyTrigger', function(name) {});
			interp.variables.set('onTweenCompleted', function(tag) {});
			interp.variables.set('onTimerCompleted', function(tag, loops, loopsLeft) {});
			interp.variables.set('onSpawnNote', function(index, direction, noteType, isSustainNote, characters) {});
			interp.variables.set('onGhostTap', function(direction) {});

			interp.execute(program);
			hscriptMap.set(path, interp);
			callHscript(path, 'onCreate', []);
		} catch (e) {
			trace(e);
			addTextToDebug('$e');
			addTextToDebug('Could not load script $path');
		}
	}

	function callHscript(name:String, func:String, args:Array<Dynamic>) {
		if (!hscriptMap.exists(name) || !hscriptMap.get(name).variables.exists(func)) {
			return FunkinLua.Function_Continue;
		}
		var hscript = hscriptMap.get(name);
		hscript.lastCalledFunction = func;
		var method = hscript.variables.get(func);
		var ret:Dynamic = null;
		//need a better way for this ;v;
		//you really did starmapo
		if (Reflect.isFunction(method)) {
			switch(args.length) {
				case 0:
					ret = method();
				case 1:
					ret = method(args[0]);
				case 2:
					ret = method(args[0], args[1]);
				case 3:
					ret = method(args[0], args[1], args[2]);
				case 4:
					ret = method(args[0], args[1], args[2], args[3]);
				case 5:
					ret = method(args[0], args[1], args[2], args[3], args[4]);
				case 6:
					ret = method(args[0], args[1], args[2], args[3], args[4], args[5]);
			}
			if (ret != null && ret != FunkinLua.Function_Continue) {
				return ret;
			}
		}
		return FunkinLua.Function_Continue;
	}

	function postSetHscript() {
		if (!inEditor) {
			setOnHscripts('boyfriend', boyfriend);
			setOnHscripts('dad', dad);
			setOnHscripts('gf', gf);
			setOnHscripts('strumLineNotes', strumLineNotes);
			setOnHscripts('playerStrums', playerStrums);
			setOnHscripts('opponentStrums', opponentStrums);
			setOnHscripts('iconP1', iconP1);
			setOnHscripts('iconP2', iconP2);
			setOnHscripts('grpNoteSplashes', grpNoteSplashes);
			setOnHscripts('scoreTxt', scoreTxt);
			setOnHscripts('ratingTxtGroup', ratingTxtGroup);
			setOnHscripts('healthBar', healthBar);
			setOnHscripts('healthBarBG', healthBarBG);
			setOnHscripts('botplayTxt', botplayTxt);
			setOnHscripts('practiceFailedTxt', practiceFailedTxt);
			//setOnHscripts('timeBar', timeBar);
			setOnHscripts('timeBarBG', timeBarBG);
			setOnHscripts('timeTxt', timeTxt);
			setOnHscripts('boyfriendGroup', boyfriendGroup);
			setOnHscripts('dadGroup', dadGroup);
			setOnHscripts('gfGroup', gfGroup);
			setOnHscripts('underlayPlayer', underlayPlayer);
			setOnHscripts('underlayOpponent', underlayOpponent);
			setOnHscripts('camGame', camGame);
			setOnHscripts('camHUD', camHUD);
			setOnHscripts('camOther', camOther);
			setOnHscripts('camFollow', camFollow);
			setOnHscripts('camFollowPos', camFollowPos);
			setOnHscripts('strumLine', strumLine);
			setOnHscripts('notes', notes);
			setOnHscripts('unspawnNotes', unspawnNotes);
			setOnHscripts('eventNotes', eventNotes);
			setOnHscripts('vocals', vocals);
			setOnHscripts('vocalsDad', vocalsDad);
		}
	}
	#end

	function setOnHscripts(variable:String, arg:Dynamic) {
		#if HSCRIPT_ALLOWED
		for (i in hscriptMap.keys()) {
			hscriptMap.get(i).variables.set(variable, arg);
		}
		#end
	}

	function startCharacterScripts(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
		#end
			luaFile = Paths.getPreloadPath(luaFile);
			if (OpenFlAssets.exists(luaFile)) {
				doPush = true;
			}
		#if MODS_ALLOWED
		}
		#end
		
		if (doPush)
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaFile) return;
			}
			luaArray.push(new FunkinLua(luaFile));
		}
		#end

		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var hscriptFile:String = 'characters/$name.hscript';
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders(hscriptFile))) {
			hscriptFile = Paths.modFolders(hscriptFile);
			doPush = true;
		} else {
		#end
			hscriptFile = Paths.getPreloadPath(hscriptFile);
			if (OpenFlAssets.exists(hscriptFile)) {
				doPush = true;
			}
		#if MODS_ALLOWED
		}
		#end
		
		if (doPush && !hscriptMap.exists(hscriptFile))
		{
			addHscript(hscriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		return null;
	}
	
	function startCharacterPos(char:Character, gfCheck:Bool = false) {
		if (gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	function addCharacter(name:String, index:Int = 0, insertAt:Int = -1, flipped:Bool = false, isPlayer:Bool = false, reversed:Bool = false, ?group:FlxTypedSpriteGroup<Character>, ?members:Array<Character>, xOffset:Float = 0, yOffset:Float = 0, scrollX:Float = 1, scrollY:Float = 1):Character {
		var char = new Character(0, 0, name, flipped);
		char.isPlayer = isPlayer;
		startCharacterPos(char);
		char.x += xOffset;
		char.y += yOffset;
		char.scrollFactor.set(scrollX, scrollY);
		if (members != null) {
			members.push(char);
		}

		if (group != null) {
			if (insertAt != -1) {
				char.x += group.x;
				char.y += group.y;
				insert(insertAt, char);
			} else if (!reversed) {
				group.add(char);
			} else {
				group.insert(0, char);
			}
		}
		return char;
	}
	
	// @CoolingTool: fucking hate this engine sometimes like why did this not exist before wtf
	function replaceCharacter(name:String, ?charType:Int = 0, index:Int) {
		var group = boyfriendGroup;
		var members = boyfriendMembers;
		var map = boyfriendMap;
		var type = 'boyfriend';
		var icon = iconP1;

		switch (charType) {
			case 1:
				group = dadGroup;
				members = dadMembers;
				map = dadMap;
				type = 'dad';
				icon = iconP2;
			case 2:
				group = gfGroup;
				members = gfMembers;
				map = gfMap;
				type = 'gf';
				icon = null;
		}

		index %= members.length;

		// get characters
		if (!map.exists(name)) addCharacterToList(name, charType, index);
		var oldChar = members[index];
		var newChar = map.get(name);

		// things
		var thing:Dynamic = group;
		var gindex = thing.members.indexOf(oldChar);
		var wasGf:Bool = oldChar.curCharacter.startsWith('gf');
		var lastAlpha:Float = oldChar.alpha;

		if (gindex == -1) { // char might be outside of group
			thing = this;
			gindex = thing.members.indexOf(oldChar);
			if (gindex == -1) return;
			newChar.x += group.x;
			newChar.y += group.y;
		}

		thing.remove(oldChar, true);
		members[index] = thing.insert(gindex, newChar);

		if (type == 'dad' && gf != null) {
			if (!newChar.curCharacter.startsWith('gf')) {
				if (wasGf)
					gf.visible = true;
			} else {
				gf.visible = false;
			}
		}
		newChar.alpha = lastAlpha;

		// set misc shit
		var char = Reflect.getProperty(this, type);
		if (icon != null && members.length == 1)
			icon.changeIcon(char.healthIcon);
		setOnScripts(type + 'Name', char.curCharacter);
		setOnHscripts(type, char);
		reloadHealthBarColors();
	}

	#if VIDEOS_ALLOWED
	public var video:MP4Handler;
	#end
	public function startVideo(name:String):Void {
		#if VIDEOS_ALLOWED
		inCutscene = true;

		var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
			-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		blackShit.scrollFactor.set();
		add(blackShit);
		var lastVisible:Bool = camHUD.visible;
		camHUD.visible = false;

		var filepath:String = Paths.video(name);
		#if sys
		if(!FileSystem.exists(filepath))
		#else
		if(!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return;
		}

		FlxG.sound.music.stop();
		video = new MP4Handler(); //note: not actually limited to mp4s
		video.playVideo(filepath);
		video.finishCallback = function()
		{
			startAndEnd();
			remove(blackShit);
			blackShit.destroy();
			camHUD.visible = lastVisible;
			video = null;
			return;
		}
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		return;
		#end
	}

	function startAndEnd() {
		if (endingSong)
			endSong();
		else if (startingSong)
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null) return;

		if (dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			if (endingSong) {
				endSong();
			} else {
				startCountdown();
			}
		}
	}

	var startTimer:FlxTimer;
	var endingTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	// @CoolingTool: why the fuck did i do this
	public var countdownReady:FarpSprite;
	public var countdownSet:FarpSprite;
	public var countdownGo:FarpSprite;
	public var countdownImages:Array<String> = [null, 'ready', 'set', 'go'];
	public var countdownTags:Array<String> = [null, 'countdownReady', 'countdownSet', 'countdownGo'];
	public var countdownLength:Int = 5;

	public var popup:FlxSprite;
	public var nonPixelPopups:Array<String> = ["enough-alt"];
	public static var startOnTime:Float = 0;
	public static var startOnTimeOffset:Float = 500;
	public var introSoundsSuffix = '';

	public function startCountdown():Void
	{
		if (startedCountdown) {
			callOnScripts('onStartCountdown', []);
			return;
		}

		// @Square789: Yeah that's the worst possible location for this
		if (FlxG.random.int(1, 10) == 10) {
			countdownImages[2] = "set_alt";
		}

		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', [], false);
		if (ret != FunkinLua.Function_Stop) {
			FlxG.timeScale = playbackRate;
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0, dadKeys);
			generateStaticArrows(1, bfKeys);
			switchKeys(bfKeys, dadKeys, true);
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX$i', playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY$i', playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX$i', opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY$i', opponentStrums.members[i].y);
			}

			#if mobile
			addMobileButtons();
			#end

			startedCountdown = true;
			if (inEditor) {
				return;
			}

			Conductor.songPosition = 0;
			Conductor.songPosition -= Conductor.normalizedCrochet * countdownLength;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', []);

			var swagCounter:Int = 0;

			if (skipCountdown || startOnTime > 0) {
				clearNotesBefore(startOnTime - startOnTimeOffset);
				setSongTime(startOnTime - startOnTimeOffset);
				FlxG.sound.music.pause();
				vocals.pause();
				vocalsDad.pause();
			}
			if (skipCountdown) {
				return;
			}

			if (!inEditor) {
				// popup and composer/charter names etc.
				var songName = Paths.formatToSongPath(SONG.song);
				var composers = SONG?.meta?.composers ?? Song.getComposers(SONG.song);
				if (songName == 'enough' && FlxG.random.bool(1)) {
					songName = 'enough-alt';
				}

				var subPopupRows:Array<{icon:String, text:String}> = [];
				if (composers.length > 0) {
					subPopupRows.push({icon: "composer", text: composers.join(", ")});
				}
				if (SONG.charterNames != null && SONG.charterNames.length > 0) {
					subPopupRows.push({icon: "charter", text: SONG.charterNames.join(", ")});
				};

				var popupStuff:Array<{o:FlxSprite, s:Float}> = [];

				var popupName:String = 'songPopups/$songName';
				var stuffYStart:Float = FlxG.height / 2.0;
				if (Paths.fileExists('images/$popupName.png', IMAGE)) {
					var pixel = !nonPixelPopups.contains(songName);
	
					popup = new FlxSprite().loadGraphic(Paths.image(popupName));
					popup.setGraphicSize(Std.int(popup.width * (pixel ? 4.0 : 1.0)));
					popup.updateHitbox();
					popup.x = CoolUtil.getGameWidth() - popup.width;
					popup.screenCenter(Y);
					popup.antialiasing = ClientPrefs.globalAntialiasing && !pixel;
					popup.scrollFactor.set();
					popupStuff.push({o: popup, s: pixel ? 1.0 : 4.0});

					showSongText = false;
					stuffYStart = popup.y + popup.height + 8;
				}

				for (entry in subPopupRows) {
					var line = new TitleCardFont(0, stuffYStart, entry.text);
					line.x = CoolUtil.getGameWidth() - line.width;
					popupStuff.push({o: line, s: 1.0});

					var icon = new FlxSprite(line.x - 44, stuffYStart + 4);
					icon.loadGraphic(Paths.image('songPopups/_icon_${entry.icon}'));
					icon.setGraphicSize(40, 40);
					icon.updateHitbox();
					popupStuff.push({o: icon, s: 1.0});

					stuffYStart += line.height;
				}

				var container = null;
				for (x in popupStuff) {
					if (container == null)
						container = x.o.getScreenBounds(camHUD);
					else
						container.union(x.o.getScreenBounds(camHUD));
				}

				var _shaders:Array<PixelErasureShader> = [];
				for (x in popupStuff) {
					var shader = new PixelErasureShader();
					shader.pixel_dimensions.value = [x.s, x.s];
					shader.palette.input = new BitmapData(1, 1, true, FlxColor.TRANSPARENT);
					shader.pixel_health.value[0] = 0.0;

					x.o.y = (FlxG.height - container.height) / 2 + (x.o.y - container.y);

					x.o.cameras = [camHUD];
					x.o.shader = shader;
					add(x.o);
					_shaders.push(shader);
				}
				if (_shaders.length > 0 ) {
					var md = new MultiDissolver(_shaders);
					modchartTweens["popupStart"] = FlxTween.tween(md, {pixel_health_direct: 1.0}, 1, {
						ease: FlxEase.quartInOut,
						startDelay: 1,
						onComplete: function(twn:FlxTween) {
							modchartTweens["popupEnd"] = FlxTween.tween(md, {pixel_health_direct: 0.0}, 1, {
								ease: FlxEase.expoIn,
								startDelay: 2.0,
								onComplete: function(twn:FlxTween) {
									popup.destroy();
									modchartTweens.remove("popupEnd");
								}
							});
							modchartTweens.remove("popupStart");
						}
					});
				}
			}

			// @CoolingTool: set default intro sounds
			var intros = songIntros.copy();
			for (i in 0...introNames.length) {
				var name = introNames[i];
				if (intros[i] == null)
					intros[i] = Paths.sound('intro$name$introSoundsSuffix');
			}

			if(startOnTime < 0) startOnTime = 0;

			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - noteKillOffset);
				return;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return;
			}
			startTimer = new FlxTimer().start(Conductor.normalizedCrochet / 1000, function(tmr:FlxTimer)
			{
				if (!inEditor) {
					if (swagCounter < (countdownLength - 1)) {
						var chars = [boyfriendMembers, dadMembers];
						for (members in chars) {
							for (char in members) {
								if (char.danceEveryNumBeats > 0 && tmr.loopsLeft % (Math.round(char.danceEveryNumBeats * (Conductor.timeSignature[1] / 4))) == 0 && !char.stunned && !char.singing() && !char.specialAnim)
								{
									char.dance(true);
								}
							}
						}
						for (bopper in boppers) {
							if (tmr.loopsLeft % (Math.round(bopper.danceEveryNumBeats * (Conductor.timeSignature[1] / 4))) == 0)
								bopper.dance(true);
						}
					}
				}

				if (countdownImages[swagCounter] != null) {
					// @CoolingTool: mod compatiblity (why do i care about this stuff)
					var tag = countdownTags[swagCounter];
					var countdown = new FarpSprite();
					if (tag != null) {
						if (Reflect.hasField(this, tag)) {
							Reflect.setField(this, tag, countdown);
						} else {
							modchartSprites.set(tag, countdown);
						}
					}

					// the actual countdown init
					if (countdown != null) {
						countdown.loadUISkin(countdownImages[swagCounter], 1, 5/6, UISkin);

						countdown.pixelPerfect();
						countdown.dissolveAlpha();

						if (!inEditor) countdown.cameras = [camHUD];
						countdown.scrollFactor.set();

						countdown.updateHitbox();
						countdown.screenCenter();
						countdown.wasAdded = true;
						insert(members.indexOf(notes), countdown);
						modchartTweens[tag] = FlxTween.tween(countdown, {alpha: 0}, Conductor.normalizedCrochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdown);
								if (modchartSprites.exists(tag))
									modchartSprites.remove(tag);
								modchartTweens.remove(tag);
								countdown.destroy();
							}
						});
					}
				}

				if (intros[swagCounter] != null)
					FlxG.sound.play(intros[swagCounter], 1, false, soundGroup);

				notes.forEachAlive(function(note:Note) {
					if(ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if(ClientPrefs.middleScroll && !note.mustPress) {
							note.alpha *= 0.35;
						}
					}
				});
				callOnScripts('onCountdownTick', [swagCounter]);

				swagCounter += 1;
			}, countdownLength);
		}
	}

	#if mobile
	function addMobileButtons() {
		buttonPAUSE = new Button(0, 564, 'PAUSE');
		buttonPAUSE.screenCenter(X);
		buttonPAUSE.x -= buttonPAUSE.width / 2;
		buttonPAUSE.cameras = [camButtons];
		grpButtons.add(buttonPAUSE);
		if (!ClientPrefs.noReset) {
			buttonRESET = new Button(buttonPAUSE.x + 136, buttonPAUSE.y, 'RESET');
			buttonRESET.screenCenter(X);
			buttonRESET.x += buttonRESET.width / 2;
			buttonRESET.cameras = [camButtons];
			grpButtons.add(buttonRESET);
		}
	}
	#end

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - noteKillOffset < time)
			{
				if (daNote.isOpponent) {
					camZooming = true;
					camBop = true;
				}
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - noteKillOffset < time)
			{
				if (daNote.isOpponent) {
					camZooming = true;
					camBop = true;
				}
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function updateScore(miss:Bool = false)
	{
		var formatedScore:String;
		switch (ClientPrefs.scoreSeperator) {
			case 'Comma':
				formatedScore = FlxStringUtil.formatMoney(songScore, false, true);
			case 'Period':
				formatedScore = FlxStringUtil.formatMoney(songScore, false, false);
			default:
				formatedScore = Std.string(songScore);
		}

		if (ClientPrefs.showRatings) {
			scoreTxt.text = 'Karma: ' + formatedScore + ' | Rating: ' + ratingName;
		} else {
			scoreTxt.text = 'Karma: ' + formatedScore + ' | Fails: ' + songMisses + ' | Rating: ' + ratingName;
		}
		if(ratingName != '?')
			scoreTxt.text += ' (' + Highscore.floorDecimal(ratingPercent * 100, 2) + '%)' + ' - ' + ratingFC;

		if (inEditor)
			scoreTxt.text = 'Hits: $songHits';

		if(ClientPrefs.scoreZoom && !miss && !cpuControlled)
		{
			if(scoreTxtTween != null) {
				scoreTxtTween.cancel();
			}
			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					scoreTxtTween = null;
				}
			});
		}
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		FlxG.sound.music.pause();
		vocals.pause();
		vocalsDad.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();

		if (time <= vocals.length)
		{
			vocals.time = time;
			vocals.play();
		}
		if (time <= vocalsDad.length)
		{
			vocalsDad.time = time;
			vocalsDad.play();
		}
		setSongPitch();
		Conductor.songPosition = time;

		updateCurStep();
		Conductor.getLastBPM(SONG, curStep);
	}

	function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		FlxG.sound.playMusic(Paths.inst(curSong, CoolUtil.getDifficultyFilePath()), 1, false);
		if (inEditor) FlxG.sound.music.time = startPos;
		if (playbackRate == 1) FlxG.sound.music.onComplete = onSongComplete;
		vocals.play();
		if (inEditor) vocals.time = startPos;
		vocalsDad.play();
		if (inEditor) vocalsDad.time = startPos;

		if(startOnTime > 0)
		{
			setSongTime(startOnTime - noteKillOffset);
		}
		startOnTime = 0;
		startOnTimeOffset = 500;

		setSongPitch();

		if (paused) {
			FlxG.sound.music.pause();
			vocals.pause();
			vocalsDad.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		if (!inEditor) {
			FlxTween.tween(timeBarBG, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
			if (showSongText) {
				FlxTween.tween(songTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut, onComplete: function(twn:FlxTween) {
					FlxTween.tween(songTxt, {alpha: 0}, 0.5, {ease: FlxEase.circOut, startDelay: 3});
					FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut, startDelay: 3});
				}});
			} else {
				if (songTxt != null) {
					songTxt.destroy();
					songTxt = null;
				}
				FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
			}
		
			#if DISCORD_ALLOWED
			// Updating Discord Rich Presence (with Time Left)
			DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter(), true, songLength / playbackRate);
			#end
		}
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart', []);
	}

	private var noteTypeMap:Map<String, Bool> = new Map();
	private var eventPushedMap:Map<String, Bool> = new Map();
	private function generateSong():Void
	{
		if (!inEditor) {
			songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

			switch(songSpeedType)
			{
				case "multiplicative":
					songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) / playbackRate;
				case "constant":
					songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
			}
		} else {
			songSpeed = SONG.speed;
		}
		songSpeed = CoolUtil.boundTo(songSpeed, 0.1, 10);
		
		Conductor.changeBPM(SONG.bpm);
		Conductor.changeSignature(SONG.timeSignature);

		if (SONG.needsVoices) {
			vocals = new FlxSound().loadEmbedded(Paths.voices(curSong, CoolUtil.getDifficultyFilePath()));

			vocalsDad = new FlxSound();
			var file = Paths.voicesDad(SONG.song, CoolUtil.getDifficultyFilePath());
			if (file != null) {
				foundDadVocals = true;
				vocalsDad.loadEmbedded(file);
			}
		} else {
			vocals = new FlxSound();
			vocalsDad = new FlxSound();
		}

		// @CoolingTool: set songs custom intro sounds located in assets/songs/{SONG}/intro{1,2,3}
		for (i in 0...introNames.length) {
			var name = introNames[i];
			if (Paths.fileExists('$curSong/intro$name.${Paths.SOUND_EXT}', MUSIC, false, 'songs')) {
				var file:Dynamic = Paths.intro(curSong, '$name');
				if (file != null)
					songIntros[i] = file;
			}
		}

		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(vocalsDad);
		FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.inst(curSong, CoolUtil.getDifficultyFilePath())));

		for (i in notes) {
			i.kill();
			notes.remove(i);
			i.destroy();
		}
		unspawnNotes = [];

		tendrils = new FlxTypedGroup<TendrilOverlay>();
		add(tendrils);
		hideInDemoMode.push(tendrils);
		
		if (Paths.fileExists('data/$curSong/events.json', TEXT)) {
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', curSong).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}

		var noteData:Array<SwagSection> = SONG.notes;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		var curStepCrochet = Conductor.stepCrochet;
		var curBPM = Conductor.bpm;
		var curDenominator = Conductor.timeSignature[1];
		#if MULTI_KEY_ALLOWED
		var curPlayerKeys = SONG.playerKeyAmount;
		var curOpponentKeys = SONG.opponentKeyAmount;
		#else
		var curPlayerKeys = 4;
		var curOpponentKeys = 4;
		#end
		for (section in noteData)
		{
			// TODO: fix issue with `curStepCrochet` being wrong when you change the stage of consume
			// (the issue is totally here im betting on it)
			if (section.changeBPM) {
				curBPM = section.bpm;
				curStepCrochet = (((60 / curBPM) * 4000) / curDenominator) / 4;
			}
			if (section.changeSignature) {
				curDenominator = section.timeSignature[1];
				curStepCrochet = (((60 / curBPM) * 4000) / curDenominator) / 4;
			}
			#if MULTI_KEY_ALLOWED
			if (section.changeKeys) {
				curOpponentKeys = section.opponentKeys;
				curPlayerKeys = section.playerKeys;
				if (!opponentStrumMap.exists(curOpponentKeys))
					generateStaticArrows(0, curOpponentKeys);
				if (!playerStrumMap.exists(curPlayerKeys))
					generateStaticArrows(1, curPlayerKeys);
			}
			#end
			var leftKeys = (section.mustHitSection ? curPlayerKeys : curOpponentKeys);
			var rightKeys = (!section.mustHitSection ? curPlayerKeys : curOpponentKeys);
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				if (inEditor && daStrumTime < startPos) continue;
				var daNoteData:Int = Std.int(songNotes[1] % leftKeys);
				if (songNotes[1] >= leftKeys) {
					daNoteData = Std.int((songNotes[1] - leftKeys) % rightKeys);
				}

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] >= leftKeys)
				{
					gottaHitNote = !gottaHitNote;
				}
				var isOpponent:Bool = !gottaHitNote;

				if (opponentChart) {
					gottaHitNote = !gottaHitNote;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[unspawnNotes.length - 1];
				else
					oldNote = null;

				var keys = curPlayerKeys;
				if (isOpponent) keys = curOpponentKeys;

				var modifier = SkinData.getSkinModifier(isOpponent);

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote, false, false, keys, curStepCrochet, modifier);
				swagNote.mustPress = gottaHitNote;
				swagNote.isOpponent = isOpponent;
				swagNote.opponentChart = opponentChart;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1] < rightKeys));
				swagNote.characters = songNotes[4];
				if (!Std.isOfType(songNotes[4], Array)) swagNote.characters = [0];
				swagNote.bpm = curBPM;
				swagNote.noteType = songNotes[3];
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				// @CoolingTool: create tendril overlay stuff
				if (swagNote.noteType == "Void Tendril") {
					var tendril = new TendrilOverlay(swagNote, curStepCrochet * 4, ClientPrefs.downScroll);
					unspawnTendrils.push(tendril);
				}

				var susLength:Float = swagNote.sustainLength / curStepCrochet;
				var floorSus:Int = Math.floor(susLength);
				if (floorSus > 0) {
					for (susNote in 0...floorSus + 1)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];
						var ogStrum = daStrumTime + (curStepCrochet * susNote);

						var sustainNote:Note = new Note(ogStrum + (curStepCrochet / 2 / songSpeed), daNoteData, oldNote, true, false, keys, curStepCrochet, modifier);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.isOpponent = isOpponent;
						sustainNote.opponentChart = opponentChart;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.characters = songNotes[4];
						if (!Std.isOfType(songNotes[4], Array)) sustainNote.characters = [0];
						sustainNote.bpm = curBPM;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);

						if (!sustainNote.isOpponent)
						{
							sustainNote.x += FlxG.width / 2; // general offset
						}
					}
				}

				if (!swagNote.isOpponent)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}

				if (!noteTypeMap.exists(swagNote.noteType)) {
					noteTypeMap.set(swagNote.noteType, true);
				}
			}
			daBeats += 1;
		}
		for (event in SONG.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}

		unspawnNotes.sort(sortByShit);

		// @Square789: Place GC disabler notes
		if (ClientPrefs.controlGC && #if cpp true #else false #end) {
			final GC_CONTROL_SAFEZONE = 420.0; // I am so funny
			var gci = 0;
			var gcj = 0;
			var gcControlEvents:Array<EventNote> = [];
			var exhausted = false;
			// back and forth between disabler and enabler notes until song is over
			while (!exhausted) {
				// Find where to place disabler note (Just before next note that needs to be played)
				while (true) {
					if (unspawnNotes[gci].mustPress) {
						var disableTime = unspawnNotes[gci].strumTime - GC_CONTROL_SAFEZONE;
						gcControlEvents.push({strumTime: disableTime, event: "_F4RPEXPERIMENTAL_GC_CONTROL", value1: "0", value2: ""});
						break;
					}
					gci += 1;
					if (gci > unspawnNotes.length) {
						exhausted = true;
						break;
					}
				}

				// Find where to place enabler note
				while (!exhausted) {
					gcj = -1;
					var x = gci + 1;
					while (x < unspawnNotes.length) {
						if (unspawnNotes[x].mustPress) {
							gcj = x;
							break;
						}
						x += 1;
					}
					if (gcj == -1) {
						exhausted = true;
					}
					var gcsearch_disablets = gcj == -1 ? 99999999.9 : unspawnNotes[gcj].strumTime - GC_CONTROL_SAFEZONE;
					var gcsearch_enablets = unspawnNotes[gci].strumTime + GC_CONTROL_SAFEZONE;

					gci = gcj;
					if (exhausted || gcsearch_enablets < gcsearch_disablets) {
						gcControlEvents.push({strumTime: gcsearch_enablets, event: "_F4RPEXPERIMENTAL_GC_CONTROL", value1: "1", value2: ""});
						break;
					}
				}
			}
			for (e in gcControlEvents) {
				eventNotes.push(e);
				eventPushed(e);
			}
		}

		eventNotes.sort(sortByTime);
		// @CoolingTool: More tendril stuff scattered all across playstate
		unspawnTendrils.sort(sortByBlahBlah);

		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:EventNote) {
		switch(event.event) {
			case 'Change Character':
				var charData:Array<String> = event.value1.split(',');
				var charType:Int = 0;
				var index = 0;
				switch(charData[0].toLowerCase()) {
					case 'gf' | 'girlfriend' | '2':
						charType = 2;
					case 'dad' | 'opponent' | '1':
						charType = 1;
				}
				if (charData[1] != null) index = Std.parseInt(charData[1]);

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType, index);

			case 'Dadbattle Spotlight':
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;

				dadbattleSmokes = new FlxSpriteGroup();
				dadbattleSmokes.alpha = 0.7;
				dadbattleSmokes.blend = ADD;
				dadbattleSmokes.visible = false;
				add(dadbattleLight);
				add(dadbattleSmokes);

				var offsetX = 200;
				var smoke:BGSprite = new BGSprite('smoke', -1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(15, 22);
				smoke.active = true;
				dadbattleSmokes.add(smoke);
				var smoke:BGSprite = new BGSprite('smoke', 1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(-15, -22);
				smoke.active = true;
				smoke.flipX = true;
				dadbattleSmokes.add(smoke);

			case 'Philly Glow':
				if (curStage == 'philly' && ClientPrefs.gameQuality != 'Crappy') {
					blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					blammedLightsBlack.visible = false;
					insert(members.indexOf(phillyStreet), blammedLightsBlack);

					phillyWindowEvent = new BGSprite('philly/window', phillyWindow.x, phillyWindow.y, 0.3, 0.3);
					phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
					phillyWindowEvent.updateHitbox();
					phillyWindowEvent.visible = false;
					insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

					phillyGlowGradient = new PhillyGlow.PhillyGlowGradient(-400, 225); //This shit was refusing to properly load FlxGradient so fuck it
					phillyGlowGradient.visible = false;
					insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);
					if(!ClientPrefs.flashing) phillyGlowGradient.intendedAlpha = 0.7;

					precacheList.set('philly/particle', 'image'); //precache particle image
					phillyGlowParticles = new FlxTypedGroup<PhillyGlow.PhillyGlowParticle>();
					phillyGlowParticles.visible = false;
					insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
				}
		}

		if (!eventPushedMap.exists(event.event)) {
			eventPushedMap.set(event.event, true);
		}

		callOnScripts('eventPushed', [event.event, event.strumTime, event.value1, event.value2]);
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Dynamic = callOnScripts('eventEarlyTrigger', [event.event]);
		if (returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	// @CoolingTool: tendril overlay sort (trying to follow the naming scheme from above lol)
	function sortByBlahBlah(Obj1:TendrilOverlay, Obj2:TendrilOverlay):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.noteTracker.strumTime, Obj2.noteTracker.strumTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int, keys:Int = 4):Void
	{
		var strumGroup = new FlxTypedGroup<StrumNote>();

		var delay = Conductor.normalizedCrochet / (250 * keys);

		for (i in 0...keys)
		{
			var targetAlpha:Float = 1;
			if ((player < 1 && ClientPrefs.middleScroll && !opponentChart) || (player > 0 && ClientPrefs.middleScroll && opponentChart)) {
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote((ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X) - betweenStrumOffset, strumLine.y, i, ClientPrefs.middleScroll && opponentChart ? 1 - player : player, keys, SkinData.getSkinModifier(player < 1));
			babyArrow.y += (160/2 * Note.DEFAULT_NOTE_SIZE) - (babyArrow.height / 2);
			babyArrow.downScroll = ClientPrefs.downScroll;
			if (!isStoryMode && !inEditor && !skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, delay, {ease: FlxEase.circOut, startDelay: delay * (i + 1)});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				if (ClientPrefs.middleScroll && opponentChart)
				{
					babyArrow.x = STRUM_X_MIDDLESCROLL + 310;
					if (i >= Math.floor(keys / 2)) {
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
			}
			else
			{
				if (ClientPrefs.middleScroll && !opponentChart)
				{
					babyArrow.x += 310;
					if (i >= Math.floor(keys / 2)) {
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
			}

			strumGroup.add(babyArrow);
			babyArrow.postAddedToGroup();
		}

		if (player == 0) {
			opponentStrumMap.set(keys, strumGroup);
		} else {
			playerStrumMap.set(keys, strumGroup);
		}
	}

	var keybindTweenGroup:Map<FlxSprite, FlxTween> = new Map();
	function showKeybindReminders() {
		if (ClientPrefs.keybindReminders && !cpuControlled) {
			for (obj in keybindGroup) {
				obj.kill();
				keybindGroup.remove(obj);
				obj.destroy();
			}
			var strumGroup = opponentChart ? opponentStrums : playerStrums;
			for (i in 0...playerKeys) {
				var keybinds = keysArray[i];
				for (j in 0...keybinds.length) {
					var daStrum = strumGroup.members[i];
					var txt = new AttachedFlxText(daStrum.x, daStrum.y, daStrum.width, InputFormatter.getInputName(keybinds[j]), Std.int(72 * daStrum.noteSize));
					txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
					txt.borderSize = 1;
					txt.yAdd = daStrum.height + (72 * daStrum.noteSize * j);
					txt.copyAlpha = false;
					if (!inEditor) txt.cameras = [camHUD];
					keybindGroup.add(txt);
					txt.sprTracker = daStrum;

					var offset = Conductor.songPosition < 0 ? Conductor.normalizedCrochet * Conductor.timeSignature[0] * 0.001 : 0;
					keybindTweenGroup.set(txt, FlxTween.tween(txt, {alpha: 0}, 0.5, {startDelay: (offset + 3) * playbackRate, onComplete: function(twn) {
						keybindTweenGroup.remove(txt);
						txt.kill();
						keybindGroup.remove(txt);
						txt.destroy();
					}}));
				}
			}
		}
	}

	function resetUnderlay(underlay:FlxSprite, strums:FlxTypedGroup<StrumNote>) {
		if (ClientPrefs.underlayFull) {
			underlay.makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
			underlay.screenCenter();
		} else {
			var fullWidth = 0.0;
			for (i in 0...strums.members.length) {
				if (i == strums.members.length - 1) {
					fullWidth += strums.members[i].width;
				} else {
					fullWidth += strums.members[i].swagWidth;
					if (strums.members[i].snapToPixelGrid)
						fullWidth = Math.floor(fullWidth / strums.members[i].pixelSize) * strums.members[i].pixelSize;
				}
			}
			underlay.makeGraphic(Math.ceil(fullWidth), FlxG.height * 2, FlxColor.BLACK);
			underlay.x = strums.members[0].x;
			if (strums.members[0].snapToPixelGrid)
				underlay.x = Math.floor(underlay.x / strums.members[0].pixelSize) / strums.members[0].pixelSize;
		}
		underlay.visible = true;
	}

	function setKeysArray(keys:Int = 4) {
		keysArray = [];
		for (i in 0...keys) {
			keysArray.push(ClientPrefs.copyNonNoneKeys('note${keys}_$i'));
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			FlxG.timeScale = 1;
			
			#if mobile
			for (i in grpNoteButtons) {
				i.visible = false;
			}
			for (i in grpButtons) {
				i.visible = false;
			}
			#end

			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				vocalsDad.pause();
			}
			soundGroup.pause();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (endingTimer != null && !endingTimer.finished)
				endingTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;
			if (cameraTwn != null)
				cameraTwn.active = false;
			if (zoomTwn != null)
				zoomTwn.active = false;

			for (txt in keybindGroup) {
				keybindTweenGroup.get(txt).active = false;
			}

			var chars = [boyfriendMembers, gfMembers, dadMembers];
			for (i in 0...chars.length) {
				for (char in chars[i]) {
					if (char.colorTween != null) {
						char.colorTween.active = false;
					}
				}
			}

			for (tween in modchartTweens) {
				tween.active = false;
			}
			for (timer in modchartTimers) {
				timer.active = false;
			}
			changeGarbageCollectorState(true);
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			FlxG.timeScale = playbackRate;

			#if mobile
			for (i in grpNoteButtons) {
				i.visible = true;
			}
			for (i in grpButtons) {
				i.visible = true;
			}
			#end

			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}
			soundGroup.resume();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (endingTimer != null && !endingTimer.finished)
				endingTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;
			if (cameraTwn != null)
				cameraTwn.active = true;
			if (zoomTwn != null)
				zoomTwn.active = true;

			for (txt in keybindGroup) {
				keybindTweenGroup.get(txt).active = true;
			}

			var chars = [boyfriendMembers, gfMembers, dadMembers];
			for (i in 0...chars.length) {
				for (char in chars[i]) {
					if (char.colorTween != null) {
						char.colorTween.active = true;
					}
				}
			}

			changeGarbageCollectorState(gcControlLastGameplayState);

			for (tween in modchartTweens) {
				tween.active = true;
			}
			for (timer in modchartTimers) {
				timer.active = true;
			}
			paused = false;
			persistentUpdate = true;
			callOnScripts('onResume', []);

			#if DISCORD_ALLOWED
			if (startTimer != null && startTimer.finished)
			{
				DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter(), true, (songLength - Conductor.songPosition) / playbackRate - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter());
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		if (!isDead && !paused)
		{
			if (FlxG.sound.music != null && !startingSong && !endingSong)
			{
				resyncVocals();
			}
			#if DISCORD_ALLOWED
			if (!inEditor) {
				if (Conductor.songPosition > 0.0)
				{
					DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter(), true, (songLength - Conductor.songPosition) / playbackRate - ClientPrefs.noteOffset);
				}
				else
				{
					DiscordClient.changePresence(detailsText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter());
				}
			}
			#end
		}

		super.onFocus();
	}
	
	override public function onFocusLost():Void
	{
		if (ClientPrefs.focusLostPause && !isDead && !paused && !inEditor && startedCountdown && canPause) {
			openPauseMenu(false);
			FlxG.sound.music.pause();
			vocals.pause();
			vocalsDad.pause();
		}

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if (FlxG.sound.music == null || vocals == null || startingSong || endingSong || endingTimer != null) return;

		if (playbackRate < 1) FlxG.sound.music.pause();
		vocals.pause();
		vocalsDad.pause();

		if (playbackRate >= 1) {
			FlxG.sound.music.play();
			Conductor.songPosition = FlxG.sound.music.time;
		} else {
			FlxG.sound.music.time = Conductor.songPosition;
			FlxG.sound.music.play();
		}
		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			vocals.play();
		}
		if (Conductor.songPosition <= vocalsDad.length)
		{
			vocalsDad.time = Conductor.songPosition;
			vocalsDad.play();
		}

		setSongPitch();
	}

	function setSongPitch() {
		#if cpp
		if (playbackRate != 1 && !startingSong && !endingSong && !transitioning) {
			@:privateAccess
			{
				var audio = [FlxG.sound.music, vocals, vocalsDad];
				for (sound in modchartSounds) {
					audio.push(sound);
				}
				for (i in audio) {
					if (i != null && i.playing && i._channel != null && i._channel.__source != null && i._channel.__source.__backend != null && i._channel.__source.__backend.handle != null) {
						AL.sourcef(i._channel.__source.__backend.handle, AL.PITCH, playbackRate);
					}
				}
			}
		}
		#end
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var limoSpeed:Float = 0;
	var skipCutsceneHold:Float = 0;

	override public function update(elapsed:Float)
	{
		callOnScripts('onUpdate', [elapsed]);

		FlxG.camera.zoom = currentCamZoom + bopCamZoom;

		if (!inEditor) {
			if (FlxG.sound.music != null && FlxG.sound.music.playing) {
				setSongPitch();
			}

			if (playbackRate != 1 && generatedMusic && startedCountdown && !endingSong && !transitioning && FlxG.sound.music != null && FlxG.sound.music.length - Conductor.songPosition <= 20)
			{
				Conductor.songPosition = FlxG.sound.music.length;
				onSongComplete();
			}

			if (FlxG.keys.justPressed.NINE)
			{
				iconP1.swapOldIcon();
			}

			if (ClientPrefs.gameQuality == 'Normal') {
				switch (curStage) {
					// High Quality stage effects here, i guess
					case "bubbo":
						bubboDrugs.update(elapsed);
						bubboDrugs.hue += elapsed * .01;
				}
			}
			if (ClientPrefs.gameQuality != 'Crappy') {
				switch (curStage) {
					// Other stage effects here, i guess
				}
			}

			/*if (!inCutscene) {
				var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed, 0, 1);
				camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			}*/
		} else {
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				vocalsDad.pause();
				LoadingState.loadAndSwitchState(new editors.ChartingState());
			}
		}

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if (!inEditor && startedCountdown && generatedMusic && SONG.notes[curSection] != null && !endingSong && !isCameraOnForcedPos)
		{
			moveCameraSection();
		}

		if (!inEditor) {
			if (botplayTxt.visible) {
				botplaySine += 180 * elapsed;
				botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
			}

			if ((controls.PAUSE #if mobile || (buttonPAUSE != null && buttonPAUSE.justPressed) #end) && startedCountdown && canPause)
			{
				var ret:Dynamic = callOnScripts('onPause', [], false);
				if (ret != FunkinLua.Function_Stop) {
					openPauseMenu();
				}
			}
		}

		// @Square789: shader experiments
		for (shader in pixelErasureShaders) {
			shader.update(elapsed);
		}

		// Twitch chatbox mashing spewer control
		var prevRecentMissesLength:Int = recentMisses.length;
		recentMisses = recentMisses.map((v) -> v - elapsed).filter((v) -> v >= 0.0);
		if (recentMisses.length != prevRecentMissesLength) {
			var forgottenMisses = prevRecentMissesLength - recentMisses.length;
			for (chatbox in twitchChatboxes) {
				chatbox.changeSpewerChance("mashing", -50 * forgottenMisses);
			}
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene) {
			AchievementManager.advanceAchievement("reddit_mod", 1);
			#if CHART_EDITOR_ALLOWED
			var ret:Dynamic = callOnScripts('onOpenChartEditor', [], false);
			if (ret != FunkinLua.Function_Stop) {
				openChartEditor();
			}
			#end
		}

		#if desktop
		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			var ret:Dynamic = callOnScripts('onOpenCharacterEditor', [], false);
			if (ret != FunkinLua.Function_Stop) {
				FlxG.timeScale = 1;
				persistentUpdate = false;
				paused = true;
				cancelMusicFadeTween();
				SONG = originalSong;
				MusicBeatState.switchState(new CharacterEditorState(dad.curCharacter));
			}
		}
		#end

		// @CoolingTool: Just makes sense y'know
		if (practiceMode && health < minHealth)
			setHealth(minHealth);

		// @ThaumcraftMC: Changed the 2 with the nex max health variable.
		if (health > maxHealth)
			setHealth(maxHealth);

		if (!inEditor) {
			for (icon in healthIconsP1) {
				icon.lerp(elapsed);
			}
			for (icon in healthIconsP2) {
				icon.lerp(elapsed);
			}

			var iconP1Offset:Int = 26;
			var iconP2Offset:Int = 24;
			var division:Float = 1 / healthBar.numDivisions;

			if (ClientPrefs.smoothHealth) {
				shownHealth = FlxMath.lerp(shownHealth, health, CoolUtil.boundTo(.7 * (elapsed*60), 0, 1));
				// @CoolingTool: snap to the end of health bar
				if((health == maxHealth) && (maxHealth - shownHealth < division)) {
					shownHealth = maxHealth;
				}
			} else {
				shownHealth = health;
			}

			final HISS = 2;
			var iconHeightVariance = 60;
			var iconDiagLineLength = 16;
			// @Square789: Arrange icons behind each other in stacks of two. Last icon is the first one because draw order.
			// Yeah code is very dogshit i know
			// If anyone ever touches this, make some functions out of it
			var xBase = opponentChart ?
				healthBar.x + (healthBar.width * (Std.int(FlxMath.remapToRange(healthBar.value, healthBar.min, healthBar.max, 0, healthBar.numDivisions)) * division)):
				healthBar.x + (healthBar.width * (Std.int(FlxMath.remapToRange(healthBar.value, healthBar.min, healthBar.max, healthBar.numDivisions, 0)) * division));
			var incompleteStackSize = healthIconsP1.members.length % HISS;
			for (i => icon in healthIconsP1.members) {
				var _inIncompleteStack = i < incompleteStackSize;
				var stackSize = _inIncompleteStack ? incompleteStackSize : HISS;
				var stackLocalI = _inIncompleteStack ? i : ((i - incompleteStackSize) % HISS);
				var height:Float = stackSize == 1 ? 0.5 : ((1.0/(stackSize - 1)) * stackLocalI);
				var addXOffset = (height - 0.5) * iconDiagLineLength;
				var stackI = Math.floor((i + (HISS - incompleteStackSize)) / HISS);
				var stackNum = Math.floor(healthIconsP1.members.length / HISS) - stackI;

				// I'm not gonna bother clustering icons with respect to their scale and instead hardcode stack distance
				icon.x = xBase + (150 * iconP1.scale.x - 150) / 2 - addXOffset + ((150 - iconP1Offset) * stackNum) - (iconP1Offset * (stackNum + 1));
				icon.y = healthBar.y - 75 + (height - 0.5) * iconHeightVariance;
			}
			incompleteStackSize = healthIconsP2.members.length % HISS;
			for (i => icon in healthIconsP2.members) {
				var _inIncompleteStack = i < incompleteStackSize;
				var stackSize = _inIncompleteStack ? incompleteStackSize : HISS;
				var stackLocalI = _inIncompleteStack ? i : ((i - incompleteStackSize) % HISS);
				var height:Float = stackSize == 1 ? 0.5 : ((1.0/(stackSize - 1)) * stackLocalI);
				var addXOffset = (height - 0.5) * iconDiagLineLength;
				var stackI = Math.floor((i + (HISS - incompleteStackSize)) / HISS);
				var stackNum = Math.floor(healthIconsP2.members.length / HISS) - stackI;

				// Yes, using the p1 offset here is intentional. No, i don't want to think about it anymore.
				icon.x = xBase - (150 * iconP1.scale.x) / 2 + addXOffset - ((150 - (iconP1Offset * 2)) * stackNum) - (iconP2Offset * (2));
				icon.y = healthBar.y - 75 + (height - 0.5) * iconHeightVariance;
			}
			// The mess above should resolve to the below for health icon groups of length 1, which is the original code:
			// iconP1.x = xBase + (150 * iconP1.scale.x - 150) / 2 - iconP1Offset;
			// iconP2.x = xBase - (150 * iconP2.scale.x) / 2 - iconP2Offset * 2;

			// @CoolingTool: Visualize max health
			if(maxHealth != 2) {
				var size:Float = healthBar.width * (Math.ceil(FlxMath.remapToRange(maxHealth, 2, 0, 0, healthBar.numDivisions)) * division) - maxhealthBarBG.xAdd;
				maxhealthBarBG.visible = true;
				maxhealthBarBG.scale.set(size, 1);
				maxhealthBarBG.updateHitbox();
				if (opponentChart)
					maxhealthBarBG.offset.x = -healthBarBG.width - maxhealthBarBG.offset.x;
			} else {
				maxhealthBarBG.visible = false;
			}

			// @CoolingTool: Visualize min health
			if(minHealth != 0) {
				var size:Float = healthBar.width * (Math.ceil(FlxMath.remapToRange(minHealth, 0, 2, 0, healthBar.numDivisions)) * division);
				minhealthBarBG.visible = true;
				minhealthBarFG.visible = true;
				minhealthBarBG.scale.set(size - minhealthBarBG.xAdd, 1);
				minhealthBarFG.scale.set(size, 1);
				minhealthBarBG.updateHitbox();
				minhealthBarFG.updateHitbox();
				if (!opponentChart)
					minhealthBarBG.offset.x = -healthBarBG.width - minhealthBarBG.offset.x;
					minhealthBarFG.offset.x = -healthBar.width - minhealthBarFG.offset.x;
			} else {
				minhealthBarBG.visible = false;
				minhealthBarFG.visible = false;
			}

			// @Square789: tesla and einstein posing with comically big heads and lightning.jpeg
			var _anims = ['losing', 'normal', 'winning'];
			var hbmul = (healthBar.percent < 20 ? -1 : (healthBar.percent > 80 ? 1 : 0));
			for (i in healthIconsP1.members) {
				i.animation.play(_anims[1 + ((opponentChart ? -1 : 1) * hbmul)]);
			}
			for (i in healthIconsP2.members) {
				i.animation.play(_anims[1 + ((opponentChart ? 1 : -1) * hbmul)]);
			}
		}

		if (startingSong)
		{
			if (!inEditor) {
				if (startedCountdown)
				{
					Conductor.songPosition += FlxG.elapsed * 1000;
					if (Conductor.songPosition >= 0) {
						startSong();
					}
				}
			} else {
				timerToStart -= elapsed * 1000;
				Conductor.songPosition = startPos - timerToStart;
				if(timerToStart < 0) {
					startSong();
				}
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused && !inEditor)
			{
				if (updateTime) {
					var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
					if(curTime < 0) curTime = 0;
					songPercent = (curTime / songLength);

					var songCalc:Float = (songLength - curTime) / playbackRate;
					if(ClientPrefs.timeBarType == 'Time Elapsed') songCalc = curTime / playbackRate;

					var secondsTotal:Int = Math.floor(songCalc / 1000);
					if (secondsTotal < 0) secondsTotal = 0;
					var minutesTotal:Int = Math.floor(secondsTotal / 60);
					var hoursTotal:Int = Math.floor(minutesTotal / 60);

					if (ClientPrefs.timeBarType != 'Song Name')
						timeTxt.text = (
							Std.string(hoursTotal).lpad("0", 2) + ":" +
							Std.string(minutesTotal % 60).lpad("0", 2) + ":" +
							Std.string(secondsTotal % 60).lpad("0", 2)
						);
				}
			}
		}

		if (!inEditor) {
			if (camZooming)
			{
				bopCamZoom = FlxMath.lerp(0, bopCamZoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
				camHUD.zoom = FlxMath.lerp(defaultCamHudZoom, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
			}

			FlxG.watch.addQuick("secShit", curSection);
			FlxG.watch.addQuick("beatShit", curBeat);
			FlxG.watch.addQuick("stepShit", curStep);

			// RESET = Quick Game Over Screen
			if (!ClientPrefs.noReset && (controls.RESET #if mobile || (buttonRESET != null && buttonRESET.justPressed) #end) && canReset && !inCutscene && startedCountdown && !endingSong)
			{
				setHealth(0);
				trace("RESET = True");
			}
			doDeathCheck();
		}

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;
			if(!inEditor) time /= camHUD.zoom;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;
				callOnScripts('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.characters]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		// @CoolingTool: spawn the unspawned tendril overlays
		if (unspawnTendrils[0] != null)
		{
			while (unspawnTendrils.length > 0 && unspawnTendrils[0].noteTracker.strumTime - Conductor.songPosition < (unspawnTendrils[0].enterDuration + unspawnTendrils[0].crochet * unspawnTendrils[0].totalBeeps))
			{
				var note:Note = unspawnTendrils[0].noteTracker;

				var strum:StrumNote = playerStrums.members[note.noteData];
				if (note.isOpponent) strum = opponentStrums.members[note.noteData];

				var dunceTendril:TendrilOverlay = unspawnTendrils[0];

				dunceTendril.strumTracker = strum;
				dunceTendril.activated = true;

				tendrils.insert(0, dunceTendril);

				var index:Int = unspawnTendrils.indexOf(dunceTendril);
				unspawnTendrils.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene) {
				if (!cpuControlled) {
					keyShit();
				}

				if (!inEditor) {
					for (char in playerMembers) {
						if (!FlxG.keys.anyPressed(char.keysPressed) && char.holdTimer > char.getSingDuration() && char.finished() && char.singing()) {
							char.dance(false, true);
						}
					}
				}
			}

			// array of beeps so multiple of the same beeps dont play at the same time
			var playingBeeps:Array<String> = [];

			tendrils.forEachAlive(function(daTendril:TendrilOverlay)
			{
				// @CoolingTool: play the funny tendril sound whatever it may be
				if (daTendril.playBeep != null) {
					if (!playingBeeps.contains(daTendril.playBeep)) {
						playingBeeps.push(daTendril.playBeep);
					}
					daTendril.playBeep = null;
				}

				// @CoolingTool: kill tendril notes that are not activated (probably means they finished)
				if (daTendril.activated == false) {
					daTendril.active = false;
					daTendril.visible = false;

					daTendril.kill();
					tendrils.remove(daTendril, true);
					daTendril.destroy();
				}
			});

			for (beepName in playingBeeps) {
				FlxG.sound.play(Paths.sound(beepName), ClientPrefs.tendrilVolume, false, soundGroup);
			}

			notes.forEachAlive(function(daNote:Note)
			{
				var strumGroup = daNote.isOpponent ? opponentStrums : playerStrums;

				if (daNote.keyAmount != strumGroup.members.length) {
					if (daNote.isOpponent) {
						strumGroup = opponentStrumMap.get(daNote.keyAmount);
					} else {
						strumGroup = playerStrumMap.get(daNote.keyAmount);
					}
				}

				if (strumGroup != null && strumGroup.members[daNote.noteData] != null) {
					var strumX:Float = strumGroup.members[daNote.noteData].x;
					var strumY:Float = strumGroup.members[daNote.noteData].y;
					var strumScreenY:Float = strumGroup.members[daNote.noteData].getScreenPosition().y;
					var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
					var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
					var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
					var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;
					var strumWidth:Float = strumGroup.members[daNote.noteData].width;
					var strumHeight:Float = strumGroup.members[daNote.noteData].height;
					var strumFrameHeight:Int = strumGroup.members[daNote.noteData].frameHeight;
					var strumScale:FlxPoint = strumGroup.members[daNote.noteData].scale;
					var strumSkin:SkinFileData = strumGroup.members[daNote.noteData].skinFile;
					var noteSpeed = songSpeed * daNote.multSpeed;

					if (daNote.centerX && !daNote.isSustainNote) strumX += (strumWidth - daNote.width) / 2;

					strumX += daNote.offsetX;
					strumY += daNote.offsetY;
					strumAngle += daNote.offsetAngle;
					strumAlpha *= daNote.multAlpha;
					if (daNote.tooLate) strumAlpha * 0.3;

					if (strumScroll) //Downscroll
					{
						daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * noteSpeed);
					}
					else //Upscroll
					{
						daNote.distance = (-0.45 * (Conductor.songPosition - daNote.strumTime) * noteSpeed);
					}

					var angleDir = strumDirection * Math.PI / 180;
					if (daNote.copyAngle)
						daNote.angle = strumDirection - 90 + strumAngle;

					if (daNote.copyAlpha)
						daNote.alpha = strumAlpha;

					if (daNote.copyScale) {
						daNote.scale.x = strumGroup.members[daNote.noteData].scale.x;
						if (!daNote.isSustainNote) {
							daNote.scale.y = strumGroup.members[daNote.noteData].scale.y;
						}
					}

					if (daNote.copyX)
						daNote.x = strumX + Math.cos(angleDir) * daNote.distance;

					if (daNote.copyY) {
						daNote.y = strumY + Math.sin(angleDir) * daNote.distance;

						if (daNote.isSustainNote && !strumScroll && daNote.skinFile.folder.endsWith('place')) {
							// most brain dead fix for place sustains being very slightly shown above notes
							daNote.y += daNote.pixelNoteSize * 2;
						}

						if (daNote.isSustainNote && strumScroll) {
							if (daNote.animation.curAnim.name.endsWith('end')) {
								daNote.y += 10.5 * (daNote.stepCrochet * 4 / 400) * 1.5 * noteSpeed + (46 * (noteSpeed - 1));
								daNote.y -= 46 * (1 - (daNote.stepCrochet * 4 / 600)) * noteSpeed;
								if(daNote.skinFile.pixel) {
									daNote.y += 8 + (6 - daNote.originalHeightForCalcs) * daPixelZoom;
								} else {
									daNote.y -= 19;
								}
							}

							daNote.y += (strumHeight / 2) - (60.5 * (noteSpeed - 1));
							daNote.y += 27.5 * ((daNote.bpm / 100) - 1) * (noteSpeed - 1);
						}
					}

					if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
					{
						opponentNoteHit(daNote);
					}

					if (cpuControlled && daNote.mustPress && !daNote.ignoreNote && !daNote.hitCausesMiss) {
						if (daNote.isSustainNote) {
							if (daNote.canBeHit) {
								goodNoteHit(daNote);
							}
						} else if (daNote.strumTime <= Conductor.songPosition) {
							goodNoteHit(daNote);
						}
					}

					if (strumDirection == 90 && strumGroup.members[daNote.noteData].sustainReduce && daNote.isSustainNote && (daNote.mustPress || !daNote.ignoreNote) &&
						(!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
					{
						var center:Float;

						if (!strumSkin.pixel)
							center = strumScreenY + strumHeight / 2;
						else
							center = strumScreenY + (strumFrameHeight / 2) * strumScale.y;

						var noteScreenY = daNote.getScreenPosition().y;
						if (daNote.isTailNote || !daNote.skinFile.pixel) {
							if (strumScroll)
							{
								if (daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center)
								{
									var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
									swagRect.height = (center - noteScreenY) / daNote.scale.y;
									swagRect.y = daNote.frameHeight - swagRect.height;

									daNote.clipRect = swagRect;
								}
							}
							else
							{
								if (daNote.y + daNote.offset.y * daNote.scale.y <= center)
								{
									var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
									swagRect.y = (center - noteScreenY) / daNote.scale.y;
									swagRect.height -= swagRect.y;

									daNote.clipRect = swagRect;
								}
							}
						} else if (daNote.skinFile.pixel) {
							// @CoolingTool: found out that clipping rect applies directly to the frame
							// and that it doesnt support floats and just rounds the rect
							if (strumScroll) {
								if (daNote.y + (daNote.storedYscale * daNote.frameHeight) > center) {
									var scaleToSet = (center - daNote.y) / daNote.frameHeight;
									if (scaleToSet > 0) {
										daNote.scalePixelSustain(scaleToSet, 2);
										daNote.updateHitbox();
										daNote.offset.y -= center - (noteScreenY + daNote.height) - (daNote.pixelSize / 2);
									} else {
										daNote.visible = false;
									}
								}
							} else {
								if (daNote.y < center) {
									var scaleToSet = daNote.storedYscale - ((center - daNote.y) / daNote.frameHeight);
									if (scaleToSet > 0) {
										daNote.scalePixelSustain(scaleToSet);
										daNote.updateHitbox();
										daNote.offset.y -= center - noteScreenY - (daNote.pixelSize / 2);
									} else {
										daNote.visible = false;
									}
								}
							}
						}
					}

					// Kill extremely late notes and cause misses
					if (Conductor.songPosition > (noteKillOffset / noteSpeed) + daNote.strumTime)
					{
						if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
							noteMiss(daNote);
						}

						daNote.active = false;
						daNote.visible = false;

						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
					}
				}
			});
		}
		checkEventNote();

		for (i in 0...ratingTxtGroup.members.length) {
			var rating = ratingTxtGroup.members[i];
			if (i < ratingsData.length) {
				rating.text = '${ratingsData[i].displayName}: ${Reflect.field(this, ratingsData[i].counter)}';
			} else {
				rating.text = 'Fails: $songMisses';
			}
		}

		if (health < 0 && practiceMode) {
			setHealth(0);
		}

		if (inEditor) {
			scoreTxt.text = 'Hits: $songHits';
			sectionTxt.text = 'Section: $curSection';
			beatTxt.text = 'Beat: $curBeat';
			stepTxt.text = 'Step: $curStep';
		} else {
			if (practiceFailed) {
				practiceFailedSine += 180 * elapsed;
				practiceFailedTxt.alpha = 1 - Math.sin((Math.PI * practiceFailedSine) / 180);
			} else {
				practiceFailedTxt.alpha = 0;
			}
		}

		if (!ClientPrefs.underlayFull) {
			if (playerStrums.length > 0) {
				underlayPlayer.x = playerStrums.members[0].x;
			}
			if (opponentStrums.length > 0) {
				underlayOpponent.x = opponentStrums.members[0].x;
			}
		}
		
		#if debug
		if (!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE && !inEditor) {
				killNotes();
				if (FlxG.sound.music.onComplete != null) FlxG.sound.music.onComplete();
				else onSongComplete();
			}
			if (FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000 * playbackRate);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		if (!inEditor) {
			setOnScripts('cameraX', camFollowPos.x);
			setOnScripts('cameraY', camFollowPos.y);
			setOnScripts('botPlay', cpuControlled);
		}

		// @Square789: Garbage collection control
		#if cpp
		if (gcControlRequestedState == false && !gcControlCooldownActive) {
			gcControlTimeout -= 1;
			if (gcControlTimeout <= 0) {
				// trace('Garbage collector was down for too long, triggering cooldown phase.');
				gcControlTimeout = GC_CONTROL_TIMEOUT;
				cpp.vm.Gc.enable(true);
				gcControlCooldownTimeout = GC_CONTROL_COOLDOWN_TIMEOUT + 1;
				gcControlCooldownActive = true;
			}
		}
		if (gcControlCooldownActive) {
			gcControlCooldownTimeout -= 1;
			if (gcControlCooldownTimeout <= 0) {
				// trace('Garbage collector cooldown expired, switching to requested state: $gcControlRequestedState');
				gcControlCooldownTimeout = GC_CONTROL_COOLDOWN_TIMEOUT;
				gcControlCooldownActive = false;
				changeGarbageCollectorState(gcControlRequestedState);
			}
		}
		#end

		callOnScripts('onUpdatePost', [elapsed]);

		//doing this after every update cause scripts might force them to be visible
		if (demoMode) {
			for (i in hideInDemoMode) {
				i.visible = false;
			}
		}
	}

	public function changeGarbageCollectorState(state:Bool) {
		#if cpp
		if (!ClientPrefs.controlGC) {
			return;
		}

		gcControlRequestedState = state;
		if (gcControlRequestedState == true) {
			gcControlTimeout = GC_CONTROL_TIMEOUT;
		}
		if (!gcControlCooldownActive) {
			// trace('Garbage collector state set to $gcControlRequestedState.');
			cpp.vm.Gc.enable(gcControlRequestedState);
		} else {
			// trace('Garbage collector state set to $gcControlRequestedState; not honored due to active cooldown.');
		}
		#end
	}

	public function openPauseMenu(playSound:Bool = true) {
		persistentUpdate = false;
		paused = true;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			vocals.pause();
			vocalsDad.pause();
			@:privateAccess { //This is so hiding the debugger doesn't play the music again
				FlxG.sound.music._alreadyPaused = true;
				vocals._alreadyPaused = true;
				vocalsDad._alreadyPaused = true;
			}
		}
		openSubState(new PauseSubState(playSound));

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(detailsPausedText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter());
		#end
	}
	
	function openChartEditor()
	{
		#if CHART_EDITOR_ALLOWED
		FlxG.timeScale = 1;
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		SONG = originalSong;
		MusicBeatState.switchState(new ChartingState(false));
		chartingMode = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
		#end
	}

	public inline function get_voidedHealth():Float {
		return (minHealth + (2.0 - maxHealth));
	}

	// @Square789: setter/getter would be possible but uuhm uh uhh
	public function setHealth(newHealth:Float):Void {
		health = newHealth;

		var bfHealth = newHealth;
		if (opponentChart) bfHealth = 2.0 - bfHealth;

		var erosionZoneStart = songMisses > 0 ? 1.8 : 0.95;
		if (opponentChart) erosionZoneStart = camBop ? 1.8 : 0.95;

		// This should keep pixel health between 0.6 and 1 for values in almost
		// the entire lower half of the healthbar and clamp them to 1.0 otherwise
		// If the player missed once, the region where pixel erosion starts is larger.
		// Division by 2 is necessary since 2 is considered to be the max health;
		// it starts out at 1.
		final PIXEL_HEALTH_MIN = 0.6;
		var stretchedHealth = FlxMath.remapToRange(bfHealth, minHealth, maxHealth, 0.0, 2.0);
		// var pixelHealth = FlxMath.bound((((2.0 - (2.0 * PIXEL_HEALTH_MIN)) / erosionZoneStart) * stretchedHealth) * 0.5 + PIXEL_HEALTH_MIN);
		var pixelHealth = FlxMath.bound(
			stretchedHealth > erosionZoneStart ?
				1.0 :
				Math.sin((stretchedHealth*0.5*Math.PI)/erosionZoneStart) * (1.0 - PIXEL_HEALTH_MIN) + PIXEL_HEALTH_MIN,
			0.0,
			1.0
		);

		var moreVoid = (voidedHealth / 2.0);
		moreVoid = FlxEase.sineIn(FlxMath.bound(moreVoid, 0.0, 1.0));
		pixelHealth = FlxMath.bound(pixelHealth - moreVoid * 0.25, 0.0, 1.0);

		// REMINDER: The organic PES works in such a way that a high pixel health (>0.8) makes it extremely unlikely
		// for a pixel to be affected. 0.5 still causes at most 10% of pixels to be affected.
		// A very small pixel health (~0.02) highlights issues in the randomness, but works about okay.
		// For this reason, slap this vibe-based function on top
		// health  feels like      feels correct nec. exponent    nec. mul
		// 0.1         0.2             0.06        1.2              0.6
		// 0.125       0.5             ~0.07       1.2              0.56
		// 0.5          ??             0.125       3.0              0.25
		// 0.8:        0.999           0.5         ~3.2             0.625
		// 0.9:        1.0             0.6         ~4.5             0.6666
		// 0.999:      1.0             0.8         200.0            0.8008
		// vibes based table, below is something that works okay-ish
		// if (pixelHealth > 0.81) {
		// 	pixelHealth = 1.0;
		// } else {
		// 	pixelHealth -= 0.08;
		// 	pixelHealth *= (0.4 + pixelHealth * 0.6);
		// }
		pixelHealth *= (0.4 + pixelHealth * 0.6);
		if (pixelHealth > 0.9) {
			pixelHealth = 1.0;
		}

		// trace('stretchedHealth: $stretchedHealth, moreVoid: $moreVoid, pixelHealth: $pixelHealth');
		for (s in pixelErasureShaders) {
			s.pixel_health.value[0] = pixelHealth;
			// seems like `more_void` was a leftover unused thing but dont mind if i do
			s.more_void.value[0] = moreVoid;
		}

		if (twitchChatboxes.length > 0) {
			var normalizedHealth:Float = newHealth / 2.0;
			var isWinning:Bool = (normalizedHealth >= 0.5) != opponentChart; // Think of this as XOR
			var extremeness:Int = Std.int(FlxMath.bound(Math.abs(normalizedHealth - 0.5) * 2 * 2000, 0.0, 1400.0));
			for (chatbox in twitchChatboxes) {
				chatbox.setSpewerChance("player_winning", isWinning ? extremeness : 0);
				chatbox.setSpewerChance("player_losing",  isWinning ? 0 : extremeness);
			}
		}

	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(skipHealthCheck:Bool = false) {
		if (!cpuControlled && ((skipHealthCheck && instakillOnMiss) || health <= minHealth)) practiceFailed = true;
		else return false;
		if (!practiceMode && !isDead)
		{
			var ret:Dynamic = callOnScripts('onGameOver', [], false);
			if (ret != FunkinLua.Function_Stop) {
				for (i in playerMembers) {
					i.stunned = true;
				}
				deathCounter++;

				paused = true;

				vocals.stop();
				vocalsDad.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				for (tween in modchartTweens) {
					tween.active = true;
				}
				for (timer in modchartTimers) {
					timer.active = true;
				}
				SONG = originalSong;
				if (ClientPrefs.instantRestart || opponentChart) {
					var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
						-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
					blackShit.scrollFactor.set();
					add(blackShit);
					camHUD.visible = false;
					FlxG.sound.play(Paths.sound(GameOverSubState.deathSoundName));
					MusicBeatState.resetState();
				} else {
					openSubState(new GameOverSubState(boyfriend.getScreenPosition().x - boyfriend.positionArray[0], boyfriend.getScreenPosition().y - boyfriend.positionArray[1], FlxG.camera.zoom));
				}

				AchievementManager.notify(BLUE_BALLED);
				
				#if DISCORD_ALLOWED
				DiscordClient.changePresence(detailsGameOverText, '$curSongDisplayName ($storyDifficultyText)', iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function controlJustPressed(key:String) {
		return FlxG.keys.anyJustPressed(ClientPrefs.copyNonNoneKeys(key));
	}

	public function controlPressed(key:String) {
		return FlxG.keys.anyPressed(ClientPrefs.copyNonNoneKeys(key));
	}

	public function controlReleased(key:String) {
		return FlxG.keys.anyJustReleased(ClientPrefs.copyNonNoneKeys(key));
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		switch(eventName) {
			case 'Dadbattle Spotlight':
				if (inEditor) return;
				var val:Null<Int> = Std.parseInt(value1);
				if(val == null) val = 0;

				switch(Std.parseInt(value1))
				{
					case 1, 2, 3: //enable and target dad
						if(val == 1) //enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleSmokes.visible = true;
							targetCamZoom += 0.12;
							moveCameraTwn();
						}

						var who:Character = dad;
						if(val > 2) who = boyfriend;
						//2 only targets dad
						dadbattleLight.alpha = 0;
						new FlxTimer().start(0.12, function(tmr:FlxTimer) {
							dadbattleLight.alpha = 0.375;
						});
						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);

					default:
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						targetCamZoom -= 0.12;
						moveCameraTwn();
						FlxTween.tween(dadbattleSmokes, {alpha: 0}, 1, {onComplete: function(twn:FlxTween)
						{
							dadbattleSmokes.visible = false;
						}});
				}
			
			case 'Hey!':
				if (inEditor) return;
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if (Math.isNaN(time) || time <= 0) time = 0.6;

				if (value != 0) {
					for (dad in dadMembers) {
						if (dad.curCharacter.startsWith('gf') && dad.animOffsets.exists('cheer')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
							dad.playAnim('cheer', true);
							dad.specialAnim = true;
							dad.heyTimer = time;
						}
					}

					for (gf in gfMembers) {
						if (gf.animOffsets.exists('cheer')) {
							gf.playAnim('cheer', true);
							gf.specialAnim = true;
							gf.heyTimer = time;
						}
					}
				}
				if (value != 1) {
					for (boyfriend in boyfriendMembers) {
						if (boyfriend.animOffsets.exists('hey')) {
							boyfriend.playAnim('hey', true);
							boyfriend.specialAnim = true;
							boyfriend.heyTimer = time;
						}
					}
				}

			case 'Set GF Speed':
				if (inEditor) return;
				var value:Int = Std.parseInt(value1);
				if (Math.isNaN(value)) value = 1;
				if (value < 0) value = 0;
				for (gf in gfMembers) {
					gf.danceEveryNumBeats = value;
				}

			case 'Philly Glow':
				if (inEditor) return;
				if (curStage == 'philly' && ClientPrefs.gameQuality != 'Crappy') {
					var lightId:Int = Std.parseInt(value1);
					if (Math.isNaN(lightId)) lightId = 0;

					var doFlash:Void->Void = function() {
						var color:FlxColor = FlxColor.WHITE;
						if(!ClientPrefs.flashing) color.alphaFloat = 0.5;
	
						FlxG.camera.flash(color, 0.15, null, true);
					};

					var chars = [boyfriendMembers, gfMembers, dadMembers];
					switch(lightId)
					{
						case 0:
							if(phillyGlowGradient.visible)
							{
								doFlash();
								if(ClientPrefs.camZooms)
								{
									bopCamZoom += 0.5;
									camHUD.zoom += 0.1;
								}

								blammedLightsBlack.visible = false;
								phillyWindowEvent.visible = false;
								phillyGlowGradient.visible = false;
								phillyGlowParticles.visible = false;
								curLightEvent = -1;

								for (charGroup in chars) {
									for (who in charGroup) {
										who.color = FlxColor.WHITE;
									}
								}
								phillyStreet.color = FlxColor.WHITE;
							}

						case 1: //turn on
							curLightEvent = FlxG.random.int(0, phillyLightsColors.length-1, [curLightEvent]);
							var color:FlxColor = phillyLightsColors[curLightEvent];

							if(!phillyGlowGradient.visible)
							{
								doFlash();
								if(ClientPrefs.camZooms)
								{
									bopCamZoom += 0.5;
									camHUD.zoom += 0.1;
								}

								blammedLightsBlack.visible = true;
								blammedLightsBlack.alpha = 1;
								phillyWindowEvent.visible = true;
								phillyGlowGradient.visible = true;
								phillyGlowParticles.visible = true;
							}
							else if(ClientPrefs.flashing)
							{
								var colorButLower:FlxColor = color;
								colorButLower.alphaFloat = 0.25;
								FlxG.camera.flash(colorButLower, 0.5, null, true);
							}

							var charColor:FlxColor = color;
							if(!ClientPrefs.flashing) charColor.saturation *= 0.5;
							else charColor.saturation *= 0.75;

							for (charGroup in chars) {
								for (who in charGroup)
								{
									who.color = charColor;
								}
							}
							phillyGlowParticles.forEachAlive(function(particle:PhillyGlow.PhillyGlowParticle)
							{
								particle.color = color;
							});
							phillyGlowGradient.color = color;
							phillyWindowEvent.color = color;

							color.brightness *= 0.5;
							phillyStreet.color = color;
		
						case 2: // spawn particles
							if(ClientPrefs.gameQuality == 'Normal')
							{
								var particlesNum:Int = FlxG.random.int(8, 12);
								var width:Float = (2000 / particlesNum);
								var color:FlxColor = phillyLightsColors[curLightEvent];
								for (j in 0...3)
								{
									for (i in 0...particlesNum)
									{
										var particle:PhillyGlow.PhillyGlowParticle = new PhillyGlow.PhillyGlowParticle(-400 + width * i + FlxG.random.float(-width / 5, width / 5), phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40), color);
										phillyGlowParticles.add(particle);
									}
								}
							}
							phillyGlowGradient.bop();
					}
				}

			// case 'Kill Henchmen':

			case 'Add Camera Zoom':
				if (inEditor) return;
				if (ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if (Math.isNaN(camZoom)) camZoom = 0.015;
					if (Math.isNaN(hudZoom)) hudZoom = 0.03;

					bopCamZoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			//case 'Trigger BG Ghouls':

			case 'Play Animation':
				if (inEditor) return;
				var charMembers = dadMembers;
				var index = 0;
				var charData = value2.split(',');
				switch(charData[0].toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '1':
						charMembers = boyfriendMembers;
					case 'gf' | 'girlfriend' | '2':
						charMembers = gfMembers;
				}
				if (charData[1] != null) index = Std.parseInt(charData[1]);
				if (charMembers[index % charMembers.length] != null && charMembers[index % charMembers.length].animOffsets.exists(value1)) {
					charMembers[index % charMembers.length].playAnim(value1, true);
					charMembers[index % charMembers.length].specialAnim = true;
				}

			case 'Camera Follow Pos':
				if (inEditor) return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1)) val1 = 0;
				if (Math.isNaN(val2)) val2 = 0;

				isCameraOnForcedPos = false;
				if (!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
					camFollow.x = val1;
					camFollow.y = val2;
					isCameraOnForcedPos = true;
					curFollow = '';
					moveCameraTwn();
				}

			case 'Alt Idle Animation':
				if (inEditor) return;
				var charMembers = dadMembers;
				var index = 0;
				var charData = value1.split(',');
				switch(charData[0].toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '1':
						charMembers = boyfriendMembers;
					case 'gf' | 'girlfriend' | '2':
						charMembers = gfMembers;
				}
				if (charData[1] != null) index = Std.parseInt(charData[1]);
				if (charMembers[index % charMembers.length] != null) {
					charMembers[index % charMembers.length].idleSuffix = value2;
					charMembers[index % charMembers.length].recalculateDanceIdle();
				}

			case 'Screen Shake':
				if (inEditor) return;
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null) duration = Std.parseFloat(split[0].trim());
					if (split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration)) duration = 0;
					if (Math.isNaN(intensity)) intensity = 0;

					if (duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				if (inEditor) return;
				var charType:Int = 0;
				var index = 0;
				var charData = value1.split(',');
				switch(charData[0].toLowerCase().trim()) {
					case 'gf' | 'girlfriend' | '2':
						charType = 2;
					case 'dad' | 'opponent' | '1':
						charType = 1;
				}
				if (charData[1] != null) index = Std.parseInt(charData[1]);

				replaceCharacter(value2, charType, index);

			// case 'BG Freaks Expression':

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1)) val1 = 1;
				if (Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1 / playbackRate;
				newValue = CoolUtil.boundTo(newValue, 0.1, 10);

				if (val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Chatbox Control':
				do {
				var affectedBoxes = (value2 == "" ?
					twitchChatboxes :
					value2.split(",")
						.map(Std.parseInt)
						.filter((v) -> v != null && v < twitchChatboxes.length)
						.map((i) -> twitchChatboxes[i]));
				if (affectedBoxes.length == 0) {
					break;
				}

				if (value1.startsWith("!")) {
					switch (value1) {
					case "!STORE":
						twitchChatboxStateStorage = affectedBoxes[0].getSpewerChances();
					case "!RESTORE":
						if (twitchChatboxStateStorage == null) {
							FlxG.log.warn("No chatbox data stored, can not restore.");
							break;
						}
						for (b in affectedBoxes) {
							b.setSpewerChances(twitchChatboxStateStorage);
						}
					case "!CLEAR":
						var nuller = [for (n in TwitchChatbox.SPEWER_NAMES) n => 0];
						for (b in affectedBoxes) {
							b.setSpewerChances(nuller);
						}
					case _:
						FlxG.log.warn('Unknown chatbox control command \"$value1\"".');
					}
				} else {
					var spl = ~/[#:;>]/.split(value1);
					if (spl.length != 2) {
						FlxG.log.warn("Malformatted `spewerName:chance` combination.");
						break;
					}
					var spewer = spl[0].trim();
					var chance = Std.parseInt(spl[1].trim());
					if (chance == null) {
						FlxG.log.warn("Bad chance value for 'Chatbox Control' note.");
						break;
					}
					for (b in affectedBoxes) {
						b.setSpewerChance(spewer, chance);
					}
				}
				} while (false);

			case 'Modify Healthbar Icons':
				do {
				var _splitv2 = ~/,/g.split(value2);
				if (_splitv2.length <= 1) {
					FlxG.log.warn("Invalid value2. Must contain at least two elements.");
					break;
				}

				var healthIconGroup:FlxTypedGroup<HealthIcon>;
				switch (_splitv2[0]) {
				case '1':
					healthIconGroup = healthIconsP1;
				case '2':
					healthIconGroup = healthIconsP2;
				case _:
					FlxG.log.warn('Invalid health icon array ${_splitv2[0]}');
					break;
				}

				switch (value1) {
				case '!ADD':
					var insIdx = -1;
					if (_splitv2.length > 2) {
						if (Std.parseInt(_splitv2[2]) != null) {
							insIdx = Std.parseInt(_splitv2[2]);
						}
					}
					if (insIdx < 0) {
						insIdx = healthIconGroup.length;
					}
					var icn = new HealthIcon(_splitv2[1], _splitv2[0] == '1');
					healthIconGroup.insert(insIdx, icn);

				case '!REMOVE':
					for (healthIcon in healthIconGroup.members) {
						if (healthIcon.getCharacter() == _splitv2[1]) {
							healthIconGroup.remove(healthIcon, true).destroy();
							break;
						}
					}

				case '!REMOVEAT':
					var idx = Std.parseInt(_splitv2[1]);
					if (idx == null) {
						FlxG.log.warn('Bad value for !REMOVEAT.');
						break;
					}
					healthIconGroup.remove(healthIconGroup.members[idx], true).destroy();

				case _:
					FlxG.log.warn('Unknown chatbox control command \"$value1\"".');
				}
				setOnHscripts('iconP1', iconP1);
				setOnHscripts('iconP2', iconP2);
				} while (false);

			case 'Set Property':
				var killMe:Array<String> = value1.split('.');
				if(killMe.length > 1) {
					FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length-1], value2);
				} else {
					FunkinLua.setVarInArray(this, value1, value2);
				}

			case '_F4RPEXPERIMENTAL_GC_CONTROL':
				#if cpp
				if (ClientPrefs.controlGC) {
					if (value1 == "1") {
						changeGarbageCollectorState(true);
						gcControlLastGameplayState = true;
					} else if (value1 == "0") {
						changeGarbageCollectorState(false);
						gcControlLastGameplayState = false;
					}
				}
				#end
		}
		callOnScripts('onEvent', [eventName, value1, value2]);
	}

	var curFollow = '';
	function moveCameraSection():Void {
		if (SONG.notes[curSection] == null) return;

		if (gf != null && SONG.notes[curSection].gfSection)
		{
			if (curFollow == 'gf')
				return;
			curFollow = 'gf';

			if (girlfriendCameraFixed) {
				camFollow.x = girlfriendCameraOffset[0] + FlxG.camera.width / 2;
				camFollow.y = girlfriendCameraOffset[1] + FlxG.camera.height / 2;
			} else {
				camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
				if (gfGroupFile != null) {
					camFollow.x += gfGroupFile.camera_position[0] + girlfriendCameraOffset[0];
					camFollow.y += gfGroupFile.camera_position[1] + girlfriendCameraOffset[1];
				} else {
					camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
					camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
				}
			}
			moveCameraTwn();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		if (!SONG.notes[curSection].mustHitSection)
		{
			moveCamera(true);
			callOnScripts('onMoveCamera', ['dad']);
		}
		else
		{
			moveCamera(false);
			callOnScripts('onMoveCamera', ['boyfriend']);
		}
	}

	var zoomTwn:FlxTween;
	var cameraTwn:FlxTween;
	var cameraEase:EaseFunction = FlxEase.expoOut;
	public function cancelCameraTwn(?twn:FlxTween) {
		if (cameraTwn != null) {
			cameraTwn.cancel();
			cameraTwn.destroy();
			cameraTwn = null;
		}
		if (zoomTwn != null) {
			zoomTwn.cancel();
			zoomTwn.destroy();
			zoomTwn = null;
		}
	}
	public function moveCameraTwn() {
		cancelCameraTwn();
		// @CoolingTool: very stupid approximation of the duration
		var duration = (2.4 / cameraSpeed) / 0.775;
		cameraTwn = FlxTween.tween(camFollowPos, {x: camFollow.x, y: camFollow.y}, duration, {ease: cameraEase, onComplete: cancelCameraTwn});
		zoomTwn = FlxTween.tween(this, {currentCamZoom: targetCamZoom}, duration, {ease: cameraEase, onComplete: cancelCameraTwn});
	}

	public function moveCamera(isDad:Bool)
	{
		if (isDad)
		{
			if (curFollow == 'dad')
				return;
			curFollow = 'dad';

			if (opponentCameraFixed) {
				camFollow.x = opponentCameraOffset[0] + FlxG.camera.width / 2;
				camFollow.y = opponentCameraOffset[1] + FlxG.camera.height / 2;
			} else {
				camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);

				if (dadGroupFile != null) {
					camFollow.x += dadGroupFile.camera_position[0] + opponentCameraOffset[0];
					camFollow.y += dadGroupFile.camera_position[1] + opponentCameraOffset[1];
				} else {
					camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
					camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
				}
			}

			targetCamZoom = opponentCamZoom;
		}
		else
		{
			if (curFollow == 'boyfriend')
				return;
			curFollow = 'boyfriend';

			if (boyfriendCameraFixed) {
				camFollow.x = boyfriendCameraOffset[0] + FlxG.camera.width / 2;
				camFollow.y = boyfriendCameraOffset[1] + FlxG.camera.height / 2;
			} else {
				camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);

				if (bfGroupFile != null) {
					camFollow.x -= bfGroupFile.camera_position[0] - boyfriendCameraOffset[0];
					camFollow.y += bfGroupFile.camera_position[1] + boyfriendCameraOffset[1];
				} else {
					camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
					camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
				}
			}

			targetCamZoom = playerCamZoom;
		}
		moveCameraTwn();
	}

	public function setupPixelErasureShader(group:Int = 0, idx:Int = 0) {
		// @Square789: shader stuff
		var charList = switch (group) {
			case 0: boyfriendMembers;
			case 1: dadMembers;
			case 2: gfMembers;
			case _: null;
		}
		if (charList == null || idx >= charList.length || idx < 0) {
			FlxG.log.warn("Invalid target for pixel erasure shader!");
			return;
		}

		var char = charList[idx];

		var pes = new AnotherFuckingOrganicPixelErasureShader();
		pes.offset.value = [0.0, 0.0];
		pes.pixel_health.value[0] = 1.0;
		pes.more_void.value[0] = 0.0;
		pes.always_pixelate.value[0] = true;
		pes.pixel_dimensions.value = [1.0, 1.0];
		char.shader = pes;
		// This is great and couldn't go wrong. ever. possibly.
		// especially not if bf is swapped out or anything hahah noooo
		char.animation.callback = (_name, _fn, fi) -> {pes.uv_base.value = [char.frames.frames[fi].uv.x, char.frames.frames[fi].uv.y];};
		pixelErasureShaders.push(pes);
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		curFollow = '';
		cancelCameraTwn();
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	private function onSongComplete()
	{
		finishSong(false);
	}
	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		vocalsDad.volume = 0;
		vocalsDad.pause();
		if (ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		} else {
			endingTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				finishCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong():Void
	{
		if (inEditor) {
			LoadingState.loadAndSwitchState(new editors.ChartingState());
			return;
		}
		//Should kill you if you tried to cheat
		if (!startingSong) {
			notes.forEach(function(daNote:Note) {
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					setHealth(health - 0.05 * healthLoss);
				}
			});
			for (daNote in unspawnNotes) {
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					setHealth(health - 0.05 * healthLoss);
				}
			}

			if (doDeathCheck()) {
				return;
			}
		}
		
		timeTxt.text = "Place a tile";
		timeTxt.x = betweenStrum - timeTxt.width / 2;
		timeBarBG.xAdd = 0;
		timeIcon.visible = false;
		if (showSongText && songTxt != null) songTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		camBop = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		FlxG.timeScale = 1;

		if (!practiceMode && !cpuControlled) {
			lowestDifficultyThisStoryRun = FlxMath.minInt(lowestDifficultyThisStoryRun, PlayState.storyDifficulty);
			AchievementManager.notify(SONG_WON);
			if (isStoryMode && storyPlaylist.length == 1) {
				AchievementManager.notify(WEEK_WON);
			}
		}
		// Square produces "worst indentation ever". Asked to delete github account
		if (
			processAchievementsToShow(
				function() {
					if (endingSong && !inCutscene) {
						endSong();
					}
				}
			) != null
		) {
			return;
		}

		var ret:Dynamic = callOnScripts('onEndSong', [], false);
		if (ret != FunkinLua.Function_Stop && !transitioning) {
			#if CHART_EDITOR_ALLOWED
			if (chartingMode)
			{
				openChartEditor();
				return;
			}
			#end
			
			if (SONG.validScore)
			{
				#if HIGHSCORE_ALLOWED
				var percent:Float = ratingPercent;
				if (Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(curSong, songScore, storyDifficulty, percent);
				#end
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					WeekData.loadTheFirstEnabledMod();
					CoolUtil.playMenuMusic();
					#if cpp
					@:privateAccess
					AL.sourcef(FlxG.sound.music._channel.__source.__backend.handle, AL.PITCH, 1);
					#end

					cancelMusicFadeTween();
					if (FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}
					MusicBeatState.switchState(new MainMenuF4rpState(true));

					if (SONG.validScore) {
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					SONG = Song.loadFromJson(storyPlaylist[0] + difficulty, storyPlaylist[0]);
					FlxG.sound.music.stop();

					cancelMusicFadeTween();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				WeekData.loadTheFirstEnabledMod();
				cancelMusicFadeTween();
				if (FlxTransitionableState.skipNextTransIn) {
					CustomFadeTransition.nextCamera = null;
				}
				SONG = originalSong;
				MusicBeatState.switchState(new FreeplayPlaceState());
				CoolUtil.playMenuMusic();
				#if cpp
				@:privateAccess
				AL.sourcef(FlxG.sound.music._channel.__source.__backend.handle, AL.PITCH, 1);
				#end
				changedDifficulty = false;
			}
			transitioning = true;
		}
	}

	public function killNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		while(tendrils.length > 0) {
			var daTendril:TendrilOverlay = tendrils.members[0];
			daTendril.active = false;
			daTendril.visible = false;

			daTendril.kill();
			tendrils.remove(daTendril, true);
			daTendril.destroy();
		}
		unspawnNotes = [];
		unspawnTendrils = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;
		
		// this is rather silly innit
		//if (opponentChart) coolText.x = FlxG.width * 0.55;

		var rating:FarpSprite = new FarpSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = note.alwaysSick ? ratingsData[0] : Conductor.judgeNote(note, noteDiff);
		var ratingNum = ratingsData.indexOf(daRating);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.increase();
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashDisabled)
		{
			spawnNoteSplashOnNote(note);
		}

		#if BOTPLAY_HIDDEN
		var bot = false;
		#else
		var bot = cpuControlled;
		#end
		if (!daRating.causesMiss) {
			setHealth(health + note.hitHealth * healthGain);
			if (!practiceMode && !bot) {
				songScore += score;
				if(!note.ratingDisabled) {
					songHits++;
					totalPlayed++;
					recalculateRating();
					doRatingTween(ratingNum);
				}
			}
		} else {
			noteMissPress(note.noteData);
		}

		rating.loadUISkin(daRating.image, 0.7, 5/6);
		if (!inEditor) rating.cameras = [camHUD];
		rating.screenCenter();
		rating.pixelPerfect();
		rating.dissolveAlpha();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = !ClientPrefs.hideHud && showRating && !demoMode;
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		var comboSpr:FarpSprite = new FarpSprite().loadUISkin('combo', 0.7, 5/6);
		if (!inEditor) comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.pixelPerfect();
		comboSpr.dissolveAlpha();
		comboSpr.x = coolText.x + 80;
		comboSpr.y += 80;
		comboSpr.acceleration.y = FlxG.random.int(200, 300);
		comboSpr.velocity.y -= FlxG.random.int(140, 160);
		comboSpr.visible = !ClientPrefs.hideHud && !note.comboDisabled && !demoMode;
		comboSpr.x += ClientPrefs.comboOffset[0];
		comboSpr.y -= ClientPrefs.comboOffset[1];
		comboSpr.velocity.x += FlxG.random.int(1, 10);

		insert(members.indexOf(strumLineNotes), rating);

		// fixed width and height without actually stretching
		var prevScale = rating.scale.clone();
		rating.setGraphicSize(240, Std.int(rating.height));
		rating.updateHitbox();
		rating.scale.copyFrom(prevScale);

		var seperatedScore:Array<Int> = [];

		if (combo >= 1000) {
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		if (opponentChart) {
			rating.x = FlxG.width - (rating.x + rating.width);
			seperatedScore.reverse();
		}

		var daLoop:Int = 0;
		var xThing:Float = 0;
		if (showCombo)
		{
			insert(members.indexOf(strumLineNotes), comboSpr);
		}
		for (i in seperatedScore)
		{
			var numScore:FarpSprite = new FarpSprite().loadUISkin('num$i', 0.5, 5/6);
			if (!inEditor) numScore.cameras = [camHUD];
			numScore.pixelPerfect();
			numScore.screenCenter();
			numScore.dissolveAlpha();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			numScore.x += ClientPrefs.comboOffset[2];
			numScore.y -= ClientPrefs.comboOffset[3];

			if (opponentChart)
				numScore.x = FlxG.width - (numScore.x + numScore.width);

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !ClientPrefs.hideHud && !note.comboDisabled && !demoMode;

			if(showComboNum)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.normalizedCrochet * 0.002
			});

			daLoop++;
			if(numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;

		coolText.text = Std.string(seperatedScore);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.normalizedCrochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.normalizedCrochet * 0.002
		});
	}

	function doRatingTween(ind:Int = 0) {
		if (ClientPrefs.scoreZoom)
		{
			if (ratingTxtTweens[ind] != null) {
				ratingTxtTweens[ind].cancel();
			}
			ratingTxtGroup.members[ind].scale.x = 1.02;
			ratingTxtGroup.members[ind].scale.y = 1.02;
			ratingTxtTweens[ind] = FlxTween.tween(ratingTxtGroup.members[ind].scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					ratingTxtTweens[ind] = null;
				}
			});
		}
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		if (!cpuControlled && startedCountdown && !paused) {
			var eventKey:FlxKey = event.keyCode;
			var key:Int = getKeyFromEvent(eventKey);

			if (key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode #if mobile || true #end))
			{
				if ((inEditor || !playerMembers[0].stunned) && generatedMusic && !endingSong)
				{
					var lastTime:Float = Conductor.songPosition;
					//more accurate hit time for the ratings?
					Conductor.songPosition = FlxG.sound.music.time;

					var canMiss:Bool = !ClientPrefs.ghostTapping;

					// heavily based on my own code LOL if it aint broke dont fix it
					var pressNotes:Array<Note> = [];
					var notesStopped:Bool = false;

					var sortedNotesList:Array<Note> = [];
					notes.forEachAlive(function(daNote:Note)
					{
						if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote)
						{
							if (daNote.noteData == key)
							{
								sortedNotesList.push(daNote);
							}
							canMiss = true;
						}
					});
					sortedNotesList.sort(sortHitNotes);

					if (sortedNotesList.length > 0) {
						for (epicNote in sortedNotesList)
						{
							for (doubleNote in pressNotes) {
								if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
									doubleNote.kill();
									notes.remove(doubleNote, true);
									doubleNote.destroy();
								} else
									notesStopped = true;
							}
								
							// eee jack detection before was not super good
							if (!notesStopped) {
								goodNoteHit(epicNote, [eventKey]);
								pressNotes.push(epicNote);
							}

						}
					} else {
						callOnScripts('onGhostTap', [key]);
						if (canMiss) {
							noteMissPress(key, [eventKey]);
						}
						if (recentMisses.length < 40) {
							recentMisses.push(5.0);
							for (chatbox in twitchChatboxes) {
								chatbox.changeSpewerChance("mashing", 50);
							}
						}
					}

					// Register the keycode as pressed
					pressedKeysThisStoryRun[eventKey] = true;

					//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go buildingsback to the time it was before for not causing a note stutter)
					Conductor.songPosition = lastTime;
				}

				var spr:StrumNote = playerStrums.members[key];
				if (opponentChart) spr = opponentStrums.members[key];
				if (spr != null && spr.animation.curAnim != null && spr.animation.curAnim.name != 'confirm')
				{
					spr.playAnim('pressed');
					spr.resetAnim = 0;
				}
				callOnScripts('onKeyPress', [key]);
			}
		}
	}

	function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}
	
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		if (!cpuControlled && startedCountdown && !paused) {
			var eventKey:FlxKey = event.keyCode;
			var key:Int = getKeyFromEvent(eventKey);
			if (key > -1)
			{
				var spr:StrumNote = playerStrums.members[key];
				if (opponentChart) spr = opponentStrums.members[key];
				if (spr != null)
				{
					spr.playAnim('static');
					spr.resetAnim = 0;
				}
				callOnScripts('onKeyRelease', [key]);
			}
		}
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if (key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes + controller input
	private function keyShit():Void
	{
		// HOLDING
		var controlHoldArray:Array<Bool> = [];
		for (i in keysArray) {
			controlHoldArray.push(FlxG.keys.anyPressed(i));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [];
			for (i in keysArray) {
				controlArray.push(FlxG.keys.anyJustPressed(i));
			}
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}
		#if mobile
		else
		{
			controlHoldArray = [];
			var controlArray:Array<Bool> = [];
			for (i in grpNoteButtons) {
				controlArray.push(i.justPressed);
				controlHoldArray.push(i.pressed);
			}
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}
		#end

		if (startedCountdown && (inEditor || !playerMembers[0].stunned) && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (daNote.isSustainNote && controlHoldArray[daNote.noteData] && daNote.canBeHit 
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
					goodNoteHit(daNote, keysArray[daNote.noteData]);
				}
			});
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [];
			for (i in keysArray) {
				controlArray.push(FlxG.keys.anyJustReleased(i));
			}
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
		#if mobile
		else
		{
			var controlArray:Array<Bool> = [];
			for (i in grpNoteButtons) {
				controlArray.push(i.justReleased);
			}
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
		#end
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		if (!daNote.comboDisabled) combo = 0;
		setHealth(health - daNote.missHealth * healthLoss);

		if (instakillOnMiss)
		{
			if (opponentChart && foundDadVocals)
				vocalsDad.volume = 0;
			else
				vocals.volume = 0;
			doDeathCheck(true);
		}

		songMisses++;
		if (opponentChart && foundDadVocals)
			vocalsDad.volume = 0;
		else
			vocals.volume = 0;
		if (!practiceMode) songScore -= 10;
		
		totalPlayed++;
		recalculateRating(true);
		doRatingTween(ratingTxtGroup.members.length - 1);

		if (!inEditor) {
			var charMembers = playerMembers;
			if (daNote.gfNote) {
				charMembers = gfMembers;
			}

			for (char in daNote.characters) {
				if (char < charMembers.length && charMembers[char] != null) {
					switch(daNote.noteType) {
						case "Void Tendril": // @CoolingTool: The Void Tendril code where it reduces the min health
							minHealth += .125;

							if (charMembers[char].animOffsets.exists('hurt')) {
								charMembers[char].playAnim('hurt', true);
								charMembers[char].specialAnim = true; 
								continue;
							}
					}

					if (!daNote.noMissAnimation && charMembers[char].hasMissAnimations) {
						var animToPlay:String = '${playerSingAnimations[daNote.noteData]}miss${daNote.animSuffix}';
						if (charMembers[char].animOffsets.exists(animToPlay)) {
							charMembers[char].playAnim(animToPlay, true);
							charMembers[char].holdTimer = 0;
						}
					}
				}
			}
		}

		callOnScripts('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.characters]);
	}

	function noteMissPress(direction:Int = 1, ?keys:Array<FlxKey>):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (inEditor || !playerMembers[0].stunned)
		{
			health -= 0.05 * healthLoss;

			if (instakillOnMiss)
			{
				if (opponentChart && foundDadVocals)
					vocalsDad.volume = 0;
				else
					vocals.volume = 0;
				doDeathCheck(true);
			}

			if (combo > 5 && !inEditor)
			{
				for (gf in gfMembers) {
					if (gf.animOffsets.exists('sad')) {
						gf.playAnim('sad');
					}
				}
			}
		}
		combo = 0;

		if (!practiceMode) songScore -= 10;
		if (!endingSong) {
			songMisses++;
		}
		totalPlayed++;
		recalculateRating(true);
		doRatingTween(ratingTxtGroup.members.length - 1);

		setHealth(health - 0.05 * healthLoss);
		if (instakillOnMiss) {
			doDeathCheck(true);
		}

		recalculateRating();

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2), soundGroup);

		if (!inEditor) {
			var animToPlay = '${playerSingAnimations[direction]}miss';
			for (char in playerMembers) {
				if (char.hasMissAnimations && char.animOffsets.exists(animToPlay)) {
					char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					if (keys != null) char.keysPressed = keys;
				}
			}
		}

		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		if (!opponentChart) {
			camZooming = true;
			camBop = true;
		}

		if (!inEditor) {
			var charMembers = opponentMembers;
			if (note.gfNote) {
				charMembers = gfMembers;
			}

			for (char in note.characters) {
				if (char < charMembers.length && charMembers[char] != null) {
					if (note.noteType == 'Hey!' && charMembers[char].animOffsets.exists('hey')) {
						charMembers[char].playAnim('hey', true);
						charMembers[char].specialAnim = true;
						charMembers[char].heyTimer = 0.6;
					} else if (note.noteType == 'Void Tendril' && charMembers[char].animOffsets.exists('dodge')) {
						charMembers[char].playAnim('dodge', true);
						charMembers[char].specialAnim = true;
					} else if (!note.noAnimation) {
						var altAnim:String = note.animSuffix;

						if (SONG.notes[curSection] != null && SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection && !opponentChart) {
							altAnim = '-alt';
						}

						var animToPlay:String = opponentSingAnimations[note.noteData] + altAnim;

						if (charMembers[char].animOffsets.exists(animToPlay)) {
							charMembers[char].playAnim(animToPlay, true);
							charMembers[char].holdTimer = 0;
						}
					}
				}
			}
		}

		if (SONG.needsVoices) {
			if (opponentChart && foundDadVocals)
				vocalsDad.volume = 1;
			else
				vocals.volume = 1;
		}

		var time:Float = 0.15;
		if (note.isSustainNote && note.animation.curAnim != null && !note.animation.curAnim.name.endsWith('end')) {
			time += 0.15;
		}
		strumPlayAnim(true, note.noteData, time);
		note.hitByOpponent = true;

		if (!note.noteSplashDisabled && !note.isSustainNote)
		{
			spawnNoteSplashOnNote(note);
		}

		callOnScripts('opponentNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.characters]);

		var strumGroup = opponentChart ? playerStrums : opponentStrums;
		if (strumGroup.members[note.noteData].direction != 90 || !note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note, ?keys:Array<FlxKey>):Void
	{
		if (keys == null) keys = [];
		if (!note.wasGoodHit) {
			if (cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled && !demoMode)
			{
				FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume, soundGroup);
			}

			if (opponentChart) {
				camZooming = true;
				camBop = true;
			}

			var charMembers = playerMembers;
			if (note.gfNote) charMembers = gfMembers;

			var strumGroup = opponentChart ? opponentStrums : playerStrums;
			if (note.hitCausesMiss) {
				noteMiss(note);
				if (!note.noteSplashDisabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}
				strumGroup.forEach(function(spr:StrumNote)
				{
					if (note.noteData == spr.ID)
					{
						spr.playAnim('confirm', true);
					}
				});

				if (!note.noMissAnimation) {
					var doesGenericHurt = false;
					switch(note.noteType) {
						case 'Hurt Note': //Hurt note
							if (!inEditor) {
								doesGenericHurt = true;
							}
						case 'Void Note': // @ThaumcraftMC: The Void Note code so that it reduces the max health.
							if (!inEditor) {
								maxHealth -= .125;
								doesGenericHurt = true;
								GameOverSubState.selfAssignVariables(SONG.player1, voidedHealth);
							}
					}

					if (doesGenericHurt) {
						for (i in note.characters) {
							if (i < charMembers.length) {
								if (charMembers[i] != null && charMembers[i].animOffsets.exists('hurt')) {
									charMembers[i].playAnim('hurt', true);
									charMembers[i].specialAnim = true;
								}
							}
						}
					}
				}

				note.wasGoodHit = true;
				if (strumGroup.members[note.noteData].direction != 90 || !note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				if (!note.comboDisabled) combo += 1;
				if (combo > 9999) combo = 9999;
				popUpScore(note);
			}
			else
			{
				setHealth(health + note.hitHealth * healthGain); //oops forgot this
			}

			if (!note.noAnimation && !inEditor) {
				var altAnim:String = note.animSuffix;

				if (SONG.notes[curSection] != null && SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection && opponentChart) {
					altAnim = '-alt';
				}

				var animToPlay:String = playerSingAnimations[note.noteData] + altAnim;
				if (note.noteType == 'Void Tendril') animToPlay = 'dodge' + altAnim;

				for (i in note.characters) {
					switch (note.noteType) {
						case 'Hey!':
							for (i in note.characters) {
								if (i < charMembers.length && charMembers[i] != null && charMembers[i].animOffsets.exists('hey')) {
									charMembers[i].playAnim('hey', true);
									charMembers[i].specialAnim = true;
									charMembers[i].heyTimer = 0.6;
								}
							}
						default:
							if (i < charMembers.length && charMembers[i] != null && charMembers[i].animOffsets.exists(animToPlay)) {
								charMembers[i].playAnim(animToPlay, true);
								charMembers[i].holdTimer = 0;
								if (keys != null) charMembers[i].keysPressed = keys;
							}
					}
				}

				if (note.noteType == 'Hey!') {
					for (gf in gfMembers) {
						if (gf.animOffsets.exists('cheer')) {
							gf.playAnim('cheer', true);
							gf.specialAnim = true;
							gf.heyTimer = 0.6;
						}
					}
				}
			}

			if (cpuControlled) {
				var time:Float = 0.15;
				if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end')) {
					time += 0.15;
				}
				strumPlayAnim(false, note.noteData, time);
			} else {
				strumGroup.forEach(function(spr:StrumNote)
				{
					if (note.noteData == spr.ID)
					{
						spr.playAnim('confirm', true);
					}
				});
			}
			note.wasGoodHit = true;
			if (opponentChart && foundDadVocals)
				vocalsDad.volume = 1;
			else
				vocals.volume = 1;

			callOnScripts('goodNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.characters]);

			if (strumGroup.members[note.noteData].direction != 90 || !note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	function spawnNoteSplashOnNote(note:Note) {
		if (note != null && ClientPrefs.noteSplashes) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (note.isOpponent) strum = opponentStrums.members[note.noteData];
			if (strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null, ?strum:StrumNote = null) {
		var skin:String = 'noteSplashes';
		var colors = playerColors;
		var keys = playerKeys;
		if (note != null && note.isOpponent) {
			colors = opponentColors;
			keys = opponentKeys;
		}
		
		var hue:Float = ClientPrefs.arrowHSV[keys - 1][data % keys][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[keys - 1][data % keys][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[keys - 1][data % keys][2] / 100;
		if (note != null) {
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, note, skin, hue, sat, brt, keys, strum);
		grpNoteSplashes.add(splash);
	}

	private var preventLuaRemove:Bool = false;
	override function destroy() {
		FlxG.timeScale = 1;
		Conductor.playbackRate = 1;
		for (lua in luaArray) {
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];
		#if HSCRIPT_ALLOWED
		for (i in hscriptMap.keys()) {
			callHscript(i, 'onDestroy', []);
			var hscript = hscriptMap.get(i);
			hscriptMap.remove(i);
			hscript = null;
		}
		hscriptMap.clear();
		#end
		instance = null;

		if (inEditor)
			FlxG.sound.music.stop();
		vocals.stop();
		vocals.destroy();
		vocalsDad.stop();
		vocalsDad.destroy();

		if (!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		#if hscript
		FunkinLua.haxeInterp = null;
		#end

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		//reset window to before lua messed with it
		Application.current.window.title = lastTitle;
		CoolUtil.setWindowIcon();
		#end

		super.destroy();

		#if cpp
		if (ClientPrefs.controlGC) {
			// trace("PlayState.destroy: reenabling GC");
			cpp.vm.Gc.enable(true);
		}
		#end
	}

	public static function cancelMusicFadeTween() {
		if (FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();
		if (generatedMusic && (Math.abs(FlxG.sound.music.time - Conductor.songPosition) > 20 * playbackRate
			|| (SONG.needsVoices && ((Math.abs(vocals.time - Conductor.songPosition) > 20 * playbackRate) 
			|| (foundDadVocals && Math.abs(vocalsDad.time - Conductor.songPosition) > 20 * playbackRate)))))
		{
			resyncVocals();
		}

		if (curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit', []);
	}

	var lastBeatHit:Int = -1;
	
	override function beatHit()
	{
		super.beatHit();

		if (lastBeatHit >= curBeat) {
			return;
		}

		for (chatbox in twitchChatboxes) {
			chatbox.generateMessage();
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		var curNumeratorBeat = Conductor.getCurNumeratorBeat(SONG, curBeat);

		if (!inEditor) {
			if (iconBopSpeed > 0 && curNumeratorBeat % (Math.round(iconBopSpeed * (Conductor.timeSignature[1] / 4))) == 0) {
				iconP1.bop();
				iconP2.bop();
			}

			if (curBeat >= 0) {
				var chars = [boyfriendMembers, dadMembers, gfMembers];
				for (members in chars) {
					for (char in members) {
						if (char.danceEveryNumBeats > 0 && curNumeratorBeat % (Math.round(char.danceEveryNumBeats * (Conductor.timeSignature[1] / 4))) == 0 && !char.stunned && !char.singing() && !char.specialAnim)
						{
							char.dance(true);
						}
					}
				}

				for (bopper in boppers) {
					if (curBeat % (Math.round(bopper.danceEveryNumBeats * (Conductor.timeSignature[1] / 4))) == 0)
						bopper.dance(true);
				}
			}

			if (ClientPrefs.gameQuality != 'Crappy') {
				switch (curStage) {
					// high Quality per-beat stage effects here, i guess
				}
			}
		}
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);//DAWGG?????
		setOnScripts('curNumeratorBeat', curNumeratorBeat);//CAT?????
		setOnScripts('curSection', curSection);
		callOnScripts('onBeatHit', []);
	}

	override function sectionHit() {
		super.sectionHit();
		
		var songSection = SONG.notes[curSection];
		if (songSection != null)
		{
			if (!inEditor && ClientPrefs.camZooms && camZooming && camBop && FlxG.camera.zoom < 1.35)
			{
				bopCamZoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (songSection.changeBPM && songSection.bpm != Conductor.bpm)
			{
				Conductor.changeBPM(songSection.bpm);
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('normalizedCrochet', Conductor.normalizedCrochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
				callOnScripts('onBPMChange', []);
			}
			if (songSection.changeSignature && (songSection.timeSignature[0] != Conductor.timeSignature[0] || songSection.timeSignature[1] != Conductor.timeSignature[1]))
			{
				Conductor.changeSignature(SONG.notes[Math.floor(curSection)].timeSignature);
				setOnScripts('signatureNumerator', Conductor.timeSignature[0]);
				setOnScripts('signatureDenominator', Conductor.timeSignature[1]);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('normalizedCrochet', Conductor.normalizedCrochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
				callOnScripts('onSignatureChange', []);
			}
			#if MULTI_KEY_ALLOWED
			if (songSection.changeKeys)
			{
				switchKeys(songSection.playerKeys, songSection.opponentKeys);
				callOnScripts('onKeyChange', []);
			}
			#end
			setOnScripts('mustHitSection', songSection.mustHitSection);
			setOnScripts('altAnim', songSection.altAnim);
			setOnScripts('gfSection', songSection.gfSection);
			setOnScripts('lengthInSteps', songSection.lengthInSteps);
			setOnScripts('changeBPM', songSection.changeBPM);
			setOnScripts('changeSignature', songSection.changeSignature);
		}
	}

	function switchKeys(bfKeys:Int = 4, dadKeys:Int = 4, init:Bool = false) {
		if (this.bfKeys != bfKeys || init) {
			if (!playerStrumMap.exists(bfKeys)) {
				generateStaticArrows(1, bfKeys);
			}
			this.bfKeys = bfKeys;
			if (!opponentChart) {
				#if mobile
				resetNoteButtons();
				#end
			}
			strumLineNotes.clear();
			playerStrums = playerStrumMap.get(bfKeys);
			for (i in opponentStrums) {
				strumLineNotes.add(i);
			}
			for (i in playerStrums) {
				strumLineNotes.add(i);
			}
			if (!opponentChart || !ClientPrefs.middleScroll) {
				resetUnderlay(underlayPlayer, playerStrums);
			}
			#if !mobile
			if (!opponentChart) showKeybindReminders();
			#end
			setOnScripts('playerKeyAmount', bfKeys);
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX$i', playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY$i', playerStrums.members[i].y);
			}
			setOnHscripts('playerStrums', playerStrums);
		}
		if (this.dadKeys != dadKeys || init) {
			if (!opponentStrumMap.exists(dadKeys)) {
				generateStaticArrows(0, dadKeys);
			}
			this.dadKeys = dadKeys;
			if (opponentChart) {
				#if mobile
				resetNoteButtons();
				#end
			}
			strumLineNotes.clear();
			opponentStrums = opponentStrumMap.get(dadKeys);
			for (i in opponentStrums) {
				strumLineNotes.add(i);
			}
			for (i in playerStrums) {
				strumLineNotes.add(i);
			}
			if (!ClientPrefs.underlayFull && (opponentChart || !ClientPrefs.middleScroll)) {
				resetUnderlay(underlayOpponent, opponentStrums);
			}
			#if !mobile
			if (opponentChart) showKeybindReminders();
			#end
			setOnScripts('opponentKeyAmount', dadKeys);
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX$i', opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY$i', opponentStrums.members[i].y);
			}
			setOnHscripts('opponentStrums', opponentStrums);
		}
		setKeysArray(playerKeys);
		playerSingAnimations = CoolUtil.coolArrayTextFile(Paths.txt('note_animations'))[playerKeys-1];
		opponentSingAnimations = CoolUtil.coolArrayTextFile(Paths.txt('note_animations'))[opponentKeys-1];
	}

	#if mobile
	function resetNoteButtons() {
		grpNoteButtons.clear();
		if (!ClientPrefs.controllerMode) {
			for (i in 0...playerKeys) {
				var button = new NoteButton(Std.int(FlxG.width / playerKeys) * i, 0, i, playerKeys);
				button.cameras = [camButtons];
				grpNoteButtons.add(button);
			}
		}
	}
	#end

	public function callOnScripts(event:String, args:Array<Dynamic>, ignoreStops = true, ?exclusions:Array<String> = null):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		if (!inEditor) {
			if(exclusions == null) exclusions = [];
			#if LUA_ALLOWED
			for (script in luaArray) {
				if(exclusions.contains(script.scriptName))
					continue;

				var ret:Dynamic = script.call(event, args);
				if(ret == FunkinLua.Function_StopLua && !ignoreStops)
					break;

				// had to do this because there is a bug in haxe where Stop != Continue doesnt work
				var bool:Bool = ret == FunkinLua.Function_Continue;
				if(!bool) {
					returnVal = cast ret;
				}
			}
			#end

			#if HSCRIPT_ALLOWED
			for (script in hscriptMap.keys()) {
				var hscript = hscriptMap.get(script);
				if(hscript.closed || exclusions.contains(hscript.scriptName))
					continue;

				var ret:Dynamic = callHscript(script, event, args);
				if(ret == FunkinLua.Function_StopLua && !ignoreStops)
					break;

				// had to do this because there is a bug in haxe where Stop != Continue doesnt work
				var bool:Bool = ret == FunkinLua.Function_Continue;
				if(!bool) {
					returnVal = cast ret;
				}
			}
			#end
		}
		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic) {
		if (!inEditor) {
			#if LUA_ALLOWED
			for (i in 0...luaArray.length) {
				luaArray[i].set(variable, arg);
			}
			#end

			#if HSCRIPT_ALLOWED
			setOnHscripts(variable, arg);
			#end
		}
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if (isDad != opponentChart) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if (spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function recalculateRating(badHit:Bool = false) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);

		if (badHit)
			updateScore(true); // miss notes shouldn't make the scoretxt bounce -Ghost
		else
			updateScore(false);

		var ret:Dynamic = callOnScripts('onRecalculateRating', [], false);
		if (ret != FunkinLua.Function_Stop)
		{
			if (totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));

				// Rating Name
				if (ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length - 1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length - 1)
					{
						if (ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			if (sicks > 0) ratingFC = "SFC";
			if (goods > 0) ratingFC = "GFC";
			if (bads > 0 || shits > 0) ratingFC = "FC";
			if (songMisses > 0 && songMisses < 10) ratingFC = "SDCB";
			else if (songMisses >= 10) ratingFC = "Clear";
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	var curLight:Int = 0;
	var curLightEvent:Int = 0;
	var traced:Bool = false;
}
