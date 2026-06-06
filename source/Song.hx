package;

import haxe.Json;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#else
import lime.utils.Assets;
#end

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Array<Dynamic>>;
	var bpm:Float;
	var timeSignature:Array<Int>;
	var needsVoices:Bool;
	var speed:Float;
	var ?playerKeyAmount:Int;
	var ?opponentKeyAmount:Int;
	/**
	 * F4RP addition: String array of the people that charted this.
	 * Needs to be added manually cause i'm not coding a field into the chart editor for that.
	 */
	var ?charterNames:Array<String>;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	var arrowSkin:String;
	var splashSkin:String;
	var skinModifier:String;
	var skinModifierOpponent:String;

	var validScore:Bool;

	var ?meta:MetaFile;

	// free get out of jail card (cough cough pause menu)
	var ?freeplaySongData:FreeplayPlaceState.FreeplaySongData;
}

typedef SwagSection =
{
	var sectionNotes:Array<Array<Dynamic>>;
	var lengthInSteps:Int;
	var mustHitSection:Bool;
	var ?gfSection:Bool;
	var ?bpm:Float;
	var ?changeBPM:Bool;
	var timeSignature:Array<Int>;
	var ?changeSignature:Bool;
	var ?altAnim:Bool;
	#if MULTI_KEY_ALLOWED
	var ?changeKeys:Bool;
	var ?playerKeys:Int;
	var ?opponentKeys:Int;
	#end
}

typedef MetaFile = {
	var ?displayName:String;
	var ?freeplayDifficulties:String;
	var ?iconHiddenUntilPlayed:Bool;
	var ?composers:Array<String>;
}

class Song
{
	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		var curSong:String = Paths.formatToSongPath(songJson.song);
		
