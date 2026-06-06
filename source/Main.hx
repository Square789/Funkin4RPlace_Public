package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
#if html5
import flixel.FlxG;
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = MainMenuF4rpState; // The FlxState the game starts with.
	var zoom:Float = 1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void {
		if (zoom == -1)
		{
			var stageWidth:Int = Lib.current.stage.stageWidth;
			var stageHeight:Int = Lib.current.stage.stageHeight;
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		ClientPrefs.setupDefaults();

		// @Square789: If i got this right:
		// Will cause HaxeFlixel to also store its config in there, as we're binding before the FlxGame constructor call.
		FlxG.save.bind('funkin');

		var game = new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);

		Application.current.window.title = "Funkin' 4 r/place";

		// @Square789: Irrelevant, keeping mod support not feasible.
		// #if MODS_ALLOWED
		// Paths.pushGlobalMods();
		// #end
		// // Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		// WeekData.loadTheFirstEnabledMod();

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = [FlxKey.ZERO];
		FlxG.sound.volumeDownKeys = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
		FlxG.sound.volumeUpKeys = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
		FlxG.keys.preventDefaultKeys = [TAB];

		PlayerSettings.init();

		ClientPrefs.loadPrefs();
		Highscore.load();

		if (FlxG.save.data != null && FlxG.save.data.fullscreen) {
			FlxG.fullscreen = FlxG.save.data.fullscreen;
		}
		if (FlxG.save.data.weekCompleted == null) {
			FlxG.save.data.weekCompleted = new Map<String, Bool>();
		}
		// if (FlxG.save.data.lastPlayed != null) {
		// 	FreeplayState.lastPlayed = FlxG.save.data.lastPlayed;
		// }

		FlxG.mouse.visible = false;

		// @CoolingTool: I really hate how haxeflixel's cursor looks, please don't murder me
		// FlxG.mouse.useSystemCursor = true;
		// @CoolingTool: so it turns out that when you make the cursor visible with system cursor it 
		// doesn't actually become visible untill the player moves the cursor 😢😢😢😢😢😢😢
		// maybe making a custom cursor would be cool idk
		CoolUtil.setWindowIcon();

		// @Square789: FlxG.save should be good here, init achievements.
		AchievementManager.initialize();
		AchievementManager.removeUnknownAchievements();
		AchievementManager.notify(GAME_STARTED);

		#if DISCORD_ALLOWED
		if (!DiscordClient.isInitialized) {
			DiscordClient.initialize();
			Application.current.onExit.add((_exitcode) -> DiscordClient.shutdown());
		}
		#end

		addChild(game);

		#if !mobile
		fpsVar = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		if (fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}
		#end

		#if html5
		FlxG.mouse.visible = false;
		#end

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end
}