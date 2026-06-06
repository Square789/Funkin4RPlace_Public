package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.TransitionData;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import AchievementManager;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import RedditColor;
import RoundedCornerShader.BetterRoundedCornerShader;
import TextHelper.isSpace;

using CoolUtil.InflatedPixelSpriteExt;
using StringTools;


final TEXT_SPACING_NAME_DESC = 1.0;
final TEXT_SPACING_DESC_NEXTDESC = -3.0;
final ACHIEVEMENT_ICON_WIDTH = 150;


class AchievementDisplayGroup extends FlxGroup {
	public var icon:FlxSprite;
	public var nameText:FlxText;
	public var descText:FlxText;
	public var nextDescText:FlxText;
	public var entry:AchievementRegistryEntry;

	public function new(baseX:Float, baseY:Float, descMaxX:Float, achievementEntry:AchievementRegistryEntry, maxSize:Int = 0) {
		super(maxSize);

		entry = achievementEntry;

		icon = new FlxSprite(baseX, baseY);
		icon.loadGraphic(Paths.image('achievement_locked'));
		icon.setGraphicSize(ACHIEVEMENT_ICON_WIDTH, ACHIEVEMENT_ICON_WIDTH);
		icon.shader = new BetterRoundedCornerShader(16.0, ACHIEVEMENT_ICON_WIDTH, ACHIEVEMENT_ICON_WIDTH);

		nameText = new FlxText(icon.x + ACHIEVEMENT_ICON_WIDTH + 16, -1.0);
		nameText.setFormat("IBM Plex Sans Bold", 32, RedditColor.TEXT);

		descText = new FlxText(nameText.x, -1.0);
		descText.fieldWidth = Math.max(32.0, descMaxX - descText.x);
		descText.setFormat("IBM Plex Sans", 22, RedditColor.TEXT);

		nextDescText = new FlxText(descText.x, -1.0);
		nextDescText.fieldWidth = Math.max(32.0, descMaxX - nextDescText.x);
		nextDescText.setFormat("IBM Plex Sans", 22, RedditColor.TEXT_WEAK);

		updateElements();

		add(icon);
		add(nameText);
		add(descText);
		add(nextDescText);
	}

	public function updateElements() {
		var info = entry.getLayerInfo();
		var locked = entry.isLocked();
		var ach = entry.achievement;

		if (locked && entry.achievement.shouldHideIconWhenLocked()) {
			icon.loadGraphic(Paths.image('achievement_locked'));
		} else {
			icon.loadGraphic(Paths.image('achievements/${entry.achievement.id}'));
		}
		icon.setGraphicSize(ACHIEVEMENT_ICON_WIDTH, ACHIEVEMENT_ICON_WIDTH);

		// Hide the suffix if the achievement only has 1 layer or is locked
		var progressSuffix:String;
		if (ach.layerCount == 1 || locked) {
			progressSuffix = '';
		} else {
			progressSuffix = ' [${entry.unlockProgress}/${ach.layerCount}]';
		}
		nameText.text = (locked && ach.shouldHideNameWhenLocked() ? "?" : info.name) + progressSuffix;
		descText.text = locked && ach.shouldHideDescriptionWhenLocked() ? "?" : info.desc;
		nextDescText.text = (
			(locked || entry.isUnlocked()) ?
				"" :
				"Next: " + entry.getLayerInfo(entry.unlockProgress).desc
		);

		// center texts vertically
		var textExtent = (
			nameText.height + TEXT_SPACING_NAME_DESC +
			descText.height + (isSpace(nextDescText.text) ? 0.0 : nextDescText.height + TEXT_SPACING_DESC_NEXTDESC)
		) - 8.0 - 6.0; // remove some speculative distances because texts are always taller than they show
		// if the heading is too low, correct upwards. just looks better
		// since there's another ~8px of space between the nameText's y and the top of capital letters, subtract that.
		var newStartY = icon.y + FlxMath.minInt(32, Std.int((icon.height - textExtent) * 0.5)) - 8.0;
		nameText.y = newStartY;
		descText.y = nameText.y + nameText.height + TEXT_SPACING_NAME_DESC;
		nextDescText.y = descText.y + descText.height + TEXT_SPACING_DESC_NEXTDESC;
	}

	public function adjustY(by:Float) {
		for (o in [icon, nameText, descText, nextDescText]) {
			o.y += by;
		}
	}
}

private final INTER_ACHIEVEMENT_PADDING = 42;
private final BORDER_PADDING = 32;


class AchievementsMenuState extends MusicBeatState {
	private var initialSelectionTarget:Null<String>;
	private var mainCam:FlxCamera;
	private var displayedAchievements:Array<AchievementDisplayGroup>;
	private var background:FlxSprite;
	private var achievementGroup:FlxGroup;
	private var curSelected:Int;
	private var holdTimer:HoldTimer;

	public override function new(
		?transIn:Null<TransitionData>, ?transOut:Null<TransitionData>, ?initialSelectionTarget:Null<String>
	) {
		super(transIn, transOut);
		this.initialSelectionTarget = initialSelectionTarget;
	}

