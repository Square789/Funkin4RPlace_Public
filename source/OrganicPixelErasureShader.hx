// "Organic" pixel erasure shader that basically has a noise function running for each pixel
// instead of rerolling the grid each time the seed changes.
// It is far from perfect and will forever be. You can only do so much when limited
// to pure shader stuff that effectively does not remember the state from previous timesteps.
// It's a hack that's looking good enough in the places it's used in if you don't look too closely.
// And I am not digging deep into openfl's guts in order to cobble together a solution that
// uses an SSBO or some shit, if these are even available in whatever ancient version of
// OpenGL this is.

package;

import haxe.Template;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameter;


private final OPES_FRAGMENT_TEMPLATE = new Template('
#pragma header

uniform vec4 eraser_color;
uniform vec2 pixel_dimensions;
uniform vec2 offset;
uniform bool always_pixelate;
uniform bool ignore_alpha;
uniform float time;
::foreach additionalUniforms::
uniform ::decl::;
::end::

// Yoinked from:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0
// Had to be modified to not make whatever version of OpenGL this is complain.
// This thing isn\'t really random at all or its randomness depends on some weird behavior of
// the GPU, but whatever.

// Will return a random value between 0.0 and 1.0, end-exclusive.
float random(vec2 co) {
	float a = 12.9898;
	float b = 78.233;
	float c = 43758.5453;
	float dt = dot(co.xy, vec2(a, b));
	float sn = mod(dt, 3.14);
	return fract(sin(sn) * c);
}

float random(float co) {
	return random(vec2(co, co));
}

float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);

	// Four corners in 2D of a tile
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
			(c - a)* u.y * (1.0 - u.x) +
			(d - b) * u.x * u.y;
}
float noise(float seed) {
	float dec = floor(seed);
	float frac = fract(seed);
	return smoothstep(random(dec), random(dec + 1.0), frac);
}


float simple_noise(vec2 seed, float t) {
	return noise(seed + random(seed) * t);
}

// Quantize time on the shader level as there is some kind of stateful
// behavior going on with the looking behind.
// We can\'t have slight dt variations deliver different results for
// queries of what would be roughly the same timestep, so make it the
// same timestep.
#define TIME_GRANULARITY 0.08
float snap_time(float t) {
	return (
		floor((t + (TIME_GRANULARITY * 0.5)) / TIME_GRANULARITY) *
		TIME_GRANULARITY
	);
}

bool simple_determiner(vec2 seed, float t, float pixel_health) {
	return random(seed * snap_time(t)) > pixel_health;
}

#define FDET_SPIKE_AVERSION_STEP 1
#define FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND 16
bool fancy_determiner(vec2 seed, float t, float pixel_health) {
    bool this_value = simple_noise(seed, snap_time(t)) > pixel_health;
    //return this_value;
    int valley_count = 0;
    int peak_count = 0;
    bool is_spike = false;
    for (
        int i = -FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND;
        i < FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND + 1;
        i++
    ) {
        if (
            simple_noise(
                seed,
                snap_time(
                    t +
                    TIME_GRANULARITY * float(FDET_SPIKE_AVERSION_STEP * i)
                )
            ) > pixel_health
        ) {
            if (!this_value) {
                is_spike = true;
            }
            peak_count += 1;
        } else {
            if (this_value) {
                is_spike = true;
            }
            valley_count += 1;
        }
    }
    return !is_spike && this_value;
	//return !is_spike && (peak_count > valley_count);
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

	vec2 seed = processed_texture_coords;

	::randoMinimumThresholdCalculationSource::

	if (fancy_determiner(seed, time, ::randoPixelizationMinimumThresholdExpr::)) {
	// if (simple_determiner(seed, time, ::randoPixelizationMinimumThresholdExpr::)) {
		// gl_FragColor = vec4(eraser_color * alpha);
		gl_FragColor = vec4(eraser_color);
	} else {
		gl_FragColor = flixel_texture2D(
			bitmap,
			always_pixelate ? processed_texture_coords : openfl_TextureCoordv
		);
	}
}

