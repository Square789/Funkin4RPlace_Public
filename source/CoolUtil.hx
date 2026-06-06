package;

import haxe.ValueException;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import lime.app.Application;
import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.utils.Assets;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

typedef PointStruct = {x:Float, y:Float};

typedef MenuMusicInfo = {name:String, bpm:Float}

class CoolUtil
{
	public static var defaultDifficulties:Array<String> = [
		// 'Easy',
		'Normal',
		'Hard',
		'Mania'
	];
	/**
	 * The default difficulty's name.
	 * Its charts have no suffix and it will be the default selection in freeplay/story mode menus.
	 */
	public static var defaultDifficulty:String = 'Normal';

	/**
	 * Indecipherable global static clusterfuck field.
	 * Good luck if you have to work with this, though I made these observations:
	 * It seems to supply a string value for the index `PlayState.storyDifficulty`.
	 * It seems to be safest to set it to a list of difficulties available for a given song
	 * whenever trying to operate on / get data in the context of that song.
	 */
	public static var difficulties:Array<String> = [];

	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		return (m / snap);
	}

	public static function getDifficultyFilePath(?num:Int = null)
	{
		if (num == null) num = PlayState.storyDifficulty;
		if (num >= difficulties.length) num = difficulties.length - 1;

		var fileSuffix:String = difficulties[num];
		if (fileSuffix == null) {
			fileSuffix = '';
		} else {
			if (fileSuffix != defaultDifficulty)
			{
				fileSuffix = '-$fileSuffix';
			}
			else
			{
				fileSuffix = '';
			}
		}
		return Paths.formatToSongPath(fileSuffix);
	}

	public static function difficultyString():String
	{
		var diff:String = difficulties[PlayState.storyDifficulty];
		if (diff == null) diff = "";
		return diff.toUpperCase();
	}

	inline public static function boundTo(value:Float, min:Float, max:Float):Float {
		return Math.max(min, Math.min(max, value));
	}

	inline public static function boundInt(value:Int, min:Int, max:Int):Int {
		return (value < min ? min : (value > max ? max : value));
	}

	public static function coolTextFile(path:String)
	{
		var daList:Array<String> = [];
		#if MODS_ALLOWED
		if (FileSystem.exists(path)) daList = File.getContent(path).trim().split('\n');
		else if (Assets.exists(path))
		#else
		if (Assets.exists(path))
		#end
			daList = Assets.getText(path).trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function coolArrayTextFile(path:String)
	{
		var daList:Array<String> = [];
		var daArray:Array<Array<String>> = [];
		#if MODS_ALLOWED
		if (FileSystem.exists(path)) daList = File.getContent(path).trim().split('\n');
		else if (Assets.exists(path))
		#else
		if (Assets.exists(path))
		#end
			daList = Assets.getText(path).trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		for (i in daList) {
			daArray.push(i.split(' '));
		}

		return daArray;
	}

	/**
	 * Reads a text file by lines.
	 * Will only replace possible occurences of window's CRLF with LF and then split by that.
	 * Will drop entirely empty lines if told to do so; may be useful to get trailing space out.
	 */
	public static function getTextFileLines(path:String, trim:Bool = true, dropEmpty:Bool = true):Array<String> {
		var contents = Assets.getText(path).replace("\r\n", "\n").split("\n"); // thanks windows
		if (trim) {
			contents = [for (line in contents) line.trim()];
		}
		return [for (line in contents) if (!dropEmpty || line.length > 0) line];
	}

	public static function dominantColor(sprite:FlxSprite):Int {
		var countByColor:Map<Int, Int> = [];
		for (col in 0...sprite.frameWidth) {
			for (row in 0...sprite.frameHeight) {
			  var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
			  if (colorOfThisPixel != 0) {
				  if (countByColor.exists(colorOfThisPixel)) {
				    countByColor[colorOfThisPixel] =  countByColor[colorOfThisPixel] + 1;
				  } else if (countByColor[colorOfThisPixel] != 13520687 - (2*13520687)) {
					countByColor[colorOfThisPixel] = 1;
				  }
			  }
			}
		 }
		var maxCount = 0;
		var maxKey:Int = 0;//after the loop this will store the max color
		countByColor[FlxColor.BLACK] = 0;
		for (key in countByColor.keys()) {
			if (countByColor[key] >= maxCount) {
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	//uhhhh does this even work at all? i'm starting to doubt
	public static function precacheSound(sound:String, ?library:String = null):Void {
		Paths.sound(sound, library);
	}

	public static function precacheMusic(sound:String, ?library:String = null):Void {
		Paths.music(sound, library);
	}

	public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	public static function getDifficultiesRet(?song:String = '', ?remove:Bool = false, ?meta:MetaFile):Array<String> {
		song = Paths.formatToSongPath(song);
		var difficulties = defaultDifficulties.copy();
		var curWeek = WeekData.getCurrentWeek();

		var freeplayDiffs = null;
		if (!PlayState.isStoryMode) {
			meta = meta == null ? Song.getMetaFile(song) : meta;
			freeplayDiffs = meta == null ? null : meta.freeplayDifficulties;
		}

		var diffStr:String = null;
		if (curWeek != null) diffStr = curWeek.difficulties;
		if (freeplayDiffs != null && freeplayDiffs.length > 0) diffStr = freeplayDiffs;
		if (diffStr == null || diffStr.length == 0) diffStr = defaultDifficulties.join(',');
		diffStr = diffStr.trim(); //Fuck you HTML5

		if (diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i = 0;
			var len = diffs.length;
			// removing invalid diff names
			while (i < len)
			{
				if (diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1 || diffs[i] == null) {
						diffs.remove(diffs[i]);
					} else {
						i++;
					}
				}
				else
				{
					diffs.remove(diffs[i]);
				}
				len = diffs.length;
			}

			// removing diffs that the song doesnt have
 			if (remove && song.length > 0) {
				var i = 0;
				var len = diffs.length;
				while (i < len) {
					if (diffs[i] != null) {
						var suffix = '-${Paths.formatToSongPath(diffs[i])}';
						if (Paths.formatToSongPath(diffs[i]) == Paths.formatToSongPath(defaultDifficulty)) {
							suffix = '';
						}
						var poop:String = song + suffix;
						if (!Paths.fileExists('data/$song/$poop.json', TEXT)) {
							diffs.remove(diffs[i]);
						} else {
							i++;
						}
					} else {
						diffs.remove(diffs[i]);
					}
					len = diffs.length;
				}
			}

			difficulties = diffs;
		}
		return difficulties;
	}

	public static function getDifficulties(?song:String = '', ?remove:Bool = false, ?meta:MetaFile) {
		difficulties = getDifficultiesRet(song, remove, meta);
	}

	public static function randomChoice<T>(arr:Array<T>):Null<T> {
		if (arr.length == 0) {
			return null;
		}
		return arr[FlxG.random.int(0, arr.length - 1)];
	}

	public static function maxInIntArray(arr:Array<Int>):Int {
		if (arr.length == 0) {
			throw new ValueException("max from empty array");
		}
		var _max = arr[0];
		for (i in arr) {
			if (i > _max) {
				_max = i;
			}
		}
		return _max;
	}

	public static function maxInArray<T>(arr:Array<T>, valfunc:T->Int):Null<T> {
		if (arr.length == 0) {
			throw new ValueException("max from empty array");
		}
		var _max = FlxMath.MIN_VALUE_INT;
		var _maxv:Null<T> = arr[0];
		for (i in arr) {
			var v = valfunc(i);
			if (v > _max) {
				_max = v;
				_maxv = i;
			}
		}
		return _maxv;
	}

	/**
	 * Should be an accurate variant of python's modulo, aka the better modulo :troll:
	 */
	public static function wrapModulo(x:Int, m:Int):Int {
		if (m == 0) {
			throw new ValueException("Mod by zero.");
		}

		if (m > 0) {
			if (x >= 0) {
				return x % m;
			} else {
				// Ok i was wrong about the previous one, luckily stackoverflow user Alex B saves the day:
				// https://stackoverflow.com/questions/1907565/c-and-python-different-behaviour-of-the-modulo-operation
				return ((x % m) + m) % m;
			}
		} else {
			m = -m;
			if (x >= 0) {
				return -1 * (((x % m) + m) % m);
			} else {
				return -1 * ((-x) % m);
			}
		}
	}

	/**
	 * im very sorry square
	 */
	public static function wrapModuloFloat(x:Float, m:Float):Float {
		if (m == 0) {
			throw new ValueException("Mod by zero.");
		}

		if (m > 0) {
			if (x >= 0) {
				return x % m;
			} else {
				// Ok i was wrong about the previous one, luckily stackoverflow user Alex B saves the day:
				// https://stackoverflow.com/questions/1907565/c-and-python-different-behaviour-of-the-modulo-operation
				return ((x % m) + m) % m;
			}
		} else {
			m = -m;
			if (x >= 0) {
				return -1 * (((x % m) + m) % m);
			} else {
				return -1 * ((-x) % m);
			}
		}
	}

	// gets the width of the games screen if `FlxG.width` decides to not be accurate
	public static inline function getGameWidth():Float {
		return ((((FlxG.stage.stageWidth / FlxG.scaleMode.scale.x) + FlxG.width) / 2) - FlxG.scaleMode.offset.x / FlxG.scaleMode.scale.x);
	}

	// above but for height
	public static inline function getGameHeight():Float {
		return ((((FlxG.stage.stageHeight / FlxG.scaleMode.scale.y) + FlxG.height) / 2) - FlxG.scaleMode.offset.y / FlxG.scaleMode.scale.y);
	}

	public static function setWindowIcon(image:String = 'iconOG') {
		#if linux
		Image.loadFromFile(Paths.getPath('images/$image.png', IMAGE)).onComplete(function (img) {
			Application.current.window.setIcon(img);
		});
		#end
	}

	private static var playingMenuMusic = 'freaky';
	private static var randomSongChoices:Array<MenuMusicInfo> = [
		{name: 'goddessawe', bpm: 80},
		{name: 'micah', bpm: 126},
	];
	private static function findMenuMusicInfoByName(name:String):Null<MenuMusicInfo> {
		for (x in randomSongChoices) {
			if (x.name == name) {
				return x;
			}
		}
		return null;
	}
	public static function playMenuMusic(volume:Float = 1, randomReplay:Bool = true):Null<MenuMusicInfo> {
		var music = Paths.formatToSongPath(ClientPrefs.menuMusic);
		switch (music) {
			case 'random':
				if (randomReplay || findMenuMusicInfoByName(CoolUtil.playingMenuMusic) == null) {
					music = CoolUtil.randomChoice(CoolUtil.randomSongChoices).name;
					CoolUtil.playingMenuMusic = music;
				} else {
					return null;
				}
			case 'none':
				volume = 0;
				music = 'micah'; // smallest file size
				CoolUtil.playingMenuMusic = 'none';
			default:
				CoolUtil.playingMenuMusic = music;
		}
		FlxG.sound.playMusic(Paths.music(music + 'Menu'), volume);
		return findMenuMusicInfoByName(music);
	}

	public static inline function d2r(deg:Float):Float {
		return deg * (Math.PI / 180.0);
	}
}

class InflatedPixelSpriteExt {
	public static function makeInflatedPixelGraphic(
		s:FlxSprite, color:FlxColor, width:Float = 1.0, height:Float = 1.0
	):FlxSprite {
		s.makeGraphic(1, 1, color);
		s.origin.set(0, 0);
		s.scale.set(width, height);
		// updateHitbox also screws with offset and origin which i do not want. Set these manually.
		s.width = width;
		s.height = height;
		return s;
	}
}
