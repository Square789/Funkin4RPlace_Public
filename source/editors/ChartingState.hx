package editors;

import flixel.util.FlxSave;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.media.AudioBuffer;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;
#if desktop
import flash.geom.Rectangle;
import haxe.io.Bytes;
#end
#if sys
import sys.io.File;
import sys.FileSystem;
#end
#if (MODS_ALLOWED || LUA_ALLOWED)
import haxe.io.Path;
#end

using StringTools;

@:access(flixel.system.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState
{
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'Void Note', // @ThaumcraftMC: Added the Void Note to the Custom Note list.
		'Void Tendril',
		'GF Sing',
		'No Animation',
	];
	private var noteTypeIntMap:Map<Int, String> = new Map();
	private var noteTypeMap:Map<String, Null<Int>> = new Map();
	public var ignoreWarnings = false;
	var undos = [];
	var redos = [];
	var eventStuff:Array<Array<String>> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		//['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		//['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		//['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character Group, Character Number\n(split with comma)\n(Character Groups: 0 = Dad, 1 = BF, 2 = GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character Group, Character Number to set (split with comma)\n(Character Groups: 0 = Dad, 1 = BF, 2 = GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character Group, Character Number to change\n(split with comma)\n(Character Groups: 0 = BF, 1 = Dad, 2 = GF)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		[
			'Chatbox Control',
			(
				"Value 1 (A): The message spewer to modify and its\n" +
				"  desired chance value, separated by any of '#:;>'.\n" +
				"  preload/data/twitch_chat/messages.json contains\n" +
				"  all available spewer names.\n" +
				"  The default spewer chance is 1000.\n" +
				"Value 1 (B): \"!STORE\", \"!RESTORE\", \"!CLEAR\"\n" +
				"Value 2: Zero-based indices of affected chatboxes,\n" +
				"  separated by commas. Leave blank to affect all.\n" +
				"  (For !STORE, only the first index has meaning.)"
			),
		],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		[
			'Modify Healthbar Icons',
			(
				"Value 1: \"!ADD\", \"!REMOVE\", \"!REMOVEAT\"\n" +
				"Value 2: the targeted side (1 or 2), a character ID\n" +
				"and optionally an insertion index separated by\n" +
				"commas. (\"1,bf\", \"1,gf,0\")\n" +
				"Index defaults to the end if not given.\n" +
				"!REMOVE ignores the index and remove at most one\n" +
				"icon by its character's name. (\"1,bf\")\n" +
				"!REMOVEAT removes the icon at the specified index\n" +
				"and does not take a name. (\"2,0\")\n" +
				"Counterintuitively, the last icon is the frontmost one.\n" +
				"It is unwise to remove all icons.\n"
			),
		],
	];

	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;
	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;
	var CAM_OFFSET:Int = 360 - 21 - 32 - 400;
	var NUMERATORS:Array<String> = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'];
	var DENOMINATORS:Array<String> = ['2', '4', '8', '16'];

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var overWaveform:FlxTypedGroup<FlxSprite>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var vocals:FlxSound = null;
	var vocalsDad:FlxSound = null;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var currentSongName:String;
	
	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Int = 1;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;
	
	public static var quantization:Int = 16;
	public static var curQuant = 3;

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	var text:String = "";
	public static var vortex:Bool = false;
	public var mouseQuant:Bool = false;

	var leftKeys:Int = 4;
	var rightKeys:Int = 4;
	var totalKeys:Int = 8;

	var autosaveTimer:FlxTimer;

	var fromMasterMenu = false;

	var autosaveSave:FlxSave;

	public function new(?fromMasterMenu:Bool) {
		super();
		if (fromMasterMenu != null) this.fromMasterMenu = fromMasterMenu;
	}

	override function create() {
		autosaveSave = new FlxSave();
		autosaveSave.bind('chart_autosave');

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();

			_song = {
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				skinModifier: '',
				skinModifierOpponent: '',
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage',
				playerKeyAmount: 4,
				opponentKeyAmount: 4,
				timeSignature: [4, 4],
				validScore: false,
				arrowSkin: null,
				splashSkin: null
			};
			addSection(_song.timeSignature[0] * 4);
			PlayState.SONG = _song;
		}

		updateKeys();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		overWaveform = new FlxTypedGroup<FlxSprite>();
		add(overWaveform);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(0, -100);
		rightIcon.setPosition(GRID_SIZE * leftKeys, -100);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		if (curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		FlxG.mouse.visible = true;

		updateSectionLengths();

		Conductor.mapBPMChanges(_song);
		Conductor.getLastBPM(_song, recalculateSteps());
		addSection(Conductor.timeSignature[0] * 4);

		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();

		strumLine = new FlxSprite(0, 50).makeGraphic(GRID_SIZE * (totalKeys + 1), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant','chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);
		
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		makeStrumNotes();
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET + 400, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = 0;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		text =
		"W/S or Mouse Wheel - Change Conductor's strum time
		\nControl + Mouse Wheel - Scroll grid left/right
		\nA/D - Go to the previous/next section
		\nLeft/Right - Change Snap
		\nUp/Down - Change Conductor's Strum Time with Snapping
		\nHold Shift to move 4x faster
		\nHold Control and click on an arrow to select it
		\nZ/X - Zoom in/out
		\nEsc - Test your chart inside Chart Editor
		\nEnter - Play your chart
		\nQ/E - Decrease/Increase Note Sustain Length
		\nSpace - Stop/Resume song";

		var tipTextArray:Array<String> = text.split('\n');
		for (i in 0...tipTextArray.length) {
			var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 8, 294, tipTextArray[i], 12);
			tipText.y += i * 12;
			tipText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tipText.borderSize = 0.5;
			tipText.scrollFactor.set();
			add(tipText);
		}
		add(UI_box);

		bpmTxt = new FlxText(UI_box.x + UI_box.width + 8, 50, 0, "", 16);
		bpmTxt.setBorderStyle(OUTLINE, FlxColor.BLACK);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();

		if (lastSong != currentSongName) {
			changeSection();
		}
		lastSong = currentSongName;

		zoomTxt = new FlxText(UI_box.x + UI_box.width + 8, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.setBorderStyle(OUTLINE, FlxColor.BLACK);
		zoomTxt.scrollFactor.set();
		add(zoomTxt);
		
		updateGrid();

		autosaveTimer = new FlxTimer().start(60, function(tmr:FlxTimer) {
			trace('60 seconds passed, autosaving');
			autosaveSong();
		}, 0);
		super.create();
	}

	var check_mute_inst:FlxUICheckBox = null;
	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;
	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var UI_songTitle:FlxUIInputText;
	var noteSkinInputText:FlxUIInputText;
	var noteSplashesInputText:FlxUIInputText;
	var skinModifierInputText:FlxUIInputText;
	var skinModifier2InputText:FlxUIInputText;
	var stageDropDown:FlxUIDropDownMenu;
	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song);
		blockPressWhileTypingOn.push(UI_songTitle);
		
		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			loadSong();
			updateWaveform();
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", function()
		{
			saveLevel();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
				currentSongName = Paths.formatToSongPath(UI_songTitle.text);
				loadJson(_song.song.toLowerCase());
			}, null, ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
				if (autosaveSave.data.autosave == null) {
					return; // Should probably inform the user somehow but i guess nothing happening is information enough
				}
				currentSongName = Paths.formatToSongPath(UI_songTitle.text);
				PlayState.SONG = Song.parseJSONshit(autosaveSave.data.autosave);
				MusicBeatState.resetState();
			}, null, ignoreWarnings));
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{
			var songName:String = Paths.formatToSongPath(_song.song);
			var file:String = Paths.json('${songName}/events');
			if (Paths.fileExists('data/$songName/events.json', TEXT))
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		});

		var saveEvents:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', function ()
		{
			saveEvents();
		});

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 1000, 3);
		stepperBPM.value = _song.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		#if MULTI_KEY_ALLOWED
		var stepperPlayerKeys:FlxUINumericStepper = new FlxUINumericStepper(stepperBPM.x + 80, stepperBPM.y, 1, 4, 1, Note.MAX_KEYS);
		stepperPlayerKeys.value = _song.playerKeyAmount;
		stepperPlayerKeys.name = 'song_playerKeys';
		blockPressWhileTypingOnStepper.push(stepperPlayerKeys);

		var stepperOpponentKeys:FlxUINumericStepper = new FlxUINumericStepper(stepperPlayerKeys.x, stepperPlayerKeys.y + stepperPlayerKeys.height + 15, 1, 4, 1, Note.MAX_KEYS);
		stepperOpponentKeys.value = _song.opponentKeyAmount;
		stepperOpponentKeys.name = 'song_opponentKeys';
		blockPressWhileTypingOnStepper.push(stepperOpponentKeys);
		#end

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods('${Paths.currentModDirectory}/characters/'), Paths.getPreloadPath('characters/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('characters/')];
		#end

		var tempMap:Map<String, Bool> = new Map();
		var characters:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));
		for (i in 0...characters.length) {
			tempMap.set(characters[i], true);
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if (FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if (!charToCheck.endsWith('-dead') && !tempMap.exists(charToCheck)) {
							tempMap.set(charToCheck, true);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		#end

		var player1DropDown = new FlxUIDropDownMenu(10, stepperSpeed.y + 45, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		if (_song.gfVersion == null) gfVersionDropDown.selectedLabel = 'gf';
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods('${Paths.currentModDirectory}/stages/'), Paths.getPreloadPath('stages/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		tempMap.clear();
		var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		var stages:Array<String> = [];
		for (i in 0...stageFile.length) { //Prevent duplicates
			var stageToCheck:String = stageFile[i];
			if (!tempMap.exists(stageToCheck)) {
				stages.push(stageToCheck);
			}
			tempMap.set(stageToCheck, true);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if (FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stageToCheck:String = file.substr(0, file.length - 5);
						if (!tempMap.exists(stageToCheck)) {
							tempMap.set(stageToCheck, true);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if (stages.length < 1) stages.push('stage');

		stageDropDown = new FlxUIDropDownMenu(player1DropDown.x + 140, player1DropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(character:String)
		{
			_song.stage = stages[Std.parseInt(character)];
		});
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		WeekData.reloadWeekFiles(PlayState.isStoryMode);
		CoolUtil.getDifficulties(currentSongName);
		if (PlayState.storyDifficulty > CoolUtil.difficulties.length - 1) {
			PlayState.storyDifficulty = CoolUtil.difficulties.indexOf('Normal');
			if (PlayState.storyDifficulty == -1) PlayState.storyDifficulty = 0;
		}
		
		var difficultyDropDown = new FlxUIDropDownMenu(stageDropDown.x, gfVersionDropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray(CoolUtil.difficulties, true), function(difficulty:String)
		{
			if (PlayState.storyDifficulty != Std.parseInt(difficulty)) {
				PlayState.storyDifficulty = Std.parseInt(difficulty);
				try {
					PlayState.SONG = Song.loadFromJson(_song.song + CoolUtil.getDifficultyFilePath(), _song.song);
					MusicBeatState.resetState();
				} catch (e) {
					trace('File ${Paths.formatToSongPath(_song.song) + CoolUtil.getDifficultyFilePath()} was not found.');
				}
			}
		});
		difficultyDropDown.selectedLabel = CoolUtil.difficulties[PlayState.storyDifficulty];
		blockPressWhileScrolling.push(difficultyDropDown);

		var stepperNumerator:FlxUINumericStepper = new FlxUINumericStepper(stageDropDown.x + 12, player2DropDown.y, 1, 4, 1, 100);
		stepperNumerator.value = _song.timeSignature[0];
		stepperNumerator.name = 'song_numerator';
		blockPressWhileTypingOnStepper.push(stepperNumerator);

		var stepperDenominator:FlxUINumericStepper = new FlxUINumericStepper(stepperNumerator.x, stepperNumerator.y + 20, 2, 4, 1, 64);
		stepperDenominator.value = _song.timeSignature[1];
		stepperDenominator.name = 'song_denominator';
		blockPressWhileTypingOnStepper.push(stepperDenominator);

		var skin = PlayState.SONG.arrowSkin;
		if(skin == null) skin = '';
		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 75, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);
	
		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 75, _song.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var skin = _song.skinModifier;
		if (skin == null) skin = '';
		skinModifierInputText = new FlxUIInputText(noteSkinInputText.x + 150, noteSkinInputText.y, 75, skin, 8);
		blockPressWhileTypingOn.push(skinModifierInputText);

		var skin = _song.skinModifierOpponent;
		if (skin == null) skin = '';
		skinModifier2InputText = new FlxUIInputText(noteSplashesInputText.x + 150, noteSplashesInputText.y, 75, skin, 8);
		blockPressWhileTypingOn.push(skinModifier2InputText);

		var reloadNotesButton:FlxButton = new FlxButton(skinModifier2InputText.x - 5, skinModifier2InputText.y + 35, 'Change Notes', function() {
			_song.arrowSkin = noteSkinInputText.text;
			_song.splashSkin = noteSplashesInputText.text;
			_song.skinModifier = skinModifierInputText.text;
			_song.skinModifierOpponent = skinModifier2InputText.text;
			PlayState.SONG = _song;
			updateGrid();
			makeStrumNotes();
		});

		var clear_events:FlxButton = new FlxButton(FlxG.width - 100, UI_songTitle.y, 'Clear events', function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
				autosaveSong();
				clearEvents();
			}, null, ignoreWarnings));
		});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(clear_events.x, clear_events.y + clear_events.height, 'Clear notes', function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', function() {
				autosaveSong();
				for (sec in 0..._song.notes.length) {
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings));
		});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		#if MULTI_KEY_ALLOWED
		tab_group_song.add(stepperPlayerKeys);
		tab_group_song.add(stepperOpponentKeys);
		#end
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);
		tab_group_song.add(skinModifierInputText);
		tab_group_song.add(skinModifier2InputText);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		#if MULTI_KEY_ALLOWED
		tab_group_song.add(new FlxText(stepperPlayerKeys.x, stepperPlayerKeys.y - 15, 0, 'Player Key Amount:'));
		tab_group_song.add(new FlxText(stepperOpponentKeys.x, stepperOpponentKeys.y - 15, 0, 'Opponent Key Amount:'));
		#end
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(new FlxText(difficultyDropDown.x, difficultyDropDown.y - 15, 0, 'Difficulty:'));
		tab_group_song.add(new FlxText(stepperNumerator.x, stepperNumerator.y - 15, 0, 'Time Signature:'));
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		tab_group_song.add(new FlxText(skinModifierInputText.x, skinModifierInputText.y - 15, 0, 'Skin Modifier:'));
		tab_group_song.add(new FlxText(skinModifier2InputText.x, skinModifier2InputText.y - 15, 0, 'Opponent Skin Modifier:'));
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stepperDenominator);
		tab_group_song.add(stepperNumerator);
		tab_group_song.add(difficultyDropDown);
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);

		FlxG.camera.follow(camPos);
	}

	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_changeSignature:FlxUICheckBox;
	var stepperSectionNumerator:FlxUINumericStepper;
	var stepperSectionDenominator:FlxUINumericStepper;
	#if MULTI_KEY_ALLOWED
	var check_changeKeys:FlxUICheckBox;
	var stepperSectionPlayerKeys:FlxUINumericStepper;
	var stepperSectionOpponentKeys:FlxUINumericStepper;
	#end
	var check_altAnim:FlxUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Array<Dynamic>>;

	function addSectionUI():Void {
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 30, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(130, 30, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;

		check_altAnim = new FlxUICheckBox(10, 60, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 90, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, 110, 1, Conductor.bpm, 0, 1000, 3);
		if (check_changeBPM.checked) {
			stepperSectionBPM.value = _song.notes[curSec].bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		check_changeSignature = new FlxUICheckBox(130, check_gfSection.y + 30, null, null, 'Change Signature', 100);
		check_changeSignature.checked = _song.notes[curSec].changeSignature;
		check_changeSignature.name = 'check_changeSignature';

		stepperSectionNumerator = new FlxUINumericStepper(check_changeSignature.x, check_changeSignature.y + 20, 1, Conductor.timeSignature[0], 1, 100);
		if (check_changeSignature.checked) {
			stepperSectionNumerator.value = _song.notes[curSec].timeSignature[0];
		}
		stepperSectionNumerator.name = 'section_numerator';
		blockPressWhileTypingOnStepper.push(stepperSectionNumerator);

		stepperSectionDenominator = new FlxUINumericStepper(stepperSectionNumerator.x, stepperSectionNumerator.y + 20, 2, Conductor.timeSignature[1], 1, 64);
		if (check_changeSignature.checked) {
			stepperSectionDenominator.value = _song.notes[curSec].timeSignature[1];
		}
		stepperSectionDenominator.name = 'section_denominator';
		blockPressWhileTypingOnStepper.push(stepperSectionDenominator);

		#if MULTI_KEY_ALLOWED
		check_changeKeys = new FlxUICheckBox(check_changeSignature.x, stepperSectionDenominator.y + 20, null, null, 'Change Keys', 100);
		check_changeKeys.checked = _song.notes[curSec].changeKeys;
		check_changeKeys.name = 'check_changeKeys';

		stepperSectionPlayerKeys = new FlxUINumericStepper(check_changeKeys.x, check_changeKeys.y + 20, 1, _song.playerKeyAmount, 1, Note.MAX_KEYS);
		if (check_changeKeys.checked) {
			stepperSectionPlayerKeys.value = _song.notes[curSec].playerKeys;
		}
		stepperSectionPlayerKeys.name = 'section_playerKeys';
		blockPressWhileTypingOnStepper.push(stepperSectionPlayerKeys);

		stepperSectionOpponentKeys = new FlxUINumericStepper(stepperSectionPlayerKeys.x, stepperSectionPlayerKeys.y + 20, 1, _song.opponentKeyAmount, 1, Note.MAX_KEYS);
		if (check_changeKeys.checked) {
			stepperSectionOpponentKeys.value = _song.notes[curSec].opponentKeys;
		}
		stepperSectionOpponentKeys.name = 'section_opponentKeys';
		blockPressWhileTypingOnStepper.push(stepperSectionOpponentKeys);
		#end

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;
		var copyButton:FlxButton = new FlxButton(10, 150, "Copy Section", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note = _song.notes[curSec].sectionNotes[i];
				notesCopied.push(note);
			}
			
			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(10, 180, "Paste Section", function()
		{
			if (notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = sectionStartTime() - (sectionStartTime(-(curSec - sectionToCopy)));

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if (note[1] < 0)
				{
					if(check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if(check_notesSec.checked)
					{
						if (note[4] != null) {
							copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
						} else {
							copiedNote = [newStrumTime, note[1], note[2], note[3], [0]];
						}	
						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear", function()
		{
			autosaveSong();
			if(check_notesSec.checked)
			{
				_song.notes[curSec].sectionNotes = [];
			}
			
			if(check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while(i > -1) {
					var event = _song.events[i];
					if (event != null && endThing > event[0] && event[0] >= startThing)
					{
						_song.events.remove(event);
					}
					--i;
				}
			}
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;

		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 50);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 100, check_notesSec.y, null, null, "Events", 50);
		check_eventsSec.checked = true;

		var swapSection:FlxButton = new FlxButton(10, check_notesSec.y + 40, "Swap section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note = _song.notes[curSec].sectionNotes[i];
				note[1] = Math.floor((note[1] + totalKeys / 2)) % totalKeys;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var swapMustHitSection:FlxButton = new FlxButton(110, swapSection.y, "Swap must hit section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note = _song.notes[curSec].sectionNotes[i];
				if (note[1] >= rightKeys) {
					note[1] -= rightKeys;
				} else {
					note[1] += rightKeys;
				}
			}
			updateGrid();
		});
		swapMustHitSection.setGraphicSize(Std.int(swapMustHitSection.width), Std.int(swapMustHitSection.height * 2));
		changeAllLabelsOffset(swapMustHitSection, 0, -6);

		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 276, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var copyLastButton:FlxButton = new FlxButton(10, 270, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if (value == 0) return;

			var daSec = FlxMath.maxInt(curSec, value);

			for (note in _song.notes[daSec - value].sectionNotes)
			{
				var strum = note[0] + (sectionStartTime() - sectionStartTime(-value));

				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3], note[4]];
				_song.notes[daSec].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					strumTime += sectionStartTime() - sectionStartTime(-value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();

		var duetButton:FlxButton = new FlxButton(10, 320, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = (note[1] % rightKeys) + leftKeys;
				if (note[1] >= leftKeys) {
					boob = (note[1] % leftKeys) - leftKeys;
				}

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3], note[4]];
				duetNotes.push(copiedNote);
			}

			for (note in _song.notes[curSec].sectionNotes) {
				for (duet in duetNotes) {
					if (duet[0] == note[0] && duet[1] == note[1]) {
						duetNotes.remove(duet);
					}
				}
			}

			for (i in duetNotes) {
				_song.notes[curSec].sectionNotes.push(i);
			}

			updateGrid();
		});
		
		var mirrorButton:FlxButton = new FlxButton(10, 350, "Mirror Notes", function()
		{
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1] % leftKeys;
				if (note[1] >= leftKeys) {
					boob = note[1] - leftKeys;
					boob = rightKeys - 1 - boob;
				} else {
					boob = leftKeys - 1 - boob;
				}
				if (note[1] >= leftKeys) boob += leftKeys;

				note[1] = boob;
			}

			updateGrid();
		});

		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapSection);
		tab_group_section.add(swapMustHitSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);
		#if MULTI_KEY_ALLOWED
		tab_group_section.add(check_changeKeys);
		tab_group_section.add(stepperSectionPlayerKeys);
		tab_group_section.add(stepperSectionOpponentKeys);
		#end
		tab_group_section.add(check_changeSignature);
		tab_group_section.add(stepperSectionDenominator);
		tab_group_section.add(stepperSectionNumerator);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenu;
	var charactersInputText:FlxUIInputText;
	var currentType:Int = 0;
	var currentChars:Array<Int> = [0];

	function addNoteUI():Void {
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, 999999);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if LUA_ALLOWED
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_notetypes/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/custom_notetypes/'));
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_notetypes/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if (FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.lua')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if (!noteTypeMap.exists(fileToCheck)) {
							displayNameList.push(fileToCheck);
							noteTypeMap.set(fileToCheck, key);
							noteTypeIntMap.set(key, fileToCheck);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...displayNameList.length) {
			displayNameList[i] = '$i. ${displayNameList[i]}';
		}

		noteTypeDropDown = new FlxUIDropDownMenu(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if (curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		charactersInputText = new FlxUIInputText(10, noteTypeDropDown.y + 50, 180, "0");
		tab_group_note.add(charactersInputText);
		blockPressWhileTypingOn.push(charactersInputText);

		tab_group_note.add(new FlxText(10, stepperSusLength.y - 15, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, strumTimeInputText.y - 15, 0, 'Strum time (in milliseconds):'));
		tab_group_note.add(new FlxText(10, noteTypeDropDown.y - 15, 0, 'Note type:'));
		tab_group_note.add(new FlxText(10, charactersInputText.y - 15, 0, 'Note singers (split by commas):'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);
		tab_group_note.add(charactersInputText);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenu;
	var descText:FlxText;
	var selectedEventText:FlxText;
	function addEventsUI():Void {
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		#if LUA_ALLOWED
		#if MODS_ALLOWED
		var eventPushedMap:Map<String, Bool> = new Map();
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_events/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/custom_events/'));
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_events/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if (FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if (!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end
		#end

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length) {
			leEvents.push(eventStuff[i][0]);
		}

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new FlxUIDropDownMenu(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(leEvents, true), function(pressed:String) {
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventStuff[selectedEvent][1];
				if (curSelectedNote != null &&  eventStuff != null) {
				if (curSelectedNote != null && curSelectedNote[2] == null) {
				curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];
					
				}
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100, "");
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100, "");
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if (curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if (curEventSelected < 0) curEventSelected = 0;
				else if (curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;
				
				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);
			
		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);
			
		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);
			
		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0) {
		if (curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if (curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if (curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ${curEventSelected + 1} / ${curSelectedNote[1].length}';
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}
	
	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float) {
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	function changeAllLabelsOffset(button:FlxButton, x:Float, y:Float) {
		for (point in button.labelOffsets)
		{
			point.set(point.x + x, point.y + y);
		}
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	#if desktop
	var waveformUseInstrumental:FlxUICheckBox;
	var waveformUseVoices:FlxUICheckBox;
	var waveformUseVoicesDad:FlxUICheckBox;
	#end
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;
	var voicesDadVolume:FlxUINumericStepper;
	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';
		
		#if desktop
		if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;
		if (FlxG.save.data.chart_waveformVoicesDad == null) FlxG.save.data.chart_waveformVoicesDad = false;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform for Instrumental", 100);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = function()
		{
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			waveformUseVoicesDad.checked = false;
			FlxG.save.data.chart_waveformVoicesDad = false;
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 120, waveformUseInstrumental.y, null, null, "Waveform for Voices", 100);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices;
		waveformUseVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			waveformUseVoicesDad.checked = false;
			FlxG.save.data.chart_waveformVoicesDad = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};

		waveformUseVoicesDad = new FlxUICheckBox(waveformUseVoices.x + 120, waveformUseInstrumental.y, null, null, "Waveform for Opponent Voices", 100);
		waveformUseVoicesDad.checked = FlxG.save.data.chart_waveformVoicesDad;
		waveformUseVoicesDad.callback = function()
		{
			waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformVoicesDad = waveformUseVoicesDad.checked;
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 210, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		mouseScrollingQuant = new FlxUICheckBox(10, check_mute_inst.y + 30, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(check_warnings.x + 120, 120, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		var check_mute_vocals = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, "Mute Vocals (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_vocals.checked)
				vol = 0;

			vocals.volume = vol;
		};

		var check_mute_vocalsDad = new FlxUICheckBox(check_mute_vocals.x, check_mute_inst.y + 30, null, null, "Mute Opponent Vocals (in editor)", 100);
		check_mute_vocalsDad.checked = false;
		check_mute_vocalsDad.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_vocalsDad.checked)
				vol = 0;

			vocalsDad.volume = vol;
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, check_mute_vocalsDad.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			function() {
				FlxG.save.data.chart_metronome = metronome.checked;
			}
		);
		if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 1000, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);
		
		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120,
			function() {
				FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
			}
		);
		if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 170, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 80, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		voicesDadVolume = new FlxUINumericStepper(voicesVolume.x + 80, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesDadVolume.value = vocalsDad.volume;
		voicesDadVolume.name = 'voicesDad_volume';
		blockPressWhileTypingOnStepper.push(voicesDadVolume);

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		tab_group_chart.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		tab_group_chart.add(new FlxText(voicesVolume.x, voicesVolume.y - 15, 0, 'Voices Volume'));
		tab_group_chart.add(new FlxText(voicesDadVolume.x, voicesDadVolume.y - 15, 0, 'Opponent Voices Volume'));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		#if desktop
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		tab_group_chart.add(waveformUseVoicesDad);
		#end
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(voicesDadVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_mute_vocalsDad);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		UI_box.addGroup(tab_group_chart);
	}

	function loadSong():Void {
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}
		if (vocals != null)
		{
			vocals.stop();
		}
		if (vocalsDad != null)
		{
			vocalsDad.stop();
		}

		vocals = new FlxSound();
		if (_song.needsVoices) {
			var file:Dynamic = Paths.voices(currentSongName, CoolUtil.getDifficultyFilePath());
			if (file != null) {
				vocals.loadEmbedded(file);
				FlxG.sound.list.add(vocals);
			}
		}
		vocalsDad = new FlxSound();
		if (_song.needsVoices) {
			var file = Paths.voicesDad(PlayState.SONG.song, CoolUtil.getDifficultyFilePath());
			if (file != null) {
				vocalsDad.loadEmbedded(file);
				FlxG.sound.list.add(vocalsDad);
			}
		}
		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
	}

	function generateSong() {
		FlxG.sound.playMusic(Paths.inst(currentSongName, CoolUtil.getDifficultyFilePath()), 0.6);
		if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			vocals.pause();
			vocals.time = 0;
			vocalsDad.pause();
			vocalsDad.time = 0;
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			vocals.play();
			vocalsDad.play();
		};
	}

	function generateUI():Void {
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSec].mustHitSection = check.checked;

					updateKeys();
					reloadGridLayer();
					updateHeads();

				case 'GF section':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					_song.notes[curSec].changeBPM = check.checked;
					Conductor.mapBPMChanges(_song);
					Conductor.getLastBPM(_song, recalculateSteps());
					stepperSusLength.stepSize = Conductor.stepCrochet / 2;
					updateGrid();

				case 'Change Signature':
					_song.notes[curSec].changeSignature = check.checked;
					updateSectionLengths();
					Conductor.mapBPMChanges(_song);
					Conductor.getLastBPM(_song, recalculateSteps());
					stepperSusLength.stepSize = Conductor.stepCrochet / 2;
					changeSection(curSec);
					reloadGridLayer();

				#if MULTI_KEY_ALLOWED
				case 'Change Keys':
					_song.notes[curSec].changeKeys = check.checked;
					updateKeys();
					reloadGridLayer();
				#end
				
				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			if (wname == 'section_length')
			{
				_song.notes[curSec].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				_song.bpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.getLastBPM(_song, recalculateSteps());
				stepperSusLength.stepSize = Conductor.stepCrochet / 2;
			}
			else if (wname == 'song_numerator')
			{
				_song.timeSignature[0] = Std.int(nums.value);
				updateSectionLengths();
				Conductor.mapBPMChanges(_song);
				Conductor.getLastBPM(_song, recalculateSteps());
				stepperSusLength.stepSize = Conductor.stepCrochet / 2;
				changeSection(curSec);
				reloadGridLayer();
			}
			else if (wname == 'song_denominator')
			{
				_song.timeSignature[1] = Std.int(nums.value);
				Conductor.mapBPMChanges(_song);
				Conductor.getLastBPM(_song, recalculateSteps());
				stepperSusLength.stepSize = Conductor.stepCrochet / 2;
				changeSection(curSec);
				reloadGridLayer();
			}
			else if (wname == 'note_susLength')
			{
				if (curSelectedNote != null && curSelectedNote[1] > -1) {
					curSelectedNote[2] = nums.value;
					updateGrid();
				} else {
					sender.value = 0;
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSec].bpm = nums.value;
				if (_song.notes[curSec].changeBPM) {
					Conductor.mapBPMChanges(_song);
					Conductor.getLastBPM(_song, recalculateSteps());
					stepperSusLength.stepSize = Conductor.stepCrochet / 2;
					updateGrid();
				}
			}
			else if (wname == 'section_numerator')
			{
				_song.notes[curSec].timeSignature[0] = Std.int(nums.value);
				if (_song.notes[curSec].changeSignature) {
					updateSectionLengths();
					Conductor.mapBPMChanges(_song);
					Conductor.getLastBPM(_song, recalculateSteps());
					stepperSusLength.stepSize = Conductor.stepCrochet / 2;
					changeSection(curSec);
					reloadGridLayer();
				}
			}
			else if (wname == 'section_denominator')
			{
				_song.notes[curSec].timeSignature[1] = Std.int(nums.value);
				if (_song.notes[curSec].changeSignature) {
					updateSectionLengths();
					Conductor.mapBPMChanges(_song);
					Conductor.getLastBPM(_song, recalculateSteps());
					stepperSusLength.stepSize = Conductor.stepCrochet / 2;
					changeSection(curSec);
					reloadGridLayer();
				}
			}
			#if MULTI_KEY_ALLOWED
			else if (wname == 'section_playerKeys')
			{
				_song.notes[curSec].playerKeys = Std.int(nums.value);
				if (_song.notes[curSec].changeKeys) {
					updateKeys();
					reloadGridLayer();
				}
			}
			else if (wname == 'section_opponentKeys')
			{
				_song.notes[curSec].opponentKeys = Std.int(nums.value);
				if (_song.notes[curSec].changeKeys) {
					updateKeys();
					reloadGridLayer();
				}
			}
			#end
			else if (wname == 'inst_volume')
			{
				FlxG.sound.music.volume = nums.value;
			}
			else if (wname == 'voices_volume')
			{
				vocals.volume = nums.value;
			}
			else if (wname == 'voicesDad_volume')
			{
				vocalsDad.volume = nums.value;
			}
			#if MULTI_KEY_ALLOWED
			else if (wname == 'song_playerKeys')
			{
				_song.playerKeyAmount = Std.int(nums.value);
				updateKeys();
				reloadGridLayer();
			}
			else if (wname == 'song_opponentKeys')
			{
				_song.opponentKeyAmount = Std.int(nums.value);
				updateKeys();
				reloadGridLayer();
			}
			#end
		}
		else if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if (curSelectedNote != null)
			{
				if (sender == value1InputText) {
					curSelectedNote[1][curEventSelected][1] = value1InputText.text;
					updateGrid();
				}
				else if (sender == value2InputText) {
					curSelectedNote[1][curEventSelected][2] = value2InputText.text;
					updateGrid();
				}
				else if (sender == strumTimeInputText) {
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if (Math.isNaN(value)) value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
				else if (sender == charactersInputText) {
					currentChars = [];
					for (i in charactersInputText.text.split(',')) {
						if (!Math.isNaN(Std.parseInt(i))) currentChars.push(Std.parseInt(i));
					}
					if (currentChars.length < 1) currentChars.push(0);
					if (curSelectedNote != null && curSelectedNote[1] > -1) {
						curSelectedNote[4] = currentChars;
					}
				}
			}
		}
	}

	function sectionStartTime(add:Int = 0):Float {
		var daBPM:Float = _song.bpm;
		var daDenominator:Int = _song.timeSignature[1];
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				if (_song.notes[i].changeSignature)
				{
					daDenominator = _song.notes[i].timeSignature[1];
				}
				daPos += ((((60 / daBPM) * 4000) / daDenominator) / 4) * _song.notes[i].lengthInSteps;
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	override function update(elapsed:Float) {
		curStep = recalculateSteps();

		if (FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = UI_songTitle.text;

		strumLineUpdateY();
		for (i in 0...strumLineNotes.length) {
			strumLineNotes.members[i].y = strumLine.y;
		}

		FlxG.mouse.visible = true;//cause reasons. trust me 
		camPos.y = strumLine.y;
		if (!disableAutoScrolling.checked) {
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection(Conductor.timeSignature[0] * 4);
				}

				changeSection(curSec + 1, false);
			} else if (strumLine.y < -10) {
				changeSection(curSec - 1, false);
			}
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSec].lengthInSteps) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else{
				var gridmult = GRID_SIZE / (quantization / 16);
				dummyArrow.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
			}
		} else {
			dummyArrow.visible = false;
		}

		if (!FlxG.mouse.overlaps(UI_box) && FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note, true);
						}
						else
						{
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSec].lengthInSteps) * zoomList[curZoom])
				{
					addNote();
				}
			}
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if (inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;
				break;
			}
		}

		if (!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:Dynamic = stepper.text_field;
				var leText:FlxUIInputText = leText;
				if (leText.hasFocus) {
					FlxG.sound.muteKeys = [];
					FlxG.sound.volumeDownKeys = [];
					FlxG.sound.volumeUpKeys = [];
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput) {
			FlxG.sound.muteKeys = ClientPrefs.copyNonNoneKeys('volume_mute');
			FlxG.sound.volumeDownKeys = ClientPrefs.copyNonNoneKeys('volume_down');
			FlxG.sound.volumeUpKeys = ClientPrefs.copyNonNoneKeys('volume_up');
			for (dropDownMenu in blockPressWhileScrolling) {
				if (dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				autosaveSong();
				LoadingState.loadAndSwitchState(new PlayState(true, sectionStartTime()));
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.chartingMode = true;
				PlayState.SONG = _song;
				FlxG.sound.music.stop();
				vocals.stop();
				vocalsDad.stop();

				StageData.loadDirectory(_song);
				LoadingState.loadAndSwitchState(new PlayState());
			}

			if (curSelectedNote != null && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}
			
			if (FlxG.keys.justPressed.BACKSPACE) {
				WeekData.loadTheFirstEnabledMod();
				PlayState.chartingMode = false;
				if (fromMasterMenu) {
					MusicBeatState.switchState(new editors.MasterEditorMenu());
				} else {
					if (PlayState.isStoryMode) {
						MusicBeatState.switchState(new MainMenuF4rpState(true));
					} else {
						MusicBeatState.switchState(new FreeplayPlaceState());
					}
				}
				CoolUtil.playMenuMusic();
				FlxG.mouse.visible = false;
				return;
			}

			if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
				undo();
			}

			if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
				--curZoom;
				updateZoom();
			}
			if (FlxG.keys.justPressed.X && curZoom < zoomList.length - 1) {
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals.pause();
					vocalsDad.stop();
				}
				else
				{
					resyncVocals(true);
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				if (FlxG.keys.pressed.CONTROL) {
					camPos.x += Std.int(CoolUtil.boundTo(FlxG.mouse.wheel, -1, 1)) * GRID_SIZE;
					camPos.x = CoolUtil.boundTo(camPos.x, gridBG.x + CAM_OFFSET, gridBG.x + gridBG.width + CAM_OFFSET);
				} else {
					FlxG.sound.music.pause();
					if (!mouseQuant)
						FlxG.sound.music.time -= (Std.int(CoolUtil.boundTo(FlxG.mouse.wheel, -1, 1)) * Conductor.stepCrochet * 0.8);
					else
					{
						var time:Float = FlxG.sound.music.time;
						var beat:Float = curDecBeat;
						var snap:Float = quantization / 4;
						var increase:Float = 1 / snap;
						if (FlxG.mouse.wheel > 0){
							var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}else{
							var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
					}
					resyncVocals();
				}
			}

			//ARROW VORTEX SHIT NO DEADASS		
			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT) holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
				{
					FlxG.sound.music.time -= daTime;
				}
				else
					FlxG.sound.music.time += daTime;

				resyncVocals();
			}

			if(!vortex){
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();
					updateCurStep();
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP) {
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					} else {
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
			}
			
			var style = currentType;
			
			if (FlxG.keys.pressed.SHIFT) {
				style = 3;
			}
			
			var conductorTime = Conductor.songPosition;
			
			//AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if(!blockInput){
				if(FlxG.keys.justPressed.RIGHT){
					curQuant++;
					if(curQuant>quantizations.length-1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if(FlxG.keys.justPressed.LEFT){
					curQuant--;
					if(curQuant<0)
						curQuant = quantizations.length-1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}

			if (vortex && !blockInput) {
				var controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
												FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
							doANoteThing(conductorTime, i, style, currentChars);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();

					updateCurStep();

					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						feces = Conductor.beatToSeconds(fuck);
					}else{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; //(Math.floor((beat+snap) / snap) * snap);
						feces = Conductor.beatToSeconds(fuck);
					}
					FlxTween.tween(FlxG.sound.music, {time:feces}, 0.1, {ease:FlxEase.circOut});
					if(vocals != null) {
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}

					var dastrum = 0;

					if (curSelectedNote != null){
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime = (feces - secStart) - (dastrum - secStart); //idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
													   FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];

						if(controlArray.contains(true))
						{
							for (i in 0...controlArray.length)
							{
								if(controlArray[i])
									if(curSelectedNote[1] == i) curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			if (FlxG.keys.justPressed.D)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A) {
				if (curSec <= 0) {
					changeSection(_song.notes.length - 1);
				} else {
					changeSection(curSec - shiftThing);
				}
			}
		} else if (FlxG.keys.justPressed.ENTER) {
			for (i in 0...blockPressWhileTypingOn.length) {
				if (blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		strumLineNotes.visible = quant.visible = vortex;
			
		if (FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...strumLineNotes.length) {
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		bpmTxt.text = 
		'${Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))} / ${Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))}
		\nSection: $curSec
		\n\nBeat: ${Std.string(curDecBeat).substring(0,4)}
		\n\nStep: $curStep
		\n\nBeat Snap: ${quantization}th';

		var playedSound:Array<Bool> = []; //Prevents ouchy GF sex sounds
		for (i in 0...totalKeys) {
			playedSound.push(false);
		}
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if (curSelectedNote != null) {
				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += leftKeys;

				if (curSelectedNote[0] == note.strumTime && ((curSelectedNote[2] == null && noteDataToCheck < 0) || (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999); //Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if (note.strumTime <= Conductor.songPosition && !note.ignoreNote && !note.hitCausesMiss) {
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += leftKeys;
					strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
					strumLineNotes.members[noteDataToCheck].resetAnim = (note.sustainLength / 1000) + 0.15;
					if (!playedSound[noteDataToCheck]) {
						if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)) {
							FlxG.sound.play(Paths.sound('hitsound')).pan = note.noteData < leftKeys ? -0.3 : 0.3; //would be coolio
							playedSound[noteDataToCheck] = true;
						}
					}
				}
			}
		});

		if (metronome.checked && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = (60 / metronomeStepper.value) * (4 / Conductor.timeSignature[1]);
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if (metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
			}
		}
		lastConductorPos = Conductor.songPosition;
		super.update(elapsed);
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if(daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	}

	/*
	function loadAudioBuffer() {
		if (audioBuffers[0] != null) {
			audioBuffers[0].dispose();
		}
		audioBuffers[0] = null;
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders('songs/$currentSongName/Inst.${Paths.SOUND_EXT}'))) {
			audioBuffers[0] = AudioBuffer.fromFile(Paths.modFolders('songs/$currentSongName/Inst.${Paths.SOUND_EXT}'));
		}
		else { #end
			var leVocals:String = Paths.getPath('$currentSongName/Inst.${Paths.SOUND_EXT}', SOUND, 'songs');
			if (OpenFlAssets.exists(leVocals)) { //Vanilla inst
				audioBuffers[0] = AudioBuffer.fromFile('./${leVocals.substr(6)}');
			}
		#if MODS_ALLOWED
		}
		#end

		if (audioBuffers[1] != null) {
			audioBuffers[1].dispose();
		}
		audioBuffers[1] = null;
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders('songs/$currentSongName/Voices.${Paths.SOUND_EXT}'))) {
			audioBuffers[1] = AudioBuffer.fromFile(Paths.modFolders('songs/$currentSongName/Voices.${Paths.SOUND_EXT}'));
		} else { #end
			var leVocals:String = Paths.getPath('$currentSongName/Voices.${Paths.SOUND_EXT}', SOUND, 'songs');
			if (OpenFlAssets.exists(leVocals)) { //Vanilla voices
				audioBuffers[1] = AudioBuffer.fromFile('./${leVocals.substr(6)}');
			}
		#if MODS_ALLOWED
		}
		#end

		if (audioBuffers[2] != null) {
			audioBuffers[2].dispose();
		}
		audioBuffers[2] = null;
		var fileName = 'VoicesDad';
		if (Paths.fileExists('$currentSongName/VoicesOpponent.${Paths.SOUND_EXT}', MUSIC, false, 'songs'))
		{
			fileName = 'VoicesOpponent';
		}
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders('songs/$currentSongName/$fileName.${Paths.SOUND_EXT}'))) {
			audioBuffers[2] = AudioBuffer.fromFile(Paths.modFolders('songs/$currentSongName/$fileName.${Paths.SOUND_EXT}'));
		} else { #end
			var leVocals:String = Paths.getPath('$currentSongName/$fileName.${Paths.SOUND_EXT}', SOUND, 'songs');
			if (OpenFlAssets.exists(leVocals)) { //Vanilla voices
				audioBuffers[2] = AudioBuffer.fromFile('./${leVocals.substr(6)}');
			}
		#if MODS_ALLOWED
		}
		#end
	}
	*/

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	function reloadGridLayer() {
		gridLayer.clear();
		overWaveform.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (totalKeys + 1), Std.int(GRID_SIZE * _song.notes[curSec].lengthInSteps * zoomList[curZoom]));

		#if desktop
		if(FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformVoicesDad) {
			updateWaveform();
		}
		#end

		var leHeight:Int = Std.int(gridBG.height);
		var foundNextSec:Bool = false;
		if(sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (totalKeys + 1), Std.int(GRID_SIZE * _song.notes[curSec + 1].lengthInSteps * zoomList[curZoom]));
			leHeight = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;

		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if(foundNextSec)
		{
			var gridBlack:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(Std.int(GRID_SIZE * (totalKeys + 1)), Std.int(nextGridBG.height), FlxColor.BLACK);
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);
		}

		var gridBlackLine = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * rightKeys)).makeGraphic(2, leHeight, FlxColor.BLACK);
		overWaveform.add(gridBlackLine);

		if (vortex) {
			for (i in 1...Conductor.timeSignature[0]) {
				var beatsep1:FlxSprite = new FlxSprite(gridBG.x,(GRID_SIZE * (4 * zoomList[curZoom])) * i).makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
				overWaveform.add(beatsep1);
			}
		}

		var gridBlackLine = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, leHeight, FlxColor.BLACK);
		overWaveform.add(gridBlackLine);
		updateGrid();

		lastSecBeats = _song.notes[curSec].lengthInSteps;
		if(sectionStartTime(1) > FlxG.sound.music.length) lastSecBeatsNext = 0;

		if (strumLineNotes != null) {
			makeStrumNotes();
		}

		rightIcon.setPosition(GRID_SIZE * leftKeys, -100);
		if (strumLine != null) {
			strumLine.makeGraphic(GRID_SIZE * (totalKeys + 1), 4);
		}
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum(Conductor.songPosition - sectionStartTime());
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() {
		#if desktop
		if (waveformPrinted) {
			waveformSprite.makeGraphic(GRID_SIZE * totalKeys, Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformVoicesDad) {
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = _song.notes[curSec].lengthInSteps;
		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		if (FlxG.save.data.chart_waveformInst) {
			var sound:FlxSound = FlxG.sound.music;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		if (FlxG.save.data.chart_waveformVoices) {
			var sound:FlxSound = vocals;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		if (FlxG.save.data.chart_waveformVoicesDad) {
			var sound:FlxSound = vocalsDad;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * totalKeys);
		var hSize:Int = Std.int(gSize / 2);

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var size:Float = 1;

		var leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);

		var rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		var index:Int;
		for (i in 0...length) {
			index = i;

			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	#if desktop
	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) {
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else {
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}
		
		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}
	#end

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps(?time:Float):Int {
		if (time == null) time = FlxG.sound.music.time;
		var lastChange = Conductor.getBPMFromSeconds(time);

		var shit = (time - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void {
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		resyncVocals();
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void {
		if (_song.notes[sec] != null)
		{
			if (_song.notes[sec + 1] == null) {
				addSection(Conductor.timeSignature[0] * 4);
			}
			var lastLeftKeys = leftKeys;
			var lastRightKeys = rightKeys;
			var lastLengthInSteps = _song.notes[curSec].lengthInSteps;
			curSec = sec;

			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				resyncVocals();
				updateCurStep();
			}

			updateKeys();
			if (leftKeys != lastLeftKeys || rightKeys != lastRightKeys || _song.notes[curSec].lengthInSteps != lastLengthInSteps) {
				reloadGridLayer();
			} else {
				updateGrid();
			}
			updateSectionUI();
		}
		else
		{
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		updateWaveform();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;
		check_changeSignature.checked = sec.changeSignature;
		stepperSectionNumerator.value = sec.timeSignature[0];
		stepperSectionDenominator.value = sec.timeSignature[1];
		#if MULTI_KEY_ALLOWED
		check_changeKeys.checked = sec.changeKeys;
		stepperSectionPlayerKeys.value = sec.playerKeys;
		stepperSectionOpponentKeys.value = sec.opponentKeys;
		#end

		updateHeads();
	}

	function updateHeads():Void {
		var healthIconP1:String = loadHealthIconFromCharacter(_song.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(_song.player2);

		if (_song.notes[curSec].mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon('gf');
		}
	}

	function loadHealthIconFromCharacter(char:String) {
		var json:Dynamic = Character.getFile(char);
		return json.healthicon;
	}

	function updateNoteUI():Void {
		if (curSelectedNote != null) {
			if (curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if (curSelectedNote[3] != null) {
					currentType = noteTypeMap.get(curSelectedNote[3]);
					if (currentType <= 0) {
						noteTypeDropDown.selectedLabel = '';
					} else {
						noteTypeDropDown.selectedLabel = '$currentType. ${curSelectedNote[3]}';
					}
				}
				if (curSelectedNote[4] != null) {
					var chars:Array<Int> = curSelectedNote[4];
					if (chars == null) chars = [];
					charactersInputText.text = chars.join(',');
					currentChars = curSelectedNote[4];
				} else {
					currentChars = [0];
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if (selected > 0 && selected < eventStuff.length) {
					descText.text = eventStuff[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '${curSelectedNote[0]}';
		}
	}

	function updateGrid():Void {
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		curRenderedNoteType.clear();
		nextRenderedNotes.clear();
		nextRenderedSustains.clear();

		Conductor.getLastBPM(_song, recalculateSteps(sectionStartTime()));

		// CURRENT SECTION
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if (note.y < -150) note.y = -150;

			if (i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var typeInt = noteTypeMap.get(i[3]);
				var theType = '$typeInt';
				if (typeInt == null) theType = '?';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);
				
				if (note.y < -150) note.y = -150;

				var text:String = 'Event: ${note.eventName} (${Math.floor(note.strumTime)} ms)\nValue 1: ${note.eventVal1}\nValue 2: ${note.eventVal2}';
				if (note.eventLength > 1) text = '${note.eventLength} Events:\n${note.eventName}';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if (note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
		}

		// NEXT SECTION
		if (curSec < _song.notes.length - 1) {
			for (i in _song.notes[curSec + 1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note, true));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var sectionUsed = curSec;
		if (isNextSection) {
			sectionUsed += 1;
		}

		var usedLeftKeys = leftKeys;
		var usedRightKeys = rightKeys;
		if (isNextSection) {
			#if MULTI_KEY_ALLOWED
			if (_song.notes[sectionUsed].changeKeys) {
				usedLeftKeys = (_song.notes[sectionUsed].mustHitSection ? _song.notes[sectionUsed].playerKeys : _song.notes[sectionUsed].opponentKeys);
				usedRightKeys = (!_song.notes[sectionUsed].mustHitSection ? _song.notes[sectionUsed].playerKeys : _song.notes[sectionUsed].opponentKeys);
			} else {
			#end
				usedLeftKeys = (_song.notes[sectionUsed].mustHitSection == _song.notes[curSec].mustHitSection ? leftKeys : rightKeys);
				usedRightKeys = (_song.notes[sectionUsed].mustHitSection == _song.notes[curSec].mustHitSection ? rightKeys : leftKeys);
			#if MULTI_KEY_ALLOWED
			}
			#end
		}

		var daNoteInfo = i[1];
		var trueData = daNoteInfo;
		if (i[1] >= usedLeftKeys) trueData -= usedLeftKeys;
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2]; // huh???? what he say???
		
		var keys = usedLeftKeys;
		if (i[1] >= usedLeftKeys) keys = usedRightKeys;

		var gottaHit = _song.notes[sectionUsed].mustHitSection;
		if (daNoteInfo >= usedLeftKeys) gottaHit = !gottaHit;
		var modifier = SkinData.getSkinModifier(!gottaHit);

		var note:Note = new Note(daStrumTime, trueData, null, null, true, keys, null, modifier);
		if (daSus != null) { //Common note
			if (!Std.isOfType(i[3], String)) //Convert old note type to new note type format
			{
				i[3] = noteTypeIntMap.get(i[3]);
			}
			note.sustainLength = daSus;
			note.mustPress = gottaHit;
			note.isOpponent = !note.mustPress;
			note.noteType = i[3];
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if (i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if (isNextSection && _song.notes[curSec].mustHitSection != _song.notes[sectionUsed].mustHitSection) {
			if (daNoteInfo >= usedLeftKeys) {
				note.x -= GRID_SIZE * usedLeftKeys;
			} else if (daSus != null) {
				note.x += GRID_SIZE * leftKeys;
			}
		}

		var usedStepCrochet = Conductor.stepCrochet;
		if (isNextSection && (_song.notes[sectionUsed].changeBPM || _song.notes[sectionUsed].changeSignature)) {
			var daBPM = Conductor.bpm;
			var daDenominator = Conductor.timeSignature[1];
			if (_song.notes[sectionUsed].changeBPM)
				daBPM = _song.notes[sectionUsed].bpm;
			if (_song.notes[sectionUsed].changeSignature)
				daDenominator = _song.notes[sectionUsed].timeSignature[1];
			usedStepCrochet = (((60 / daBPM) * 4000) / daDenominator) / 4;
		}

		note.y = getYFromStrumNotes(daStrumTime - sectionStartTime(isNextSection ? 1 : 0), isNextSection);
		if(note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String {
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if (addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note, nextSection:Bool = false):FlxSprite {
		var height:Int = FlxMath.minInt(Std.int(gridBG.height + nextGridBG.height), Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * _song.notes[nextSection ? curSec + 1 : curSec].lengthInSteps, 0, (nextSection ? nextGridBG.height : gridBG.height)) + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE / 2));
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if (height < minHeight) height = minHeight;
		if (height < 1) height = 1; //Prevents error of invalid height

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		return spr;
	}

	function getYFromStrumNotes(strumTime:Float, isNextSection:Bool = false) {
		return (GRID_SIZE * (isNextSection ? _song.notes[curSec].lengthInSteps : 0)) * zoomList[curZoom] + Math.floor(getYfromStrum(strumTime, isNextSection));
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			timeSignature: _song.timeSignature.copy(),
			changeSignature: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			altAnim: false,
			#if MULTI_KEY_ALLOWED
			changeKeys: false,
			playerKeys: _song.playerKeyAmount,
			opponentKeys: _song.opponentKeyAmount
			#end
		};

		_song.notes.push(sec);
		updateSectionLengths();
	}

	function selectNote(note:Note, setType:Bool = false):Void {
		var noteDataToCheck:Int = note.noteData;

		if (noteDataToCheck > -1)
		{
			if (note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += leftKeys;
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if (i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					changeEventSelected();
					break;
				}
			}
		}
		
		stepperSusLength.stepSize = Conductor.stepCrochet / 2;

		if (setType && curSelectedNote != null) {
			curSelectedNote[3] = noteTypeIntMap.get(currentType);
			curSelectedNote[4] = currentChars;
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void {
		var noteDataToCheck:Int = note.noteData;
		if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += leftKeys;

		if (note.noteData > -1) //Normal Notes
		{
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if (i == curSelectedNote) curSelectedNote = null;
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else //Events
		{
			for (i in _song.events)
			{
				if (i[0] == note.strumTime)
				{
					if (i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style, chars) {
		var delnote = false;
		var checkData = d;
		if (d >= leftKeys) checkData -= leftKeys;
		if (strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y + 1)) && note.noteData == checkData)
				{
					if (!delnote) deleteNote(note);
					delnote = true;
				}
			});
		}
		
		if (!delnote) {
			addNote(cs, d, style, chars);
		}
	}

	function clearSong():Void {
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(?strum:Float = null, ?data:Int = null, ?type:Int = null, ?chars:Array<Int> = null):Void
	{
		var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
		var noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus = 0;
		var daType = currentType;
		var daChars = currentChars;

		if (strum != null) noteStrum = strum;
		if (data != null) noteData = data;
		if (type != null) daType = type;
		if (chars != null) daChars = chars;
		
		if (noteData > -1) {
			_song.notes[curSec].sectionNotes.push([noteStrum, noteData, noteSus, noteTypeIntMap.get(daType), daChars]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		} else {
			var event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
			changeEventSelected();
		}

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			var data = noteData + leftKeys;
			if (noteData >= leftKeys) data = noteData - leftKeys;
			_song.notes[curSec].sectionNotes.push([noteStrum, data % totalKeys, noteSus, noteTypeIntMap.get(daType), daChars]);
		}

		stepperSusLength.stepSize = Conductor.stepCrochet / 2;

		updateGrid();
		updateNoteUI();
	}
	// will figure this out l8r
	function redo() {
		//_song = redos[curRedoIndex];
	}
	function undo() {
		//redos.push(_song);
		undos.pop();
		//_song.notes = undos[undos.length - 1];
		///trace(_song.notes);
		//updateGrid();
	}
	function getStrumTime(yPos:Float):Float
	{
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height, 0, _song.notes[curSec].lengthInSteps * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, nextSection:Bool = false):Float
	{
		return FlxMath.remapToRange(strumTime, 0, _song.notes[nextSection ? curSec + 1 : curSec].lengthInSteps * Conductor.stepCrochet, gridBG.y, gridBG.y + (nextSection ? nextGridBG.height : gridBG.height));
	}

	function makeStrumNotes():Void {
		for (i in 0...strumLineNotes.length) {
			strumLineNotes.members[i].destroy();
		}
		strumLineNotes.clear();
		for (i in 0...totalKeys) {
			var note:StrumNote;
			if (i >= leftKeys) {
				note = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i - leftKeys, 0, rightKeys);
			} else {
				note = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i, 0, leftKeys);
			}
			note.snapToPixelGrid = false;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
	}

	function updateSectionLengths():Void {
		var daNumerator:Int = _song.timeSignature[0];
		for (i in 0..._song.notes.length)
		{
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeSignature)
				{
					daNumerator = _song.notes[i].timeSignature[0];
				}
				_song.notes[i].lengthInSteps = daNumerator * 4;
			}
		}
	}

	function updateKeys():Void {
		#if MULTI_KEY_ALLOWED
		var curPlayer = _song.playerKeyAmount;
		var curOpponent = _song.opponentKeyAmount;
		for (i in 0...curSec + 1) {
			if (_song.notes[i] != null && _song.notes[i].changeKeys) {
				curPlayer = _song.notes[i].playerKeys;
				curOpponent = _song.notes[i].opponentKeys;
			}
		}
		leftKeys = (_song.notes[curSec].mustHitSection ? curPlayer : curOpponent);
		rightKeys = (!_song.notes[curSec].mustHitSection ? curPlayer : curOpponent);
		totalKeys = leftKeys + rightKeys;
		#end
	}

	function resyncVocals(?play:Bool = false):Void {
		if (play) vocals.play();
		vocals.pause();
		vocals.time = FlxG.sound.music.time;
		if (play) vocals.play();

		if (play) vocalsDad.play();
		vocalsDad.pause();
		vocalsDad.time = FlxG.sound.music.time;
		if (play) vocalsDad.play();
	}

	function loadJson(song:String):Void
	{
		//shitty null fix, i fucking hate it when this happens
		CoolUtil.getDifficulties(currentSongName);
		if(CoolUtil.difficulties[PlayState.storyDifficulty] == null){
			PlayState.SONG = Song.loadFromJson(Paths.formatToSongPath(song), Paths.formatToSongPath(song));
		}else{
			PlayState.SONG = Song.loadFromJson(Paths.formatToSongPath(song) + CoolUtil.getDifficultyFilePath(PlayState.storyDifficulty), Paths.formatToSongPath(song));
		}
		LoadingState.loadAndSwitchState(new ChartingState(fromMasterMenu));
	}

	function autosaveSong():Void {
		autosaveSave.data.autosave = Json.stringify({"song": _song});
		autosaveSave.flush();
		autosaveTimer.reset(60);
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveLevel() {
		_song.events.sort(sortByTime);
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), '${Paths.formatToSongPath(_song.song) + CoolUtil.getDifficultyFilePath()}.json');
		}
	}
	
	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int {
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents() {
		_song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}