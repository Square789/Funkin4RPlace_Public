package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;
	override function create()
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		// warnText = new FlxText(0, 0, FlxG.width,
		// 	"It looks like you\'re running an   \n
		// 	outdated version of Funkin' 4 r/place (${MainMenuF4rpState.modVersion}),\n
		// 	please update to ${TitleState.updateVersion}!\n
		// 	Press ESCAPE to proceed anyway.\n
		// 	\n
		// 	Thank you for playing Funkin' 4 r/place!",
		// 	32);
		warnText = new FlxText(
			0,
			0,
			FlxG.width,
			(
				"It looks like you're running on an\noutdated version of Funkin' 4 r/place.\n" +
				"Please update, or press ESCAPE to proceed anyway.\n\n" +
				"Thank you for playing Funkin' 4 r/place!"
			)
		);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override function update(elapsed:Float)
	{
		if (!leftState) {
			if (controls.ACCEPT) {
				leftState = true;
				CoolUtil.browserLoad("https://github.com/Funkin4RPlace/Funkin4RPlace/releases");
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						MusicBeatState.switchState(new MainMenuF4rpState(true));
					}
				});
			}
		}
		super.update(elapsed);
	}
}
