package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import CoolUtil.PointStruct;

using StringTools;


class GameOverSubState extends MusicBeatSubState {
	public var boyfriend:Boyfriend;
	public var camGame:FlxCamera;
	var camFollowPos:PointStruct;
	var camFollowObj:FlxObject;
	var deathSound:FlxSound;
	var totalElapsed:Float;
	var playingDeathSound:Bool = false;

	var stageSuffix:String = "";

	// @CoolingTool: funkmix
	var gravity:Float = -(12.5 * 130);
	var yVelocity:Float = 0;
	var initialYPosition:Float;

	// @Square789: Do what the main menu did and throw in a new camera
	// for death achievements
	private var camAchievement:FlxCamera;
	// @Square789: A bunch of setup was done in `new` which the state docs specifically
	// say not to do and i guess the separate cameras finally screwed it all up.
	// Store variables here to have them available in `create`.
	// Ok i think actually i just forgot to set bgColor.alpha to 0 but uuh lmao
	private var creationVars:{bfx:Float, bfy:Float, zoom:Float} = null;

	public static var defaultCamZoom:Float = 1;
	public static var camStartTime:Float = 0.5;
	public static var camDuration:Float = 9;
	public static var camEasing:EaseFunction = FlxEase.expoOut;
	public static var deathSoundEndTime:Float = 2.41;
	public static var loopSoundBPM:Float = 100;
	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:Null<String> = 'fnf_loss_sfx';
	public static var loopSoundName:Null<String> = 'gameOver';
	public static var endSoundName:Null<String> = 'gameOverEnd';
	public static var quitSoundName:Null<String> = 'gameOverQuit';
	public static var cameraOffset:PointStruct = {x: 0.0, y: 0.0};
	public static var retrySpriteData: Null<{name:String, x:Int, y:Int}>;

	public static var instance:GameOverSubState;

	#if mobile
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	public static function resetVariables() {
		defaultCamZoom = 1;
		camStartTime = 0.5;
		camDuration = 9;
		camEasing = FlxEase.expoOut;
		deathSoundEndTime = 2.41;
		loopSoundBPM = 100;
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		quitSoundName = 'gameOverQuit';
		cameraOffset = {x: 0.0, y: 0.0};
		retrySpriteData = null;
	}

	public static function selfAssignVariables(char:String, voided:Float) {
		switch(char) {
			case 'ross-bf':
				characterName = 'ross-bf';
				retrySpriteData = {name: "ross", x: -1, y: -26};
			case 'flag-bf':
				characterName = voided >= 1.399 ? 'flag-bf-void-death' : 'flag-bf';
				deathSoundName = 'fnf_loss_sfx_no_mic';
				deathSoundEndTime = 1.07;
				retrySpriteData = {name: "flag", x:  3, y: -16};
			case 'flagpico':
				characterName = 'flagpico';
				deathSoundName = 'pico-death';
				// loopSoundName = 'gameOver-flagpico';
				deathSoundEndTime = 1.07;
				retrySpriteData = {name: "flag", x:  3, y: -16};
			case '8BF':
				characterName = '8BF';
				deathSoundName = 'fnf_loss_sfx_no_mic';
				deathSoundEndTime = 1.07;
				camEasing = FlxEase.circOut;
				camStartTime = 0;
				camDuration = deathSoundEndTime - camStartTime + .04;
				retrySpriteData = {name: "8bf",  x: -7, y:  -5};
			case 'rainbowdash':
				characterName = 'rainbowdash-dead';
				deathSoundName = null;
				deathSoundEndTime = 1.0;
				loopSoundName = null;
				quitSoundName = null;
				endSoundName = null;
				camEasing = function(x:Float) {return 1.0;};
				camStartTime = 0.0;
				cameraOffset = {x: 370.0, y: -154.0}
			case 'bf-pixel': // irrelevant just for testing
				characterName = 'bf-pixel-dead';
				deathSoundName = 'fnf_loss_sfx-pixel';
				loopSoundName = 'gameOver-pixel';
				endSoundName = 'gameOverEnd-pixel';
			case 'bf-holding-gf': // why'not
				characterName = 'bf-holding-gf-dead';
		}
	}

	override function create()
	{
		instance = this;
		PlayState.instance.callOnScripts('onGameOverStart', []);

		super.create();

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		achievementNotificationBox.cameras = [camAchievement];

		camGame.zoom = creationVars.zoom;

		boyfriend = new Boyfriend(creationVars.bfx, creationVars.bfy, characterName);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		initialYPosition = boyfriend.y;

		if (deathSoundName != null) {
			deathSound = FlxG.sound.play(Paths.sound(deathSoundName));
		}
		Conductor.changeBPM(100);
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		var container = boyfriend.getScreenBounds();

		if (retrySpriteData != null) {
			// Attempt to compensate for topleft weirdness introduced by scaling:
			var scaleDiff = (1.0 - 6.0) * 0.5;
			var trueTopLX = boyfriend.x + (boyfriend.frame.frame.width * scaleDiff);
			var trueTopLY = boyfriend.y + (boyfriend.frame.frame.height * scaleDiff);

			var retrySprite = new FarpSprite(
				trueTopLX + (retrySpriteData.x * 6), (trueTopLY + retrySpriteData.y * 6)
			);
			retrySprite.loadGraphic(Paths.image('retry/${retrySpriteData.name}'));
			retrySprite.pixelSize = 6;
			retrySprite.snapToPixelGrid = true;
			retrySprite.antialiasing = false;
			retrySprite.origin.set(0.0, 0.0);
			retrySprite.setGraphicSize(Std.int(retrySprite.width) * 6);
			add(retrySprite);

			container.union(retrySprite.getScreenBounds());
		}

		camFollowPos = {
			x: container.x + container.width / 2 + cameraOffset.x,
			y: container.y + container.height / 2 + cameraOffset.y,
		};

		camFollowObj = new FlxObject(0, 0, 1, 1);
		camFollowObj.setPosition(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2));
		add(camFollowObj);

