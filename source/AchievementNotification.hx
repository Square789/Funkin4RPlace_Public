import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import AchievementManager.AchievementRegistryEntry;

using StringTools;


enum AchievementNotificationBoxState {
	OPENING;
	OPEN;
	CLOSING;
	CLOSED;
}


class AchievementNotificationBox extends FlxSpriteGroup {
	/**
	 * The currently shown notif.
	 * Will never be the one scrolling in, but may be scrolling out.
	 */
	private var currentNotification:AchievementNotification;

	/**
	 * This notification is in the process of scrolling in.
	 */
	private var nextNotification:AchievementNotification;

	private var background:FlxSprite;

	/**
	 * Y position of the box when it is open
	 */
	private var openY:Float;

	/**
	 * Y position of the box when it is closed
	 */
	private var closedY:Float;

	/**
	 * The distance that should always be kept between two scrolling notifications.
	 */
	private var notificationDistance:Float;

	private var displayTimeLeft:Float;

	/**
	 * Function to be called once display of the current achievement is done.
	 */
	private var onDisplayFinish:Null<Void->Void>;

	private var tweenTime:Float;
	private var tweenDuration:Float;
	private var tweenStartY:Float;
	private var tweenTargetY:Float;

	var state(default, null):AchievementNotificationBoxState;

	/**
	 * Whether two achievement notifs are currently being scrolled.
	 * This being true should imply `state` being `OPEN`.
	 */
	private var scrolling:Bool;

	public function new(
		x:Float,
		y:Float,
		?camera:Null<FlxCamera>
	) {
		super(x, y, 3);

		visible = false;
		cameras = camera == null ? null : [camera];

		background = new FlxSprite(0, 0, Paths.image("achievement_notification_box_bg"));
		background.antialiasing = ClientPrefs.globalAntialiasing;
		add(background);

		openY = y;
		closedY = y - (background.height + 1);
		notificationDistance = background.height + 4;

		this.y = closedY;

		state = CLOSED;
		displayTimeLeft = -1.0;
		scrolling = false;
	}

	/**
	 * Whether display of the current achievement is done and `showAchievement` can be
	 * called with everything looking nice.
	 */
	public function canDisplayNewNotification():Bool {
		return (state == CLOSED) || (state == OPEN && nextNotification == null && displayTimeLeft < 0.0);
	}

	public function isOpen():Bool {
		return state == OPEN;
	}

	public function showAchievement(entry:AchievementRegistryEntry, onFinish:Null<Void->Void> = null) {
		if (!canDisplayNewNotification()) {
			return;
		}

		FlxG.sound.play(Paths.sound(entry.getLayerInfo().sound), 0.7);

		onDisplayFinish = onFinish;

		if (state == CLOSED) {
			state = OPENING;
			visible = true;
			_setupTween(y, openY);

			currentNotification = new AchievementNotification(entry, background.width - 12);
			currentNotification.x = currentNotification.y = 16;
			add(currentNotification);
		} else if (state == OPEN) { // Yeah i could omit that check but it's way more understandable
			scrolling = true;
			_setupTween(16, 16 - notificationDistance);

			nextNotification = new AchievementNotification(entry, background.width - 12);
			nextNotification.x = 16;
			nextNotification.y = 16 + notificationDistance;
			nextNotification.clipRect = _makeClipRect(16 + notificationDistance);
			add(nextNotification);
		}
	}

	public function close() {
		if (state == CLOSED || state == CLOSING) {
			return;
		}

		if (scrolling) {
			_instantlyFinishScroll();
		}

		state = CLOSING;
		_setupTween(y, closedY);
	}

