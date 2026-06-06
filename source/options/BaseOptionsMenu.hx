package options;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

class BaseOptionsMenu extends MusicBeatSubState {
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<TitleCardFont>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedTitleCardFont>;

	private var boyfriend:Character = null;
	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	#if mobile
	var grpButtons:FlxTypedGroup<Button> = new FlxTypedGroup();
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonLEFT:Button;
	var buttonRESET:Button;
	var buttonRIGHT:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	public function new() {
		super();

		if (title == null) title = 'Options';
		if (rpcTitle == null) rpcTitle = 'Options Menu';
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('f4rp_shatter_bg'));
		bg.antialiasing = false;
		bg.setGraphicSize(Std.int(bg.width) * 4);
		bg.screenCenter();
		bg.y += 2;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<TitleCardFont>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedTitleCardFont>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:TitleCardFont = new TitleCardFont(0, 0, title, true, false, 0, 0.5);
		titleText.x += 60;
		titleText.y += 40;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length) {
			var optionText:TitleCardFont = new TitleCardFont(0, 70 * i, optionsArray[i].name, true);
			optionText.isMenuItem = true;
			optionText.x += 300;
			optionText.xAdd = 200;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			} else if (optionsArray[i].type == 'button') {
				optionText.x -= 80;
				optionText.xAdd -= 80;
			} else {
				optionText.x -= 80;
				optionText.xAdd -= 80;
				var valueText:AttachedTitleCardFont = new AttachedTitleCardFont('${optionsArray[i].getValue()}', optionText.width + 80, true);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}

			if (optionsArray[i].showBoyfriend && boyfriend == null) {
				reloadBoyfriend();
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();

		#if mobile
		buttonUP = new Button(10, 130, 'UP');
		buttonDOWN = new Button(buttonUP.x, buttonUP.y + buttonUP.height + 10, 'DOWN');
		buttonLEFT = new Button(834, 564 - 114, 'LEFT');
		buttonRESET = new Button(984, buttonLEFT.y, 'RESET');
		buttonRIGHT = new Button(buttonLEFT.x + 300, buttonLEFT.y, 'RIGHT');
		buttonENTER = new Button(492, buttonLEFT.y, 'ENTER');
		buttonESC = new Button(buttonENTER.x + 136, buttonENTER.y, 'ESC');

		grpButtons.add(buttonUP);
		grpButtons.add(buttonDOWN);
		grpButtons.add(buttonLEFT);
		grpButtons.add(buttonRESET);
		grpButtons.add(buttonRIGHT);
		grpButtons.add(buttonENTER);
		grpButtons.add(buttonESC);
		add(grpButtons);
		#end
	}

	public function addOption(option:Option) {
		if (optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
	}

	override function update(elapsed:Float) {
		if (controls.UI_UP_P #if mobile || buttonUP.justPressed #end)
		{
			changeSelection(-1);
			holdTime = 0;
		}
		if (controls.UI_DOWN_P #if mobile || buttonDOWN.justPressed #end)
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

		if (controls.BACK #if mobile || buttonESC.justPressed #end) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
		}

		if (nextAccept <= 0)
		{
			var usesCheckbox = true;
			if (curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if (usesCheckbox)
			{
				if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			} else if (curOption.type == 'button') {
				if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curOption.change();
				}
			} else if (!down && !up) {
				if (controls.UI_LEFT || controls.UI_RIGHT #if mobile || buttonLEFT.pressed || buttonRIGHT.pressed #end || (FlxG.mouse.wheel != 0 && FlxG.keys.pressed.SHIFT)) {
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P #if mobile || buttonLEFT.justPressed || buttonRIGHT.justPressed #end);
					if (holdTime > 0.5 || pressed) {
						if (pressed) {
							var add:Dynamic = null;
							if (curOption.type != 'string') {
								add = (controls.UI_LEFT #if mobile || buttonLEFT.pressed #end) ? -curOption.changeValue : curOption.changeValue;
							}

							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if (holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.curOption; //lol
									if (controls.UI_LEFT_P #if mobile || buttonLEFT.justPressed #end) --num;
									else num++;

									if (num < 0) {
										num = curOption.options.length - 1;
									} else if (num >= curOption.options.length) {
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
						} else if (curOption.type != 'string') {
							holdValue += curOption.scrollSpeed * elapsed * ((controls.UI_LEFT #if mobile || buttonLEFT.pressed #end) ? -1 : 1);
							if (holdValue < curOption.minValue) holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));
								
								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (curOption.type != 'string') {
						holdTime += elapsed;
					}
				} else if (controls.UI_LEFT_R || controls.UI_RIGHT_R #if mobile || buttonLEFT.justReleased || buttonRIGHT.justReleased #end) {
					clearHold();
				}
			}

			if (controls.RESET #if mobile || buttonRESET.justPressed #end) {
				for (i in 0...optionsArray.length) {
					var leOption:Option = optionsArray[i];
					if (leOption.type != 'button') {
						leOption.setValue(leOption.defaultValue);
						if (leOption.type != 'bool') {
							if (leOption.type == 'string') {
								leOption.curOption = leOption.options.indexOf(leOption.getValue());
							}
							updateTextFrom(leOption);
						}
						leOption.change();
					}
				}
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
				reloadCheckboxes();
			}
		}

		if (boyfriend != null && boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.finished) {
			boyfriend.dance();
		}

		if (nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function updateTextFrom(option:Option) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if (option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	function clearHold() {
		if (holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		holdTime = 0;
	}
	
	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionsArray.length - 1;
		if (curSelected >= optionsArray.length)
			curSelected = 0;

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;
		if (descText.height > 138) {
			descText.y -= (descText.height - 138);
		}

		for (i => item in grpOptions.members) {
			item.targetY = i - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
		for (text in grpTexts) {
			text.alpha = 0.6;
			if (text.ID == curSelected) {
				text.alpha = 1;
			}
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		if (boyfriend != null) {
			boyfriend.visible = optionsArray[curSelected].showBoyfriend;
		}
		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	public function reloadBoyfriend() {
		var wasVisible:Bool = false;
		if (boyfriend != null) {
			wasVisible = boyfriend.visible;
			boyfriend.kill();
			remove(boyfriend);
			boyfriend.destroy();
		}

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		insert(1, boyfriend);
		boyfriend.visible = wasVisible;
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}