');
private function setOrganicPixelErasureShaderTemplateContextDefaults(context:Dynamic):Dynamic {
	if (context.textureSizeExpr == null)                        context.textureSizeExpr = "openfl_TextureSize";
	if (context.additionalUniforms == null)                     context.additionalUniforms = [];
	if (context.randoMinimumThresholdCalculationSource == null) context.randoMinimumThresholdCalculationSource = "";
	if (context.randoPixelizationMinimumThresholdExpr == null)  context.randoPixelizationMinimumThresholdExpr = "0.0";
	return context;
}

private class OPESBase extends RuntimeShader {
	public var eraser_color:ShaderParameter<Float>;
	public var pixel_dimensions:ShaderParameter<Float>;
	public var offset:ShaderParameter<Float>;
	public var always_pixelate:ShaderParameter<Bool>;
	public var ignore_alpha:ShaderParameter<Bool>;
	public var time:ShaderParameter<Float>;

	private var seedChangeProgress:Float;
	private var seedChangeThreshold:Float;

	public function new(templateContext:Dynamic) {
		super(OPES_FRAGMENT_TEMPLATE.execute(setOrganicPixelErasureShaderTemplateContextDefaults(templateContext)));

		this.eraser_color = data.eraser_color;         this.eraser_color.value = [0.0, 0.0, 0.0, 1.0];
		this.pixel_dimensions = data.pixel_dimensions; this.pixel_dimensions.value = [1.0, 1.0];
		this.offset = data.offset;                     this.offset.value = [0.0, 0.0];
		this.always_pixelate = data.always_pixelate;   this.always_pixelate.value = [false];
		this.ignore_alpha = data.ignore_alpha;         this.ignore_alpha.value = [false];
		// Start later as 0 causes weirdness with the noise functions
		this.time = data.time;                         this.time.value = [42.0];
	}

	public function update(dt:Float) {
		this.time.value[0] += dt;
	}
}

class ManualTexSizeOrganicPixelErasureShader extends OPESBase {
	public var pixel_health:ShaderParameter<Float>;
	public var pixel_health_direct(get, set):Float;

	public var manual_texture_size:ShaderParameter<Float>;

