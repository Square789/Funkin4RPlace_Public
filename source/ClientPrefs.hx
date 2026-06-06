package;

import flixel.FlxG;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;

class ClientPrefs {
	public static var downScroll:Bool = false;
	public static var middleScroll:Bool = false;
	public static var opponentStrums:Bool = true;
	public static var showFPS:Bool = false;
	public static var flashing:Bool = true;
	public static var globalAntialiasing:Bool = true;
	public static var noteSplashes:Bool = true;
	public static var gameQuality:String = 'Normal';
	public static var framerate:Int = 60;
	public static var camZooms:Bool = true;
	public static var hideHud:Bool = false;
	public static var noteOffset:Int = 0;
	public static var arrowHSV:Array<Array<Array<Int>>> = [];
	public static var ghostTapping:Bool = true;
	public static var timeBarType:String = 'Time Left';
	public static var scoreSeperator:String = 'Comma';
	public static var scoreZoom:Bool = true;
	public static var showRatings:Bool = false;
	public static var noReset:Bool = false;
	public static var healthBarAlpha:Float = 1;
	public static var controllerMode:Bool = false;
	public static var hitsoundVolume:Float = 0;
	public static var pauseMusic:String = 'Cooldown';
	public static var menuMusic:String = 'Random';
	public static var tendrilVolume:Float = 1;
	public static var checkForUpdates:Bool = true;
	public static var underlayAlpha:Float = 0;
	public static var underlayFull:Bool = false;
	public static var instantRestart:Bool = false;
	#if !html5
	public static var autoPause:Bool = true;
	#else
	public static var autoPause:Bool = false;
	#end
	public static var focusLostPause:Bool = true;
	public static var shitMisses:Bool = true;
	public static var smoothHealth:Bool = false;
	public static var keybindReminders:Bool = false;
	public static var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => false,
		'demomode' => false
	];

	public static var comboOffset:Array<Int> = [0, 0, 0, 0];
	public static var ratingOffset:Int = 0;
	public static var sickWindow:Int = 45;
	public static var goodWindow:Int = 90;
	public static var badWindow:Int = 135;
	public static var safeFrames:Float = 10;
	public static var noteSkin:String = 'Default';
	public static var uiSkin:String = 'Default'; // unused
	public static var controlGC:Bool = true;

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		#if MULTI_KEY_ALLOWED
		'note1_0'		=> [SPACE, UP],

		'note2_0'		=> [A, LEFT],
		'note2_1'		=> [D, RIGHT],

		'note3_0'		=> [A, LEFT],
		'note3_1'		=> [S, DOWN],
		'note3_2'		=> [D, RIGHT],
		#end

		'note4_0'		=> [A, LEFT],
		'note4_1'		=> [S, DOWN],
		'note4_2'		=> [W, UP],
		'note4_3'		=> [D, RIGHT],

		#if MULTI_KEY_ALLOWED
		'note5_0'		=> [A, LEFT],
		'note5_1'		=> [S, DOWN],
		'note5_2'		=> [SPACE, NONE],
		'note5_3'		=> [W, UP],
		'note5_4'		=> [D, RIGHT],

		'note6_0'		=> [A, NONE],
		'note6_1'		=> [S, NONE],
		'note6_2'		=> [D, NONE],
		'note6_3'		=> [J, LEFT],
		'note6_4'		=> [K, DOWN],
		'note6_5'		=> [L, RIGHT],

		'note7_0'		=> [A, NONE],
		'note7_1'		=> [S, NONE],
		'note7_2'		=> [D, NONE],
		'note7_3'		=> [SPACE, NONE],
		'note7_4'		=> [J, LEFT],
		'note7_5'		=> [K, DOWN],
		'note7_6'		=> [L, RIGHT],

		'note8_0'		=> [A, NONE],
		'note8_1'		=> [S, NONE],
		'note8_2'		=> [D, NONE],
		'note8_3'		=> [F, NONE],
		'note8_4'		=> [H, NONE],
		'note8_5'		=> [J, NONE],
		'note8_6'		=> [K, NONE],
		'note8_7'		=> [L, NONE],

		'note9_0'		=> [A, NONE],
		'note9_1'		=> [S, NONE],
		'note9_2'		=> [D, NONE],
		'note9_3'		=> [F, NONE],
		'note9_4'		=> [SPACE, NONE],
		'note9_5'		=> [H, NONE],
		'note9_6'		=> [J, NONE],
		'note9_7'		=> [K, NONE],
		'note9_8'		=> [L, NONE],

		'note10_0'		=> [Q, NONE],
		'note10_1'		=> [W, NONE],
		'note10_2'		=> [E, NONE],
		'note10_3'		=> [R, NONE],
		'note10_4' 		=> [V, NONE],
		'note10_5'		=> [N, NONE],
		'note10_6'		=> [U, NONE],
		'note10_7'		=> [I, NONE], 
		'note10_8'		=> [O, NONE],
		'note10_9'		=> [P, NONE],

		'note11_0'		=> [Q, NONE],
		'note11_1'		=> [W, NONE],
		'note11_2'		=> [E, NONE],
		'note11_3'		=> [R, NONE],
		'note11_4' 		=> [V, NONE],
		'note11_5'		=> [SPACE, NONE],
		'note11_6'		=> [N, NONE],
		'note11_7'		=> [U, NONE],
		'note11_8'		=> [I, NONE], 
		'note11_9'		=> [O, NONE],
		'note11_10'		=> [P, NONE],

		'note12_0'		=> [Q, NONE],
		'note12_1'		=> [W, NONE],
		'note12_2'		=> [E, NONE],
		'note12_3'		=> [R, NONE],
		'note12_4' 		=> [C, NONE],
		'note12_5' 		=> [V, NONE],
		'note12_6' 		=> [N, NONE],
		'note12_7'		=> [M, NONE],
		'note12_8'		=> [U, NONE],
		'note12_9'		=> [I, NONE], 
		'note12_10'		=> [O, NONE],
		'note12_11'		=> [P, NONE],

		'note13_0'		=> [Q, NONE],
		'note13_1'		=> [W, NONE],
		'note13_2'		=> [E, NONE],
		'note13_3'		=> [R, NONE],
		'note13_4' 		=> [C, NONE],
		'note13_5' 		=> [V, NONE],
		'note13_6'		=> [SPACE, NONE],
		'note13_7' 		=> [N, NONE],
		'note13_8'		=> [M, NONE],
		'note13_9'		=> [U, NONE],
		'note13_10'		=> [I, NONE], 
		'note13_11'		=> [O, NONE],
		'note13_12'		=> [P, NONE],
		#end
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [ENTER, SPACE],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [THREE, NONE],
		
		'volume_mute'	=> [ZERO, NONE],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN, NONE],
		'debug_2'		=> [EIGHT, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;

	public static function setupDefaults() {
		defaultKeys = keyBinds.copy();

		#if MULTI_KEY_ALLOWED
		for (i in 0...Note.MAX_KEYS) {
			arrowHSV.push([]);
			for (j in 0...i + 1) {
				arrowHSV[i].push([0, 0, 0]);
			}
		}
		#else
		arrowHSV[3] = [];
		for (i in 0...4) {
			arrowHSV[3].push([0, 0, 0]);
		}
		#end
	}

	public static function saveSettings() {
		FlxG.save.data.downScroll = downScroll;
		FlxG.save.data.middleScroll = middleScroll;
		FlxG.save.data.opponentStrums = opponentStrums;
		FlxG.save.data.showFPS = showFPS;
		FlxG.save.data.flashing = flashing;
		FlxG.save.data.globalAntialiasing = globalAntialiasing;
		FlxG.save.data.noteSplashes = noteSplashes;
		FlxG.save.data.gameQuality = gameQuality;
		FlxG.save.data.framerate = framerate;
		FlxG.save.data.camZooms = camZooms;
		FlxG.save.data.noteOffset = noteOffset;
		FlxG.save.data.hideHud = hideHud;
		FlxG.save.data.arrowHSV = arrowHSV;
		FlxG.save.data.ghostTapping = ghostTapping;
		FlxG.save.data.timeBarType = timeBarType;
		FlxG.save.data.scoreSeperator = scoreSeperator;
		FlxG.save.data.scoreZoom = scoreZoom;
		FlxG.save.data.showRatings = showRatings;
		FlxG.save.data.noReset = noReset;
		FlxG.save.data.healthBarAlpha = healthBarAlpha;
		FlxG.save.data.comboOffset = comboOffset;
		FlxG.save.data.tendrilVolume = tendrilVolume;
		FlxG.save.data.underlayAlpha = underlayAlpha;
		FlxG.save.data.underlayFull = underlayFull;
		FlxG.save.data.instantRestart = instantRestart;
		FlxG.save.data.autoPause = autoPause;
		FlxG.save.data.focusLostPause = focusLostPause;
		FlxG.save.data.shitMisses = shitMisses;
		FlxG.save.data.smoothHealth = smoothHealth;
		FlxG.save.data.keybindReminders = keybindReminders;
		// @Square789: Achievement saving not needed here anymore since the AchievementManager
		// takes control of the needed fields in data.

		FlxG.save.data.ratingOffset = ratingOffset;
		FlxG.save.data.sickWindow = sickWindow;
		FlxG.save.data.goodWindow = goodWindow;
		FlxG.save.data.badWindow = badWindow;
		FlxG.save.data.safeFrames = safeFrames;
		FlxG.save.data.noteSkin = noteSkin;
		FlxG.save.data.controlGC = controlGC;
		FlxG.save.data.controllerMode = controllerMode;
		FlxG.save.data.hitsoundVolume = hitsoundVolume;
		FlxG.save.data.pauseMusic = pauseMusic;
		FlxG.save.data.menuMusic = menuMusic;
		FlxG.save.data.checkForUpdates = checkForUpdates;
		FlxG.save.data.gameplaySettings = gameplaySettings;
	
		FlxG.save.flush();

		var save = new FlxSave();
		save.bind('controls_v2'); //Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		save.data.customControls = keyBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs() {
		if (FlxG.save.data.downScroll != null) {
			downScroll = FlxG.save.data.downScroll;
		}
		if (FlxG.save.data.middleScroll != null) {
			middleScroll = FlxG.save.data.middleScroll;
		}
		if(FlxG.save.data.opponentStrums != null) {
			opponentStrums = FlxG.save.data.opponentStrums;
		}
		if (FlxG.save.data.showFPS != null) {
			showFPS = FlxG.save.data.showFPS;
			if (Main.fpsVar != null) {
				Main.fpsVar.visible = showFPS;
			}
		}
		if (FlxG.save.data.flashing != null) {
			flashing = FlxG.save.data.flashing;
		}
		if (FlxG.save.data.globalAntialiasing != null) {
			globalAntialiasing = FlxG.save.data.globalAntialiasing;
		}
		if (FlxG.save.data.noteSplashes != null) {
			noteSplashes = FlxG.save.data.noteSplashes;
		}
		if (FlxG.save.data.gameQuality != null) {
			gameQuality = FlxG.save.data.gameQuality;
		} else if (FlxG.save.data.lowQuality != null) {
			gameQuality = (FlxG.save.data.lowQuality ? 'Low' : 'Normal');
		}
		if (FlxG.save.data.framerate != null) {
			framerate = FlxG.save.data.framerate;
			if (framerate > FlxG.drawFramerate) {
				FlxG.updateFramerate = framerate;
				FlxG.drawFramerate = framerate;
			} else {
				FlxG.drawFramerate = framerate;
				FlxG.updateFramerate = framerate;
			}
		}
		if (FlxG.save.data.camZooms != null) {
			camZooms = FlxG.save.data.camZooms;
		}
		if (FlxG.save.data.hideHud != null) {
			hideHud = FlxG.save.data.hideHud;
		}
		if (FlxG.save.data.noteOffset != null) {
			noteOffset = FlxG.save.data.noteOffset;
		}
		#if MULTI_KEY_ALLOWED
		if (FlxG.save.data.arrowHSV != null && FlxG.save.data.arrowHSV.length == Note.MAX_KEYS) {
		#else
		if (FlxG.save.data.arrowHSV != null && FlxG.save.data.arrowHSV.length == 4) {
		#end
			arrowHSV = FlxG.save.data.arrowHSV;
		}
		if (FlxG.save.data.ghostTapping != null) {
			ghostTapping = FlxG.save.data.ghostTapping;
		}
		if (FlxG.save.data.timeBarType != null) {
			timeBarType = FlxG.save.data.timeBarType;
		}
		if (FlxG.save.data.scoreSeperator != null) {
			scoreSeperator = FlxG.save.data.scoreSeperator;
		}
		if (FlxG.save.data.scoreZoom != null) {
			scoreZoom = FlxG.save.data.scoreZoom;
		}
		if (FlxG.save.data.showRatings != null) {
			showRatings = FlxG.save.data.showRatings;
		}
		if (FlxG.save.data.noReset != null) {
			noReset = FlxG.save.data.noReset;
		}
		if (FlxG.save.data.healthBarAlpha != null) {
			healthBarAlpha = FlxG.save.data.healthBarAlpha;
		}
		if (FlxG.save.data.comboOffset != null) {
			comboOffset = FlxG.save.data.comboOffset;
		}
		
		if (FlxG.save.data.ratingOffset != null) {
			ratingOffset = FlxG.save.data.ratingOffset;
		}
		if (FlxG.save.data.sickWindow != null) {
			sickWindow = FlxG.save.data.sickWindow;
		}
		if (FlxG.save.data.goodWindow != null) {
			goodWindow = FlxG.save.data.goodWindow;
		}
		if (FlxG.save.data.badWindow != null) {
			badWindow = FlxG.save.data.badWindow;
		}
		if (FlxG.save.data.safeFrames != null) {
			safeFrames = FlxG.save.data.safeFrames;
		}
		if (FlxG.save.data.noteSkin != null) {
			noteSkin = FlxG.save.data.noteSkin;
		}
		if (FlxG.save.data.controlGC != null) {
			controlGC = FlxG.save.data.controlGC;
		}
		if(FlxG.save.data.controllerMode != null) {
			controllerMode = FlxG.save.data.controllerMode;
		}
		if(FlxG.save.data.hitsoundVolume != null) {
			hitsoundVolume = FlxG.save.data.hitsoundVolume;
		}
		if(FlxG.save.data.pauseMusic != null) {
			pauseMusic = FlxG.save.data.pauseMusic;
		}
		if(FlxG.save.data.menuMusic != null) {
			menuMusic = FlxG.save.data.menuMusic;
		}
		if (FlxG.save.data.checkForUpdates != null)
		{
			checkForUpdates = FlxG.save.data.checkForUpdates;
		}	
		if (FlxG.save.data.tendrilVolume != null) {
			tendrilVolume = FlxG.save.data.tendrilVolume;
		}
		if (FlxG.save.data.underlayAlpha != null) {
			underlayAlpha = FlxG.save.data.underlayAlpha;
		}
		if (FlxG.save.data.underlayFull != null) {
			underlayFull = FlxG.save.data.underlayFull;
		}
		if (FlxG.save.data.instantRestart != null) {
			instantRestart = FlxG.save.data.instantRestart;
		}
		if (FlxG.save.data.autoPause != null) {
			autoPause = FlxG.save.data.autoPause;
			FlxG.autoPause = autoPause;
		}
		if (FlxG.save.data.focusLostPause != null) {
			focusLostPause = FlxG.save.data.focusLostPause;
		}
		if (FlxG.save.data.shitMisses != null) {
			shitMisses = FlxG.save.data.shitMisses;
		}
		if (FlxG.save.data.smoothHealth != null) {
			smoothHealth = FlxG.save.data.smoothHealth;
		}
		if (FlxG.save.data.keybindReminders != null) {
			keybindReminders = FlxG.save.data.keybindReminders;
		}
		if (FlxG.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
			{
				gameplaySettings.set(name, value);
			}
		}
		
		// flixel automatically saves your volume!
		@:privateAccess
		FlxG.sound.loadSavedPrefs();

		var save = new FlxSave();
		save.bind('controls_v2');
		if (save != null && save.data.customControls != null) {
			var loadedControls:Map<String, Array<FlxKey>> = save.data.customControls;
			for (control => keys in loadedControls) {
				keyBinds.set(control, keys);
			}
			reloadControls();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic {
		return (gameplaySettings.exists(name) ? gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadControls() {
		PlayerSettings.player1.controls.setKeyboardScheme(Solo);

		FlxG.sound.muteKeys = copyNonNoneKeys('volume_mute');
		FlxG.sound.volumeDownKeys = copyNonNoneKeys('volume_down');
		FlxG.sound.volumeUpKeys = copyNonNoneKeys('volume_up');
	}

	public static function copyNonNoneKeys(controlName:String):Array<FlxKey> {
		return [for (key in keyBinds[controlName]) if (key != NONE) key];
	}
}
