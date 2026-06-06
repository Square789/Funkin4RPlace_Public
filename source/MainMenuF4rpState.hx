/**
 * Merger menu of title screen, actual main menu and story menu. Less transitions and faster action.
 * That's the plan anyways.
**/

package;


import TitleCardFont;
import flixel.addons.display.FlxBackdrop;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.ValueException;
import lime.app.Application;
import openfl.display.BitmapData;

import AchievementManager.AchievementRegistryEntry;
import CoolUtil.PointStruct;
import ChainEffects;
import OrganicPixelErasureShader.HoleOrganicPixelErasureShader;
import PixelErasureShader.GradientPixelErasureShader;
import RedditColor;
import RoundedCornerShader.BetterRoundedCornerShader;
import SelectionWeb;

using CoolUtil.InflatedPixelSpriteExt;
using StringTools;


private final REDDIT_POST_BORDER_INCL_HEIGHT = 114;
private final SECTION_PADDING = 24;
private final SIDEBAR_BUTTON_HEIGHT = 42;
private final ACHIEVEMENT_IPADDING = 16;
private final ACHIEVEMENT_ICON_SIZE = 75;
private final REDDIT_POST_BAY_SELECTOR_RECT_DEDENT = 5;
private final PILL_BUTTON_RADIUS_CORRECTION = 1.0;

/** How many decorative posts to place between top of the post bay and the hidden song's btn.
 * Good thing we only have a single week.
 */
private final HIDDEN_POST_OFFSET = 9;

private final SELECTION_BLINK_INTERVAL = 2.1;
private final SELECTION_BLINK_SPEED = 3.0;


typedef RedditPostOptions = {
	var title:String;
	var regions:Array<{icon:String, text:String}>;
	var ?subtitle:Null<String>;
	var ?karmaText:Null<String>;
	var ?thumbnail:Null<String>;
	var ?flairText:Null<String>;
	var ?flairColor:Null<FlxColor>;
	var ?unimportant:Null<Bool>;
}

typedef RedditPostRegion = {icon:FlxSprite, text:FlxText, span:FlxRect}

class RedditPost extends FlxSpriteGroup {
	private var regions:Array<RedditPostRegion>;

	private var redditPostHeight:Int;
	private var backgroundRect:FlxSprite;
	private var selectorRect:FlxSprite;
	private var selectorRectOutline:FlxSprite;
	private var lastSelectorRectIndex:Int;

	private var karmaTextCenterX:Float;
	private var karmaText:FlxText;
	private var subtitleText:FlxText;

	public function new(
		x:Float,
		y:Float,
		width:Int,
		height:Int,
		options:RedditPostOptions
	) {
		super(x, y);

		this.redditPostHeight = height;

		var unimportant = options.unimportant != null && options.unimportant;
		var bgColor = unimportant ? RedditColor.FADED : RedditColor.BACKGROUND;
		var highlitTextColor = unimportant ? RedditColor.TEXT_WEAK : RedditColor.TEXT;

		backgroundRect = new FlxSprite(1, 1).makeGraphic(width - 2, height - 2, bgColor);
		add(backgroundRect);

		var upvoteArrow = new FlxSprite(12, 12).loadGraphic(Paths.image("mainmenu/place_upvotearrow"));
		karmaTextCenterX = (upvoteArrow.x + (upvoteArrow.width / 2.0));
		karmaText = new FlxText(0, upvoteArrow.y + upvoteArrow.height + 4, 0);
		karmaText.setFormat("IBM Plex Sans Bold", 12, highlitTextColor);
		var downvoteArrow = new FlxSprite(upvoteArrow.x, karmaText.y + karmaText.height + 4).loadGraphic(
			Paths.image("mainmenu/place_downvotearrow")
		);
		add(upvoteArrow);
		add(karmaText);
		add(downvoteArrow);
		setKarmaText(options.karmaText == null ? "0" : options.karmaText);

		var postImage = new FlxSprite(64, 9).loadGraphic(
			Paths.image("mainmenu/place_post_thumbnails/" + (options.thumbnail == null ? "default" : options.thumbnail))
		);
		postImage.shader = new BetterRoundedCornerShader(8.0, postImage.width, postImage.height);
		var titleText = new FlxText(postImage.x + postImage.width + 4, postImage.y, 0, options.title);
		// "Medium" requires the Paths.font way, for whatever reason
		titleText.setFormat(Paths.font("IBMPlexSans-Medium.ttf"), 20, highlitTextColor);
		subtitleText = new FlxText(titleText.x, titleText.y + titleText.height - 2);
		subtitleText.setFormat("IBM Plex Sans", 14, RedditColor.TEXT_WEAK);
		subtitleText.text = options.subtitle == null ? "" : options.subtitle;

		var addFlair = options.flairText != null;
		var flairText:Null<FlxText> = null;
		var flairBackground:Null<FlxSprite> = null;
		if (addFlair) {
			flairText = new FlxText(titleText.x + titleText.width + 12, titleText.y + 4, 0, options.flairText);
			flairText.setFormat(Paths.font("IBMPlexSans-Medium.ttf"), 14, FlxColor.BLACK);
			flairBackground = new FlxSprite(flairText.x - 6, flairText.y - 2).makeGraphic(
				Std.int(flairText.width) + 12, 24, options.flairColor
			);
			flairBackground.shader = new BetterRoundedCornerShader(
				12.0 - PILL_BUTTON_RADIUS_CORRECTION, flairBackground.width, flairBackground.height
			);
		}

		add(postImage);
		add(titleText);
		add(subtitleText);
		if (addFlair) {
			add(flairBackground);
			add(flairText);
		}

		selectorRectOutline = new FlxSprite(0, 0).makeInflatedPixelGraphic(0xFFFFFFFF);
		selectorRectOutline.visible = false;
		add(selectorRectOutline);
		selectorRect = new FlxSprite(0, 0).makeInflatedPixelGraphic(RedditColor.HIGHLIGHT_MILD);
		selectorRect.visible = false;
		add(selectorRect);
		lastSelectorRectIndex = 0;

		this.regions = [];
		for (region in options.regions) {
			var icon = new FlxSprite().loadGraphic(Paths.image('mainmenu/place_${region.icon}'));
			var text = new FlxText(0, 0, 0, region.text);
			text.setFormat("IBM Plex Sans Bold", 14, RedditColor.TEXT_WEAKER);
			add(icon);
			add(text);
			regions.push({icon: icon, text: text, span: new FlxRect()});
		}
		relayoutRegions();
	}

	private function relayoutRegions() {
		final REGION_PADDING = 8;
		final ICON_OCCUPIED_SPACE = 25;
		final ICON_ASSUMED_SIZE = 29;
		final ICON_X_CORRECTION = Std.int((ICON_OCCUPIED_SPACE - ICON_ASSUMED_SIZE) / 2);
		// Pull icons up by 4 pixels since the region seems a bit too tall otherwise.
		final ICON_Y_CORRECTION = ICON_OCCUPIED_SPACE - ICON_ASSUMED_SIZE;

		// Post image x/expected width + title buffer + region padding
		// You'd think the title buffer is 4, but it's actually 7 idk
		var startX = 64 + 112 + 7 + REGION_PADDING;
		var startY = redditPostHeight - ICON_OCCUPIED_SPACE - REGION_PADDING;

		for (region in regions) {
			// Icons are 29x29 the way i export them, but at most 25px in width on the screenshot,
			// so adjust it accordingly and always assume a width of 25px.
			// Factor in the fact this is still a SpriteGroup, need to add this.x|y
			region.icon.setPosition(this.x + startX + ICON_X_CORRECTION,       this.y + startY + ICON_Y_CORRECTION);
			region.text.setPosition(this.x + startX + ICON_OCCUPIED_SPACE + 4, this.y + startY + 2);
			region.span.setPosition(startX - REGION_PADDING, startY - REGION_PADDING);
			region.span.setSize(
				ICON_OCCUPIED_SPACE + 4 + region.text.width + REGION_PADDING * 2,
				ICON_OCCUPIED_SPACE + REGION_PADDING * 2 - 1
			);
			startX += Std.int(region.span.width) + 6;
		}
	}

	private function positionSelectorRect() {
		var span = regions[lastSelectorRectIndex].span;
		selectorRectOutline.setPosition(this.x + span.x, this.y + span.y + 1);
		selectorRectOutline.scale.set(span.width, span.height);
		selectorRect.setPosition(this.x + span.x + 1, this.y + span.y + 2);
		selectorRect.scale.set(span.width - 2, span.height - 2);
	}

	public function select(index:Int) {
		if (index < 0 || index > 2) {
			selectorRectOutline.visible = false;
			selectorRect.visible = false;
			return;
		}
		lastSelectorRectIndex = index;
		selectorRectOutline.visible = true;
		selectorRect.visible = true;
		positionSelectorRect();
	}

	public function renameRegion(idx:Int, newName:String) {
		regions[idx].text.text = newName;
		relayoutRegions();
		if (selectorRect.visible) {
			positionSelectorRect();
		}
	}

	public function setKarmaText(newText:String) {
		karmaText.text = newText;
		karmaText.x = this.x + (karmaTextCenterX - (karmaText.width / 2.0));
	}

	public function setSubtitleText(newText:String) {
		subtitleText.text = newText;
	}
}

// Week posts are guaranteed to have three selectable regions: The play button, the difficulty indicator and
// the gameplay changer menu.

// SWNID for the main post bay, only on top of it.
private final SWNID_POST_BAY = 0;
// SWNID for pill-button sidebar
private final SWNID_SIDEBAR = 1;
// SWNID for achievement sidebar
private final SWNID_ACHIEVEMENTS = 2;
// SWNID for in-post play buttons
private final SWNID_PLAY_NODE = 3;
// SWNID for in-post difficulty changer button
private final SWNID_DIFFICULTY_NODE = 4;
// SWNID for in-post gameplay changer button
private final SWNID_GAMEPLAY_CHANGER_NODE = 5;
// SWNID for the hidden posts super-node.
private final SWNID_HIDDEN_POSTS = 6;

