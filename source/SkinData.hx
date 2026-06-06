import flixel.FlxG;
import flixel.FlxSprite;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

/* 
 * @CoolingTool: i think i overcomplicated this out of boredom but i like how it works
 * basically the only reasons i did this is 
 *  1. place ui (ratings and countdown) needs to be unpixelated while it's notes are pixelated
 *  2. i want other noteskins to have void notes and to scale them up even if the current noteskin isnt pixelated
 *  3. found out that you can make static extensions from reading yoshi engine source so i wanted to try (see FlxSpriteSkinLoader) 
 * probably gonna like make a client pref that lets you choose your noteskin and uiskin
*/

typedef SkinFileData = {image:String, pixel:Bool, folder:String, skin:String}

enum SkinDataType {
    Noteskin;
    UISkin;
}

class SkinData {
    // i wish there i could come up with a way to use jsons but it seems like that would be really messy and also be not very useful and if one json's syntax is wrong the entire game would probably crash and it would probably make loading stuff slower

    // enum stuff
    public static var typeFolders:Map<SkinDataType, String> = [
        Noteskin => "noteskins",
        UISkin => "uiskins",
    ];
    public static var pixelSkins:Map<SkinDataType, Array<String>> = [
        Noteskin => ['week6', 'pixel', 'place'],
        UISkin => ['week6', 'pixel', 'place'],
    ];
    // hybrid skins
    public static var pixelSkinOverrides:Map<SkinDataType, Map<String, Array<String>>> = [
        Noteskin => [],
        UISkin => [
            //no longer needed cause captain made every uiskin element pixel art lol
            //'place' => ['combo'].concat([for (i in 0...10) 'num'+i]),
        ],
    ];

    // @CoolingTool: the order of uiskin/noteskin folders to check as fallback
    public static var folderFallbackOrder = [
        'default/base',
        'default/place'
    ];

    public static var defaultSkinModifier = 'place';

    // this function is so goofy
    // why does PlayState.SONG not become null after you exit to the menu
    // forces me to do all this stuff just to verify if the player is in game or not
	public static function getSkinModifier(?opponent:Bool):String {
        var inGame = false;
        if (PlayState.SONG != null) {
            var curClass = Type.getClass(FlxG.state);
            switch curClass {
                case PlayState | editors.ChartingState | editors.CharacterEditorState:
                    inGame = true;
                case options.OptionsState | options.NoteOffsetState:
                    inGame = options.OptionsState.goToPlayState;
            }
        }

        if (!inGame) {
            return defaultSkinModifier;
        } else {
            if (opponent == null) opponent = ClientPrefs.getGameplaySetting('opponentplay', false);
            return !opponent ? PlayState.SONG.skinModifier : PlayState.SONG.skinModifierOpponent;
        }
	}

    public static function getSkinFile(type:SkinDataType, file:String, ?folder:String, ?skin:String):SkinFileData {
        if (folder == null) folder = getSkinModifier();
        if (skin == null) skin = ClientPrefs.noteSkin;
        skin = Paths.formatToSongPath(skin);

        var path = '';

        #if MODS_ALLOWED
        // og psych engine modpack
        if (isSkinPixel(type, folder)) {
            path = 'pixelUI/$file';
            if (Paths.fileExists('images/$path.png', IMAGE))
                return {image: path, pixel: true, folder: 'week6', skin: 'default'};
        }
        if (FileSystem.exists(Paths.modFolders('images/$file.png'))) {
            return {image: file, pixel: false, folder: 'base', skin: 'default'};
        }
        #end
        var fallbacks = folderFallbackOrder.copy();

        // add our own fallbacks
        fallbacks.remove('default/$folder');
        fallbacks.unshift('default/$folder');
        if (skin != 'default') { // kinda already did that
            fallbacks.remove('$skin/$folder');
            fallbacks.unshift('$skin/$folder');
        }
        for (fallback in fallbacks) {
            path = '${typeFolders[type]}/$fallback/$file';
            if (Paths.fileExists('images/$path.png', IMAGE)) {
                var elPixel = isSkinPixel(type, fallback);
                var sep = fallback.split('/');
                var elSkin = sep[0];
                var elFolder = sep.slice(1).join('/'); // should return stuff like "place" and "week6" using arrays and splice incase the folder is actually multiple 

                var overrides = pixelSkinOverrides[type];
                if (overrides[elFolder] != null && overrides[elFolder].contains(file))
                    elPixel = !elPixel;

                return {image: path, pixel: elPixel, skin: elSkin, folder: elFolder};
            }
        }

        return {image: file, pixel: false, folder: 'base', skin: 'default'};
    }

    public static function isSkinPixel(type:SkinDataType, folder:String) {
        for (suffix in pixelSkins[type]) {
            if (folder.endsWith(suffix)) return true;
        }
        return false;
    }
}