	public override function create() {
		super.create();
		
		FlxG.cameras.remove(achievementNotificationCamera, false);
		mainCam = new FlxCamera();
		mainCam.bgColor = RedditColor.MIDNIGHT;
		FlxG.cameras.reset(mainCam);
		readdOrSetAchievementNotificationBoxCamera();

		background = new FlxSprite(128, 0);
		background.makeInflatedPixelGraphic(RedditColor.BACKGROUND, FlxG.width - 256, 32);
		background.shader = new BetterRoundedCornerShader(24.0, FlxG.width - 256, 32, 3.0, RedditColor.SIDEBAR_BORDER);
		add(background);

		var rect = new FlxSprite(background.x + BORDER_PADDING * 0.5);
		rect.makeInflatedPixelGraphic(
			RedditColor.BACKGROUND_ACTIVE,
			background.width - BORDER_PADDING,
			150 + BORDER_PADDING
		);
		rect.scrollFactor.set(0.0, 0.0);
		rect.screenCenter(Y);
		rect.shader = new BetterRoundedCornerShader(16, rect.width, rect.height);
		add(rect);

		achievementGroup = new FlxGroup();
		add(achievementGroup);

		var rectBorder = new FlxSprite(background.x + BORDER_PADDING * 0.5);
		rectBorder.makeInflatedPixelGraphic(0x00000000, rect.width, rect.height);
		rectBorder.scrollFactor.set(0.0, 0.0);
		rectBorder.screenCenter(Y);
		rectBorder.shader = new BetterRoundedCornerShader(16, rectBorder.width, rectBorder.height, 2.0, 0xFFFFFFFF);
		add(rectBorder);

		displayedAchievements = [];
		for (entry in AchievementManager.getAchievements()) {
			if (entry.unlockProgress <= 0 && entry.achievement.isSecret()) {
				continue;
			}

			_insertAchievementLine(entry);
		}
		_setBackgroundHeight(displayedAchievements[displayedAchievements.length - 1].icon.y + 150 + BORDER_PADDING);

		holdTimer = new HoldTimer(0.5, 0.18, 0.08);
		holdTimer.listen(controls.ui_downP, controls.ui_down, changeSelection, 1);
		holdTimer.listen(controls.ui_upP, controls.ui_up, changeSelection, -1);
		curSelected = 0;
		if (initialSelectionTarget != null) {
			for (i => s in displayedAchievements) {
				if (s.entry.achievement.id == initialSelectionTarget) {
					curSelected = i;
					break;
				}
			}
		}

		mainCam.scroll.y = Std.int(
			displayedAchievements[curSelected].icon.y +
			displayedAchievements[curSelected].icon.height * 0.5 -
			mainCam.height * 0.5
		);

	}

	public override function update(dt:Float) {
		super.update(dt);

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		holdTimer.update(dt);
	}

	private function changeSelection(by:Int) {
		curSelected = CoolUtil.wrapModulo(curSelected + by, displayedAchievements.length);
		tweenScrollCameraTo(
			displayedAchievements[curSelected].icon.y +
			displayedAchievements[curSelected].icon.height * 0.5
		);
	}

	private function tweenScrollCameraTo(y:Float) {
		FlxTween.cancelTweensOf(mainCam);
		FlxTween.tween(mainCam, {"scroll.y": Std.int(y - mainCam.height * 0.5)}, 0.3, {ease: FlxEase.quintOut});
	}

	private function _insertAchievementLine(entry:AchievementRegistryEntry, idx:Int = -1) {
		if (idx < 0 || idx > displayedAchievements.length) {
			idx = displayedAchievements.length;
		}

		// Push following achievement listings away
		for (i in idx...(displayedAchievements.length)) {
			displayedAchievements[i].adjustY(150 + INTER_ACHIEVEMENT_PADDING);
		}

		var ad = new AchievementDisplayGroup(
			background.x + BORDER_PADDING,
			background.y + BORDER_PADDING + (150 + INTER_ACHIEVEMENT_PADDING) * idx,
			background.x + background.width - BORDER_PADDING,
			entry
		);

		achievementGroup.add(ad);
		displayedAchievements.insert(idx, ad);
	}

	private function _setBackgroundHeight(newHeight:Float) {
		background.scale.y = newHeight;
		background.height = newHeight;
		cast(background.shader, BetterRoundedCornerShader).texture_size.value[1] = newHeight;
	}

	private override function processAchievementsToShow(?onDisplayDone:Null<Void->Void>):Null<AchievementRegistryEntry> {
		var newEntry = super.processAchievementsToShow(onDisplayDone);
		if (newEntry == null) {
			return null;
		}

		// There is a pending achievement that needs to be inserted into the currently displayed ones.
		if (newEntry.unlockProgress <= 0) {
			// Mega strange and should not happen probably idk why i am writing this if statement
			return newEntry;
		}

		var idx:Int = -1;
		for (i => achGroup in displayedAchievements) {
			if (achGroup.entry.achievement.id == newEntry.achievement.id) {
				idx = i;
				break;
			}
		}
		if (idx == -1) {
			// Must be a secret achievement, find and prepare insertion point
			var insertionIdx = displayedAchievements.length;
			for (i => achGroup in displayedAchievements) {
				if (achGroup.entry.index > newEntry.index) {
					insertionIdx = i;
					break;
				}
			}

			_insertAchievementLine(newEntry, insertionIdx);
			_setBackgroundHeight(displayedAchievements[displayedAchievements.length - 1].icon.y + 150 + BORDER_PADDING);
		} else {
			displayedAchievements[idx].updateElements();
		}

		return newEntry;
	}
}
