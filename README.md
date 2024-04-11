# pdlocalization
LUA-based localization for Playdate

# Setup
Download the Localization.lua file to your projects source.

Then create a `strings-en.txt` file in the `languageFilePath` folder (`assets/loc/` by default). Within that text file, paste this text for testing, and save:
```
test1	Hello
test2	World
test3	[L:test1] [L:test2]
```

In your code, add the following lines:
```
import "Localization"
local loc <const> = Localization.get

-- Load the strings-en.txt file
Localization.load("en")

-- print the 'test3' entry
print(loc("test3"))
```
When you run this, you should see a 'Hello World' in your console output.

# Localization file syntax
The file should be called `strings-<languageId>.txt`.  
The basic syntax is tab-separated key-value pairs:  
`key	value`  
Tags can be added anywhere in the `value` strings, that will be replaced through the `Localization.get` call.  
There are some tags supported by default:  
`[L:key]`: Localizes the string with key `key` and slot it in the place where the tag was.  
`[LUPPER:key]`: Same as above, but will convert the localized string to uppercase.  
`[LLOWER:key]`: Same as above, but with lowercase instead.  
`[NEWLINE]`: Insert a newline (`\n`) in the localized string.  
`[EMPTY]`: Is replaced with an empty string. Useful if a tag should explicitly localize to an empty string.  
Additionally, any custom tags can be added, to be passed as `replacements` argument to `Localization.get`. These don't have a set syntax (it's a straight string replacement) but it's recommended to use all caps surrounded by square brackets for consistency.

An example entry using a custom tag:  
`moveToLocation	Move to [LOCATION]`, when called with `Localization.get("moveToLocation", {{"[LOCATION]", "McDonalds"}})`, will result in the text "Move to McDonalds".

When loading, any empty lines, and lines starting with `#`, are ignored entirely.

# Configuration
At the top of Localization.lua are a few things to configure if necessary:  
`Localization.mainLanguage = "en"`: The 'main' language to use as the basis for checking localization entries in other languages for missing keys, inconsistent tag usage, etc.  
`Localization.languageFilePath = "assets/loc/"`: The path to your localization files.  
`Localization.cacheLanguages = true`: Whether loaded languages should be cached. Setting this to true prevents framedrops when loading a language a second time, but takes up more memory.  
`Localization.defaultTextReplacements = { [...] }`: Default tags to replace. If you have any commonly used tags that you don't want to repeatedly define in the `replacements` argument to `Localization.get`, add them here.  

It's recommended to configure these as assignments from outside the Localization.lua file (e.g. `Localization.mainLanguage = "nl"` in main.lua) so that for any updates to this library you can fully overwrite the Localization.lua file without breaking your game.

# API Documentation

## Localization.check(languages, measurements)
Compares string entries in the language files, and prints missing entries, inconsistent tag usage, and keys of localized strings that don't fit within given measurements.

Arguments:  
`languages`: Array of language identification strings, e.g. `{"en", "es"}`  
`measurements`: Array of measurements to be used to check string sizes. Can be `nil`. e.g.:
```
{
{
	keyMatchPattern = "^action_",
	font = titleFont,
	maxWidth = 390,
	maxHeight = 48
},
}
```
`keyMatchPattern`: A lua pattern used to identify which keys to check for this measurement.  
`font`: A playdate font (loaded with `playdate.graphics.font.new()`) to use for measuring the text  
`maxWidth`: The max width of this text - if the text exceeds this width, the key for this string will be printed along with its measured size.  
`maxHeight`: (Optional) The max height of this text. If defined, the text will be measured using `playdate.graphics.getTextSizeForMaxWidth(maxWidth)` and flagged if its height exceeds `maxHeight`.  

## Localization.get(key, replacements, quiet)
Retrieves a localized entry from the currently loaded localization file.

Arguments:  
`key`: The key to retrieve  
`replacements`: (Optional) An array of key-value arrays to be used when replacing text in the retrieved value, e.g. `{{"[TEST]", 5},}` to replace any instances of `[TEST]` with `5`.  
`quiet`: (Optional) If false or absent, will print that the key could not be found.

If the value cannot be found, the key will be returned surrounded by ##s so you can identify any missing strings visually immediately.  
Replacement values will be converted to strings automatically, so numbers and strings are both acceptable.  
In addition to the passed `replacements`, `Localization.defaultTextReplacements` will also be replaced. The argument `replacements` will be processed first, so it's possible to override `defaultTextReplacements` if necessary.  
See 'Localization file syntax' for details on tags.

## Localization.getCurrentLanguage()
Returns the currently loaded/active language identifier

## Localization.load(language)
Loads the provided language and sets it as active.

Arguments:  
`language`: The language identifier to load. E.g. `Localization.load("en")` will result in the file `assets/loc/strings-en.txt` being loaded and parsed. If `Localization.cacheLanguages` is true, the previously loaded language will be cached - otherwise, it'll be discarded.

Upon successful load, all listener functions registered through `Localization.registerListener` will be called.

## Localization.registerListener(listener)
Registers a function to be called when a new language has been loaded.

Arguments:  
`listener`: The function to be called. The function will be called without any arguments, as soon as a language was successfully loaded.