private enum abstract SelectionAction(Int) to Int from Int {
	public var NONE;
	public var SELECT_DOWN;
	public var START_WEEK;
	public var BUMP_DIFFICULTY;
	public var GAMEPLAY_CHANGERS;
	public var FREEPLAY;
	public var SETTINGS;
	public var AWARDS;
	public var CREDITS;
	public var DISCORD;
	public var LOREBOOK;
	public var OPEN_ACHIEVEMENTS_MENU;
}

/**
 * Stores some auxiliary stuff for the weeks.
 */
class WeekBlob {
	public var weekData:WeekData;
	public var songs:Array<SongData>;

	/**
	 * The index this week is known under in the static global WeekData.weeksList array, as some
	 * places keep accessing the week that way.
	 */
	public var staticWeekDataIndex:Int;
	private var difficulties:Array<String>;
	private var selectedDifficultyIdx:Int;

	public function new(weekData:WeekData, staticWeekDataIndex:Int, availableDifficulties:Array<String>) {
		this.weekData = weekData;
		this.songs = [for (arr in weekData.songs) new SongData(arr)];
		this.staticWeekDataIndex = staticWeekDataIndex;
		this.difficulties = availableDifficulties;
		this.selectedDifficultyIdx = 0;
	}

	public function setStaticDifficultyGarbage() {
		// Extracted from the corresponding code in StoryMenuState.
		// i know i shouldn't hate whoever wrote this cause they're 15 but man
		CoolUtil.difficulties = difficulties.copy();
		var diffic = CoolUtil.getDifficultyFilePath(selectedDifficultyIdx);
		PlayState.storyDifficulty = selectedDifficultyIdx;
		return diffic == null ? "" : diffic;
	}

	public function setStaticPlayStateGarbagePrepareWeek() {
		PlayState.storyPlaylist = [for (s in songs) s.name];
		PlayState.storyWeek = staticWeekDataIndex;
		PlayState.isStoryMode = true;

		var formattedDifficulty = setStaticDifficultyGarbage();
		PlayState.SONG = Song.loadFromJson(
			PlayState.storyPlaylist[0] + formattedDifficulty,
			PlayState.storyPlaylist[0]
		);

		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;
	}

	// (I shouldn't have to put this comment here like it's some assembler routine, i really shouldn't)
	/**
	 * Retrieves the score for this week with the current difficulty.
	 * This modifies the global difficulty state.
	 */
	public function getScore():Int {
		#if HIGHSCORE_ALLOWED
		CoolUtil.difficulties = difficulties.copy();
		return Highscore.getWeekScore(weekData.fileName, selectedDifficultyIdx);
		#else
		return 0;
		#end
	}

	public function changeDifficulty(dir:Int) {
		selectedDifficultyIdx = CoolUtil.wrapModulo(selectedDifficultyIdx + dir, difficulties.length);
	}

	public function getCurDifficultyDisplayName():String {
		var raw = difficulties[selectedDifficultyIdx];
		if (raw.length == 0) {
			return "<none>";
		}
		// Probably good enough, our difficulties don't have spaces in them
		return raw.charAt(0).toUpperCase() + raw.substr(1).toLowerCase();
	}
}

typedef PostBayEntry = {
	var postOptions:RedditPostOptions;
	var ?dontConfigureSubtitle:Null<Bool>;
	var ?selectionAction:Null<SelectionAction>;
	var ?weekBlob:Null<WeekBlob>;
	var ?post:Null<RedditPost>;
}

private enum VirtualMenuState {
	NONE; // Since switches complain about null otherwise
	// NONE is the only vstate not tied to any explicit setup/teardown code
	PRE_TITLE_FLASHING_LIGHTS_WARNING;
	TITLE_TEXT_INTRO;
	TITLE;
	TITLE_MAIN_MENU_BETWEEN;
	MAIN_MENU;
}

typedef AchievementDisplayTrio = {
	var icon:FlxSprite;
	var name:FlxText;
	var entry:AchievementRegistryEntry;
}


class MainMenuF4rpState extends MusicBeatState {
	public static var psychEngineVersion:String = '0.6.2';
	public static var psychEngineExtraVersion:String = '0.1'; //This is also used for Discord RPC
	public static var modVersion:String = '1.0.0';

	private var virtualState:VirtualMenuState;
	// Disables user input / the controlling part of `update`.
	private var pendingVirtualStateSwitch:Bool;
	// Disables state switching.
	private var allowVirtualStateSwitch:Bool;
	private var skipIntroAndTitle:Bool;

	private var debugKeys:Array<FlxKey>;

	private var introTexts:Null<Array<Array<String>>>;
	private var selectedIntroTextIdx:Int;
	private var textIntroBeatCounter:Int;

	private var stripeBackgroundScrollShader:RuntimeShader;

	private var menuCamera:FlxCamera;
	private var staticCamera:FlxCamera;
	private var titleFocusPoint:FlxObject;
	private var mainMenuFocusPoint:FlxObject;

	private var flashingNotificationText:FlxText;
	private var introAlphabetGroup:FlxSpriteGroup;
	private var introElementGroup:FlxGroup;
	private var susgroundsLogo:FlxSprite;
	private var voidCoverSprite:FlxSprite;
	private var voidCoverShader:HoleOrganicPixelErasureShader;
	private var modLogo:FlxSprite;
	private var pressToEnterButton:FlxSprite;
	private var orangeCoverSprite:FlxSprite;
	private var orangeCoverShader:GradientPixelErasureShader;

	private var mainMenuSelectionManager:SelectionWebManager;
	private var selectionWebPostBayNode:SelectionWebNode;
	private var selectionWebAchievementsSidebarNode:SelectionWebNode;
	private var selectionWebSidebarNode:SelectionWebNode;
	private var defaultSelectionNode:SelectionWebNode;
	private var hiddenPostsNode:SelectionWebNode;
	private var hiddenPostNodeIdxToPostBayIdx:Array<Int>;
	private var xxxRemovedxxxWeekBlob:WeekBlob;
	private var redditPostBaySelectorRect:FlxSprite;
	private var redditPostBaySelectorRectBase:FlxPoint;
	private var redditPostBayPosts:Array<PostBayEntry>;
	private var sidebarButtons:Array<FlxSprite>;
	private var achievementsSidebar:FlxSprite;
	private var achievementsSidebarSelectorRect:FlxSprite;
	private var achievementDisplayTrios:Array<AchievementDisplayTrio>;
	private var decoPostPool:Array<{title:String, thumb:Null<String>}>;
	private var usernamePool:Array<String>;
	private var redditUiBackground:FlxSprite;
	private var redditPostBayBackground:FlxSprite;
	private var REDDIT_POST_BAY_WIDTH:Int;

	private var selectionBlinkProgress:Float;

	private var holdTimer:HoldTimer;

	public override function new(skipIntroAndTitle = false) {
		super();
		this.virtualState = NONE;
		this.pendingVirtualStateSwitch = false;
		this.allowVirtualStateSwitch = true;
		this.skipIntroAndTitle = skipIntroAndTitle;
		this.textIntroBeatCounter = 0;
		this.selectionBlinkProgress = 0.0;
		this.debugKeys = ClientPrefs.copyNonNoneKeys('debug_1');
	}

