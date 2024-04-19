local pd <const> = playdate
local sgmatch <const> = string.gmatch
local sbyte <const> = string.byte

local currentLanguage = ""

Localization = {}

Localization.mainLanguage = "en"
Localization.languageFilePath = "assets/loc/"
Localization.cacheLanguages = true
Localization.defaultTextReplacements = {
	{"[NEWLINE]",	"\n"},
	{"[EMPTY]",		""}
}

function Localization.getCurrentLanguage() return currentLanguage end

local cachedLanguages = {}

local textEntries = {}
local listeners = {}

function Localization.registerListener(listener)
	table.insert(listeners, listener)
end

function Localization.load(language)
	if language == currentLanguage then
		return
	end

	currentLanguage = language

	if Localization.cacheLanguages and cachedLanguages[language] ~= nil then
		textEntries = cachedLanguages[language]
		
		for _, listener in ipairs(listeners) do
			listener()
		end
		return
	end

	textEntries = {}
	print("Loading localization: ", language)
	local path = Localization.languageFilePath .. "strings-" .. language .. ".txt"
	if not pd.file.exists(path) then
		print("File", path, "doesn't exist")
		return
	end

	local textFile, error = pd.file.open(path)
	if error then
		print("File load error:", error)
		return
	end

	local fileSize = pd.file.getSize(path)
	local numEntriesApprox = fileSize / 100
	textEntries = table.create(0, numEntriesApprox)

	local content = textFile:read(fileSize)
	textFile:close()

	local commentByte = sbyte('#')
	local numEntries = 0

	for line, k, v in sgmatch(content, "[\r\n]*((%g-)\t(.-))[\r\n]+") do
		if sbyte(line, 1, 1) ~= commentByte then
			if k ~= "" then
				--print("Loc entry:", k)
				textEntries[k] = v
				numEntries += 1
			end
		end
	end
	print("Localization load done,", numEntries, "entries")

	for _, listener in ipairs(listeners) do
		listener()
	end

	if Localization.cacheLanguages then
		cachedLanguages[language] = table.deepcopy(textEntries)
	end
end

local function replaceInString(str, needle, repl)
    needle = needle:gsub("[]%-%%[^$().*+?]", "%%%1")
    repl = repl:gsub("%%", "%%%%")
    return str:gsub(needle, repl)
end

local function getSpecific(translations, str, replacements, quiet)
	local text = translations[str]
	if text == nil or text == "" then
		if quiet == false then
			print("Localization entry", str, "not found")
		end
		return "##" .. str .. "##"
	end

	if string.find(text, "%[") then
		-- Nested localization
		for set, entry in sgmatch(text, "(%[L:([%w_]+)%])") do
			text = replaceInString(text, set, getSpecific(translations, entry))
		end
		for set, entry in sgmatch(text, "(%[LUPPER:([%w_]+)%])") do
			text = replaceInString(text, set, string.upper(getSpecific(translations, entry)))
		end
		for set, entry in sgmatch(text, "(%[LLOWER:([%w_]+)%])") do
			-- Lowercase needs to do replacements since tags are (assumed) uppercase
			text = replaceInString(text, set, string.lower(getSpecific(translations, entry, replacements)))
		end

		-- Custom replacements
		if replacements ~= nil then
			for _, v in ipairs(replacements) do
				text = replaceInString(text, v[1], tostring(v[2]))
			end
		end
		-- Default replacements
		for _, v in ipairs(Localization.defaultTextReplacements) do
			text = replaceInString(text, v[1], tostring(v[2]))
		end
	end

	return text
end

function Localization.get(str, replacements, quiet)
	return getSpecific(textEntries, str, replacements, quiet)
end