		if (songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		if (songJson.playerKeyAmount == null)
		{
			songJson.playerKeyAmount = 4;
			songJson.opponentKeyAmount = 4;
		}
		if (songJson.timeSignature == null)
		{
			songJson.timeSignature = [4, 4];
		}
		if (songJson.skinModifier == null || songJson.skinModifier.length < 1) {
			songJson.skinModifier = '';
		}
		if (songJson.skinModifierOpponent == null || songJson.skinModifierOpponent.length < 1) {
			songJson.skinModifierOpponent = '';
		}
		songJson.displayName = songJson.song;
		
		for (secNum in 0...(songJson.notes?.length ?? 0)) {
			var sec:SwagSection = songJson.notes[secNum];
			if (sec.gfSection == null) sec.gfSection = false;
			if (sec.bpm == null) sec.bpm = songJson.bpm;
			if (sec.changeBPM == null) sec.changeBPM = false;
			if (sec.timeSignature == null) {
				var timeSignature:Array<Int> = songJson.timeSignature;
				sec.timeSignature = timeSignature.copy(); //haxe why are you so WEEEEEEEIIIIIIRD
			}
			if (sec.changeSignature == null) sec.changeSignature = false;
			if (sec.altAnim == null) sec.altAnim = false;
			#if MULTI_KEY_ALLOWED
			if (sec.changeKeys == null) sec.changeKeys = false;
			if (sec.playerKeys == null) sec.playerKeys = songJson.playerKeyAmount;
			if (sec.opponentKeys == null) sec.opponentKeys = songJson.opponentKeyAmount;
			#end
			var i:Int = 0;
			var notes = sec.sectionNotes;
			var len:Int = notes.length;
			while(i < len)
			{
				var note = notes[i];
				while (note.length < 5) {
					note.push(null);
				}
				if (note[3] != null && Std.isOfType(note[3], Int)) note[3] = editors.ChartingState.noteTypeList[note[3]];
				if (note[3] != null && note[3] == true) note[3] = 'Alt Animation';
				if (note[3] == null) note[3] = '';
				if (note[4] == null || note[4].length < 1) note[4] = [0];
				notes[i] = [note[0], note[1], note[2], note[3], note[4]];
				i++;
			}
			songJson.notes[secNum] = sec;
		}
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsData('$formattedFolder/$formattedSong');
		if (FileSystem.exists(moddyFile)) {
			rawJson = File.getContent(moddyFile).trim();
		}
		#end

		if (rawJson == null) {
			#if MODS_ALLOWED
			rawJson = File.getContent(Paths.json('$formattedFolder/$formattedSong')).trim();
			#else
			rawJson = Assets.getText(Paths.json('$formattedFolder/$formattedSong')).trim();
			#end
		}

		if (rawJson == null) {
			return null;
		}

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		var songJson:Dynamic = parseJSONshit(rawJson);
		if (formattedSong != 'events' && formattedSong != 'picospeaker') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song; //actual song
		var tempSong:Dynamic = cast Json.parse(rawJson).song; //copy to check for other variables

		if (swagShit.gfVersion == null) {
			if (tempSong.player3 != null) {
				swagShit.gfVersion = tempSong.player3;
			}
			if (tempSong.gf != null) {
				swagShit.gfVersion = tempSong.gf;
			}
		}

		var renamedSkins = [null => "base", "" => "base", "default" => "base", "pixel" => "week6"];

		var uiskin = tempSong.uiSkin;
		if (swagShit.skinModifier == null) {
			var uiskinFix = renamedSkins[uiskin];
			swagShit.skinModifier = uiskinFix == null ? uiskin : uiskinFix;
		}
		var uiskin = tempSong.uiSkinOpponent;
		if (swagShit.skinModifierOpponent == null) {
			var uiskinFix = renamedSkins[uiskin];
			swagShit.skinModifierOpponent = uiskinFix == null ? uiskin : uiskinFix;
		}
		if (swagShit.playerKeyAmount == null) {
			if (tempSong.mania != null) {
				switch (tempSong.mania) {
					case 1:
						swagShit.playerKeyAmount = 6;
					case 2:
						swagShit.playerKeyAmount = 7;
					case 3:
						swagShit.playerKeyAmount = 9;
					default:
						swagShit.playerKeyAmount = 4;
				}
				swagShit.opponentKeyAmount = swagShit.playerKeyAmount;
			}
			if (tempSong.keyCount != null) {
				swagShit.playerKeyAmount = tempSong.keyCount;
				swagShit.opponentKeyAmount = tempSong.keyCount;
			}
			if (tempSong.playerKeyCount != null) {
				swagShit.playerKeyAmount = tempSong.playerKeyCount;
			}
		}
		if (swagShit.timeSignature == null) {
			if (tempSong.numerator != null && tempSong.denominator != null) {
				swagShit.timeSignature = [tempSong.numerator, tempSong.denominator];
			}
			if (tempSong.timescale != null && tempSong.timescale.length == 2) {
				var timescale:Array<Int> = tempSong.timescale;
				swagShit.timeSignature = timescale.copy();
			}
		}

		for (i in 0...(tempSong.notes?.length ?? 0)) {
			var sec = tempSong.notes[i];
			var numerator:Null<Int> = sec.numerator;
			var denominator:Null<Int> = sec.denominator;
			var sectionBeats:Null<Float> = sec.sectionBeats;
			if (numerator != null && denominator != null) {
				swagShit.notes[i].timeSignature = [numerator, denominator];
				if (sectionBeats != null) {
					swagShit.notes[i].timeSignature[0] = Math.round(sectionBeats);
					swagShit.notes[i].changeSignature = true;
				}
			}
		}

		swagShit.validScore = true;
		return swagShit;
	}

	public static function getMetaFile(name:String):MetaFile {
		name = Paths.formatToSongPath(name);
		var characterPath:String = 'data/$name/meta.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Assets.exists(path))
		#end
		{
			var meta:MetaFile = {
				displayName: null,
				freeplayDifficulties: null,
				iconHiddenUntilPlayed: false
			};
			return meta;
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		if (rawJson == null) {
			return null;
		}

		var json:MetaFile = cast Json.parse(rawJson);
		if (json.iconHiddenUntilPlayed == null) json.iconHiddenUntilPlayed = true;
		return json;
	}

	public static function getDisplayName(song:String) {
		var meta = Song.getMetaFile(song);
		return meta.displayName != null ? meta.displayName : song;
	}

	public static function getComposers(song:String) {
		var meta = Song.getMetaFile(song);
		return meta.composers != null ? meta.composers : [];
	}
}