	public override function create() {
		super.create();

		// @Square789: Sometimes ignored by the game? Add it here again to make it less likely i guess
		FlxG.mouse.visible = false;

		var sidebarEntries = [{text: "Lorebook", action: LOREBOOK}, {text: "Credits", action: CREDITS}, {text: "Discord", action: DISCORD}];

		final SIDEBAR_WIDTH = Std.int(FlxG.width / 4.0);
		REDDIT_POST_BAY_WIDTH = FlxG.width - (3 * SECTION_PADDING) - SIDEBAR_WIDTH;

		// @Square789: Collect weeks, hopefully this does it mostly right.
		redditPostBayPosts = [];
		WeekData.reloadWeekFiles(true);
		for (i => weekName in WeekData.weeksList) {
			var weekData = WeekData.weeksLoaded[weekName];
			var isLocked = (
				!weekData.startUnlocked &&
				weekData.weekBefore.length > 0 &&
				!Highscore.completedWeek(weekData.weekBefore)
			);
			if (isLocked) {
				continue;
			}
			// This combination is for hidden songs. Of which there is one.
			if (weekData.hideFreeplay) {
				continue;
			}

			PlayState.storyWeek = i;
			// Thank you Cooling for fixing this half of global awfulness
			var weekBlob = new WeekBlob(weekData, i, CoolUtil.getDifficultiesRet());

			var score = #if HIGHSCORE_ALLOWED weekBlob.getScore() #else FlxG.random.int(500, 80000) #end ;
			redditPostBayPosts.push({
				postOptions: {
					title: weekData.storyName,
					subtitle: 'Score: ${score}',
					karmaText: formatKarma(score),
					thumbnail: weekData.placePostThumbnail,
					flairText: [for (song in weekBlob.songs) song.name].join(", "),
					flairColor: weekBlob.songs[0].color,
					regions: [
						{icon: "comment", text: "Play"},
						{icon: "lightning", text: weekBlob.getCurDifficultyDisplayName()},
						{icon: "options", text: "Gameplay Options"},
					],
				},
				selectionAction: SELECT_DOWN,
				weekBlob: weekBlob,
			});
		}

		// Just hardcode I don't care anymore
		for (i => weekName in WeekData.weeksList) {
			if (weekName != "XXX") { // as listed in weekList.txt
				continue;
			}
			PlayState.storyWeek = i;
			xxxRemovedxxxWeekBlob = new WeekBlob(WeekData.weeksLoaded[weekName], i, CoolUtil.getDifficultiesRet());
			break;
		}
		if (xxxRemovedxxxWeekBlob == null) {
			// trace('Failed finding XXX');
		}

		var nonWeekEntries:Array<PostBayEntry> = [
			{
				postOptions: {title: "Freeplay", thumbnail: "freeplay", regions: []},
				selectionAction: FREEPLAY
			},
			{
				postOptions: {title: "Settings", thumbnail: "settings", regions: []},
				selectionAction: SETTINGS
			},
			{
				postOptions: {title: "Awards", thumbnail: "awards", regions: []},
				selectionAction: AWARDS
			},
		];

		decoPostPool = [
			{title: "Interesting redesign", thumb: "deco_canada"},
			{title: "Boutta fight I'll post the video later", thumb: "deco_france"},
			{title: "no meme here just wanna appreciate these guys :)", thumb: "deco_bench"},
			{title: "Everyone else while Spain and France are duking it out :", thumb: "deco_rap_oorn"},
			{title: "Honestly the flags still had great art", thumb: "deco_flags"},
			{title: "Star Wars with the closet big win", thumb: "deco_star_wars"},
			{title: "coughing baby vs. hydrogen bomb", thumb: "deco_hand"},
			{title: "the numbers mason, what do they mean??", thumb: "deco_timeout"},
			{title: "come on guys", thumb: "deco_unfunnysimpson"},
			{title: "They would never", thumb: "deco_to_the_mod"},
			{title: "Title or something", thumb: "deco_realestate"},
			{title: "The four horsemen of the apocalypse", thumb: "deco_horsemen"},
			{title: "haha... unless?", thumb: "deco_unless"},
			{title: "r/place as an anime", thumb: "deco_naruto"},
			{title: "what is he even doing", thumb: "deco_mine"},
			{title: "do they spell it like r/flace over in the uk?", thumb: "deco_uk"},
			{title: "goodbye LOL", thumb: "deco_censor"},
		];
		FlxG.random.shuffle(decoPostPool);

		// Reddit usernames technically have a limit of 20 chars but that actually excludes many, so we dont care
		var usernameRegex = ~/^[A-Za-z0-9_-]{3,28}$/;
		usernamePool = CoolUtil.getTextFileLines(Paths.txt("usernames"));
		usernamePool = [for (l in usernamePool) if (usernameRegex.match(l)) l];
		FlxG.random.shuffle(usernamePool);

		// Enhance all non-week posts
		for (i => o in nonWeekEntries) {
			var user = i < usernamePool.length ? usernamePool[i] : "[none]";
			o.postOptions.subtitle = 'Posted by u/$user ${FlxG.random.int(2, 22)} hours ago';
			o.postOptions.karmaText = formatKarma(100000 + FlxG.random.int(-20000, 20000));
		}
		redditPostBayPosts = redditPostBayPosts.concat(nonWeekEntries);

		hiddenPostNodeIdxToPostBayIdx = [];

		menuCamera = new FlxCamera();
		FlxG.cameras.reset(menuCamera);
		staticCamera = new FlxCamera();
		staticCamera.bgColor.alpha = 0;
		FlxG.cameras.add(staticCamera, false);
		readdOrSetAchievementNotificationBoxCamera(staticCamera);

		// I believe these totally disrespect zoom, so probably don't zoom!
		this.titleFocusPoint = new FlxObject(FlxG.width / 2, FlxG.height / 2);
		var mainMenuTopLeft:PointStruct = {x: 0, y: FlxG.height};
		this.mainMenuFocusPoint = new FlxObject(
			mainMenuTopLeft.x + FlxG.width / 2.0,
			mainMenuTopLeft.y + FlxG.height / 2.0
		);

		this.introTexts = getIntroTexts();

		var stripeBackground = new FlxBackdrop(Paths.image("f4rp_stripe_bg"), X);
		stripeBackgroundScrollShader = ChainEffectShaderGenerator.getHardcoded(
			[new ScrollEffect({speed: [64.0, 0.0]})]
		);
		stripeBackground.shader = stripeBackgroundScrollShader;
		stripeBackgroundScrollShader.data.time.value = [0.0];
		add(stripeBackground);

		redditUiBackground = new FlxSprite(mainMenuTopLeft.x, mainMenuTopLeft.y);
		add(redditUiBackground);

		var placeBanner = new FlxSprite(0, 0).loadGraphic(Paths.image("mainmenu/place_banner"));
		placeBanner.antialiasing = false;
		// Image is 7px high by default.
		placeBanner.setGraphicSize(0, 7 * 12);
		placeBanner.updateHitbox();
		placeBanner.x = mainMenuTopLeft.x + (FlxG.width - placeBanner.width);
		placeBanner.y = mainMenuTopLeft.y;
		add(placeBanner);

		var placeBannerSeparatorBlock = new FlxSprite(mainMenuTopLeft.x, placeBanner.y + placeBanner.height);
		// It's only minimally smaller than the banner. Same height as the icon may look good, who cares.
		placeBannerSeparatorBlock.makeGraphic(FlxG.width, 96, RedditColor.BACKGROUND);
		add(placeBannerSeparatorBlock);

		var placeIcon = new FlxSprite().loadGraphic(Paths.image("mainmenu/place_icon"));
		placeIcon.setGraphicSize(96, 96);
		placeIcon.updateHitbox();
		placeIcon.x = mainMenuTopLeft.x + 32;
		// Roughly 18% of it clip above the block.
		placeIcon.y = placeBannerSeparatorBlock.y - Std.int(0.18 * placeIcon.height);
		add(placeIcon);

		var subredditTitle = new FlxText(
			placeIcon.x + placeIcon.width + 16, placeBannerSeparatorBlock.y + 8, 0, "place"
		);
		subredditTitle.setFormat("IBM Plex Sans Bold", 32, RedditColor.TEXT);
		add(subredditTitle);
		var subredditSubTitle = new FlxText(
			subredditTitle.x, subredditTitle.y + subredditTitle.height + 2, 0, "r/place"
		);
		subredditSubTitle.setFormat(Paths.font("IBMPlexSans-Medium.ttf"), 16, RedditColor.TEXT_WEAKER);
		add(subredditSubTitle);

		redditPostBayBackground = new FlxSprite(
			mainMenuTopLeft.x + SECTION_PADDING,
			placeBannerSeparatorBlock.y + placeBannerSeparatorBlock.height + SECTION_PADDING
		);
		add(redditPostBayBackground);

		redditPostBaySelectorRectBase = new FlxPoint(
			redditPostBayBackground.x - REDDIT_POST_BAY_SELECTOR_RECT_DEDENT, redditPostBayBackground.y
		);
		redditPostBaySelectorRect = new FlxSprite().makeInflatedPixelGraphic(
			0xFFFFFFFF,
			REDDIT_POST_BAY_WIDTH + REDDIT_POST_BAY_SELECTOR_RECT_DEDENT,
			REDDIT_POST_BORDER_INCL_HEIGHT
		);
		redditPostBaySelectorRect.visible = false;
		add(redditPostBaySelectorRect);

		var postOffset = 0;
		for (entry in redditPostBayPosts) {
			var post = new RedditPost(
				redditPostBayBackground.x,
				redditPostBayBackground.y + postOffset,
				REDDIT_POST_BAY_WIDTH,
				REDDIT_POST_BORDER_INCL_HEIGHT,
				entry.postOptions
			);
			add(post);
			entry.post = post;
			postOffset += REDDIT_POST_BORDER_INCL_HEIGHT - 1;
		}

		var sidebar = new FlxSprite(
			redditPostBayBackground.x + REDDIT_POST_BAY_WIDTH + SECTION_PADDING,
			redditPostBayBackground.y
		);
		add(sidebar);

		sidebarButtons = [];
		var sidebarHeight = SECTION_PADDING;
		for (entry in sidebarEntries) {
			var button = new FlxSprite(sidebar.x + SECTION_PADDING, sidebar.y + sidebarHeight);
			button.makeGraphic(SIDEBAR_WIDTH - 2 * SECTION_PADDING, SIDEBAR_BUTTON_HEIGHT, 0xFFFFFFFF);
			button.color = RedditColor.BACKGROUND;
			button.shader = new BetterRoundedCornerShader(
				SIDEBAR_BUTTON_HEIGHT / 2.0 - PILL_BUTTON_RADIUS_CORRECTION,
				button.width,
				button.height,
				1.0,
				RedditColor.TEXT_WEAK // entry.action == DISCORD ? RedditColor.TEXT_WEAKER : RedditColor.TEXT_WEAK
			);
			add(button);

			var text = new FlxText(0, button.y + 6, 0, entry.text);
			text.setFormat("IBM Plex Sans", 18, /*entry.action == DISCORD ? RedditColor.TEXT_WEAK :*/ RedditColor.TEXT);
			text.x = button.x + (button.width - text.width) / 2.0;
			add(text);

			sidebarButtons.push(button);
			sidebarHeight += SECTION_PADDING + SIDEBAR_BUTTON_HEIGHT;
		}

		var vstrings = [
			'Funkin\' 4 r/place v${modVersion}',
			'Psych Engine Extra v${psychEngineExtraVersion}',
			'Psych Engine v${psychEngineVersion}',
			'Friday Night Funkin\' v${Application.current.meta.get("version")}',
		];
		var textUnderlay = new FlxSprite(sidebar.x + SECTION_PADDING * 0.5, sidebar.y + sidebarHeight - 5);
		textUnderlay.makeInflatedPixelGraphic(RedditColor.INSET, SIDEBAR_WIDTH - SECTION_PADDING, vstrings.length * 20 + 10);
		add(textUnderlay);
		for (string in vstrings) {
			var text = new FlxText(0, sidebar.y + sidebarHeight, 0, string);
			text.setFormat("Reddit Mono Regular", 14, RedditColor.TEXT);
			text.x = (sidebar.x + SIDEBAR_WIDTH - (SECTION_PADDING * 0.5) - 5) - text.width;
			add(text);
			sidebarHeight += 20;
		}
		sidebarHeight += SECTION_PADDING;

		sidebar.makeInflatedPixelGraphic(RedditColor.BACKGROUND, SIDEBAR_WIDTH, sidebarHeight);
		sidebar.shader = new BetterRoundedCornerShader(8.0, SIDEBAR_WIDTH, sidebarHeight, 1.0, RedditColor.SIDEBAR_BORDER);

		achievementsSidebar = new FlxSprite(sidebar.x, sidebar.y + sidebar.height + SECTION_PADDING);
		add(achievementsSidebar);

		achievementsSidebarSelectorRect = new FlxSprite(achievementsSidebar.x + ACHIEVEMENT_IPADDING * 0.5);
		achievementsSidebarSelectorRect.makeInflatedPixelGraphic(
			RedditColor.BACKGROUND_ACTIVE, SIDEBAR_WIDTH - ACHIEVEMENT_IPADDING, ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING
		);
		achievementsSidebarSelectorRect.shader = new BetterRoundedCornerShader(
			8,
			achievementsSidebarSelectorRect.width,
			achievementsSidebarSelectorRect.height,
			1.0,
			0xFFFFFFFF
		);
		achievementsSidebarSelectorRect.visible = false;
		add(achievementsSidebarSelectorRect);

		achievementDisplayTrios = [];
		for (i => entry in [
			for (entry in AchievementManager.getAchievements())
				if (!(entry.isLocked() && entry.achievement.isSecret()))
					entry
		]) {
			achievementDisplayTrios.push(createAchievementTrio(entry, i));
		}
		var achSidebarHeight = achievementDisplayTrios.length * (ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING) + ACHIEVEMENT_IPADDING;
		achievementsSidebar.makeInflatedPixelGraphic(RedditColor.BACKGROUND, SIDEBAR_WIDTH, achSidebarHeight);
		achievementsSidebar.shader = new BetterRoundedCornerShader(
			8.0, SIDEBAR_WIDTH, achSidebarHeight, 1.0, RedditColor.SIDEBAR_BORDER
		);

		// === Initialize main menu's selection web
		selectionWebPostBayNode = new SelectionWebNode(SelectionAction.NONE, SWNID_POST_BAY, true);
		for (postData in redditPostBayPosts) {
			if (postData.selectionAction == null) {
				continue;
			}
			selectionWebPostBayNode.addChild(_createPostSelectionWebNode(postData));
		}
		selectionWebPostBayNode.linkChildrenVertical(true);

		selectionWebSidebarNode = new SelectionWebNode(SelectionAction.NONE, SWNID_SIDEBAR, true);
		for (e in sidebarEntries) {
			selectionWebSidebarNode.addChild(new SelectionWebNode(e.action, -1, false));
		}
		selectionWebSidebarNode.linkChildrenVertical();

		// Populate achievements sidebar and link with sidebar above
		selectionWebAchievementsSidebarNode = new SelectionWebNode(SelectionAction.NONE, SWNID_ACHIEVEMENTS, true);
		for (_ in achievementDisplayTrios) {
			selectionWebAchievementsSidebarNode.addChild(new SelectionWebNode(OPEN_ACHIEVEMENTS_MENU));
		}
		relinkSidebars();

		mainMenuSelectionManager = new SelectionWebManager(selectionWebPostBayNode);
		defaultSelectionNode = selectionWebPostBayNode;

		hiddenPostsNode = new SelectionWebNode(SelectionAction.NONE, SWNID_HIDDEN_POSTS, true);

		readjustPostBayAndSelectionWeb();
		// === Selection web initialization end

		// Title screen stuff below

		modLogo = new FlxSprite().loadGraphic(Paths.image('f4rp_logo'));
		modLogo.setGraphicSize(Std.int(modLogo.width * 2.0));
		modLogo.updateHitbox();
		modLogo.screenCenter();
		modLogo.y -= 36;
		add(modLogo);

		pressToEnterButton = new FlxSprite().loadGraphic(Paths.image('f4rp_title_enter'));
		pressToEnterButton.screenCenter(X);
		pressToEnterButton.y = modLogo.y + modLogo.height + 24;
		add(pressToEnterButton);

		orangeCoverShader = new GradientPixelErasureShader();
		orangeCoverShader.palette.input = new BitmapData(1, 1, true, FlxColor.TRANSPARENT);
		orangeCoverShader.pixel_dimensions.value = [12.0, 12.0];

		orangeCoverSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, RedditColor.CHUNGERINE);
		orangeCoverSprite.shader = orangeCoverShader;
		orangeCoverSprite.visible = false;
		add(orangeCoverSprite);

