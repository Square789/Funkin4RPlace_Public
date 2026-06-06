
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import RoundedCornerShader.BetterRoundedCornerShader;
import RoundedCornerShader.ManualTexSizeInvertedRoundedCornerShader;
import editors.ChartingState;

using CoolUtil.InflatedPixelSpriteExt;
using StringTools;

private final HIGHLIGHT_STRIP_PIXEL_SIZE:Float = 4.0;
private final HIGHLIGHT_STRIP_PIXEL_HEIGHT:Int = 3;

private final SELECTION_ARROW_SPACING:Int = 8;

private final DECO_LINE_WIDTH:Float = 112.0;
private final DECO_LINE_HEIGHT:Float = 2.0;
private final DECO_LINE_OFFSET:Float = 12.0;


class LabelCarousel extends FlxTypedSpriteGroup<FlxSprite> {
	private var options:Array<String>;
	private var currentIndex:Int;

	function new(options:Array<String>) {
		super();

		this.options = options.copy();
		this.currentIndex = 0;
	}
}



class FreeplaySongData extends SongData {
	// global bs
	var weekIndex:Int;
	var folder:String;

	// nicer way to access the mix arrays
	public var mixId(default, set):Int = 0;
	public var songName(get, null):String;
	public var meta(get, null):MetaFile;
	public var defaultMeta(get, null):MetaFile;
	public var difficulties(get, null):Array<String>;

	public var avaliableMixSongNames:Array<String> = [];
	public var availableMixMetas:Array<MetaFile> = [];
	public var availableMixDifficulties:Array<Array<String>> = [];

	public function new(songData:Array<Dynamic>, weekIndex:Int, ?folder:Null<String>) {
		super(songData);

		this.weekIndex = weekIndex;

		var defaultMeta:MetaFile = Song.getMetaFile(this.name) ?? {};

		defaultMeta.displayName = defaultMeta.displayName ?? this.name;
		defaultMeta.iconHiddenUntilPlayed = defaultMeta.iconHiddenUntilPlayed ?? false;

		for (i => mix in availableMixes) {
			if (mix == SongData.DEFAULT_MIX) {
				this.avaliableMixSongNames[i] = this.name;
				this.availableMixMetas[i] = defaultMeta;
				this.availableMixDifficulties[i] = CoolUtil.getDifficultiesRet(this.name, true, defaultMeta);
			} else {
				var mixSongName = '$name $mix';
				var mixMeta = Song.getMetaFile(mixSongName);

				mixMeta.displayName = mixMeta.displayName ?? '${defaultMeta.displayName} $mix';
				mixMeta.iconHiddenUntilPlayed = mixMeta.iconHiddenUntilPlayed ?? defaultMeta.iconHiddenUntilPlayed;
				mixMeta.composers = mixMeta.composers ?? defaultMeta.composers;

				this.avaliableMixSongNames[i] = mixSongName;
				this.availableMixMetas[i] = mixMeta;
				this.availableMixDifficulties[i] = CoolUtil.getDifficultiesRet(mixSongName, true, mixMeta);
			};
		}

		this.folder = folder ?? "";
	}

	public function setStaticBullcrap(setDiffs:Bool = true) {
		Paths.currentModDirectory = folder;
		PlayState.storyWeek = weekIndex;
		if (setDiffs) CoolUtil.difficulties = difficulties.copy();
	}

	public function set_mixId(newId):Int {
		return mixId = CoolUtil.wrapModulo(newId, availableMixes.length);
	}

	public function get_songName():String return avaliableMixSongNames[mixId];
	public function get_meta():MetaFile return availableMixMetas[mixId];
	public function get_defaultMeta():MetaFile return availableMixMetas[availableMixes.indexOf(SongData.DEFAULT_MIX)];
	public function get_difficulties():Array<String> return availableMixDifficulties[mixId];
}

private enum MenuSection {
	SONG;
	MIX;
	DIFFICULTY;
	// CANVAS;
}


private function centerAroundX(object:FlxObject, x:Float) {
	object.x = x - (object.width * 0.5);
}

