package;

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

// This module kinda sucks, there's 4 shaders in here, only two are used and all
// use slightly different math.
// I suggest you look at BetterRoundedCornerShader.

// Now, this shader does say "inner_border" but it's kind of just a pile of broken math that looks ok enough
// in the places it's used in and also kind of smoothes the outer border.
// smooth_outer_edge_with_border_color will cause the outer edge of the element to be mixed with the
// border color, which will look horrid if there is no border color and you just want to carve out the
// edges of an element.
// leave at false unless the element actually needs a visibly distinct border like the main menu pill buttons
class RoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;
		uniform bool smooth_outer_edge_with_border_color;

		// Wouldn\'t be here without the following:
		// https://www.shadertoy.com/view/7tsXRN

		void main() {
			vec2 position = openfl_TextureCoordv * openfl_TextureSize;
			vec2 center = openfl_TextureSize / 2.0;

			// Don\'t ask me what "dist" means, i don\'t really know what kind of
			// distance i have to imagine there. Well, i kinda do know it\'s the distance
			// of a virtual circle that somehow comes to be by these abs and center
			// subtractions which is only considered in one direction by the max, but
			// i actually am too smoothbrained to wrap my head around it. Oh well.
			float dist = length(max(
				abs(position - center) - center + vec2(radius),
				vec2(0.0, 0.0)
			)) - radius;

			float alpha;
			vec3 color;
			if (dist > 0.0) {
				// Outside of rounded border.
				float smoothv = smoothstep(0.0, 1.0, dist + (smooth_outer_edge_with_border_color ? 0.0 : 0.5));
				alpha = 1.0 - smoothv;
				color = smooth_outer_edge_with_border_color ?
					mix(inner_border_color, flixel_texture2D(bitmap, openfl_TextureCoordv).rgb, smoothv) :
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb;
			} else { // if (dist > -inner_border_width)
				// Inside. We may be on the border, so mix the border color with the texture\'s color.
				float true_color_weight = 1.0 - smoothstep(0.0, 1.0, dist + inner_border_width + 0.5);
				vec3 res = mix(
					inner_border_color,
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb,
					true_color_weight
				);

				alpha = flixel_texture2D(bitmap, openfl_TextureCoordv).a;
				color = res.rgb;
			}

			gl_FragColor = vec4(color * alpha, alpha);
		}
	')

	public function new(
		radius:Float,
		innerBorderWidth:Float = 0.0,
		innerBorderColor:FlxColor = 0xFF000000,
		smoothOuterEdgeWithBordercolor = false
	) {
		super();
		this.radius.value = [radius];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
		this.smooth_outer_edge_with_border_color.value = [smoothOuterEdgeWithBordercolor];
	}
}

// I can't help but think this is a really disgusting way of doing it
class ManualTexSizeRoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform vec2 texture_size;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;
		uniform bool smooth_outer_edge_with_border_color;

		// Wouldn\'t be here without the following:
		// https://www.shadertoy.com/view/7tsXRN

		void main() {
			vec2 position = openfl_TextureCoordv * texture_size;
			vec2 center = texture_size / 2.0;

			// Don\'t ask me what "dist" means, i don\'t really know what kind of
			// distance i have to imagine there. Well, i kinda do know it\'s the distance
			// of a virtual circle that somehow comes to be by these abs and center
			// subtractions which is only considered in one direction by the max, but
			// i actually am too smoothbrained to wrap my head around it. Oh well.
			float dist = length(max(
				abs(position - center) - center + vec2(radius),
				vec2(0.0, 0.0)
			)) - radius;

			float alpha;
			vec3 color;
			if (dist > 0.0) {
				// Outside of rounded border.
				float smoothv = smoothstep(0.0, 1.0, dist + (smooth_outer_edge_with_border_color ? 0.0 : 0.5));
				alpha = 1.0 - smoothv;
				color = smooth_outer_edge_with_border_color ?
					mix(inner_border_color, flixel_texture2D(bitmap, openfl_TextureCoordv).rgb, smoothv) :
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb;
			} else { // if (dist > -inner_border_width)
				// Inside. We may be on the border, so mix the border color with the texture\'s color.
				float true_color_weight = 1.0 - smoothstep(0.0, 1.0, dist + inner_border_width + 0.5);
				vec3 res = mix(
					inner_border_color,
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb,
					true_color_weight
				);

				alpha = flixel_texture2D(bitmap, openfl_TextureCoordv).a;
				color = res.rgb;
			}

			gl_FragColor = vec4(color * alpha, alpha);
		}
	')

	public function new(
		radius:Float,
		texSizeW:Float = 1.0,
		texSizeH:Float = 1.0,
		innerBorderWidth:Float = 0.0,
		innerBorderColor:FlxColor = 0xFF000000,
		smoothOuterEdgeWithBordercolor = false
	) {
		super();
		this.radius.value = [radius];
		this.texture_size.value = [texSizeW, texSizeH];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
		this.smooth_outer_edge_with_border_color.value = [smoothOuterEdgeWithBordercolor];
	}
}