	// Rewrite tweens in update so the thing properly stops when its state does.
	// Pause menus and other substates may reveal epic software design fails (of which
	// this codebase has more than enough. (wtf Funkin' 4 r/place OST - Enough reference))
	public override function update(elapsed:Float) {
		// This manages three pseudo-tweens:
		// opening, closing and scrolling.
		switch (state) {
		case OPENING:
			tweenTime += elapsed;
			if (tweenTime > tweenDuration) {
				state = OPEN;
				displayTimeLeft = 2.2;
			}
			y = _calculateTweenY();

		case OPEN:
			if (displayTimeLeft >= 0.0) {
				displayTimeLeft -= elapsed;
				if (displayTimeLeft < 0.0 && onDisplayFinish != null) {
					onDisplayFinish();
				}
			}
			if (scrolling) {
				tweenTime += elapsed;
				if (tweenTime > tweenDuration) {
					_instantlyFinishScroll();
					displayTimeLeft = 2.2;
				} else {
					var curNotifAbsoluteY =  y + _calculateTweenY();
					var nextNotifAbsoluteY = curNotifAbsoluteY + notificationDistance;
					currentNotification.y = curNotifAbsoluteY;
					nextNotification.y    = nextNotifAbsoluteY;
					// not really necessary as it will slide off screen.
					// currentNotification.clipRect = _makeClipRect(curNotifAbsoluteY);
					nextNotification.clipRect = _makeClipRect(nextNotifAbsoluteY);
				}
			}

		case CLOSING:
			tweenTime += elapsed;
			if (tweenTime > tweenDuration) {
				state = CLOSED;
				if (currentNotification != null) {
					remove(currentNotification).destroy();
				}
				visible = false;
			}
			y = _calculateTweenY();

		case CLOSED:
			// Don't blink
		}
	}

	private function _calculateTweenY():Float {
		var tweenRate:Float = FlxMath.bound(tweenTime / tweenDuration, 0.0, 1.0);
		tweenRate = 1 - Math.pow(1 - tweenRate, 4);
		return tweenStartY + ((tweenTargetY - tweenStartY) * tweenRate);
	}

	private function _instantlyFinishScroll() {
		// The scrolling tween is tricky as it doesn't operate on the notification box
		// but its contained messages. Need to do some ugly math to keep them aligned with
		// the notification box
		scrolling = false;
		remove(currentNotification).destroy();
		currentNotification = nextNotification;
		nextNotification = null;

		currentNotification.x = x + 16;
		currentNotification.y = y + 16;
		currentNotification.clipRect = null;
	}

	/**
	 * Convenience function to set the tween variables.
	 */
	private function _setupTween(from:Float, to:Float, duration:Float = 0.5) {
		tweenTime = 0.0;
		tweenDuration = duration;
		tweenStartY = from;
		tweenTargetY = to;
	}

	/**
	 * Creates a clip rect for an achievement notification so that it will only be drawn exactly
	 * where the notification box is; based on the notification's absolute world y position.
	 */
	private inline function _makeClipRect(notificationAbsoluteY:Float):FlxRect {
		return new FlxRect(0, y - notificationAbsoluteY, background.width - 2, background.height - 1);
	}
}


class AchievementNotification extends FlxSpriteGroup {
	public function new(achievementEntry:AchievementRegistryEntry, availableSpace:Float) {
		super();

		var achievementIcon:FlxSprite = new FlxSprite(0, 0)
			.loadGraphic(Paths.image('achievements/${achievementEntry.achievement.id}'));
		achievementIcon.setGraphicSize(150, 150);
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = ClientPrefs.globalAntialiasing;

		var layerInfo = achievementEntry.getLayerInfo();
		var imagePadX = achievementIcon.width + 15;
		var achievementName:FlxText = new FlxText(
			imagePadX,
			achievementIcon.y,
			availableSpace - imagePadX,
			layerInfo.name,
			20
		);
		achievementName.setFormat(Paths.font("RedditMono-Regular.ttf"), 20, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set(0, 0);
		achievementName.antialiasing = ClientPrefs.globalAntialiasing;

		var achievementText:FlxText = new FlxText(
			achievementName.x,
			achievementName.y + 24,
			availableSpace - imagePadX - 30,
			layerInfo.desc,
			16
		);
		achievementText.setFormat(Paths.font("Inter-Regular.otf"), 16, FlxColor.WHITE, LEFT);
		achievementText.scrollFactor.set(0, 0);
		achievementText.antialiasing = ClientPrefs.globalAntialiasing;

		for (thing in [achievementName, achievementText, achievementIcon]) {
			add(thing);
		}
	}
}