		// Intro stuff below

		voidCoverShader = new HoleOrganicPixelErasureShader();
		// voidCoverShader.palette.input = new BitmapData(1, 1, true, FlxColor.TRANSPARENT);
		voidCoverShader.eraser_color.value = [0.0, 0.0, 0.0, 0.0];
		voidCoverShader.pixel_dimensions.value = [4.0, 4.0];
		voidCoverShader.deform.value = [1.0, FlxG.width / FlxG.height];

		voidCoverSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		voidCoverSprite.shader = voidCoverShader;
		voidCoverSprite.visible = false;
		add(voidCoverSprite);

		introAlphabetGroup = new FlxSpriteGroup();
		add(introAlphabetGroup);

		susgroundsLogo = new FlxSprite(0, FlxG.height * 0.56).loadGraphic(Paths.image('susgrounds_logo'));
		susgroundsLogo.setGraphicSize(Std.int(susgroundsLogo.width * 4));
		susgroundsLogo.updateHitbox();
		susgroundsLogo.screenCenter(X);
		susgroundsLogo.antialiasing = false;
		susgroundsLogo.visible = false;
		add(susgroundsLogo);

		var flashWarning = (
			'Hey, watch out!\nThis mod contains some flashing lights!\n' +
			'Press [${controls.getFormattedInputNames(Controls.Control.ACCEPT)}] to keep them enabled.\n' +
			'Press [${controls.getFormattedInputNames(Controls.Control.BACK)}] to disable them.\n\n' +
			'You can always change this later in the options menu.'
		);
		flashingNotificationText = new FlxText(0, 0, FlxG.width, flashWarning);
		flashingNotificationText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		flashingNotificationText.screenCenter(Y);
		flashingNotificationText.visible = false;
		add(flashingNotificationText);

		// Ok, all elements created.

		setAndVisualizeDefaultSelection();

		// Make title intro stuff immovable so it's not affected by the camera flying around.
		// (and the striped background too.)
		for (thing in [
			flashingNotificationText, susgroundsLogo, introAlphabetGroup, voidCoverSprite, stripeBackground
		]) {
			thing.scrollFactor.set(0, 0);
		}

		// NOTE: Order of these is important!
		holdTimer = new HoldTimer(0.5, 0.18, 0.08);
		holdTimer.listen(controls.ui_leftP, controls.ui_left);
		holdTimer.listen(controls.ui_downP, controls.ui_down);
		holdTimer.listen(controls.ui_rightP, controls.ui_right);
		holdTimer.listen(controls.ui_upP, controls.ui_up);

		if (skipIntroAndTitle) {
			switchVirtualState(MAIN_MENU);
			return;
		}

