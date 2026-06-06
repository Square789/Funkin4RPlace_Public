package;

import flixel.FlxSprite;
import Note;
import StrumNote;

using StringTools;

class TendrilOverlay extends FarpSprite {
    var directions:Array<String> = ['left', 'down', 'up', 'right'];

    public var beepSounds:Array<String> = ['alert', 'alert', 'attack'];

    public var currentBeep:Int = 0;
    public var totalBeeps:Int = 2;
    public var currentAnimationCount:Int = 0;

	private var colorSwap:ColorSwap;
    public var noteTracker:Note;
    public var strumTracker:StrumNote;
    public var crochet:Float;
    public var downscroll:Bool = false;

    public var activated:Bool = false;
    public var hasEntered:Bool = false;
    public var hasAttacked:Bool = false;
    public var isFading:Bool = false;

    public var playBeep:Null<String>;

    public var enterDuration:Float;
    public var attackDuration:Float;

	public var offsetY:Float = -6;

    public function new(note:Note, crochet:Float, downscroll:Bool) {
        noteTracker = note;
        this.crochet = crochet;
        this.downscroll = downscroll;

		colorSwap = new ColorSwap();
        shader = colorSwap.shader;

        super(0, 0);

        var imagePath = 'TENDRILS-' + directions[noteTracker.noteData];
        if (downscroll) imagePath = 'downscroll/' + imagePath;
        imagePath = 'tendril/' + imagePath;
        loadGraphic(Paths.image(imagePath));

        frames = Paths.getSparrowAtlas(imagePath);
        animation.addByPrefix('enter', 'tendril enter', 5, false);
        animation.addByPrefix('beep', 'tendril beep', 0, false);
        animation.addByPrefix('attack', 'tendril attack', 24, false);
        animation.addByPrefix('fade', 'tendril fade', 12, false);

        visible = false;

        setGraphicSize(Std.int(width * note.pixelNoteSize));
        updateHitbox();

        antialiasing = false;
        snapToPixelGrid = true;
        pixelSize = scale.x;
        offsetFix = false;

        { // Calculate durations of animations for timings
            var attackanim = animation.getByName('attack');
            var enteranim = animation.getByName('enter');
            attackDuration = attackanim.numFrames * (1/attackanim.frameRate) * 1000;
            enterDuration = enteranim.numFrames * (1/enteranim.frameRate) * 1000;
        }
    }

    override function update(elapsed:Float) {
        super.update(elapsed);

        if (strumTracker != null) {
            var downset = downscroll ? -height + strumTracker.height : 0;
            var center = (strumTracker.width - (width)) / 2;
            setPosition(strumTracker.x + center, strumTracker.y + offsetY + downset);
        }

        if (noteTracker != null) {
            alpha = noteTracker.alpha;
        }

        if (activated) {
            // the convoluted animation chain

            if (isFading && animation.finished) {
                // goes away and is deleted somewhere in playstate
                activated = false;
                visible = false;
            }

            if (!isFading && hasAttacked && (noteTracker.wasGoodHit || animation.finished)) {
                // the fade animation/the hit animation
                colorSwap.hue = ClientPrefs.arrowHSV[3][noteTracker.noteData][0] / 360;
			    colorSwap.saturation = ClientPrefs.arrowHSV[3][noteTracker.noteData][1] / 100;
			    colorSwap.brightness = ClientPrefs.arrowHSV[3][noteTracker.noteData][2] / 100;
                animation.play('fade');
                isFading = true;
                visible = true;
                return;
            }

            if (!hasEntered) {
                // play the enter animation
                animation.play('enter');
                hasEntered = true;
                visible = true;
                return;
            }

            var animationTime = noteTracker.strumTime - crochet * (totalBeeps - currentAnimationCount);
            var soundTime = (noteTracker.strumTime - crochet * (totalBeeps - currentBeep)) - ClientPrefs.noteOffset;
            if (currentBeep < totalBeeps + 1 && Conductor.songPosition > soundTime) {
                currentBeep += 1;
                playBeep = beepSounds[currentBeep - 1];
            }
            if (currentAnimationCount < totalBeeps + 1 && Conductor.songPosition > animationTime) {
                currentAnimationCount += 1;
                if (currentAnimationCount <= totalBeeps) {
                    animation.play('beep', true, false, currentAnimationCount - 1);
                    visible = true;
                }
            }

            if (!hasAttacked && Conductor.songPosition > (noteTracker.strumTime - attackDuration)) {
                // attacking animation
                animation.play('attack');
                hasAttacked = true;
                visible = true;
                return;
            }
        }
    }
}