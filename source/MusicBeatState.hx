package;

import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import flixel.input.FlxInput.FlxInputState;

import AchievementManager.AchievementRegistryEntry;
import AchievementNotification.AchievementNotificationBox;


class MusicBeatState extends FlxUIState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	private var achievementNotificationBox:AchievementNotificationBox;
	private var achievementNotificationCamera:Null<FlxCamera>;

	inline function get_controls():Controls {
		return PlayerSettings.player1.controls;
	}

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		super.create();

		achievementNotificationBox = new AchievementNotificationBox(40, 0, null);
		readdOrSetAchievementNotificationBoxCamera();
		add(achievementNotificationBox);

		// Custom made Trans out
		if (!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
	}

	public function readdOrSetAchievementNotificationBoxCamera(?camera:Null<FlxCamera>) {
		if (camera == null) {
			if (achievementNotificationCamera == null) {
				achievementNotificationCamera = new FlxCamera();
				achievementNotificationCamera.bgColor.alpha = 0;
			}
			achievementNotificationBox.cameras = [achievementNotificationCamera];
			FlxG.cameras.add(achievementNotificationCamera, false);
		} else {
			achievementNotificationBox.cameras = [camera];
			if (achievementNotificationCamera != camera) {
				if (FlxG.cameras.list.contains(achievementNotificationCamera)) {
					FlxG.cameras.remove(achievementNotificationCamera, true);
				} else {
					achievementNotificationCamera.destroy();
				}
				achievementNotificationCamera = null;
			}
		}
	}

	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep >= 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep) {
					updateSection();
				}
				else {
					rollbackSection();
				}
			}
		}

		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		super.update(elapsed);

		// @Square789: This is like a really deep intrusion into a core scene
		// and private fields but probably doesn't hurt toooo much.
		// Mirrors what i believe runs `FlxG.keys.pressed.ANY`.
		@:privateAccess
		for (key in FlxG.keys._keyListArray) {
			if (key != null && FlxG.keys.checkStatus(key.ID, FlxInputState.JUST_PRESSED)) {
				AchievementManager.notify(KEY_PRESSED, key.ID);
			}
		}
		processAchievementsToShow();
	}

	/**
	 * This function is called every update call and should display achievements in the scene's
	 * `AchievementNotificationBox`. The reason this actually calls into a static method is
	 * a bullshit inheritance chain system that makes substates (of which there can be at most
	 * one??!) a pain to use.
	 */
	private function processAchievementsToShow(
		?onDisplayDone:Null<Void->Void>
	):Null<AchievementRegistryEntry> {
		return stat_processAchievementsToShow(achievementNotificationBox, onDisplayDone);
	}

	/**
	 * Reads the pending unshown achievements. If one is available, populates the given
	 * AchievementNotificationBox with it. Otherwise, checks whether the box is open and then
	 * closes it or just does nothing.
	 * Returns the AchievementRegistryEntry associated with the just displayed achievement or null.
	 */
	public static function stat_processAchievementsToShow(
		box:AchievementNotificationBox,
		?onDisplayDone:Null<Void->Void>
	):Null<AchievementRegistryEntry> {
		if (AchievementManager.unshownAchievements.length == 0) {
			// Can't show anything. If the box is done displaying something, make it go away
			if (box.isOpen() && box.canDisplayNewNotification()) {
				box.close();
			}
			return null;
		}
		if (!box.canDisplayNewNotification()) {
			// Could show something, but box is busy
			return null;
		}

		// Can give the box something new to show here
		var achoo = AchievementManager.getAchievements([AchievementManager.unshownAchievements.shift().id])[0];
		box.showAchievement(achoo, onDisplayDone);
		return achoo;
	}

	private function updateSection():Void
	{
		if (PlayState.SONG.notes[curSection] != null) {
			if(stepsToDo < 1) stepsToDo = PlayState.SONG.notes[curSection].lengthInSteps;
			while(curStep >= stepsToDo)
			{
				curSection++;
				if (PlayState.SONG.notes[curSection] != null) {
					stepsToDo += PlayState.SONG.notes[curSection].lengthInSteps;
					sectionHit();
				} else {
					stepsToDo += PlayState.SONG.timeSignature[0] * 4;
					sectionHit();
				}
			}
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += PlayState.SONG.notes[i].lengthInSteps;
				if(stepsToDo > curStep) break;

				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}

	private function updateCurStep():Void {
		var curSteps = Conductor.getCurStep();
		curDecStep = curSteps.curDecStep;
		curStep = curSteps.curStep;
	}

	public static function switchState(nextState:FlxState) {
		FlxGridOverlay.clearCache();
		// Custom made Trans in
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;
		if (!FlxTransitionableState.skipNextTransIn) {
			leState.openSubState(new CustomFadeTransition(0.6, false));
			if (nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = function() {
					FlxG.resetState();
				};
			} else {
				CustomFadeTransition.finishCallback = function() {
					FlxG.switchState(nextState);
				};
			}
			return;
		}
		FlxTransitionableState.skipNextTransIn = false;
		if (nextState == FlxG.state) {
			FlxG.resetState();
		} else {
			FlxG.switchState(nextState);
		}
	}

	public static function resetState() {
		switchState(FlxG.state);
	}

	public static function getState():MusicBeatState {
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;
		return leState;
	}

	var passedFirstStep:Bool = false;
	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();

		if (curStep >= 0 && !passedFirstStep) {//stupid fix but whatever
			sectionHit();
			passedFirstStep = true;
		}
	}

	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
	}
}