function Localization.check(languages, measurements)
	pd.graphics.pushContext()
	local preCheckLanguage = currentLanguage

	-- Load and cache all languages
	Localization.cacheLanguages = true
	for i = 1, #languages do
		Localization.load(languages[i])
	end

	print("\nCHECKING LOCALIZATION ENTRIES\n")
	print("Languages:")
	for _, language in ipairs(languages) do
		print("  - " .. language)
	end
	local mainLanguageTable = cachedLanguages[Localization.mainLanguage]
	local keys = {}
	for key, _ in pairs(mainLanguageTable) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local numIssues = 0

	-- Check potential key/format issues
	print("\n-- CHECKING FILE FORMAT --")
	for _, lang in ipairs(languages) do
		local path = Localization.languageFilePath .. "strings-" .. lang .. ".txt"
		if not pd.file.exists(path) then
			print(lang .. " localization file doesn't exist")
			numIssues += 1
		else
			local textFile, error = pd.file.open(path)
			if error then
				print("File load error:", error)
				numIssues += 1
			else
				local line = textFile:readline()
				local lineNumber = 0
				while line ~= nil do
					lineNumber += 1
					if line ~= "" and sbyte(line, 1, 1) ~= sbyte('#') then
						local keyExists = false
						for k, v in sgmatch(line, "(.-)\t(.*)") do
							if k ~= "" then
								keyExists = true
							end
						end
						if not keyExists then
							if sbyte(line, 1, 1) ~= sbyte('#') then
								print(lang .. ": Potential format issue (no key/value pair detected) at line " .. lineNumber .. ":", line)
								numIssues += 1
							end
						end
					end
					line = textFile:readline()
				end
				textFile:close()
			end
		end
	end

	-- Compare tags/keys
	print("\n-- CHECKING TAGS/KEYS --")
	for _, lang in ipairs(languages) do
		if lang ~= Localization.mainLanguage then
			local translations = cachedLanguages[lang]

			for k, _ in pairs(translations) do
				if mainLanguageTable[k] == nil then
					print(lang .. ": Key '" .. k .. "' does not exist in main language (" .. Localization.mainLanguage .. ")")
					numIssues += 1
				end
			end

			for _, key in ipairs(keys) do
				local valueMain = mainLanguageTable[key]
				local valueLang = translations[key]
				if valueLang == nil then
					print(lang .. ": Missing key '" .. key .. "'")
					numIssues += 1
				else
					-- Get tags in main language
					local tagsMain = {}
					for entry in sgmatch(valueMain, "%[[%w%s_:]+%]") do
						table.insert(tagsMain, entry)
					end
					table.sort(tagsMain)

					-- Get tags in lang
					local tagsLang = {}
					for entry in sgmatch(valueLang, "%[[%w%s_:]+%]") do
						table.insert(tagsLang, entry)
					end
					table.sort(tagsLang)

					-- Compare
					for i = 1, #tagsMain do
						if tagsMain[i] ~= nil then
							if tagsLang[i] ~= tagsMain[i] then
								if tagsLang[i] == nil then
									print(lang .. ": Entry '" .. key .. "' has incorrect number of tags")
									numIssues += 1
								else
									print(lang .. ": Entry '" .. key .. "' uses an incorrect tag: ".. tagsLang[i] .. " vs " .. tagsMain[i])
									numIssues += 1
								end
							end
						end
					end
				end
			end
		end
	end

	-- Check text measurements
	print("\n-- CHECKING MEASUREMENTS --")
	if measurements ~= nil then
		for _, lang in ipairs(languages) do
			local translations = cachedLanguages[lang]

			for _, key in ipairs(keys) do
				for _, measurement in ipairs(measurements) do
					if string.find(key, measurement.keyMatchPattern) then
						local translation = getSpecific(translations, key)
						--print("Measured text: " .. translations[key] .. " - " .. width .. "px")
						if measurement.maxHeight == nil then
							local width = measurement.font:getTextWidth(translation)
							if width > measurement.maxWidth then
								print(lang .. ": Entry '" .. key .. "' is too long: " .. width .. " vs " .. measurement.maxWidth)
								numIssues += 1
							end
						else
							pd.graphics.setFont(measurement.font)
							local _, height = pd.graphics.getTextSizeForMaxWidth(translation, measurement.maxWidth)
							if height > measurement.maxHeight then
								print(lang .. ": Entry '" .. key .. "' is too tall: " .. height .. " vs " .. measurement.maxHeight)
								numIssues += 1
							end
						end
					end
				end
			end
		end
	end

	print("\nLocalization check done, found", numIssues, "issues\n")
	pd.graphics.popContext()
	Localization.load(preCheckLanguage)
end
