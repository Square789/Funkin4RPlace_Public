package;

import FreeplayPlaceState.FreeplaySongData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;

typedef PrevItems = {
	selected:Int,
	items:Array<String>,
}

class PauseSubState extends MusicBeatSubState
{
	public static var songName:String = '';

	private var grpMenuShit:FlxTypedGroup<TitleCardFont>;
	private var curSelected:Int = 0;

	var menuItems:Array<String> = [];
	var prevItemsStack:Array<PrevItems> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Mix', 'Change Difficulty', 'Options', 'Exit to menu'];
	var mixChoices:Array<String> = [];
	var mixDifficultyChoices:Array<Array<String>> = [];
	var difficultyChoices:Array<String> = [];

	var song:FreeplaySongData;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:TitleCardFont;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	#if mobile
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	public function new(playSound:Bool = true)
	{
		super();

		if (PlayState.chartingMode) {
			menuItemsOG.insert(2, 'Leave Charting Mode');

			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		}
		if (PlayState.isStoryMode && PlayState.seenCutscene) {
			menuItemsOG.insert(2, 'Restart Cutscene');
		}
		menuItems = menuItemsOG;

		song = PlayState.SONG.freeplaySongData;
		var difficulties = song == null ? CoolUtil.difficulties : song.difficulties;

		if (song == null || song.availableMixes.length < 2) {
			menuItemsOG.remove('Change Mix');
		} else {
			for (id => mix in song.availableMixes) {
				if (song.mixId != id) {
					mixChoices.push(mix);
					var len = mixDifficultyChoices.push(song.availableMixDifficulties[id].copy());
					mixDifficultyChoices[len-1].push('BACK');
				};
			}
			mixChoices.push('BACK');
		}

		if (difficulties.length < 2) {
			menuItemsOG.remove('Change Difficulty'); //No need to change difficulty if there is only one!
		} else {
			for (i in 0...CoolUtil.difficulties.length) {
				if (i != PlayState.storyDifficulty) {
					var diff:String = CoolUtil.difficulties[i];
					difficultyChoices.push(diff);
				}
			}
			difficultyChoices.push('BACK');
		}

		pauseMusic = new FlxSound();
		if(songName != null) {
			pauseMusic.loadEmbedded(Paths.music(songName), true, true);
		} else if (ClientPrefs.pauseMusic != 'None') {
			pauseMusic.loadEmbedded(Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic)), true, true);
		}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		grpMenuShit = new FlxTypedGroup<TitleCardFont>();
		add(grpMenuShit);

		regenMenu(playSound);

		var levelInfo:FlxText = new FlxText(20, 15, 0, "", 32);
		levelInfo.text += PlayState.instance.curSongDisplayName;
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, "", 32);
		levelDifficulty.text += CoolUtil.difficultyString();
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 15 + 64, 0, "", 32);
		blueballedTxt.text = 'Blueballed: ${PlayState.deathCounter}';
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, "PRACTICE MODE", 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, "CHARTING MODE", 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		#if mobile
		buttonUP = new Button(10, 240, 'UP');
		add(buttonUP);
		buttonDOWN = new Button(buttonUP.x, buttonUP.y + buttonUP.height + 10, 'DOWN');
		add(buttonDOWN);
		buttonENTER = new Button(1044, 574, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + buttonENTER.width + 10, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateSkipTextStuff();

		var upP = controls.UI_UP_P #if mobile || buttonUP.justPressed #end;
		var downP = controls.UI_DOWN_P #if mobile || buttonDOWN.justPressed #end;
		var accepted = controls.ACCEPT #if mobile || buttonENTER.justPressed #end;
		var back = controls.BACK #if mobile || buttonESC.justPressed #end;

		if (upP)
		{
			changeSelection(-1);
			holdTime = 0;
		}
		if (downP)
		{
			changeSelection(1);
			holdTime = 0;
		}
		
		var down = controls.UI_DOWN #if mobile || buttonDOWN.pressed #end;
		var up = controls.UI_UP #if mobile || buttonUP.pressed #end;
		if (down || up)
		{
			var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
			holdTime += elapsed;
			var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

			if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
			{
				changeSelection((checkNewHold - checkLastHold) * (up ? -1 : 1));
			}
		}

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if(curTime >= PlayState.instance.songLength) curTime -= PlayState.instance.songLength;
					else if(curTime < 0) curTime += PlayState.instance.songLength;
					updateSkipTimeText();
				}
		}

		if (back) {
			closeCurMenu();
			return;
		}

		if (accepted && (cantUnpause <= 0 || !ClientPrefs.controllerMode))
		{
			// @CoolingTool: submenu crap (the worst)
			if (prevItemsStack.length > 0) {
				if (daSelected == 'BACK') {
					// BACK
					closeCurMenu();
				} else if (menuItems == mixChoices) {
					// Mix for Change Mix Selected
					var menu = mixDifficultyChoices[curSelected];
					var retained = menu.indexOf(song.difficulties[PlayState.storyDifficulty]);
					if (retained == -1) retained = 0;
					genSubMenu(menu, retained);
				} else if (mixDifficultyChoices.contains(menuItems)) {
					// Difficulty for Mix Selected
					var mixStr = mixChoices[mixDifficultyChoices.indexOf(menuItems)];
					song.mixId = song.availableMixes.indexOf(mixStr);
					song.setStaticBullcrap();
					tormentPlayStateAndLoad(song.songName, false, song.difficulties.indexOf(daSelected));
				} else if (menuItems == difficultyChoices) {
					// Difficulty for Change Difficulty selected
					tormentPlayStateAndLoad(PlayState.SONG.song, true, CoolUtil.difficulties.indexOf(daSelected));
				}
				return;
			}

			switch (daSelected)
			{
				case "Resume":
					close();
				case 'Change Mix':
					genSubMenu(mixChoices);
				case 'Change Difficulty':
					genSubMenu(difficultyChoices);
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case "Restart Cutscene":
					PlayState.seenCutscene = false;
					restartSong();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
					PlayState.startOnTime = 0;
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case "End Song":
					close();
					PlayState.instance.killNotes();
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					#if BOTPLAY_HIDDEN
					var bot = false;
					#else
					var bot = PlayState.instance.cpuControlled;
					#end
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = bot;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
					PlayState.instance.scoreTxt.visible = !ClientPrefs.hideHud && !bot;
					PlayState.instance.scoreBG.visible = !ClientPrefs.hideHud && !bot;
				case "Options":
					MusicBeatState.switchState(new options.OptionsState(true));
					CoolUtil.playMenuMusic();
				case "Exit to menu":
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					WeekData.loadTheFirstEnabledMod();
					if (PlayState.isStoryMode) {
						MusicBeatState.switchState(new MainMenuF4rpState(true));
					} else {
						PlayState.SONG = PlayState.originalSong;
						MusicBeatState.switchState(new FreeplayPlaceState());
					}
					PlayState.cancelMusicFadeTween();
					CoolUtil.playMenuMusic();
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					PlayState.startOnTime = 0;
			}
		}
	}

	function tormentPlayStateAndLoad(name:String, changedDifficulty:Bool, actualDiff:Int) {
		var poop = Highscore.formatSong(name, actualDiff, false);
		var goodOldFreeplayData = PlayState.SONG.freeplaySongData;
		PlayState.SONG = Song.loadFromJson(poop, name);
		if (goodOldFreeplayData != null) {
			PlayState.SONG.meta = goodOldFreeplayData.meta;
			PlayState.SONG.freeplaySongData = goodOldFreeplayData;
		}
		PlayState.storyDifficulty = actualDiff;
		LoadingState.loadAndResetState();
		FlxG.sound.music.volume = 0;
		PlayState.changedDifficulty = changedDifficulty;
		PlayState.chartingMode = false;
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		FlxG.timeScale = 1;
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;
		PlayState.instance.vocalsDad.volume = 0;
		PlayState.SONG = PlayState.originalSong;

		if (noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		pauseMusic.destroy();

		super.destroy();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true):Void
	{
		curSelected += change;

		if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;

				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
	}

	function genSubMenu(items:Array<String>, playSound:Bool = true, selected:Int = 0):Void {
		prevItemsStack.push({selected: curSelected, items: menuItems});
		menuItems = items;
		deleteSkipTimeText();
		regenMenu(playSound, selected);
	}

	function closeCurMenu():Void {
		if (prevItemsStack.length > 0) {
			var prev = prevItemsStack.pop();
			menuItems = prev.items;
			regenMenu(prev.selected);
		} else {
			close();
		}
	}

	function regenMenu(playSound:Bool = true, selected:Int = 0):Void {
		for (i in 0...grpMenuShit.members.length) {
			var obj = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (i in 0...menuItems.length) {
			var item = new TitleCardFont(0, 70 * i + 30, menuItems[i], true, false);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if(menuItems[i] == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = selected;
		changeSelection(0, playSound);
	}

	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
	{
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / Conductor.playbackRate / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / Conductor.playbackRate / 1000)), false);
	}
}
