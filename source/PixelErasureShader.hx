package;

import haxe.Template;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameter;


private final PES_FRAGMENT_TEMPLATE = new Template('
#pragma header

uniform sampler2D palette;

uniform float seed;
uniform vec2 pixel_dimensions;
// NOTE: offset doesn\'t really do what i want it to.
// I guess it does work for really small values and if the spritesheet has some space.
// (Which it realistically won\'t. Hmm.)
uniform vec2 offset;
uniform bool always_pixelate;
uniform float more_void;
uniform bool ignore_alpha;
::foreach additionalUniforms::
uniform ::decl::;
::end::

vec4 lookup_color(float indexer) {
	return texture2D(palette, vec2((indexer - more_void) * (1.0 / (1.0 - more_void)), 0));
}

// Yoinked from:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0
// Had to be modified to not make whatever version of OpenGL this is complain.
// This thing isn\'t really random at all or its randomness depends on some weird behavior of
// the GPU, but whatever.

// Will return a random value between 0.0 and 1.0, end-exclusive.
float random2D(vec2 co) {
	float a = 12.9898;
	float b = 78.233;
	float c = 43758.5453;
	float dt = dot(co.xy, vec2(a, b));
	float sn = mod(dt, 3.14);
	return fract(sin(sn) * c);
}

void main() {
	vec2 screen_pixel_size = ::textureSizeExpr:: / pixel_dimensions;
	vec2 processed_texture_coords = (
		// Extrapolate the texcoord here, floor it to get the pixelation effect
		// and then div it back to the 0.0..1.0 range.
		floor(openfl_TextureCoordv * screen_pixel_size) / screen_pixel_size +
		// Add an offset because something about pixels always being centered?
		// Looks better when toggling pixelation, no edge sprite bleeding for now afaict
		(1.0 / ::textureSizeExpr::) * (offset + (0.5 * pixel_dimensions))
	);

	float alpha = ignore_alpha ? 1.0 : flixel_texture2D(bitmap, processed_texture_coords).a;
	float rando = random2D(processed_texture_coords * seed);

	::randoMinimumThresholdCalculationSource::

	// @CoolingTool: making this an else if branch for `more_void` :(((, lord forgive me
	if (rando < more_void) {
		gl_FragColor = vec4(0, 0, 0, alpha);
	} else if (rando >= ::randoPixelizationMinimumThresholdExpr::) {
		// Alpha multiplication is necessary to not make translucent areas of the sprite
		// pixelated.
		gl_FragColor = vec4(lookup_color(random2D(vec2(rando, 1.0 - rando))) * alpha);
	} else {
		gl_FragColor = flixel_texture2D(
			bitmap,
			always_pixelate ? processed_texture_coords : openfl_TextureCoordv
		);
	}
}
');
private function setPixelErasureShaderTemplateContextDefaults(context:Dynamic):Dynamic {
	if (context.textureSizeExpr == null)                        context.textureSizeExpr = "openfl_TextureSize";
	if (context.additionalUniforms == null)                     context.additionalUniforms = [];
	if (context.randoMinimumThresholdCalculationSource == null) context.randoMinimumThresholdCalculationSource = "";
	if (context.randoPixelizationMinimumThresholdExpr == null)  context.randoPixelizationMinimumThresholdExpr = "0.0";
	return context;
}

/**
 * Base for the pixel erasure shaders. It contains the following uniforms:
 * - palette (sampler): The colors to pick from. This must be a one-row image.
 * - seed (float): Constantly modify this to affect the random seed value, otherwise the
 *                 pixelation effect will be static on no changes. Also, try not to set it to 0.
 * - pixel_dimensions (vec2): Actual screen size pixels for each pixel
 *                            (Still influenced by camera zoom and sprite scaling)
 * - offset (vec2): Offset in screen pixels. Pretty unstable, keep this to small values or the sprite
 *                  will leak into other animation frames.
 *                  (Recommended to not exceed pixel_dimensions / 2).
 * - always_pixelate (bool): Whether to always run a pixelization effect or keep areas that are not
 *                           affected like they are originally. (Does not apply offset in safe areas then).
 * - more_void (float): Increases the chances of getting the first color in the palette by checking if
 *                      indexer is less than more_void. If it isn't then indexer is remapped to the range 0.0 - 1.0.
 * - ignore_alpha (bool): Ignores existing alpha on the sprite and will always replace it with the exact
 *                        palette colors.
**/
private class PESBase extends RuntimeShader {
	public var palette:ShaderInput<openfl.display.BitmapData>;
	public var seed:ShaderParameter<Float>;
	public var pixel_dimensions:ShaderParameter<Float>;
	public var offset:ShaderParameter<Float>;
	public var always_pixelate:ShaderParameter<Bool>;
	public var more_void:ShaderParameter<Float>;
	public var ignore_alpha:ShaderParameter<Bool>;

	public var more_void_direct(get, set):Float;

	private var seedChangeProgress:Float;
	private var seedChangeThreshold:Float;

	public function new(templateContext:Dynamic, seedChangeThreshold:Float = -1.0) {
		super(PES_FRAGMENT_TEMPLATE.execute(setPixelErasureShaderTemplateContextDefaults(templateContext)));

		var file = Paths.image("palette");
		this.palette = data.palette;                   this.palette.input = file.bitmap;
		this.seed = data.seed;                         this.seed.value = [13.37];
		this.pixel_dimensions = data.pixel_dimensions; this.pixel_dimensions.value = [1.0, 1.0];
		this.offset = data.offset;                     this.offset.value = [0.0, 0.0];
		this.always_pixelate = data.always_pixelate;   this.always_pixelate.value = [false];
		this.more_void = data.more_void;               this.more_void.value = [0.0];
		this.ignore_alpha = data.ignore_alpha;         this.ignore_alpha.value = [false];
		
		this.seedChangeProgress = 0.0;
		this.seedChangeThreshold = seedChangeThreshold;
	}

	public function update(dt:Float) {
		if (seedChangeThreshold < 0.0) {
			return;
		} else if (seedChangeThreshold == 0.0) {
			this.seed.value[0] += 0.069;
		} else {
			seedChangeProgress += dt;
			while (seedChangeProgress >= seedChangeThreshold) {
				seedChangeProgress -= seedChangeThreshold;
				this.seed.value[0] += 0.420;
			}
		}
	}

	public function set_more_void_direct(newV:Float):Float {
		return this.more_void.value[0] = newV;
	}
	public function get_more_void_direct():Float {
		return this.more_void.value[0];
	}
}

/**
 * Shader that pixelates a sprite and turns some of these pixels into random colors
 * chosen from the r/place 2022 palette.
 * The shader has the following unique uniforms:
 * - pixel_health (float): Percentage of the sprite that should be covered in random pixels (0..1).
 *
 * *For other uniforms, see documentation of the parent class.*
**/
class PixelErasureShader extends PESBase {
	public var pixel_health:ShaderParameter<Float>;
	public var pixel_health_direct(get, set):Float;

	public function new(seedChangeThreshold:Float = -1.0) {
		super(
			{
				additionalUniforms: [{decl: "float pixel_health"}],
				randoPixelizationMinimumThresholdExpr: "pixel_health",
			},
			seedChangeThreshold
		);

		this.pixel_health = data.pixel_health;
		this.pixel_health.value = [1.0];
	}

	public function set_pixel_health_direct(newV:Float):Float {
		return this.pixel_health.value[0] = newV;
	}
	public function get_pixel_health_direct():Float {
		return this.pixel_health.value[0];
	}
}

/**
 * Shader that pixelates a sprite and turns some of these pixels into random colors
 * chosen from the r/place 2022 palette. The texture size must be set manually, which can be
 * handy for scaled sprites.
 * The shader has the following unique uniforms:
 * - pixel_health (float): Percentage of the sprite that should be covered in random pixels (0..1). *
 * - manual_texture_size (vec2): Size of the texture that should be operated by, in pixels.
 *                               For example, if you have a 4x6 FlxSprite with a scale factor of 4, this should
 *                               be set to 16, 24 for the shader to not overshoot the actual screen pixel size.
 * *For other uniforms, see documentation of the parent class.*
**/
class ManualTexSizePixelErasureShader extends PESBase {
	public var pixel_health:ShaderParameter<Float>;
	public var pixel_health_direct(get, set):Float;
	public var manual_texture_size:ShaderParameter<Float>;

	public function new(seedChangeThreshold:Float = -1.0) {
		super(
			{
				additionalUniforms: [{decl: "float pixel_health"}, {decl: "vec2 manual_texture_size"}],
				randoPixelizationMinimumThresholdExpr: "pixel_health",
				textureSizeExpr: "manual_texture_size",
			},
			seedChangeThreshold
		);

		this.pixel_health = data.pixel_health;
		this.pixel_health.value = [1.0];

		this.manual_texture_size = data.manual_texture_size;
		this.manual_texture_size.value = [1.0, 1.0];
	}

	public function set_pixel_health_direct(newV:Float):Float {
		return this.pixel_health.value[0] = newV;
	}
	public function get_pixel_health_direct():Float {
		return this.pixel_health.value[0];
	}
}

/**
 * Shader that pixelates a sprite and turns some of these pixels into random colors
 * chosen from the a palette, this time with a gradient.
 * The shader has the following unique uniforms:
 * - gradient_start (vec3): Start of the pixel health gradient: x, y, value.
 * - gradient_stop (vec3): Stop of the pixel health gradient: x, y, value.
 *
 * For these two: Start's value must ALWAYS be lower than stop's. This is not done in the shader to
 * save a min/max swap and out of laziness. (0.0, 0.0) is the top left corner and (1.0, 1.0) should be the
 * bottom right. You're gonna have to figure out the pixel/resolution math for more exact stuff, apologies.
 * Also, if you want to study the code, I think the names are swapped. You'd expect the gradient progress to
 * increase from start to stop, but the exact opposite is the case. Oops.
 *
 * *For other uniforms, see documentation of the parent class.*
 */
class GradientPixelErasureShader extends PESBase {
	public var gradient_start:ShaderParameter<Float>;
	public var gradient_start_x_direct(get, set):Float;
	public var gradient_start_y_direct(get, set):Float;
	public var gradient_start_v_direct(get, set):Float;

	public var gradient_stop:ShaderParameter<Float>;
	public var gradient_stop_x_direct(get, set):Float;
	public var gradient_stop_y_direct(get, set):Float;
	public var gradient_stop_v_direct(get, set):Float;

	public function new(seedChangeThreshold:Float = -1.0) {
		super(
			{
				additionalUniforms: [{decl: "vec3 gradient_start"}, {decl: "vec3 gradient_stop"}],
				randoPixelizationMinimumThresholdExpr: "local_pixel_health",
				randoMinimumThresholdCalculationSource: "
					// Cool formula, i still do not understand it
					// https://gamedev.stackexchange.com/questions/125218/linear-gradient-with-angle-formula
					vec2 diff = gradient_start.xy - gradient_stop.xy;
					float gradient_progress = (
						dot(processed_texture_coords - gradient_stop.xy, diff) /
						dot(diff, diff)
					);
					float local_pixel_health = clamp(
						mix(gradient_stop.z, gradient_start.z, gradient_progress),
						gradient_start.z,
						gradient_stop.z
					);
				",
			},
			seedChangeThreshold
		);

		this.gradient_start = data.gradient_start; this.gradient_start.value = [0.0, 0.0, 1.0];
		this.gradient_stop = data.gradient_stop;   this.gradient_stop.value =  [0.0, 1.0, 1.0];
	}

	public function set_gradient_start_x_direct(newV:Float):Float {
		return gradient_start.value[0] = newV;
	}
	public function get_gradient_start_x_direct():Float {
		return gradient_start.value[0];
	}

	public function set_gradient_start_y_direct(newV:Float):Float {
		return gradient_start.value[1] = newV;
	}
	public function get_gradient_start_y_direct():Float {
		return gradient_start.value[1];
	}

	public function set_gradient_start_v_direct(newV:Float):Float {
		return gradient_start.value[2] = newV;
	}
	public function get_gradient_start_v_direct():Float {
		return gradient_start.value[2];
	}

	public function set_gradient_stop_x_direct(newV:Float):Float {
		return gradient_stop.value[0] = newV;
	}
	public function get_gradient_stop_x_direct():Float {
		return gradient_stop.value[0];
	}

	public function set_gradient_stop_y_direct(newV:Float):Float {
		return gradient_stop.value[1] = newV;
	}
	public function get_gradient_stop_y_direct():Float {
		return gradient_stop.value[1];
	}

	public function set_gradient_stop_v_direct(newV:Float):Float {
		return gradient_stop.value[2] = newV;
	}
	public function get_gradient_stop_v_direct():Float {
		return gradient_stop.value[2];
	}
}

/**
 * Pixel erasure shader that operates by creating a hole in the center of a sprite.
 * The shader has the following unique uniforms:
 * NOTE: THIS SHADER IS INTENTIONALLY HARDCODED TO ALWAYS USE ZERO ALPHA WHEN A PIXEL IS AFFECTED.
 * BECAUSE OPENFL IS SATAN.
 * IT'S ONLY USED IN A SINGLE PLACE, SO THIS SHOULD BE FINE.
 * - hole_radius (float): Radius of the hole, in sprite pixels.
 * - hole_border_width (float): Border width of the hole, in sprite pixels.
 *                              The pixel health chance will run from 0 to 1 in this border, which expands
 *                              equally in both directions from the radius.
 * - deform (float): Deforms the hole by multiplying the width and height gained from the radius
 *                   with a two-element vector. Can be used to turn it into an ellipse
 * - invert (float): Invert the pixel health, for having the hole appear from the outside.
 *
 * *For other uniforms, see documentation of the parent class.*
 */
 class HolePixelErasureShader extends PESBase {
	public var hole_radius:ShaderParameter<Float>;
	public var hole_radius_direct(get, set):Float;

	public var hole_border_width:ShaderParameter<Float>;
	public var hole_border_width_direct(get, set):Float;

	public var deform:ShaderParameter<Float>;

	public var invert:ShaderParameter<Bool>;

	public function new(seedChangeThreshold:Float = -1.0) {
		super(
			{
				additionalUniforms: [
					{decl: "float hole_radius"},
					{decl: "float hole_border_width"},
					{decl: "vec2 deform"},
					{decl: "bool invert"},
				],
				randoPixelizationMinimumThresholdExpr: "local_pixel_health",
				randoMinimumThresholdCalculationSource: "
					vec2 pos = ((processed_texture_coords - vec2(0.5, 0.5)) * openfl_TextureSize);
					pos *= deform;
					float d = sqrt(dot(pos, pos));
					float local_pixel_health = smoothstep(
						0.0,
						1.0,
						(d - (hole_radius - hole_border_width)) / (2.0*hole_border_width)
					);
					if (invert) {
						local_pixel_health = 1.0 - local_pixel_health;
					}
					// @Square789: Go fuck yourself. This shader is specially broken.
					// I don't know why alpha behaves so damn weirdly in this engine.
					alpha = 0.0;
				",
			},
			seedChangeThreshold
		);

		this.hole_radius =       data.hole_radius;
		this.hole_radius.value = [0.0, 0.0];

		this.hole_border_width =       data.hole_border_width;
		this.hole_border_width.value = [1.0, 1.0];

		this.deform =       data.deform;
		this.deform.value = [1.0, 1.0];

		this.invert = data.invert;
		this.invert.value = [false];
	}

	public function get_hole_radius_direct():Float {
		return hole_radius.value[0];
	}
	public function set_hole_radius_direct(v:Float):Float {
		return hole_radius.value[0] = v;
	}

	public function get_hole_border_width_direct():Float {
		return hole_border_width.value[0];
	}
	public function set_hole_border_width_direct(v:Float):Float {
		return hole_border_width.value[0] = v;
	}
}