private function createFooterInfoObjects(
	keyText:String,
	otherText:String,
	x:Float,
	y:Float,
	?maxWidth:Float = 0.0
):Array<FlxSprite> {
	var rText = new FlxText(0, 0, 0, keyText);
	rText.setFormat("IBM Plex Sans", 16, RedditColor.FADED);
	var rBg = new FlxSprite(x, y).makeInflatedPixelGraphic(RedditColor.TEXT_WEAK, rText.width + 4, rText.height + 4);
	rBg.shader = new BetterRoundedCornerShader(6.0, rText.width + 4, rText.height + 4);
	rText.setPosition(rBg.x + 2, rBg.y + 2);

	var otherText = new FlxText(rText.x + rText.width + 2, rText.y, otherText);
	otherText.setFormat("IBM Plex Sans", 16, RedditColor.TEXT);

	return [rBg, rText, otherText];
}

class FreeplayPlaceState extends MusicBeatState {
	static private var selectedSongIdx:Int = 0;
	static private var selectedDifficultyIdx:Int = FlxMath.maxInt(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty));
	static private var selectedMixIdx:Int = 0;
	private var activeElementIdx:Int = 0;
	private var displayedSongs:Array<FreeplaySongData>;
	private var canvasCamera:FlxCamera;
	private var uiCamera:FlxCamera;
	private var cameraTarget:FlxObject;

	private var mixNameText:FlxText;
	private var mixLeftArrow:FlxSprite;
	private var mixRightArrow:FlxSprite;
	private var songNameText:FlxText;
	private var songLeftArrow:FlxSprite;
	private var songRightArrow:FlxSprite;
	private var scoreText:FlxText;
	private var difficultyText:FlxText;
	private var difficultyLeftArrow:FlxSprite;
	private var difficultyRightArrow:FlxSprite;

	private var optionBarCenterX:Float;

	private final ELEMENT_ORDER:Array<MenuSection> = [SONG, MIX, DIFFICULTY];

	public override function create() {
		displayedSongs = [];

		// @Square789: Copypasted from old playstate
		// God knows what this does, but it does cause an error in the rendering system if super.create()
		// is called beforehand. Very nice.
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		AtlasFrameMaker.clearCache();

		// persistentUpdate = true; // freeze on open substate, this is used in the wrongest way originally
		PlayState.isStoryMode = false; // Worst control flow of all time
		WeekData.reloadWeekFiles(false);
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy(); // wtf why

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (weekIdx => weekId in WeekData.weeksList) {
			var week:WeekData = WeekData.weeksLoaded[weekId];
			WeekData.setDirectoryFromWeek(week);
			if ((
				!week.startUnlocked &&
				week.weekBefore.length > 0 &&
				!Highscore.completedWeek(week.weekBefore))
			) { // Week is locked
				continue;
			}

			for (song in week.songs) {
				displayedSongs.push(new FreeplaySongData(song, weekIdx));
			}
		}
		// ??? Probably useless, keeping it in regardless
		WeekData.loadTheFirstEnabledMod();

		// Some layout vars
		final PANEL_PADDING = 16;
		final OFFSCREEN_SHIFT = 12;
		final PANEL_LEFT_OFFSET = -2;
		var optBarAndCanvasHoleHeight = Std.int(FlxG.height * 0.85) + OFFSCREEN_SHIFT;
		var canvasHoleX = Std.int(FlxG.width * 0.3) + PANEL_LEFT_OFFSET;
		var canvasHoleWidth = FlxG.width - canvasHoleX;

		// Camera setup
		uiCamera = new FlxCamera();
		canvasCamera = new FlxCamera(canvasHoleX, -OFFSCREEN_SHIFT, canvasHoleWidth, optBarAndCanvasHoleHeight);
		canvasCamera.bgColor = 0xff333333;
		uiCamera.bgColor.alpha = 0x00;

		FlxG.cameras.reset(canvasCamera);
		FlxG.cameras.add(uiCamera, false);
		// This is the worst. Needed, otherwise the transition will appear on the canvasCamera
		// and appear behind UI elements.
		CustomFadeTransition.nextCamera = uiCamera;
		cameraTarget = new FlxObject(0, 0, 1, 1);
		canvasCamera.follow(cameraTarget);

		// Populate canvas cam
		var orrSloshPlace = new FlxSprite(0, 0, Paths.image("place_edit"));
		orrSloshPlace.antialiasing = false;

		var edge = new FlxSprite(0, 0, Paths.image("snoo_edge"));
		edge.setGraphicSize(Std.int(edge.width / 60));
		edge.updateHitbox();
		edge.x = orrSloshPlace.x - (edge.width * 0.33);
		edge.y = orrSloshPlace.x - (edge.height * 0.67);
		edge.angle = 3.21;

		var c = [canvasCamera];
		for (canvasItem in [edge, orrSloshPlace]) {
			canvasItem.cameras = c;
			add(canvasItem);
		}

		// Populate UI cam

		// More layout vars
		var bottomBgPartY = optBarAndCanvasHoleHeight - OFFSCREEN_SHIFT;
		var optBarWidth = canvasHoleX - PANEL_PADDING * 2 - PANEL_LEFT_OFFSET;
		var footerY = (optBarAndCanvasHoleHeight - OFFSCREEN_SHIFT) + PANEL_PADDING;
		var footerWidth = optBarWidth;
		var footerHeight = FlxG.height - footerY + OFFSCREEN_SHIFT;
		optionBarCenterX = PANEL_PADDING + PANEL_LEFT_OFFSET + optBarWidth * 0.5;

		var topBg = new FlxSprite(0.0, 0.0).makeInflatedPixelGraphic(RedditColor.MIDNIGHT, canvasHoleX, optBarAndCanvasHoleHeight);
		var bottomBg = new FlxSprite(0.0, bottomBgPartY).makeInflatedPixelGraphic(RedditColor.MIDNIGHT, FlxG.width, FlxG.height - bottomBgPartY);
		var canvasHole = new FlxSprite(canvasHoleX, -OFFSCREEN_SHIFT).makeInflatedPixelGraphic(RedditColor.MIDNIGHT, canvasHoleWidth + OFFSCREEN_SHIFT, optBarAndCanvasHoleHeight);
		var optionBar = new FlxSprite(PANEL_PADDING + PANEL_LEFT_OFFSET, -OFFSCREEN_SHIFT).makeInflatedPixelGraphic(RedditColor.BACKGROUND, optBarWidth, optBarAndCanvasHoleHeight);
		var footer = new FlxSprite(PANEL_PADDING + PANEL_LEFT_OFFSET, footerY).makeInflatedPixelGraphic(RedditColor.BACKGROUND, footerWidth, footerHeight);

		canvasHole.shader = new ManualTexSizeInvertedRoundedCornerShader(8.0, canvasHole.width, canvasHole.height, 2.0, RedditColor.SIDEBAR_BORDER);
		optionBar.shader = new BetterRoundedCornerShader(8.0, optionBar.width, optionBar.height, 1.5, RedditColor.SIDEBAR_BORDER);
		footer.shader = new BetterRoundedCornerShader(8.0, footer.width, footer.height, 1.5, RedditColor.SIDEBAR_BORDER);

		songNameText = new FlxText(0, 220, 0);
		songNameText.setFormat("IBM Plex Sans Bold", 36, RedditColor.TEXT);

		mixNameText = new FlxText(0, 274, 0);
		mixNameText.setFormat("IBM Plex Sans Bold", 24, RedditColor.TEXT);

		difficultyText = new FlxText(0, 342, 0);
		difficultyText.setFormat("IBM Plex Sans Bold", 32, RedditColor.TEXT);

		scoreText = new FlxText(0, 420, 0);
		scoreText.setFormat("IBM Plex Sans", 24, RedditColor.TEXT);

		mixLeftArrow = new FlxSprite();
		mixRightArrow = new FlxSprite();
		songLeftArrow = new FlxSprite();
		songRightArrow = new FlxSprite();
		difficultyLeftArrow = new FlxSprite();
		difficultyRightArrow = new FlxSprite();
		var arrowFrames = Paths.getSparrowAtlas("menu_arrows");
		for (i in [
			{o: mixLeftArrow,         name: "smallpointy_left",  size: 0.5},
			{o: mixRightArrow,        name: "smallpointy_right", size: 0.5},
			{o: songLeftArrow,        name: "smallpointy_left",  size: 0.5},
			{o: songRightArrow,       name: "smallpointy_right", size: 0.5},
			{o: difficultyLeftArrow,  name: "smallpointy_left",  size: 0.5},
			{o: difficultyRightArrow, name: "smallpointy_right", size: 0.5},
		]) {
			i.o.frames = arrowFrames;
			i.o.frame = arrowFrames.getByName(i.name);
			i.o.pixelPerfectRender = true;
			i.o.setGraphicSize(Std.int(i.o.width * i.size));
			i.o.updateHitbox();
		}

		var fto0 = createFooterInfoObjects(
			"CTRL",
			"to open the Gameplay Changers Menu",
			30,
			FlxG.height - 80
		);
		var fto1 = createFooterInfoObjects(
			controls.getFormattedInputNames(RESET),
			"to reset your Score and Accuracy",
			30,
			FlxG.height - 42
		);

		var songNameTextTopDecoLine = new FlxSprite(0.0, songNameText.y - DECO_LINE_OFFSET - 2)
			.makeInflatedPixelGraphic(RedditColor.SIDEBAR_BORDER, optBarWidth - 42, DECO_LINE_HEIGHT);
		centerAroundX(songNameTextTopDecoLine, optionBarCenterX);

		var difficultyTextTopDecoLine = new FlxSprite(0.0, difficultyText.y - DECO_LINE_OFFSET - 2)
			.makeInflatedPixelGraphic(RedditColor.SIDEBAR_BORDER, optBarWidth - 42, DECO_LINE_HEIGHT);
		centerAroundX(difficultyTextTopDecoLine, optionBarCenterX);

		var difficultyTextBottomDecoLine = new FlxSprite(0.0, difficultyText.y + difficultyText.height + DECO_LINE_OFFSET)
			.makeInflatedPixelGraphic(RedditColor.SIDEBAR_BORDER, optBarWidth - 42, DECO_LINE_HEIGHT);
		centerAroundX(difficultyTextBottomDecoLine, optionBarCenterX);

		c = [uiCamera];
		for (uiItem in [
			topBg, bottomBg, canvasHole,
			optionBar, mixNameText, songNameText, scoreText, difficultyText,
			songLeftArrow, songRightArrow, difficultyLeftArrow, difficultyRightArrow,
			mixLeftArrow, mixRightArrow,
			songNameTextTopDecoLine, difficultyTextTopDecoLine, difficultyTextBottomDecoLine,
			footer
		].concat(fto0).concat(fto1)) {
			uiItem.cameras = c;
			add(uiItem);
		}

		super.create();
		readdOrSetAchievementNotificationBoxCamera(uiCamera);

		changeActiveElement(0);
		changeSelectedSong(0);
	}

	override function destroy() {
		FlxG.cameras.bgColor = 0xff000000;
		super.destroy();
	}

	public override function update(dt:Float) {
		super.update(dt);

		// Snap camera if it's close enough
		var diffX = 0.0;
		var diffY = 0.0;
		@:privateAccess {
			diffX = Math.abs(canvasCamera._scrollTarget.x - canvasCamera.scroll.x);
			diffY = Math.abs(canvasCamera._scrollTarget.y - canvasCamera.scroll.y);
		}
		// Snapping 2 canvas pixels on zoom 1 does not matter.
		// Snapping 2 canvas pixels on zoom 8 very much does, so prevent that by multiplying with zoom.
		diffX *= canvasCamera.zoom;
		diffY *= canvasCamera.zoom;
		if (diffX < 1.5 && diffY < 1.5) {
			canvasCamera.snapToTarget();
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			CustomFadeTransition.nextCamera = uiCamera;
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		if (FlxG.keys.justPressed.CONTROL) {
			openSubState(new GameplayChangersSubState(uiCamera));
			return;
		}

		if (controls.RESET) {
			var selectedSong = displayedSongs[selectedSongIdx];
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			// [[See the `Highscore.formatSong` rant below]]
			selectedSong.setStaticBullcrap();
			openSubState(new ResetScoreSubState(selectedSong.songName, selectedDifficultyIdx, selectedSong.presentedOpponent, '', selectedSong.meta.displayName, uiCamera));
			return;
		}

		if (controls.ACCEPT) {
			var selectedSong = displayedSongs[selectedSongIdx];
			if (selectedSong.difficulties.length > 0) {
				// Highscore(why the fuck does Highscore deliver the json filename anyways (at least that is
				// what i think this method does)).formatSong relies on the CONTENTS of
				// CoolUtil.difficulties, which it accesses via an index instead of - oh idk maybe just
				// the difficulty as the string? Fuck this so much, dude
				selectedSong.setStaticBullcrap();
				var name = selectedSong.songName;
				var poop:String = Highscore.formatSong(name, selectedDifficultyIdx, false);

				// Set some more global static magic garbage
				PlayState.SONG = Song.loadFromJson(poop, name);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = selectedDifficultyIdx;
				PlayState.SONG.meta = selectedSong.meta;
				PlayState.SONG.freeplaySongData = selectedSong;

				CustomFadeTransition.nextCamera = uiCamera;

				trace('CURRENT WEEK: ${WeekData.getWeekName()}');

				#if CHART_EDITOR_ALLOWED
				if (FlxG.keys.pressed.SHIFT) {
					PlayState.chartingMode = true;
					LoadingState.loadAndSwitchState(new ChartingState(false));
				} else {
				#end
				LoadingState.loadAndSwitchState(new PlayState());
				#if CHART_EDITOR_ALLOWED
				}
				#end

				FlxG.sound.music.volume = 0;

				#if PRELOAD_ALL
				destroyFreeplayVocals();
				#end
			}
			return;
		}

		if (controls.UI_UP_P != controls.UI_DOWN_P) {
			var change = controls.UI_DOWN_P ? 1 : -1;
			changeActiveElement(change);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}

		if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
			var change = controls.UI_RIGHT_P ? 1 : -1;
			switch (ELEMENT_ORDER[activeElementIdx]) {
			case SONG:
				changeSelectedSong(change);
			case DIFFICULTY:
				changeSelectedDifficulty(change);
			case MIX:
				changeSelectedMix(change);
			}
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
	}

	function getTextForActiveElement():FlxText {
		return switch (ELEMENT_ORDER[activeElementIdx]) {
			case SONG:       songNameText;
			case DIFFICULTY: difficultyText;
			case MIX:        mixNameText;
		}
	}

	public function changeActiveElement(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];

		getTextForActiveElement().color = RedditColor.TEXT;

		activeElementIdx = CoolUtil.wrapModulo(activeElementIdx + by, ELEMENT_ORDER.length);
		if (by != 0) {
			var selectionOk = false;
			while (true) {
				selectionOk = switch (ELEMENT_ORDER[activeElementIdx]) {
					case SONG:       true;
					case DIFFICULTY: currentSong.difficulties.length > 0;
					case MIX:        currentSong.availableMixes.length > 1;
				};
				if (selectionOk) {
					break;
				}
				activeElementIdx = CoolUtil.wrapModulo(activeElementIdx + FlxMath.signOf(by), ELEMENT_ORDER.length);
			}
		}

		getTextForActiveElement().color = RedditColor.CHUNGERINE;
	}

	public function changeSelectedSong(by:Int) {
		selectedSongIdx = CoolUtil.wrapModulo(selectedSongIdx + by, displayedSongs.length);

		var newSong = displayedSongs[selectedSongIdx];

		songNameText.text = newSong.defaultMeta.displayName;
		centerAroundX(songNameText, optionBarCenterX);
		repositionSongArrows();

		newSong.mixId = selectedMixIdx;
		retainOldDifficulty(by, 0);

		final FOCUS_OFFSET_X = -30.0;
		final FOCUS_OFFSET_Y = -20.0;

		// Sic camera onto new location
		var eases = [FlxEase.quintOut, FlxEase.quintIn];
		if (canvasCamera.zoom > newSong.placeZoom) eases = [FlxEase.quintInOut, FlxEase.quintOut];
		var duration = Math.max(1, FlxMath.vectorLength(cameraTarget.x - newSong.placePos.x, cameraTarget.y - newSong.placePos.y) / 500);
		FlxTween.cancelTweensOf(cameraTarget);
		FlxTween.cancelTweensOf(canvasCamera);
		var z = newSong.placeZoom;
		FlxTween.tween(
			cameraTarget,
			{x: newSong.placePos.x + (1/z) * FOCUS_OFFSET_X, y: newSong.placePos.y + (1/z) * FOCUS_OFFSET_Y},
			duration,
			{ease: eases[0]}
		);
		FlxTween.tween(canvasCamera, {zoom: z}, duration, {ease: eases[1]});

		// TODO: Maybe recolor something else to the song's color

		availableMixesChanged();
		changeSelectedMix(0);
	}

	private function availableDifficultiesChanged() {
		var diffs = displayedSongs[selectedSongIdx].difficulties;
		if (diffs.length == 0) {
			difficultyText.color = RedditColor.TEXT_WEAK;
			difficultyLeftArrow.visible = false;
			difficultyRightArrow.visible = false;

		} else {
			difficultyText.color = RedditColor.TEXT;
			difficultyLeftArrow.visible = true;
			difficultyRightArrow.visible = true;
		}
	}

	public function changeSelectedDifficulty(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];
		var diffs = currentSong.difficulties;
		if (diffs.length > 0) {
			selectedDifficultyIdx = CoolUtil.wrapModulo(selectedDifficultyIdx + by, diffs.length);
			difficultyText.text = diffs[selectedDifficultyIdx];
		} else {
			difficultyText.text = "???";
		}

		repositionDifficultySection();

		#if HIGHSCORE_ALLOWED
		CoolUtil.difficulties = diffs.copy(); // fuck this
		var name = currentSong.songName;
		var score = Highscore.getScore(name, selectedDifficultyIdx);
		var ratingStr = Std.string(Std.int(Math.fround(
			Highscore.getRating(name, selectedDifficultyIdx) * 10000
		)));
		if (ratingStr.length <= 2) {
			ratingStr = "0." + ratingStr.rpad('0', 2);
		} else {
			ratingStr = ratingStr.substr(0, ratingStr.length - 2) + '.' + ratingStr.substr(ratingStr.length - 2, 2);
		}
		scoreText.text = '$score ($ratingStr%)';
		centerAroundX(scoreText, optionBarCenterX);
		#end
	}

	private function availableMixesChanged() {
		if (displayedSongs[selectedSongIdx].availableMixes.length > 1) {
			mixNameText.color = RedditColor.TEXT;
			mixLeftArrow.visible = true;
			mixRightArrow.visible = true;
		} else {
			mixNameText.color = RedditColor.TEXT_WEAK;
			mixLeftArrow.visible = false;
			mixRightArrow.visible = false;
		}
	}

	public function changeSelectedMix(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];
		var mixes = currentSong.availableMixes;

		selectedMixIdx = currentSong.mixId += by;

		var newMix:String = mixes[selectedMixIdx];
		var mixDisplayName:String = newMix;

		mixNameText.text = mixDisplayName;
		centerAroundX(mixNameText, optionBarCenterX);
		if (mixes.length > 1) {
			repositionMixArrows();
		}

		availableDifficultiesChanged();
		retainOldDifficulty(0, by);
		changeSelectedDifficulty(0);
	}

	private function retainOldDifficulty(songBy:Int, mixBy:Int) {
		var oldSongIdx = CoolUtil.wrapModulo(selectedSongIdx - songBy, displayedSongs.length);
		var oldSong = displayedSongs[oldSongIdx];
		var oldSongMixIdx = CoolUtil.wrapModulo(oldSong.mixId - mixBy, oldSong.availableMixDifficulties.length);
		var oldDifficulty = oldSong.availableMixDifficulties[oldSongMixIdx][selectedDifficultyIdx];

		var currentSong = displayedSongs[selectedSongIdx];

		// It is possible that the new song has different difficulties from
		// the other one. Rectify here.
		var x = currentSong.difficulties.indexOf(oldDifficulty);
		// The old freeplay state had a bunch of code here that checks for a title-cased,
		// capitalized and lowercased variant, but we can fix this problem by staying uniform
		// in one naming style! (pfft yeah, as if)
		if (x == -1) {
			x = FlxMath.maxInt(0, currentSong.difficulties.indexOf(CoolUtil.defaultDifficulty));
		}
		selectedDifficultyIdx = x;
	}

	private function repositionSongArrows() {
		songLeftArrow.x = songNameText.x - songLeftArrow.width - SELECTION_ARROW_SPACING;
		songLeftArrow.y = songNameText.y + (songNameText.height - songLeftArrow.height) / 2;
		songRightArrow.x = songNameText.x + songNameText.width + SELECTION_ARROW_SPACING + 1;
		songRightArrow.y = songNameText.y + (songNameText.height - songRightArrow.height) / 2;
	}

	private function repositionMixArrows() {
		mixLeftArrow.x = mixNameText.x - mixLeftArrow.width - SELECTION_ARROW_SPACING;
		mixLeftArrow.y = mixNameText.y + (mixNameText.height - mixLeftArrow.height) / 2;
		mixRightArrow.x = mixNameText.x + mixNameText.width + SELECTION_ARROW_SPACING + 1;
		mixRightArrow.y = mixNameText.y + (mixNameText.height - mixRightArrow.height) / 2;
	}

	private function repositionDifficultySection() {
		centerAroundX(difficultyText, optionBarCenterX);
		difficultyLeftArrow.x = difficultyText.x - difficultyLeftArrow.width - SELECTION_ARROW_SPACING;
		difficultyLeftArrow.y = difficultyText.y + (difficultyText.height - difficultyLeftArrow.height) / 2;
		difficultyRightArrow.x = difficultyText.x + difficultyText.width + SELECTION_ARROW_SPACING + 1;
		difficultyRightArrow.y = difficultyText.y + (difficultyText.height - difficultyRightArrow.height) / 2;
	}
}
