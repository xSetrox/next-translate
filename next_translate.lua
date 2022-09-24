---@diagnostic disable: lowercase-global

function get_iso_version_of_lang(lang_code)
    lang_code = string.lower(lang_code)
    if lang_code ~= "zh-cn" and lang_code ~= "zh-tw" then
        return string.split(lang_code, '-')[1]
    else
        return lang_code
    end

end

local ind = -1
local message_history <const> = {}
local player_action_list <const> = {}
local language_codes_by_enum = {
    [0]= "en-us",
    [1]= "fr-fr",
    [2]= "de-de",
    [3]= "it-it",
    [4]= "es-es",
    [5]= "pt-br",
    [6]= "pl-pl",
    [7]= "ru-ru",
    [8]= "ko-kr",
    [9]= "zh-tw",
    [10] = "ja-jp",
    [11] = "es-mx",
    [12] = "zh-cn"
}
local output_modes <const> = {
	"All Chat",
	"Team Chat",
	"IIRC",
}
local my_name = players.get_name(players.user())
local my_lang = lang.get_current()
local iso_my_lang = get_iso_version_of_lang(my_lang)
------------------------settings-----------------------
local translate_incoming = false
local translate_language_incoming = "en"
local output_mode = 2
local translate_networked = false

local translate_outgoing = false
local translate_language_outgoing = "en"

local only_translate_foreign = true
-------------------Incoming Messages----------------------
local incoming <const> = menu.list(menu.my_root(), "Incoming Messages", {"incomingtranslate"}, "")
menu.toggle(incoming, "Enable", {"translateincoming"}, "Enable Translations", function(toggle)
	translate_incoming = toggle
end)
menu.text_input(incoming, "Select Language", {"translateincominglanguage"}, "", function (input)
	translate_language_incoming = input
end, "en")
menu.slider_text(incoming, "Output", {"translateoutputmode"}, "Where to output the translation to", output_modes, function(index)
	output_mode = index - 1
end)
menu.toggle(incoming, "Networked Messages", {"translatenetworked"}, "Other people will be able to see the translation messages", function(toggle)
	translate_networked = toggle
end)
menu.toggle(incoming, "Only translate foreign game lang", {"nextforeignonly"}, "Only translates messages from users with a different game language, thus saving API calls. You should leave this on to prevent the chance of Google temporarily blocking your requests.", function(on)
    only_translate_foreign = on
end, true)
--------------------Outgoing Messages-------------------
local outgoing <const> = menu.list(menu.my_root(), "Outgoing Messages", {"outgoingtranslate"}, "")
menu.toggle(outgoing, "Enable", {"translateoutgoing"}, "", function(toggle)
	translate_outgoing = toggle
	if output_mode == 1 then
		output_mode = 2
		util.log("Changed translation output to IIRC to avoid double translation")
		util.toast("Changed translation output to IIRC to avoid double translation")
	end
end)
menu.text_input(outgoing, "Select Language", {"translateoutgoinglanguage"}, "", function (input)
	translate_language_outgoing = input
end, "en")
local disclaimer = menu.action(menu.my_root(), "Disclaimer", {""}, "Disclaimer: Note that the Google Translate API, used to translate messages, is not supposed to be used like this, and while the script has multiple safeguards to limit API calls, you may receive a temporary IP-based ban for over-usage. The chances are slim, but you have been warned.", function() end)

local function encode_for_web(text)
	return string.gsub(text, "%s", "+")
end

local function web_decode(text)
    return string.gsub(text, "+", " ")
end

local function create_label(player_name, team_chat, message)
	if team_chat then
		message = " [TEAM] " .. message
	else
		message = " [ALL] " .. message
	end
	message = player_name .. message
	return message
end

local function output_incoming(text)
	if output_mode < 2 then
		local is_team = output_mode == 1 and true or false
		chat.send_message(text, is_team, true, translate_networked)
	else
		util.log(text)
	end
end

function output_outgoing(text)
	chat.send_message(text, false, true, true)
end

function on_fail(type, sender)
	if type == 1 then
		util.log("Failed to translate a message from " .. (sender or my_name))
		util.toast("Failed to translate a message from " .. (sender or my_name))
	else
		util.log("Request failed to translate message from " .. (sender or my_name))
		util.toast("Request failed to translate message from " .. (sender or my_name))
	end
end

function send_translated_message(message)
	local encoded_text = encode_for_web(message.message)
	
        local translation
		async_http.init("translate.googleapis.com", "/translate_a/single?client=gtx&sl=auto&tl=" .. (type(message.sender) == 'string' and translate_language_incoming or translate_language_outgoing) .."&dt=t&q=".. encoded_text,
		function(data)
			translation, original, source_lang = data:match("^%[%[%[\"(.-)\",\"(.-)\",.-,.-,.-]],.-,\"(.-)\"")
			if source_lang == false then on_fail(1, message.sender) end
			translation = web_decode(translation)
			if translation ~= message.message then
				if type(message.sender) == 'string' then
					output_incoming(create_label(message.sender, message.team_chat, translation))
				else
					output_outgoing(translation)
				end
			end
		end, on_fail(2, message.sender))
	async_http.dispatch()
end

menu.text_input(outgoing, "Send Translated Message", {"sendtrwanslatedmessage"}, "", function (input)
	send_translated_message({sender = false, team_chat = false, message = input})
end)

chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
	local player_name = players.get_name(sender)
	local player_lang = language_codes_by_enum[players.get_language(sender)]

	ind = ind + 1
	table.insert(message_history, {
		sender = player_name,
		team_chat = team_chat,
		message = text,
	})
	table.insert(player_action_list, {create_label(player_name, team_chat, text), {ind + 1}, "Translate Message"})
	if only_translate_foreign and player_lang == my_lang then
		return
	end	
	if translate_incoming and my_name ~= player_name then
		send_translated_message({sender = player_name, team_chat = team_chat, message = text})
	end
	if translate_outgoing and team_chat and my_name == player_name then
		send_translated_message({sender = false, team_chat = false, message = text})
	end
	if chat_history then menu.delete(chat_history) end
	menu.delete(disclaimer)

	chat_history = menu.list_action(menu.my_root(), "Chat History", {"chathistory" .. ind}, "History of translateable chat messages", player_action_list, function (index)
		send_translated_message(message_history[index])
	end)

	disclaimer = menu.action(menu.my_root(), "Disclaimer", {'remdisclaimer'}, "Disclaimer: Note that the Google Translate API, used to translate messages, is not supposed to be used like this, and while the script has multiple safeguards to limit API calls, you may receive a temporary IP-based ban for over-usage. The chances are slim, but you have been warned.", function() end)
end)

util.keep_running()