// Shadertoy shader for the below for reference
/*
#define RADIUS 80.0
#define INNER_BORDER_WIDTH 1.0

const vec4 INNER_BORDER_COLOR = vec4(1.0, 0.0, 0.0, 1.0);

float get_dist(vec2 position, vec2 center, float radius) {
    vec2 q = abs(position - center) - center + vec2(radius) + vec2(0.5, 0.5);
    return length(max(q, vec2(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec2 position = fragCoord;
    
    vec2 center = iResolution.xy / 2.0;
    
    float dist = get_dist(position, center, RADIUS) + 0.5;
    float inner_border_dist = get_dist(position, center, RADIUS + INNER_BORDER_WIDTH);

    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));
    col = mix(INNER_BORDER_COLOR.rgb, col, clamp(dist, 0.0, 1.0));
    col = mix(texture(iChannel0, uv).rgb, col, smoothstep(0.0, 1.0, dist + INNER_BORDER_WIDTH));

    fragColor = vec4(col,1.0);
}
*/
// fucj
// This shader has different logic to the one below it. I don't really care, looks alright.
class ManualTexSizeInvertedRoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform vec2 texture_size;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;

		// Wouldn\'t be here without the following:
		// https://www.shadertoy.com/view/7tsXRN

		float get_dist(vec2 position, vec2 center, float r) {
			vec2 q = abs(position - center) - center + vec2(r) + vec2(0.5, 0.5);
			return length(max(q, vec2(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
		}

		void main() {
			float dist = get_dist(openfl_TextureCoordv * texture_size, texture_size / 2.0, radius);

			float alpha;
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);
			color = mix(vec4(inner_border_color, 1.0), color, smoothstep(0.0, 1.0, dist));
			color = mix(vec4(0.0, 0.0, 0.0, 0.0), color, smoothstep(0.0, 1.0, dist + inner_border_width));

			alpha = color.a;
			gl_FragColor = vec4(color.rgb * alpha, alpha);
		}
	')

	public function new(
		radius:Float,
		texSizeW:Float = 1.0,
		texSizeH:Float = 1.0,
		innerBorderWidth:Float = 0.0,
		innerBorderColor:FlxColor = 0xFF000000
	) {
		super();
		this.radius.value = [radius];
		this.texture_size.value = [texSizeW, texSizeH];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
	}
}

/*
Better shader.
(This is based on https://www.shadertoy.com/view/7tsXRN, however that one has an incomplete SDF function)
#define RADIUS 118.0
#define INNER_BORDER_WIDTH 1.0

const vec4 INNER_BORDER_COLOR = vec4(1.0, 0.0, 0.0, 1.0);

float get_dist(vec2 position, vec2 center, float radius) {
    vec2 q = abs(position - center) - center + vec2(radius) + vec2(0.5, 0.5);
    return length(max(q, vec2(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec2 position = fragCoord;

    vec2 center = iResolution.xy / 2.0;

    // "dist" refers to "distance of current fragment to rounded path around image"
    // positive when outside, negative when inside.
    float dist = get_dist(position, center, RADIUS);

    float outside_mix_factor = clamp(dist, 0.0, 1.0);
    float inside_mix_factor = clamp(1.0 - dist - INNER_BORDER_WIDTH, 0.0, 1.0);
    float border_strength = clamp(1.0 - outside_mix_factor - inside_mix_factor, 0.0, 1.0);

    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));

    fragColor = vec4(
        texture(iChannel0, uv).rgb * outside_mix_factor +
        INNER_BORDER_COLOR.rgb * border_strength +
        col * inside_mix_factor
    , 1.0);
}*/
class BetterRoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform vec2 texture_size;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;

		// From https://iquilezles.org/articles/distfunctions/
		float get_dist(vec2 position, vec2 center, float r) {
			vec2 q = abs(position - center) - center + vec2(r) + vec2(0.5, 0.5); // THE half-pixel addition (very important)
			return length(max(q, vec2(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
		}

		void main() {
			float dist = get_dist(openfl_TextureCoordv * texture_size, texture_size / 2.0, radius);

			float outside_mix_factor = clamp(dist, 0.0, 1.0);
			float inside_mix_factor = clamp(1.0 - dist - inner_border_width, 0.0, 1.0);
			
			// Makes border bolder, which looks far better.
			// However, when radius is 1, it gets a bit too bold, so that explains this mess.
			float strengthening_factor = clamp(radius - 0.5, 0.5, 1.0);
			outside_mix_factor -= strengthening_factor * (outside_mix_factor - pow(outside_mix_factor, 2.0));
			inside_mix_factor -= strengthening_factor * (inside_mix_factor - pow(inside_mix_factor, 2.0));

			float border_strength = clamp(1.0 - outside_mix_factor - inside_mix_factor, 0.0, 1.0);

			vec4 ultimate_color = (
				vec4(0.0, 0.0, 0.0, 0.0) * outside_mix_factor +
				vec4(inner_border_color, 1.0) * border_strength +
				flixel_texture2D(bitmap, openfl_TextureCoordv) * inside_mix_factor
			);
			float alpha = ultimate_color.a;
			gl_FragColor = vec4(ultimate_color.rgb * alpha, alpha);
		}
	')

	public function new(
		radius:Float,
		texSizeW:Float = 1.0,
		texSizeH:Float = 1.0,
		innerBorderWidth:Float = 0.0,
		innerBorderColor:FlxColor = 0xFF000000
	) {
		super();
		this.radius.value = [radius];
		this.texture_size.value = [texSizeW, texSizeH];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
	}
}