		if (FlxG.save.data.flashing == null) {
			switchVirtualState(PRE_TITLE_FLASHING_LIGHTS_WARNING);
		} else {
			switchVirtualState(TITLE_TEXT_INTRO);
		}
	}

	private inline function _createPostSelectionWebNode(postData:PostBayEntry):SelectionWebNode {
		var bayChild = new SelectionWebNode(postData.selectionAction);
		if (postData.weekBlob != null) {
			bayChild.addChild(new SelectionWebNode(START_WEEK,        SWNID_PLAY_NODE));
			bayChild.addChild(new SelectionWebNode(BUMP_DIFFICULTY,   SWNID_DIFFICULTY_NODE));
			bayChild.addChild(new SelectionWebNode(GAMEPLAY_CHANGERS, SWNID_GAMEPLAY_CHANGER_NODE));
			bayChild.linkChildrenHorizontal();
		}
		return bayChild;
	}

	public override function update(dt:Float) {
		super.update(dt);

		voidCoverShader.update(dt);
		stripeBackgroundScrollShader.data.time.value[0] += dt; // same as above but without typing niceness

		if (FlxG.sound.music != null) {
			Conductor.songPosition = FlxG.sound.music.time;
		}

		if (pendingVirtualStateSwitch) {
			// State is gonna switch by the hands of a timer, don't do anything.
			// Do not allow the user to interact.
			return;
		}

		selectionBlinkProgress += dt;
		if (selectionBlinkProgress > SELECTION_BLINK_INTERVAL) {
			selectionBlinkProgress = CoolUtil.wrapModuloFloat(selectionBlinkProgress, SELECTION_BLINK_INTERVAL);
		}
		// var selectionBlinkInterp = 1.0 - Math.pow(((Math.sin(selectionBlinkProgress * SELECTION_BLINK_SPEED - 3.0) + 1.0) * 0.39), 2.0);
		switch (mainMenuSelectionManager.selectionPath[0].id) {
		// TODO: These just turn the elements black for some reason. Even if they did work, they would probably look awful
		// Fix later:tm:

		// case SWNID_POST_BAY:
		// 	if (mainMenuSelectionManager.selectionPath.length == 3) {
		// 		@:privateAccess
		// 		redditPostBayPosts[mainMenuSelectionManager.selectionPath[1].index].post.selectorRect.color = (
		// 			FlxColor.interpolate(RedditColor.HIGHLIGHT_MILD, RedditColor.BACKGROUND_ACTIVE, selectionBlinkInterp)
		// 		);
		// 	} else {
		// 		@:privateAccess
		// 		redditPostBayPosts[mainMenuSelectionManager.selectionPath[1].index].post.backgroundRect.color = (
		// 			FlxColor.interpolate(RedditColor.ELEMENT_BACKGROUND, RedditColor.HIGHLIGHT_MILD, selectionBlinkInterp)
		// 		);
		// 	}
		// case SWNID_ACHIEVEMENTS:
		// 	achievementsSidebarSelectorRect.color = FlxColor.interpolate(RedditColor.BACKGROUND_ACTIVE, 0xFF3A3B3C, selectionBlinkInterp);
		case SWNID_SIDEBAR:
			// NOTE: Looks fairly awful, change or delete
			// sidebarButtons[mainMenuSelectionManager.selectionPath[1].index].color = (
			// 	FlxColor.interpolate(RedditColor.ELEMENT_BACKGROUND, RedditColor.BACKGROUND_ACTIVE, selectionBlinkInterp)
			// );
		default:
		}

		var accept:Bool = controls.ACCEPT;
		var back:Bool = controls.BACK;

		switch (virtualState) {
		case NONE: // nothing
		case PRE_TITLE_FLASHING_LIGHTS_WARNING:
			if (accept != back) {
				if (accept) {
					ClientPrefs.flashing = true;
					ClientPrefs.saveSettings();
				} else {
					ClientPrefs.flashing = false;
					ClientPrefs.saveSettings();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
				scheduleVirtualStateSwitch(TITLE_TEXT_INTRO, 0.32);
			}

		case TITLE_TEXT_INTRO:
			if (accept) {
				switchVirtualState(TITLE);
			}

		case TITLE:
			if (_isAnyKeyPressed()) {
				FlxG.sound.play(Paths.sound("confirmMenu"), 0.7);
				switchVirtualState(TITLE_MAIN_MENU_BETWEEN);
			}

		case TITLE_MAIN_MENU_BETWEEN:
			if (_isAnyKeyPressed()) {
				// User is understandably expressing punkett - Impatience (Funkscop OST), so skip
				// the animation and tween garbage and just instantly throw them into the main menu.
				switchVirtualState(MAIN_MENU);
			}

		case MAIN_MENU:
			var left:Bool = false;
			var right:Bool = false;
			var down:Bool = false;
			var up:Bool = false;
			var scrolls = holdTimer.update(dt, true);
			if (scrolls > 0) {
				switch (holdTimer.activeListener) { // hardcoded as fuck
					case 0: left = true;
					case 1: down = true;
					case 2: right = true;
					case 3: up = true;
					default:
				}
			}
			var prevSelection = mainMenuSelectionManager.selectionPath.copy();
			var selectionPath = mainMenuSelectionManager.selectionPath;
			var toplevelSelection = selectionPath.length == 2;
			var inPost = _isSelectionInPost(selectionPath);
			var difficultyChange = 0;
			var selectionChanged = false;

			#if desktop
			if (FlxG.keys.anyJustPressed(debugKeys)) {
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				// MusicBeatState.switchState(new TextTestState());
				return;
			}
			#end

			if (accept && !back) {
				var action = selectionPath[selectionPath.length - 1].action;
				switch (action) {
					case SELECT_DOWN:
						selectionChanged = mainMenuSelectionManager.selectChild() || selectionChanged;
					case FREEPLAY:
						MusicBeatState.switchState(new FreeplayPlaceState());
						return;
					case SETTINGS:
						LoadingState.loadAndSwitchState(new options.OptionsState());
						return;
					case AWARDS:
						MusicBeatState.switchState(new AchievementsMenuState());
						return;
					case CREDITS:
						MusicBeatState.switchState(new CreditsState());
						// #if MODS_ALLOWED
						// case 'mods':
						// 	MusicBeatState.switchState(new ModsMenuState());
						// #end
						return;
					case DISCORD:
						CoolUtil.browserLoad("https://discord.gg/zwbWabneNa");
					case LOREBOOK:
						MusicBeatState.switchState(new LorebookState());
					case START_WEEK:
						// Following: code to start the song, best described by the words: Zutiefst ranzig.
						// Copied from StoryMenuState.

						var weekBlob = redditPostBayPosts[_selectionToPostIndex(selectionPath)].weekBlob;

						weekBlob.setStaticPlayStateGarbagePrepareWeek();

						LoadingState.loadAndSwitchState(new PlayState(), true);
						return;

					case BUMP_DIFFICULTY:
						difficultyChange = 1;

					case GAMEPLAY_CHANGERS:
						openSubState(new GameplayChangersSubState(staticCamera));
						return;

					case OPEN_ACHIEVEMENTS_MENU:
						var achId = achievementDisplayTrios[selectionPath[1].index].entry.achievement.id;
						MusicBeatState.switchState(new AchievementsMenuState(achId));

					default: // spanish inquisition
				}
			} else if (back) {
				if (toplevelSelection) {
					switchVirtualState(TITLE);
					return;
				} else {
					selectionChanged = mainMenuSelectionManager.selectParent() || selectionChanged;
				}
			}

			if (right != left) {
				var dir = right ? SWND_RIGHT : SWND_LEFT;
				selectionChanged = mainMenuSelectionManager.selectLateral(dir) || selectionChanged;
			}

			if (up != down) {
				var dir = up ? SWND_UP : SWND_DOWN;
				if (inPost && selectionPath[2].id == SWNID_DIFFICULTY_NODE) {
					difficultyChange = up ? 1 : -1;
				} else {
					if (inPost) {
						// Jump out of post if up/down is pressed on non-difficulty
						selectionChanged = mainMenuSelectionManager.selectParent() || selectionChanged;
					}
					selectionChanged = mainMenuSelectionManager.selectLateral(dir) || selectionChanged;
				}
			}

			if (inPost /*extra safety, kinda useless*/ && difficultyChange != 0) {
				var entry = redditPostBayPosts[_selectionToPostIndex(selectionPath)];
				entry.weekBlob.changeDifficulty(difficultyChange);
				entry.post.renameRegion(1, entry.weekBlob.getCurDifficultyDisplayName());
				#if HIGHSCORE_ALLOWED
				var score = entry.weekBlob.getScore();
				entry.post.setKarmaText(formatKarma(score));
				if (!(entry.dontConfigureSubtitle ?? false)) {
					entry.post.setSubtitleText('Score: $score');
				}
				#end
			}
			if (selectionChanged) {
				updateSelectionVisuals(prevSelection);
			}
		}
	}

	private inline function _isAnyKeyPressed():Bool {
		// firstJustPressed takes no exclusion list. Yes, this means if you press a volume key and an acceptable
		// key in the same frame, maybe it won't be registered. Tough luck man, tough luck.
		var fjp = FlxG.keys.firstJustPressed();
		return fjp > -1 && !FlxG.sound.volumeDownKeys.contains(fjp) && !FlxG.sound.volumeUpKeys.contains(fjp);
	}

	override function destroy() {
		super.destroy();
		// exceedingly annoying: The default tween manager clears itself on state switches
		// and the default tween manager is what the music's fadeIn tween is added to.
		FlxG.sound.music.volume = 1.0;
	}

	private inline function _selectionToPostIndex(selection:Array<SelectionWebNode>):Int {
		if (selection[0].id == SWNID_POST_BAY) {
			return selection[1].index;
		}
		if (selection[0].id == SWNID_HIDDEN_POSTS) {
			return hiddenPostNodeIdxToPostBayIdx[selection[1].index];
		}
		return -1;
	}

	private inline function _isSelectionInPost(selection:Array<SelectionWebNode>):Bool {
		return (
			(selection[0].id == SWNID_POST_BAY || selection[0].id == SWNID_HIDDEN_POSTS) &&
			selection.length > 2
		);
	}

	private function updateSelectionVisuals(prevSelection:Array<SelectionWebNode>, leaveCameraAlone:Bool = false) {
		var curSelection = mainMenuSelectionManager.selectionPath;

		if (
			// If the previous selection was in a post
			_isSelectionInPost(prevSelection) &&
			// And the new selection is not or in a different one
			(curSelection.length <= 2 || curSelection[1] != prevSelection[1])
		) {
			// Unselect the old post
			redditPostBayPosts[_selectionToPostIndex(prevSelection)].post.select(-1);
		}

		if (curSelection[0].id == SWNID_POST_BAY || curSelection[0].id == SWNID_HIDDEN_POSTS) {
			var postIndex = _selectionToPostIndex(curSelection);
			var inPost = _isSelectionInPost(curSelection);
			var selrcol:FlxColor = inPost ? RedditColor.CHUNGERINE : RedditColor.TEXT;
			redditPostBaySelectorRect.visible = true;
			redditPostBaySelectorRect.setPosition(
				redditPostBaySelectorRectBase.x,
				redditPostBaySelectorRectBase.y + (REDDIT_POST_BORDER_INCL_HEIGHT - 1) * postIndex
			);
			redditPostBaySelectorRect.setColorTransform(selrcol.redFloat, selrcol.greenFloat, selrcol.blueFloat);

			var post = redditPostBayPosts[postIndex].post;
			if (inPost) {
				post.select(curSelection[2].index);
			}
			if (prevSelection[1] != curSelection[1]) {
				// The selected post has changed, scroll camera.
				if (!leaveCameraAlone) {
					tweenScrollCameraToY(post.y + (REDDIT_POST_BORDER_INCL_HEIGHT / 2.0));
				}
			}
		} else {
			redditPostBaySelectorRect.visible = false;
		}

		if (prevSelection[0].id == SWNID_SIDEBAR) {
			// Selection changed within sidebar (or out of it)
			var button = sidebarButtons[prevSelection[1].index];
			button.color = RedditColor.BACKGROUND;
			cast(button.shader, BetterRoundedCornerShader).inner_border_width.value = [1.0];
			cast(button.shader, BetterRoundedCornerShader).inner_border_color.value = [RedditColor.TEXT_WEAK.redFloat, RedditColor.TEXT_WEAK.greenFloat, RedditColor.TEXT_WEAK.blueFloat];
		}
		if (curSelection[0].id == SWNID_SIDEBAR) {
			// Selection changed into a sidebar button, so mark it active and make the camera scroll.
			var button = sidebarButtons[curSelection[1].index];
			button.color = RedditColor.BACKGROUND_ACTIVE;
			cast(button.shader, BetterRoundedCornerShader).inner_border_width.value = [2.0];
			cast(button.shader, BetterRoundedCornerShader).inner_border_color.value = [RedditColor.TEXT.redFloat, RedditColor.TEXT.greenFloat, RedditColor.TEXT.blueFloat];
			if (!leaveCameraAlone) {
				tweenScrollCameraToY(button.y + button.height / 2.0);
			}
		}

		if (prevSelection[0].id == SWNID_ACHIEVEMENTS) {
			// Selection changed within achievements or out of them
			achievementsSidebarSelectorRect.visible = false;
		}
		if (curSelection[0].id == SWNID_ACHIEVEMENTS) {
			var acht = achievementDisplayTrios[curSelection[1].index];
			achievementsSidebarSelectorRect.visible = true;
			achievementsSidebarSelectorRect.y = acht.icon.y - ACHIEVEMENT_IPADDING * 0.5;
			if (!leaveCameraAlone) {
				tweenScrollCameraToY(acht.icon.y + acht.icon.height / 2.0);
			}
		}
	}

	override function beatHit() {
		super.beatHit();

		if (virtualState == TITLE_TEXT_INTRO) {
			textIntroBeatCounter += 1;
			switch (textIntroBeatCounter) {
				case 1:
					var musicInfo = CoolUtil.playMenuMusic(0);
					FlxG.sound.music.fadeIn(2, 0, 1.0);
					Conductor.changeBPM(musicInfo.bpm);
					allowVirtualStateSwitch = true;
				case 2:
					#if PSYCH_WATERMARKS
					addIntroAlphabets(['Psych Engine by'], 15);
					#else
					addIntroAlphabets(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					#end
				case 4:
					#if PSYCH_WATERMARKS
					addIntroAlphabets(['Shadow Mario', 'RiverOaken', 'shubs'], 15);
					#else
					addIntroAlphabets(['present']);
					#end
				case 5:
					deleteIntroAlphabets();
				case 6:
					#if PSYCH_WATERMARKS
					addIntroAlphabets(['Not associated', 'with'], -40);
					#else
					addIntroAlphabets(['In association', 'with'], -40);
					#end
				case 8:
					addIntroAlphabets(['newgrounds'], -40);
					susgroundsLogo.visible = true;
				case 9:
					deleteIntroAlphabets();
					susgroundsLogo.visible = false;
				case 10:
					addIntroAlphabets([introTexts[selectedIntroTextIdx][0]]);
				case 12:
					addIntroAlphabets([introTexts[selectedIntroTextIdx][1]]);
				case 13:
					deleteIntroAlphabets();
				case 14:
					addIntroAlphabets(['Funkin']);
				case 15:
					addIntroAlphabets(['4']);
				case 16:
					addIntroAlphabets(['r/place']);
				case 18:
					switchVirtualState(TITLE);

			}
		}
		// not using else if or switch as i want this to run as well if the above possibly
		// switches to it.
		if (virtualState == TITLE || virtualState == TITLE_MAIN_MENU_BETWEEN) {
			if (curBeat % 2 == 0) {
				FlxTween.cancelTweensOf(modLogo);
				modLogo.scale.set(2.08, 2.08);
				FlxTween.tween(modLogo, {"scale.x": 2.0, "scale.y": 2.0}, 0.32, {ease: FlxEase.cubeOut});
			}
		}
	}

	private function scheduleVirtualStateSwitch(newState:VirtualMenuState, after:Float) {
		if (pendingVirtualStateSwitch || !allowVirtualStateSwitch) {
			return;
		}
		pendingVirtualStateSwitch = true;
		new FlxTimer().start(after, (_) -> switchVirtualState(newState));
	}

	private function switchVirtualState(newState:VirtualMenuState) {
		if (!allowVirtualStateSwitch) {
			return;
		}

		pendingVirtualStateSwitch = false;
		switch (virtualState) { // read: previous vstate
			case NONE: // nope
			case PRE_TITLE_FLASHING_LIGHTS_WARNING:
				flashingNotificationText.visible = false;

			case TITLE_TEXT_INTRO:
				deleteIntroAlphabets();
				susgroundsLogo.visible = false;

			case TITLE | MAIN_MENU:
				// Effectively insta-finish the cover's full-to-lingering tween
				FlxTween.cancelTweensOf(voidCoverShader);
				// Only relevant if we were in the main menu, terminate tweens cause they pull the camera back down.
				FlxTween.cancelTweensOf(menuCamera);
				voidCoverSprite.visible = true;
				voidCoverShader.hole_radius.value = [700.0];
				voidCoverShader.hole_border_width.value = [128.0];

			case TITLE_MAIN_MENU_BETWEEN:
				// Cancel everything cause it may have been triggered by a skip
				FlxFlicker.stopFlickering(pressToEnterButton);
				// Instafinish the linger-to-disappear tween
				FlxTween.cancelTweensOf(voidCoverShader);
				voidCoverSprite.visible = false;
				// Instafinish (just hide) the orange stuff
				FlxTween.cancelTweensOf(orangeCoverShader);
				orangeCoverSprite.visible = false;
				FlxTween.cancelTweensOf(menuCamera);
				// Camera is adjusted in the MAIN_MENU entry code piece below,
				// no need to make it snap here.
		}

		switch (newState) {
			case NONE: // shouldn't ever be set via this function, do nothing
			case PRE_TITLE_FLASHING_LIGHTS_WARNING:
				commonTitleTextAndFlashingStateEntry();
				flashingNotificationText.visible = true;

			case TITLE_TEXT_INTRO:
				commonTitleTextAndFlashingStateEntry();
				allowVirtualStateSwitch = false; // Not until actual music has been started in first beat.
				selectedIntroTextIdx = FlxG.random.int(0, introTexts.length - 1);
				textIntroBeatCounter = 0;
				// @Square789: This plays a random track silently. Replacing it with nonsensical bpm alone doesn't
				// work for some reason, you actually need to fill FlxG.sound.music to bridge the gap to the first
				// `beatHit` call. Why? Who knows, don't feel like digging the answer to that up now.
				// Do set a relatively high fake bpm though so the gap is shorter.
				if (FlxG.sound.music == null) {
					CoolUtil.playMenuMusic(0);
					Conductor.changeBPM(160);
				}

			case TITLE:
				menuCamera.scroll.copyFrom(
					titleFocusPoint.getPosition().subtract(menuCamera.width / 2.0, menuCamera.height / 2.0)
				);
				FlxTween.tween(
					voidCoverShader,
					{hole_radius_direct: 700.0, hole_border_width_direct: 128.0},
					0.25
				);

			case TITLE_MAIN_MENU_BETWEEN:
				// Set the menu's default selection visuals here so it's absolutely
				// sure it won't be seen changing. This method leaves the camera alone.
				setAndVisualizeDefaultSelection();

				FlxTween.tween( // Make void lingerer disappear
					voidCoverShader,
					{hole_radius_direct: 900.0},
					0.25,
					{onComplete: (_) -> voidCoverSprite.visible = false}
				);
				FlxFlicker.flicker(pressToEnterButton, 0.4, 0.05);
				// Start's value always lower than stop's => start must lead upwards
				orangeCoverShader.gradient_start.value = [0.5, 1.0, 0.0];
				orangeCoverShader.gradient_stop.value = [0.5, 1.5, 1.0];
				orangeCoverSprite.visible = true;
				FlxTween.tween(
					orangeCoverShader,
					{gradient_start_y_direct: -0.26},
					0.8,
					{startDelay: 0.4, ease: FlxEase.cubeIn}
				);
				FlxTween.tween(
					orangeCoverShader,
					{gradient_stop_y_direct: -0.25, gradient_stop_v_direct: 1.0},
					0.775,
					{
						startDelay: 0.45,
						ease: FlxEase.cubeIn,
					}
				);
				FlxTween.tween(
					menuCamera,
					{"scroll.y": mainMenuFocusPoint.y - menuCamera.height / 2.0},
					0.5,
					{startDelay: 1.15, ease: FlxEase.sineOut, onComplete: (_) -> switchVirtualState(MAIN_MENU)}
				);

			case MAIN_MENU:
				// In case the main menu is entered immediately by going back from another state.
				// Shouldn't have a negative effect otherwise.
				menuCamera.scroll.copyFrom(
					mainMenuFocusPoint.getPosition().subtract(menuCamera.width / 2.0, menuCamera.height / 2.0)
				);

		}

		this.virtualState = newState;
	}

	private function commonTitleTextAndFlashingStateEntry() {
		menuCamera.scroll.copyFrom(
			titleFocusPoint.getPosition().subtract(menuCamera.width / 2.0, menuCamera.height / 2.0)
		);
		voidCoverSprite.visible = true;
		voidCoverShader.hole_radius.value = [0.0];
		voidCoverShader.hole_border_width.value = [0.0];
	}

	private function tweenScrollCameraToY(targetY:Float) {
		// Utilizes a deadzone-ish thing to not always center the camera on the latter posts
		var trueTargetY = targetY - (menuCamera.height / 2.0);
		var lowerBar = menuCamera.scroll.y + 136;
		var upperBar = menuCamera.scroll.y - 96;
		if (trueTargetY >= lowerBar) {
			trueTargetY = camera.scroll.y - (lowerBar - trueTargetY);
		} else if (trueTargetY <= upperBar) {
			trueTargetY = camera.scroll.y - (upperBar - trueTargetY);
		} else {
			return;
		} // i don't think anyone in my ancestry or family would be particularly proud
		// if they knew the answer to "so what are you doing in your twenties" is "oh yeah,
		// just reimplementing the reddit ui for a fnf mod's main menu full of weird transitions
		// and strangely confining scroll effects", but as a wise man once said: FUCK IT; WE BALL.

		// Std.int here cause strange imperfections can otherwise appear on... well, everything.
		trueTargetY = Std.int(Math.max(trueTargetY, mainMenuFocusPoint.y - (menuCamera.height / 2.0)));

		// Actually don't do anything if the scroll is too small since tiny jumps look weird
		if (Math.abs(menuCamera.scroll.y - trueTargetY) < 10.0) {
			return;
		}
		FlxTween.cancelTweensOf(menuCamera);
		FlxTween.tween(menuCamera, {"scroll.y": trueTargetY}, 0.125, {ease: FlxEase.quadOut});
	}

	/**
	 * I forgot what this function is meant to do. Fill in deco posts and make sure the stripes
	 * dont leak through at the bottom when an achievement is added i think.
	 */
	private function readjustPostBayAndSelectionWeb() {
		if (redditPostBayPosts.length == 0) {
			throw new ValueException("Es ist kein Post im Haus!");
		}

		// figure out how many bay posts exist/how many are needed depending on the maximum y
		// that may be funneled to `tweenScrollCameraToY`.
		var firstDecoPostIdx = -1;
		var weekPostCount = 0;
		for (i => entry in redditPostBayPosts) {
			if (entry.weekBlob != null) {
				weekPostCount += 1;
			}
			if (entry.selectionAction == null) {
				firstDecoPostIdx = i;
				break;
			}
		}
		var lastTopPostIdx = (firstDecoPostIdx == -1 ? redditPostBayPosts.length : firstDecoPostIdx) - 1;
		var lastSelectablePostIdx = hiddenPostNodeIdxToPostBayIdx.length > 0 ?
			FlxMath.maxInt(lastTopPostIdx, CoolUtil.maxInIntArray(hiddenPostNodeIdxToPostBayIdx)) :
			lastTopPostIdx;
		var lastSelectablePostIdxHasChanged = true;
		while (lastSelectablePostIdxHasChanged) {
			lastSelectablePostIdxHasChanged = false;

			var maxScrollableAchY = achievementDisplayTrios[achievementDisplayTrios.length - 1].icon.y + (ACHIEVEMENT_ICON_SIZE * 0.5);
			var maxScrollablePostBayY = redditPostBayPosts[lastSelectablePostIdx].post.y + (REDDIT_POST_BORDER_INCL_HEIGHT / 2.0);
			var maxScrollableY = Math.max(maxScrollableAchY, maxScrollablePostBayY);
			// Formula copypaste from `tweenScrollCameraToY`.
			// TODO: should really extract some shit to constants/inlines.
			var maxDisplayableY = maxScrollableY + (FlxG.height / 2.0) - 136.0;
			var decoPostsRequired = FlxMath.maxInt(
				0,
				Math.ceil(
					(
						maxDisplayableY -
						(redditPostBayPosts[lastTopPostIdx].post.y + REDDIT_POST_BORDER_INCL_HEIGHT)
					) /
					(REDDIT_POST_BORDER_INCL_HEIGHT - 1.0)
				)
			);
			var decoPostsExisting = redditPostBayPosts.length - lastTopPostIdx - 1;

			// trace(
			// 	'largest displayable Y is $maxDisplayableY, as max scrollable Y is $maxScrollableY ' +
			// 	(maxScrollableAchY > maxScrollablePostBayY ? "(last achievement)" : "(last selectable post(including hidden))") + ". " +
			// 	'From the last non-hidden post, we need $decoPostsRequired decorative posts to stretch there (currently $decoPostsExisting).'
			// );

			// create posts
			if (decoPostsExisting == decoPostsRequired) {
				// return;
			} else if (decoPostsExisting > decoPostsRequired) {
				throw new ValueException("Not designed to shrink tbh.");
			} else {
				var postOffset = (REDDIT_POST_BORDER_INCL_HEIGHT - 1) * redditPostBayPosts.length;
				for (i in decoPostsExisting...decoPostsRequired) {
					var o = i < decoPostPool.length ? decoPostPool[i] : {title: "[unselectable]", thumb: null};
					var upi = redditPostBayPosts.length - weekPostCount;
					var user = upi < usernamePool.length ? usernamePool[upi] : "[none]";

					var entry:PostBayEntry;
					if (i == HIDDEN_POST_OFFSET && xxxRemovedxxxWeekBlob != null) {
						// Trample over the post with XXX
						entry = {
							postOptions: {
								title: "XXX",
								subtitle: 'Posted by u/XXX just now',
								karmaText: formatKarma(xxxRemovedxxxWeekBlob.getScore()),
								thumbnail: null,
								unimportant: true,
								regions: [
									{icon: "comment", text: "Play"},
									{icon: "lightning", text: xxxRemovedxxxWeekBlob.getCurDifficultyDisplayName()},
									{icon: "options", text: "Gameplay Options"}
								],
							},
							dontConfigureSubtitle: true,
							selectionAction: SELECT_DOWN,
							weekBlob: xxxRemovedxxxWeekBlob,
						};
						if (hiddenPostNodeIdxToPostBayIdx.length != 0) {
							throw new ValueException("sanity check failed, more than 1 hidden post");
						}
						hiddenPostsNode.addChild(_createPostSelectionWebNode(entry));
						hiddenPostNodeIdxToPostBayIdx.push(redditPostBayPosts.length);
						lastSelectablePostIdx = redditPostBayPosts.length;
						lastSelectablePostIdxHasChanged = true;
					} else {
						entry = {
							postOptions: {
								title: o.title,
								subtitle: 'Posted by u/$user ${FlxG.random.int(2, 22)} hours ago',
								karmaText: formatKarma(100000 + FlxG.random.int(-20000, 20000)),
								thumbnail: o.thumb,
								unimportant: true,
								regions: [],
							},
						};
					}
					entry.post = new RedditPost(
						redditPostBayBackground.x,
						redditPostBayBackground.y + postOffset,
						REDDIT_POST_BAY_WIDTH,
						REDDIT_POST_BORDER_INCL_HEIGHT,
						entry.postOptions
					);
					add(entry.post);
					redditPostBayPosts.push(entry);
					postOffset += REDDIT_POST_BORDER_INCL_HEIGHT - 1;
				}
			}
		}

		// adjust post bay background rect and main ui background rect
		redditPostBayBackground.makeInflatedPixelGraphic(
			RedditColor.BACKGROUND_ACTIVE,
			REDDIT_POST_BAY_WIDTH,
			(redditPostBayPosts.length * (REDDIT_POST_BORDER_INCL_HEIGHT - 1)) + 1
		);
		redditUiBackground.makeInflatedPixelGraphic(
			RedditColor.MIDNIGHT,
			FlxG.width,
			redditPostBayBackground.y + redditPostBayBackground.height - redditUiBackground.y
		);

		// un-and relink all postbay/sidebar nodes based on y positions
		// Involves really ugly interweave of the selector web and actual on-screen location.
		var sidebarNodes:Array<{node:SelectionWebNode, y:Float}> = [];
		for (i => n in selectionWebSidebarNode.children) {
			sidebarNodes.push({node: n, y: sidebarButtons[i].y + (SIDEBAR_BUTTON_HEIGHT / 2.0)});
		}
		for (i => n in selectionWebAchievementsSidebarNode.children) {
			sidebarNodes.push({node: n, y: achievementDisplayTrios[i].icon.y + (ACHIEVEMENT_ICON_SIZE / 2.0)});
		}
		for (x in sidebarNodes) {
			x.node.left = null;
		}
		for (n in selectionWebPostBayNode.children) {
			n.right = null;
			if (n.children.length > 0) {
				n.lastChild.right = null;
			}
		}
		for (n in hiddenPostsNode.children) {
			n.right = null;
			if (n.children.length > 0) {
				n.lastChild.right = null;
			}
		}
		var nextUnlinkedSidebarNode = 0;
		for (i in 0...(selectionWebPostBayNode.children.length - 1)) {
			var stretchEnd = nextUnlinkedSidebarNode;
			while (stretchEnd < sidebarNodes.length) {
				var candidateY = sidebarNodes[stretchEnd].y;
				if (
					Math.abs(redditPostBayPosts[i].post.y + (REDDIT_POST_BORDER_INCL_HEIGHT / 2.0) - candidateY) >
					Math.abs(redditPostBayPosts[i + 1].post.y + (REDDIT_POST_BORDER_INCL_HEIGHT / 2.0) - candidateY)
				) { // Next post is closer to this sidebar entry.
					break;
				}
				stretchEnd += 1;
			}
			var postNode = selectionWebPostBayNode.children[i];
			if (stretchEnd == nextUnlinkedSidebarNode) { // No sidebar nodes for this post, so assign its right to the most recent one.
				if (nextUnlinkedSidebarNode != 0) {
					linkPostNode(postNode, sidebarNodes[nextUnlinkedSidebarNode - 1].node, false);
				}
			} else {
				for (j in nextUnlinkedSidebarNode...stretchEnd) {
					linkPostNode(postNode, sidebarNodes[j].node, true);
				}
			}
			nextUnlinkedSidebarNode = stretchEnd;
		}

		// Ruin this logic some more by explicitly linking the hidden posts.
		for (i in 0...hiddenPostsNode.children.length) {
			var postIdx = hiddenPostNodeIdxToPostBayIdx[i];
			var postY = redditPostBayPosts[postIdx].post.y;
			// If the post's rect expanded once in each direction overlaps a sidebar entry, consider it a candidate.
			var hpInfluenceYMin = postY - REDDIT_POST_BORDER_INCL_HEIGHT + 1;
			var hpInfluenceYMax = postY + REDDIT_POST_BORDER_INCL_HEIGHT * 2 - 2;
			var nextPostYMin = i == hiddenPostsNode.children.length - 1 ?
				99999999.0 :
				Math.max(postY, redditPostBayPosts[hiddenPostNodeIdxToPostBayIdx[i + 1]].post.y - REDDIT_POST_BORDER_INCL_HEIGHT + 1);
			var hpCandidates = [
				for (sn in sidebarNodes)
					if (hpInfluenceYMin <= sn.y && hpInfluenceYMax > sn.y && nextPostYMin > sn.y)
						{node: sn.node, y: sn.y, yDiff: Math.abs(postY + (REDDIT_POST_BORDER_INCL_HEIGHT / 2.0) - sn.y)}];
			hpCandidates.sort((a, b) -> Std.int(a.yDiff * 100.0 - b.yDiff * 100.0));
			var closestCandidate = hpCandidates.length == 0 ? null : hpCandidates[0];
			for (c in hpCandidates) {
				if (c.node.left == null) {
					if (c == closestCandidate) {
						linkPostNode(hiddenPostsNode.children[i], c.node, true);
					} else {
						c.node.left = hiddenPostsNode.children[i];
					}
				}
			}
		}

		// Either give the last regular post a right one-way connection like above if it's run out
		// (not realistic), else link all remaining sidebar nodes, skipping the hidden ones (.left != null).
		if (nextUnlinkedSidebarNode >= sidebarNodes.length) {
			linkPostNode(selectionWebPostBayNode.lastChild, sidebarNodes[sidebarNodes.length - 1].node, false);
		} else {
			linkPostNode(selectionWebPostBayNode.lastChild, sidebarNodes[nextUnlinkedSidebarNode].node, false);
			for (i in nextUnlinkedSidebarNode...(sidebarNodes.length)) {
				if (sidebarNodes[i].node.left == null) {
					sidebarNodes[i].node.left = selectionWebPostBayNode.lastChild;
				}
			}
		}
	}

	private function linkPostNode(postNode:SelectionWebNode, targetNode:SelectionWebNode, bidirectional:Bool) {
		if (bidirectional) {
			postNode.linkRight(targetNode, true);
			if (postNode.children.length > 0) {
				postNode.lastChild.right = targetNode;
			}
		} else {
			postNode.right = targetNode;
			if (postNode.children.length > 0) {
				postNode.lastChild.right = targetNode;
			}
		}
	}

	private function setAndVisualizeDefaultSelection() {
		var oldSel = mainMenuSelectionManager.selectionPath.copy();
		mainMenuSelectionManager.selectAbsolute(defaultSelectionNode);
		updateSelectionVisuals(oldSel, true);
	}

	function getIntroTexts():Array<Array<String>> {
		var res:Array<Array<String>> = [];
		for (line in CoolUtil.getTextFileLines(Paths.txt("introText"))) {
			var split = line.split("--");
			if (split.length == 2) {
				res.push(split);
			}
		}
		return res.length == 0 ? [["null", "null"]] : res;
	}

	private function addIntroAlphabets(textArray:Array<String>, ?offset:Float = 0) {
		for (text in textArray) {
			var alph:TitleCardFont = new TitleCardFont(0, 0, text, true);
			alph.screenCenter(X);
			alph.y += (introAlphabetGroup.length * 80) + 200 + offset;
			introAlphabetGroup.add(alph);
		}
	}

	private function deleteIntroAlphabets() {
		for (a in introAlphabetGroup) {
			a.destroy();
		}
		introAlphabetGroup.clear();
	}

	override function processAchievementsToShow(?onDisplayDone:Null<Void->Void>):Null<AchievementRegistryEntry> {
		if (virtualState == TITLE_TEXT_INTRO || virtualState == PRE_TITLE_FLASHING_LIGHTS_WARNING) {
			// @Square789: NOTE: hacky copypaste; can't be bothered to change achievement display system again
			// This isn't done in transition scenes as those can't ever open the box in the first place
			if (achievementNotificationBox.isOpen() && achievementNotificationBox.canDisplayNewNotification()) {
				achievementNotificationBox.close();
			}
			return null;
		}
		var newEntry = super.processAchievementsToShow(onDisplayDone);
		if (newEntry == null) {
			return null;
		}

		var trioIdx:Int = -1;
		for (i => trio in achievementDisplayTrios) {
			if (trio.entry.achievement.id == newEntry.achievement.id) {
				trioIdx = i;
				break;
			}
		}
		if (trioIdx == -1) {
			// Must be a secret achievement, find and prepare insertion point
			var insertionIdx = achievementDisplayTrios.length;
			for (i => trio in achievementDisplayTrios) {
				if (trio.entry.index > newEntry.index) {
					insertionIdx = i;
					break;
				}
			}
			// Push following achievement listings away
			for (i in insertionIdx...(achievementDisplayTrios.length)) {
				achievementDisplayTrios[i].icon.y += ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING;
				achievementDisplayTrios[i].name.y += ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING;
			}

			// NOTE: this is technically causing a crappy layering job, probably does not matter.
			var newTrio = createAchievementTrio(newEntry, insertionIdx);

			achievementDisplayTrios.insert(insertionIdx, newTrio);
			selectionWebAchievementsSidebarNode.insertChild(new SelectionWebNode(OPEN_ACHIEVEMENTS_MENU), insertionIdx);
			// NOTE: garbage codewall it's 4:53AM whatever
			var achSidebarHeight = achievementDisplayTrios.length * (ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING) + ACHIEVEMENT_IPADDING;
			achievementsSidebar.scale.y = achievementsSidebar.height = achSidebarHeight;
			cast(achievementsSidebar.shader, BetterRoundedCornerShader).texture_size.value[1] = achSidebarHeight;
			relinkSidebars();
			readjustPostBayAndSelectionWeb();
		} else {
			achievementDisplayTrios[trioIdx].name.text = newEntry.getLayerInfo().name;
			configureAchievementTrioIconSprite(achievementDisplayTrios[trioIdx].icon, newEntry);
		}

		return newEntry;
	}

	private function createAchievementTrio(entry:AchievementRegistryEntry, pos:Int):AchievementDisplayTrio {
		var icon = new FlxSprite(
			achievementsSidebar.x + ACHIEVEMENT_IPADDING,
			achievementsSidebar.y + ACHIEVEMENT_IPADDING + (ACHIEVEMENT_ICON_SIZE + ACHIEVEMENT_IPADDING) * pos
		);
		configureAchievementTrioIconSprite(icon, entry);
		icon.shader = new BetterRoundedCornerShader(8, ACHIEVEMENT_ICON_SIZE, ACHIEVEMENT_ICON_SIZE);

		var nameText = new FlxText(
			icon.x + icon.width + 10,
			icon.y,
			0,
			(entry.isLocked() && entry.achievement.shouldHideNameWhenLocked()) ? "?" : entry.getLayerInfo().name
		);
		nameText.setFormat("IBM Plex Sans Bold", 16, RedditColor.TEXT);
		add(icon);
		add(nameText);

		return {icon: icon, name: nameText, entry: entry};
	}

	private function configureAchievementTrioIconSprite(sprite:FlxSprite, entry:AchievementRegistryEntry) {
		if (entry.isLocked() && entry.achievement.shouldHideIconWhenLocked()) {
			sprite.loadGraphic(Paths.image('achievement_locked'));
		} else {
			sprite.loadGraphic(Paths.image('achievements/${entry.achievement.id}'));
		}
		sprite.setGraphicSize(ACHIEVEMENT_ICON_SIZE, ACHIEVEMENT_ICON_SIZE);
		sprite.updateHitbox();
	}

	private function relinkSidebars() {
		selectionWebAchievementsSidebarNode.linkChildrenVertical();
		if (selectionWebAchievementsSidebarNode.children.length == 0) {
			selectionWebSidebarNode.firstChild.linkUp(selectionWebSidebarNode.lastChild);
		} else {
			selectionWebSidebarNode.firstChild.linkUp(selectionWebAchievementsSidebarNode.lastChild);
			selectionWebSidebarNode.lastChild.linkDown(selectionWebAchievementsSidebarNode.firstChild);
		}
	}

	private static final MAGNITUDE_SUFFIXES = ["", "k", "M", "B", "T", "Q"];
	private static function formatKarma(karma:Int):String {
		var sep:String = switch (ClientPrefs.scoreSeperator) {
			// swap since iirc the fraction separator is the exact
			// opposite of the thousands separator.
			case "Comma": ".";
			case "Period" | _: ",";
		}
		var prefix = karma < 0 ? "-" : "";
		karma = FlxMath.absInt(karma);
		if (karma < 1000) {
			return prefix + Std.string(karma);
		}

		var magnitude = 1;
		while (karma > 999499) { // Trust me on this value
			karma = Std.int(karma / 1000);
			magnitude += 1;
		}

		// This shouldn't even be possible with 32bit ints but whatever
		var suffix = (magnitude >= MAGNITUDE_SUFFIXES.length) ? "?" : MAGNITUDE_SUFFIXES[magnitude];
		var thousands = Std.int(karma / 1000);
		var roundedHundredths = Math.round((karma / 100.0) % 10.0);
		var div = Std.int(roundedHundredths / 10); // Might overflow to 1, otherwise 0.
		var rem = roundedHundredths % 10;

		thousands += div;
		if (thousands < 100) {
			return '$prefix$thousands$sep$rem$suffix';
		}
		return '$prefix${Math.round(karma / 1000)}$suffix';
	}
}
