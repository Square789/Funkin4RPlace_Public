package options;

import SkinData.SkinFileData;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

class NotesChooseSubState extends MusicBeatSubState {
    private static var curSelected:Int = 0;
    var optionShit:Array<String> = [];

	var grpOptions:FlxTypedGroup<TitleCardFont>;

    #if mobile
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

    override function create()
	{
		#if MULTI_KEY_ALLOWED
        for (i in 0...Note.MAX_KEYS) {
		#else
		{ var i = 3;
		#end
			optionShit.push('${i + 1}K');
		}

		// var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		// bg.color = 0xFFea71fd;
		// bg.screenCenter();
		// bg.antialiasing = ClientPrefs.globalAntialiasing;
		// add(bg);
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('f4rp_shatter_bg'));
		bg.setGraphicSize(Std.int(bg.width) * 4);
		bg.screenCenter();
		bg.y += 2;
		add(bg);

		grpOptions = new FlxTypedGroup<TitleCardFont>();
		add(grpOptions);

		for (i in 0...optionShit.length) {
			var optionText:TitleCardFont = new TitleCardFont(0, (10 * i), optionShit[i], true, false);
			optionText.isMenuItem = true;
            optionText.screenCenter(X);
            optionText.forceX = optionText.x;
            optionText.yAdd = -55;
			optionText.yMult = 60;
			optionText.targetY = i;
			grpOptions.add(optionText);
		}
		changeSelection();

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

	var holdTime:Float = 0;
	var firstFramePass:Bool = false;
    override function update(elapsed:Float) {
        var shiftMult:Int = 1;
        if (FlxG.keys.pressed.SHIFT) shiftMult = 3;
        if (controls.UI_UP_P || #if mobile buttonUP.justPressed #else FlxG.mouse.wheel > 0 #end) {
            changeSelection(-shiftMult);
			holdTime = 0;
        }
        if (controls.UI_DOWN_P || #if mobile buttonDOWN.justPressed #else FlxG.mouse.wheel < 0 #end) {
            changeSelection(shiftMult);
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
				changeSelection((checkNewHold - checkLastHold) * (up ? -shiftMult : shiftMult));
			}
		}

        if (controls.BACK #if mobile || buttonESC.justPressed #end) {
            close();
            FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
        }

        if (firstFramePass && (controls.ACCEPT || #if mobile buttonENTER.justPressed #else FlxG.mouse.justPressed #end)) {
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            openSubState(new options.NotesSubState(curSelected + 1));
        }
		super.update(elapsed);
		firstFramePass = true;
	}

    function changeSelection(change:Int = 0) {
        curSelected += change;
        if (curSelected < 0)
            curSelected = optionShit.length - 1;
        if (curSelected >= optionShit.length)
            curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

            item.alpha = 0.6;
            if (item.targetY == 0) {
                item.alpha = 1;
            }
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
}

class NotesSubState extends MusicBeatSubState
{
	var curSelected:Int = 0;
	private static var typeSelected:Int = 0;
	private var grpNumbers:FlxTypedGroup<TitleCardFont>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	var curValue:Float = 0;
	var holdTime:Float = 0;
	var nextAccept:Int = 5;
	var keyAmount:Int = 4;
	var currentData:Array<Array<Int>>;

	var blackBG:FlxSprite;
	var hsbText:TitleCardFont;

	var camFollow:FlxObject;
	var camFollowPos:FlxObject;

	var posX = 230;

	#if mobile
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonLEFT:Button;
	var buttonRESET:Button;
	var buttonRIGHT:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	public function new(keyAmount:Int = 4) {
		super();
		this.keyAmount = keyAmount;
		currentData = ClientPrefs.arrowHSV[keyAmount - 1];
	}

	override function create()
	{
		resetCameraOnClose = true;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('f4rp_shatter_bg'));
		bg.antialiasing = false;
		bg.setGraphicSize(Std.int(bg.width) * 4);
		bg.screenCenter();
		bg.y += 2;
		bg.scrollFactor.set(0, 0);
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);
		FlxG.camera.follow(camFollowPos, null, 1);
		
		blackBG = new FlxSprite(posX - 25).makeGraphic(870, 200, FlxColor.BLACK);
		blackBG.alpha = 0.4;
		blackBG.scrollFactor.set(0, 1);
		add(blackBG);

		grpNotes = new FlxTypedGroup<FlxSprite>();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup<TitleCardFont>();
		add(grpNumbers);

		var skin = SkinData.getSkinFile(Noteskin, 'NOTE_assets');
		for (i in 0...currentData.length) {
			var offset:Float = 35 - (Math.max(currentData.length, 4) - 4) * 90;
			var yPos:Float = (165 * i) + offset;
			for (j in 0...3) {
				var optionText:TitleCardFont = new TitleCardFont(0, yPos + 60, '0', true);
				optionText.text = Std.string(currentData[i][j]);
				optionText.x = posX + (225 * j) + 250;
				optionText.scrollFactor.set(0, 1);
				grpNumbers.add(optionText);
			}

			var note:FlxSprite = new FlxSprite(posX, yPos);
			note.frames = Paths.getSparrowAtlas(skin.image);
			var animations:Array<String> = CoolUtil.coolArrayTextFile(Paths.txt('note_colors'))[keyAmount-1];
			note.animation.addByPrefix('idle', '${animations[i]}0');
			note.animation.play('idle');
			note.setGraphicSize(160);
			note.updateHitbox();
			note.antialiasing = ClientPrefs.globalAntialiasing && !skin.pixel;
			note.scrollFactor.set(0, 1);
			grpNotes.add(note);

			var newShader:ColorSwap = new ColorSwap();
			note.shader = newShader.shader;
			newShader.hue = currentData[i][0] / 360;
			newShader.saturation = currentData[i][1] / 100;
			newShader.brightness = currentData[i][2] / 100;
			shaderArray.push(newShader);
		}

		hsbText = new TitleCardFont(0, 0, " Hue                 Saturation            Brightness", false, false, 0, 1);
		hsbText.x = posX + 240;
		hsbText.scrollFactor.set(0, 1);
		add(hsbText);

		changeSelection();

		#if mobile
		buttonUP = new Button(10, 130, 'UP');
		add(buttonUP);
		buttonDOWN = new Button(buttonUP.x, buttonUP.y + buttonUP.height + 10, 'DOWN');
		add(buttonDOWN);
		buttonLEFT = new Button(834, 564, 'LEFT');
		add(buttonLEFT);
		buttonRESET = new Button(984, buttonLEFT.y, 'RESET');
		add(buttonRESET);
		buttonRIGHT = new Button(buttonLEFT.x + 300, buttonLEFT.y, 'RIGHT');
		add(buttonRIGHT);
		buttonENTER = new Button(492, 564, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + 136, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end

		super.create();
	}

	var changingNote:Bool = false;
	override function update(elapsed:Float) {
		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		
		if (changingNote) {
			if (holdTime < 0.5) {
				if (controls.UI_LEFT_P #if mobile  || buttonLEFT.justPressed #end) {
					updateValue(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				} else if (controls.UI_RIGHT_P #if mobile || buttonRIGHT.justPressed #end) {
					updateValue(1);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				} else if (controls.RESET #if mobile || buttonRESET.justPressed #end) {
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				}
				if (controls.UI_LEFT_R || controls.UI_RIGHT_R #if mobile || buttonLEFT.justReleased || buttonRIGHT.justReleased #end) {
					holdTime = 0;
				} else if (controls.UI_LEFT || controls.UI_RIGHT #if mobile || buttonLEFT.pressed || buttonRIGHT.pressed #end) {
					holdTime += elapsed;
				}
			} else {
				var add:Float = 90;
				switch(typeSelected) {
					case 1 | 2: add = 50;
				}
				if (controls.UI_LEFT #if mobile || buttonLEFT.pressed #end) {
					updateValue(elapsed * -add);
				} else if (controls.UI_RIGHT #if mobile || buttonRIGHT.pressed #end) {
					updateValue(elapsed * add);
				}
				if (controls.UI_LEFT_R || controls.UI_RIGHT_R #if mobile || buttonLEFT.justReleased || buttonRIGHT.justReleased #end) {
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					holdTime = 0;
				}
			}
		} else {
			if (currentData.length > 1) {
				if (controls.UI_UP_P #if mobile || buttonUP.justPressed #end) {
					changeSelection(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P #if mobile || buttonDOWN.justPressed #end) {
					changeSelection(1);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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
			}
			if (controls.UI_LEFT_P #if mobile || buttonLEFT.justPressed #end) {
				changeType(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
			if (controls.UI_RIGHT_P #if mobile || buttonRIGHT.justPressed #end) {
				changeType(1);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
			if (controls.RESET #if mobile || buttonRESET.justPressed #end) {
				for (i in 0...3) {
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
			if ((controls.ACCEPT #if mobile || buttonENTER.justPressed #end) && nextAccept <= 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changingNote = true;
				holdTime = 0;
				for (i in 0...grpNumbers.length) {
					var item = grpNumbers.members[i];
					item.alpha = 0;
					if ((curSelected * 3) + typeSelected == i) {
						item.alpha = 1;
					}
				}
				for (i in 0...grpNotes.length) {
					var item = grpNotes.members[i];
					item.alpha = 0;
					if (curSelected == i) {
						item.alpha = 1;
					}
				}
				super.update(elapsed);
				return;
			}
		}

		if (controls.BACK #if mobile || buttonESC.justPressed #end || (changingNote && (controls.ACCEPT #if mobile || buttonENTER.justPressed #end))) {
			if (!changingNote) {
				close();
			} else {
				changeSelection();
			}
			changingNote = false;
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
		}

		if (nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = currentData.length-1;
		if (curSelected >= currentData.length)
			curSelected = 0;

		curValue = currentData[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
		for (i in 0...grpNotes.length) {
			var item = grpNotes.members[i];
			item.alpha = 0.6;
			item.setGraphicSize(Std.int(160 * 0.75));
			if (curSelected == i) {
				item.alpha = 1;
				item.setGraphicSize(160);
				hsbText.y = item.y - 10;
				blackBG.y = item.y - 20;
				camFollow.setPosition(item.getGraphicMidpoint().x, item.getGraphicMidpoint().y);
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function changeType(change:Int = 0) {
		typeSelected += change;
		if (typeSelected < 0)
			typeSelected = 2;
		if (typeSelected > 2)
			typeSelected = 0;

		curValue = currentData[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
	}

	function resetValue(selected:Int, type:Int) {
		curValue = 0;
		ClientPrefs.arrowHSV[keyAmount - 1][selected][type] = 0;
		switch(type) {
			case 0: shaderArray[selected].hue = 0;
			case 1: shaderArray[selected].saturation = 0;
			case 2: shaderArray[selected].brightness = 0;
		}

		var item = grpNumbers.members[(selected * 3) + type];
		item.text = '0';
	}
	function updateValue(change:Float = 0) {
		curValue += change;
		var roundedValue:Int = Math.round(curValue);
		var max:Float = 180;
		switch(typeSelected) {
			case 1 | 2: max = 100;
		}

		if (roundedValue < -max) {
			curValue = -max;
		} else if (roundedValue > max) {
			curValue = max;
		}
		roundedValue = Math.round(curValue);
		ClientPrefs.arrowHSV[keyAmount - 1][curSelected][typeSelected] = roundedValue;

		switch(typeSelected) {
			case 0: shaderArray[curSelected].hue = roundedValue / 360;
			case 1: shaderArray[curSelected].saturation = roundedValue / 100;
			case 2: shaderArray[curSelected].brightness = roundedValue / 100;
		}

		var item = grpNumbers.members[(curSelected * 3) + typeSelected];
		item.text = Std.string(roundedValue);
	}
}