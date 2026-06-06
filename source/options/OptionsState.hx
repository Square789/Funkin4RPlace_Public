package options;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;

using StringTools;
using CoolUtil.InflatedPixelSpriteExt;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = ['Note Colors', #if !mobile 'Controls', #end 'Adjust Delay and Combo', 'Graphics', 'Visuals and UI', 'Gameplay', 'Save Data'];
	private var grpOptions:FlxTypedGroup<TitleCardFont>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var goToPlayState(default, null):Bool = false;

	#if mobile
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	var selectionBackgroundHighlight:FlxSprite;

	var selectorLeft:TitleCardFont;
	var selectorRight:TitleCardFont;

	var holdTime:Float = 0;

	public function new(?goToPlayState:Bool) {
		super();
		if (goToPlayState != null)
			OptionsState.goToPlayState = goToPlayState;
	}

	function openSelectedSubState(label:String) {
		switch(label) {
			case 'Note Colors':
				openSubState(
					#if MULTI_KEY_ALLOWED
					new options.NotesChooseSubState()
					#else
					new options.NotesSubState()
					#end
				);
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals and UI':
				openSubState(new options.VisualsUISubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				LoadingState.loadAndSwitchState(new options.NoteOffsetState());
			case 'Save Data':
				openSubState(new options.SaveDataSubState());
		}
	}

	override function create() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('f4rp_shatter_bg'));
		bg.antialiasing = false;
		bg.setGraphicSize(Std.int(bg.width) * 4);
		bg.screenCenter();
		// bg is 426x240px high, so 1704x960. Centering leaves overrun of 212/70 on each edge; y+2 to get pixel alignment
		bg.y += 2.0;
		add(bg);

		selectionBackgroundHighlight = new FlxSprite().makeInflatedPixelGraphic(0x99000000, FlxG.width, 76);
		add(selectionBackgroundHighlight);

		grpOptions = new FlxTypedGroup<TitleCardFont>();
		add(grpOptions);

		for (i in 0...options.length) {
			var optionText:TitleCardFont = new TitleCardFont(0, 0, options[i], true, false);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			grpOptions.add(optionText);
		}

		selectorLeft = new TitleCardFont(0, 0, '>', true, false);
		add(selectorLeft);
		selectorRight = new TitleCardFont(0, 0, '<', true, false);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		#if mobile
		buttonUP = new Button(10, 240, 'UP');
		add(buttonUP);
		buttonDOWN = new Button(buttonUP.x, buttonUP.y + buttonUP.height + 10, 'DOWN');
		add(buttonDOWN);
		buttonENTER = new Button(904, 574, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + buttonENTER.width + 10, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end

		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		ClientPrefs.saveSettings();
		// @Square789: oh my fucking god who cares about antialiasing it literally makes no difference cause
		// we're just rendering 2D sprites, plus the fact this is like the only place where it's actually
		// applied to everything

		// for (sprite in members)
		// {
		// 	var sprite:Dynamic = sprite; //Make it check for FlxSprite instead of FlxBasic
		// 	var sprite:FlxSprite = sprite; //Don't judge me ok
		// 	if (sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
		// 		sprite.antialiasing = ClientPrefs.globalAntialiasing;
		// 	}
		// }
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (controls.UI_UP_P #if mobile || buttonUP.justPressed #end) {
			changeSelection(-1);
			holdTime = 0;
		}
		if (controls.UI_DOWN_P #if mobile || buttonDOWN.justPressed #end) {
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

		if (controls.BACK #if mobile || buttonESC.justPressed #end) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			if (goToPlayState) {
				StageData.loadDirectory(PlayState.SONG);
				goToPlayState = false;
				LoadingState.loadAndSwitchState(new PlayState(), true);
			} else {
				MusicBeatState.switchState(new MainMenuF4rpState(true));
			}
		}

		if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end) {
			openSelectedSubState(options[curSelected]);
		}
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		for (i => item in grpOptions.members) {
			item.targetY = i - curSelected;

			if (item.targetY == 0) {
				selectionBackgroundHighlight.y = item.y - 4;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
}