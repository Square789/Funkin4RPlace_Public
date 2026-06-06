
using flixel.system.FlxAssets.FlxShader;


class TransparencyMaskShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		#define uv openfl_TextureCoordv

		uniform sampler2D mask;
		uniform float obscurance;

		void main() {
			float v = flixel_texture2D(mask, uv).r;
			if (obscurance >= v) {
				gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
			} else {
				gl_FragColor = flixel_texture2D(bitmap, uv);
			}
		}
	')

	public var obscurance_direct(get, set):Float;

	public function new(angle:Float) {
		super();
		this.obscurance.value = [1.0];
	}

	public function get_obscurance_direct():Float {
		return this.obscurance.value[0];
	}
	public function set_obscurance_direct(v:Float):Float {
		return this.obscurance.value[0] = v;
	}
}