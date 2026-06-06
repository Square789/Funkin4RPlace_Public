
import flixel.FlxCamera;
import flixel.FlxG;


/**
 * An alternative to the default shake, which moves the entire target sprite of the camera,
 * instead modifying the scroll values via the `preDraw` and `postDraw` signals.
 * Flimsy, but works.
 */
class WorldShakeCamera extends FlxCamera {
	public var canvasShakeMultiplier:Float;
	public var worldShakeMultiplier:Float;
	var worldScrollBeforeX:Float;
	var worldScrollBeforeY:Float;
	var shakenScrollX:Float;
	var shakenScrollY:Float;

	public override function new(x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0) {
		super(x, y, width, height);

		canvasShakeMultiplier = 0.0;
		worldShakeMultiplier = 1.0;
		worldScrollBeforeX = 0.0;
		worldScrollBeforeY = 0.0;
		shakenScrollX = scroll.x;
		shakenScrollY = scroll.y;

		FlxG.signals.preDraw.add(addShakeOffset);
		FlxG.signals.postDraw.add(removeShakeOffset);
	}

	function addShakeOffset() {
		worldScrollBeforeX = scroll.x;
		worldScrollBeforeY = scroll.y;
		scroll.set(shakenScrollX, shakenScrollY);
	}

	function removeShakeOffset() {
		scroll.set(worldScrollBeforeX, worldScrollBeforeY);
	}

	override function updateShake(elapsed:Float) {
		// just copypaste it
		if (_fxShakeDuration <= 0) {
			shakenScrollX = scroll.x;
			shakenScrollY = scroll.y;
			return;
		}

		_fxShakeDuration -= elapsed;

		if (_fxShakeDuration <= 0) {
			shakenScrollX = scroll.x;
			shakenScrollY = scroll.y;
			if (_fxShakeComplete != null) {
				_fxShakeComplete();
			}
		} else {
			if (_fxShakeAxes.x) {
				var s = FlxG.random.float(-_fxShakeIntensity * width, _fxShakeIntensity * width) * zoom * FlxG.scaleMode.scale.x;
				shakenScrollX = scroll.x + s * worldShakeMultiplier;
				flashSprite.x += s * canvasShakeMultiplier;
			}
			if (_fxShakeAxes.y) {
				var s = FlxG.random.float(-_fxShakeIntensity * height, _fxShakeIntensity * height) * zoom * FlxG.scaleMode.scale.y;
				shakenScrollY = scroll.y + s * worldShakeMultiplier;
				flashSprite.y += s * canvasShakeMultiplier;
			}
		}
	}

	override function destroy() {
		super.destroy();
		FlxG.signals.preDraw.remove(addShakeOffset);
		FlxG.signals.postDraw.remove(removeShakeOffset);
	}
}