		#if mobile
		buttonENTER = new Button(492, 564, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + 136, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end
	}

	public function new(x:Float, y:Float, zoom:Float)
	{
		super();
		creationVars = {bfx: x, bfy: y, zoom: zoom};

		PlayState.instance.callOnScripts('inGameOver', [true]);

		totalElapsed = 0;
		Conductor.songPosition = 0;
	}

	var isFollowingAlready:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		totalElapsed += elapsed;

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end)
		{
			endBullshit();
		}

		if (controls.BACK #if mobile || buttonESC.justPressed #end)
		{
			quitBullshit();
		}

		if (boyfriend.animation.curAnim.name == 'firstDeath' && !boyfriend.startedDeath && !boyfriend.endingDeath)
		{
			// @CoolingTool: why was it hardcoded to only start moving camera on the 12th frame lol
			// well i understand why but still
			if (!isFollowingAlready)
			{	
				isFollowingAlready = true;
				startCamera();
			}

			if (boyfriend.animation.curAnim.finished && (deathSoundEndTime < totalElapsed))
			{
				coolStartDeath();
				boyfriend.startedDeath = true;
				yVelocity = 750;
			}
		}

		// @CoolingTool: the values are basically just stolen from funk mix source code
		if (characterName == "8BF")
		{
			if (boyfriend.isOnScreen() || boyfriend.endingDeath){
				if (boyfriend.startedDeath || boyfriend.endingDeath) {
					yVelocity += (gravity * elapsed);
				}
				boyfriend.y -= yVelocity * elapsed;
				if (boyfriend.endingDeath && yVelocity < 0.0 && boyfriend.y > initialYPosition) {
					boyfriend.y = initialYPosition;
					yVelocity = 0;
					if (boyfriend.animation.curAnim.name != "idle") {
						boyfriend.playAnim('idle', true);
					}
				}
			}
		}

		if (FlxG.sound.music.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	override function beatHit()
	{
		super.beatHit();
		boyfriend.dance(true);
	}

	function coolStartDeath(?volume:Float = 1):Void {
		if (loopSoundName != null) {
			FlxG.sound.playMusic(Paths.music(loopSoundName), volume);
			Conductor.changeBPM(loopSoundBPM);
		} else {
			Conductor.changeBPM(42.0);
		}
	}

	function startCamera(?delay:Float):Void {
		var options:TweenOptions = {ease: camEasing, startDelay: delay != null ? delay : camStartTime}
		FlxG.camera.follow(camFollowObj, LOCKON, 1);
		FlxTween.tween(camFollowObj, {x: camFollowPos.x, y: camFollowPos.y}, camDuration, options);
		FlxTween.tween(camGame, {zoom: defaultCamZoom}, camDuration, options);
	}

	function endBullshit():Void {
		if (boyfriend.endingDeath) {
			return;
		}

		boyfriend.endingDeath = true;
		if (boyfriend.animOffsets.exists('deathConfirm')) {
			boyfriend.playAnim('deathConfirm', true);
		}

		FlxG.sound.music.stop();
		if (endSoundName != null) {
			FlxG.sound.play(Paths.music(endSoundName));
		}

		if (boyfriend.curCharacter == "8BF") {
			if (boyfriend.y < initialYPosition) {
				yVelocity = 450;
			} else {
				yVelocity = Math.sqrt(2 * gravity * (-(boyfriend.y - initialYPosition) - 42));
			}
		}

		new FlxTimer().start(0.7, function(tmr:FlxTimer) {
			FlxG.camera.fade(FlxColor.BLACK, 2, false, MusicBeatState.resetState);
		});
		PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
	}

	// @CoolingTool: death quit animation
	function quitBullshit():Void
	{
		if (!boyfriend.endingDeath)
		{
			boyfriend.endingDeath = true;
			if (boyfriend.animOffsets.exists('deathCancel'))
				boyfriend.playAnim('deathCancel', true);
			else if (boyfriend.animOffsets.exists('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);

			if (quitSoundName != null) {
				FlxG.sound.play(Paths.music(quitSoundName));
			}

			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;
			PlayState.chartingMode = false;

			new FlxTimer().start(0.3, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, .4, false, function() 
				{
					WeekData.loadTheFirstEnabledMod();
					if (PlayState.isStoryMode)
						MusicBeatState.switchState(new MainMenuF4rpState(true));
					else
						MusicBeatState.switchState(new FreeplayPlaceState());

					CoolUtil.playMenuMusic();
				});
			});
		}
		PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
	}
}
