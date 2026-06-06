package;

import flixel.util.FlxColor;
import flixel.FlxG;
import haxe.ValueException;

import CoolUtil.PointStruct;

class SongData {
	public var name:String;
	public var presentedOpponent:String;
	public var color:FlxColor;
	public var placePos:PointStruct;
	public var placeZoom:Float;

	/**
	 * Contains each of the song's variations/mixes as a string, unformatted.
	 * Will at least be of length 1 and contain "Original".
	 */
	public var availableMixes:Array<String>;

	public static final DEFAULT_MIX = 'Original';

	public function new(songData:Array<Dynamic>) {
		if (songData.length < 3) {
			throw new ValueException('Raw song data was too short!');
		}

		this.name = songData[0];
		this.presentedOpponent = songData[1];
		var rawColor:Array<Int> = songData[2];

		if (rawColor == null || rawColor.length < 3) {
			FlxG.log.warn('Failed to load ${this.name}\'s colors!');
			this.color = FlxColor.fromRGB(146, 113, 253);
		} else {
			this.color = FlxColor.fromRGB(rawColor[0], rawColor[1], rawColor[2]);
		}

		this.placePos = {x: 127, y: 290};
		this.placeZoom = 8.0; // STOTAL MISPLAY

		if (songData.length > 3) {
			var placeData:Array<Float> = songData[3];
			if (placeData != null) {
				this.placePos = {x: songData[3][0], y: songData[3][1]};
				this.placeZoom = songData[3][2];
			} else {
				FlxG.log.warn('Place data for ${this.name} malformed!');
			}
		}
		if (songData.length > 4) {
			this.availableMixes = songData[4];
			if (!this.availableMixes.contains(SongData.DEFAULT_MIX)) {
				this.availableMixes.insert(0, SongData.DEFAULT_MIX);
			}
		} else {
			this.availableMixes = [SongData.DEFAULT_MIX];
		}
	}
}