	public function new() {
		super(
			{
				additionalUniforms: [{decl: "float pixel_health"}, {decl: "vec2 manual_texture_size"}],
				randoPixelizationMinimumThresholdExpr: "pixel_health",
				textureSizeExpr: "manual_texture_size",
			}
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


class HoleOrganicPixelErasureShader extends OPESBase {
	public var hole_radius:ShaderParameter<Float>;
	public var hole_radius_direct(get, set):Float;

	public var hole_border_width:ShaderParameter<Float>;
	public var hole_border_width_direct(get, set):Float;

	public var deform:ShaderParameter<Float>;

	public var invert:ShaderParameter<Bool>;

	public function new() {
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
				",
			}
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


class MalderSkyOrganicPixelErasureShader extends OPESBase {
	public var horizon_progress:ShaderParameter<Float>;
	public var horizon_progress_direct(get, set):Float;

	public function new() {
		// Not that -3.0, - 3.0 need to be 3.0, - 4.0 when copypasting into shadertoy.
		// Something is clearly flipped upside down, guess i only noticed now? has it always been like that?
		// am i going insane
		super(
			{
				additionalUniforms: [
					{decl: "float horizon_progress"},
				],
				randoPixelizationMinimumThresholdExpr: "pix_chance",
				randoMinimumThresholdCalculationSource: "
					float center_x_dist = abs(processed_texture_coords.x - 0.5);
					// float horizon_progress = 1.0 - (iMouse.y / iResolution.y);
					// dist will be 0 when in range of the circle / when the overlay is hidden
					float horizon_dist = length(
						(processed_texture_coords + vec2(-0.5, -3.0))
					) - 3.0 + horizon_progress;
					// warp downwards to the edges if it's closer
					horizon_dist += pow(center_x_dist, 2.5) * horizon_progress;

					float shock_pix_chance = sin(horizon_dist * 32.0 + time * 6.0) - 0.4;
					// shockwaves diminish going downwards and to the sides
					shock_pix_chance -= center_x_dist * 0.4;
					shock_pix_chance += horizon_dist * 2.5;
					shock_pix_chance = clamp(shock_pix_chance, 0.0, 0.1);

					float horizon_pix_chance = clamp(horizon_dist * 7.0, 0.0, 9999.9);
					horizon_pix_chance = pow(horizon_pix_chance, 1.5);

					float pix_chance = horizon_pix_chance;
					//pix_chance += shock_pix_chance;
				",
			}
		);

		this.horizon_progress =       data.horizon_progress;
		this.horizon_progress.value = [0.0];
	}

	public function get_horizon_progress_direct():Float {
		return horizon_progress.value[0];
	}
	public function set_horizon_progress_direct(v:Float):Float {
		return horizon_progress.value[0] = v;
	}
}


class ManualTexSizeSidePulserOrganicPixelErasureShader extends OPESBase {
	public var manual_texture_size:ShaderParameter<Float>;

	public function new() {
		super({
			additionalUniforms: [
				{decl: "vec2 manual_texture_size"},
			],
			textureSizeExpr: "manual_texture_size",
			randoPixelizationMinimumThresholdExpr: "local_pixel_health",
			randoMinimumThresholdCalculationSource: "
				float center_x_dist = abs(processed_texture_coords.x - 0.5);
				float local_pixel_health = sin(-center_x_dist * 32.0 + time * 12.0);
				float full_override_factor = pow(0.5 - center_x_dist, 0.4);
				local_pixel_health += (1.0 - local_pixel_health) * full_override_factor;
			",
		});

		this.manual_texture_size = data.manual_texture_size;
		this.manual_texture_size.value = [1.0, 1.0];
	}
}


private final OPES2_SOURCE:String = "
#pragma header
uniform sampler2D palette;
uniform vec2 pixel_dimensions;
uniform vec2 offset;
uniform bool always_pixelate;
uniform bool ignore_alpha;
uniform float time;
uniform float pixel_health;
uniform float more_void;
uniform vec2 uv_base;

// Yoinked from:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0
// Had to be modified to not make whatever version of OpenGL this is complain.
// This thing isn\'t really random at all or its randomness depends on some weird behavior of
// the GPU, but whatever.

// Will return a random value between 0.0 and 1.0, end-exclusive.
float random(vec2 co) {
	float a = 12.9898;
	float b = 78.233;
	float c = 43758.5453;
	float dt = dot(co.xy, vec2(a, b));
	float sn = mod(dt, 3.14);
	return fract(sin(sn) * c);
}

float random(float co) {
	return random(vec2(co, co));
}

float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);

	// Four corners in 2D of a tile
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
			(c - a)* u.y * (1.0 - u.x) +
			(d - b) * u.x * u.y;
}
float noise(float seed) {
	float dec = floor(seed);
	float frac = fract(seed);
	return smoothstep(random(dec), random(dec + 1.0), frac);
}


float simple_noise(vec2 seed, float t) {
	return noise(seed + random(seed) * t);
}

// Quantize time on the shader level as there is some kind of stateful
// behavior going on with the looking behind.
// We can\'t have slight dt variations deliver different results for
// queries of what would be roughly the same timestep, so make it the
// same timestep.
#define TIME_GRANULARITY 0.08
float snap_time(float t) {
	return (
		floor((t + (TIME_GRANULARITY * 0.5)) / TIME_GRANULARITY) *
		TIME_GRANULARITY
	);
}

bool simple_determiner(vec2 seed, float t, float pixel_health) {
	return random(seed * snap_time(t)) > pixel_health;
}

#define FDET_SPIKE_AVERSION_STEP 1
#define FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND 16
bool fancy_determiner(vec2 seed, float t, float pixel_health) {
    bool this_value = simple_noise(seed, snap_time(t)) > pixel_health;
    //return this_value;
    int valley_count = 0;
    int peak_count = 0;
    bool is_spike = false;
    for (
        int i = -FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND;
        i < FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND + 1;
        i++
    ) {
        if (
            simple_noise(
                seed,
                snap_time(
                    t +
                    TIME_GRANULARITY * float(FDET_SPIKE_AVERSION_STEP * i)
                )
            ) > pixel_health
        ) {
            if (!this_value) {
                is_spike = true;
            }
            peak_count += 1;
        } else {
            if (this_value) {
                is_spike = true;
            }
            valley_count += 1;
        }
    }
    return !is_spike && this_value;
	//return !is_spike && (peak_count > valley_count);
}

vec4 lookup_color(float indexer) {
	return texture2D(palette, vec2((indexer - more_void) * (1.0 / (1.0 - more_void)), 0));
}

void main() {
	vec2 screen_pixel_size = openfl_TextureSize / pixel_dimensions;
	vec2 processed_texture_coords = (
		// Extrapolate the texcoord here, floor it to get the pixelation effect
		// and then div it back to the 0.0..1.0 range.
		floor(openfl_TextureCoordv * screen_pixel_size) / screen_pixel_size +
		// Add an offset because something about pixels always being centered?
		// Looks better when toggling pixelation, no edge sprite bleeding for now afaict
		(1.0 / openfl_TextureSize) * (offset + (0.5 * pixel_dimensions))
	);

	float alpha = ignore_alpha ? 1.0 : flixel_texture2D(bitmap, processed_texture_coords).a;

	vec2 seed = (
		floor((openfl_TextureCoordv - uv_base) * screen_pixel_size) / screen_pixel_size +
		(1.0 / openfl_TextureSize) * (offset + (0.5 * pixel_dimensions))
	);
	float rando = random(seed);

	// if (fancy_determiner(seed + fract(rando * seed), time + 2591.0, more_void)) {
	// 	gl_FragColor = vec4(0.0, 0.0, 0.0, alpha) * alpha;
	// } else
	if (fancy_determiner(seed, time, pixel_health)) {
		gl_FragColor = vec4(lookup_color(random(vec2(rando, floor(time / 12.0)))) * alpha);
	} else {
		gl_FragColor = flixel_texture2D(
			bitmap,
			always_pixelate ? processed_texture_coords : openfl_TextureCoordv
		);
	}
}";
class AnotherFuckingOrganicPixelErasureShader extends RuntimeShader {
	public var palette:ShaderInput<openfl.display.BitmapData>;
	public var pixel_dimensions:ShaderParameter<Float>;
	public var offset:ShaderParameter<Float>;
	public var always_pixelate:ShaderParameter<Bool>;
	public var ignore_alpha:ShaderParameter<Bool>;
	public var time:ShaderParameter<Float>;
	public var pixel_health:ShaderParameter<Float>;
	public var more_void:ShaderParameter<Float>;
	public var uv_base:ShaderParameter<Float>;

	public function new() {
		super(OPES2_SOURCE);

		var file = Paths.image("palette");
		this.palette = data.palette;                   this.palette.input = file.bitmap;
		this.pixel_dimensions = data.pixel_dimensions; this.pixel_dimensions.value = [1.0, 1.0];
		this.offset = data.offset;                     this.offset.value = [0.0, 0.0];
		this.always_pixelate = data.always_pixelate;   this.always_pixelate.value = [false];
		this.ignore_alpha = data.ignore_alpha;         this.ignore_alpha.value = [false];
		// Start later as 0 causes weirdness with the noise functions
		this.time = data.time;                         this.time.value = [42.0];
		this.pixel_health = data.pixel_health;         this.pixel_health.value = [1.0];
		this.more_void = data.more_void;               this.more_void.value = [1.0];
		this.uv_base = data.uv_base;                   this.uv_base.value = [0.0, 0.0];
	}

	public function update(dt:Float) {
		this.time.value[0] += dt;
	}
}

// shadertoy variant below
/**#define eraser_color vec4(0.0, 0.0, 0.0, 0.0)
#define pixel_dimensions vec2(4.0, 4.0)
#define offset 0.0
#define always_pixelate true
#define ignore_alpha true
#define time iTime

// Will return a random value between 0.0 and 1.0, end-exclusive.
float random(vec2 co) {
	float a = 12.9898;
	float b = 78.233;
	float c = 43758.5453;
	float dt = dot(co.xy, vec2(a, b));
	float sn = mod(dt, 3.14);
	return fract(sin(sn) * c);
}

float random(float co) {
	return random(vec2(co, co));
}

float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);

	// Four corners in 2D of a tile
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
			(c - a)* u.y * (1.0 - u.x) +
			(d - b) * u.x * u.y;
}
float noise(float seed) {
	float dec = floor(seed);
	float frac = fract(seed);
	return smoothstep(random(dec), random(dec + 1.0), frac);
}


float simple_noise(vec2 seed, float t) {
	return noise(seed + random(seed) * t);
}

// Quantize time on the shader level as there is some kind of stateful
// behavior going on with the looking behind.
// We can\'t have slight dt variations deliver different results for
// queries of what would be roughly the same timestep, so make it the
// same timestep.
#define TIME_GRANULARITY 0.08
float snap_time(float t) {
	return (
		floor((t + (TIME_GRANULARITY * 0.5)) / TIME_GRANULARITY) *
		TIME_GRANULARITY
	);
}

bool simple_determiner(vec2 seed, float t, float pixel_health) {
	return random(seed * snap_time(t)) > pixel_health;
}

#define FDET_SPIKE_AVERSION_STEP 1
#define FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND 16
bool fancy_determiner(vec2 seed, float t, float pixel_health) {
    bool this_value = simple_noise(seed, snap_time(t)) > pixel_health;
    //return this_value;
    int valley_count = 0;
    int peak_count = 0;
    bool is_spike = false;
    for (
        int i = -FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND;
        i < FDET_SPIKE_AVERSION_BIDIR_LOOKAROUND + 1;
        i++
    ) {
        if (
            simple_noise(
                seed,
                snap_time(
                    t +
                    TIME_GRANULARITY * float(FDET_SPIKE_AVERSION_STEP * i)
                )
            ) > pixel_health
        ) {
            if (!this_value) {
                is_spike = true;
            }
            peak_count += 1;
        } else {
            if (this_value) {
                is_spike = true;
            }
            valley_count += 1;
        }
    }
    return !is_spike && this_value;
	//return !is_spike && (peak_count > valley_count);
}

void mainImage( out vec4 out_color, in vec2 in_pos ) {
    vec2 openfl_TextureCoordv = in_pos / iResolution.xy;
	vec2 screen_pixel_size = iResolution.xy / pixel_dimensions;
	vec2 processed_texture_coords = (
		// Extrapolate the texcoord here, floor it to get the pixelation effect
		// and then div it back to the 0.0..1.0 range.
		floor(openfl_TextureCoordv * screen_pixel_size) / screen_pixel_size +
		// Add an offset because something about pixels always being centered?
		// Looks better when toggling pixelation, no edge sprite bleeding for now afaict
		(1.0 / iResolution.xy) * (offset + (0.5 * pixel_dimensions))
	);

	float alpha = ignore_alpha ? 1.0 : texture(iChannel0, processed_texture_coords).a;

	vec2 seed = processed_texture_coords;

    float center_x_dist = abs(processed_texture_coords.x - 0.5);
    float pix_chance = sin(-center_x_dist * 32.0 + time * 12.0);
    float adjusted_dist = (0.5 - center_x_dist) * 2.0 + 0.5;
    float full_override_factor = pow(clamp(0.8 - center_x_dist, 0.0, 1.0), 0.4);
    pix_chance += (1.0 - pix_chance) * full_override_factor;

	if (fancy_determiner(seed, time, pix_chance)) {
		out_color = vec4(eraser_color);
	} else {
		out_color = texture(
			iChannel0,
			always_pixelate ? processed_texture_coords : openfl_TextureCoordv
		);
	}
}
**/
