-- thank you sapphire for scaleform help and also fixing google's/the regex's bullshit 

util.ensure_package_is_installed("lua/ScaleformLib")
local chat_scaleform = require("lib.ScaleformLib")("multiplayer_chat")
chat_scaleform:draw_fullscreen()

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

local my_lang = lang.get_current()

local function encode_for_web(text)
    return string.gsub(text, "%s", "+")
end
local function web_decode(text)
    return string.gsub(text, "+", " ")
end

local function get_iso_version_of_lang(lang_code)
    lang_code = string.lower(lang_code)
    if lang_code ~= "zh-cn" and lang_code ~= "zh-tw" then
        return string.split(lang_code, '-')[1]
    else
        return lang_code
    end
end

local iso_my_lang = get_iso_version_of_lang(my_lang)

local do_translate = false
menu.toggle(menu.my_root(), "On", {"nextton"}, "Turns translating on/off", function(on)
    do_translate = on
end, false)

local only_translate_foreign = true
menu.toggle(menu.my_root(), "Only translate foreign game lang", {"nextforeignonly"}, "Only translates messages from users with a different game language, thus saving API calls. You should leave this on to prevent the chance of Google temporarily blocking your requests.", function(on)
    only_translate_foreign = on
end, true)

menu.action(menu.my_root(), "Disclaimer", {}, "Disclaimer: Note that the Google Translate API, used to translate messages, is not supposed to be used like this, and while the script has multiple safeguards to limit API calls, you may receive a temporary IP-based ban for over-usage. The chances are slim, but you have been warned.", function() end)

local players_on_cooldown = {}

chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
    if do_translate and networked and players.user() ~= sender then
        local encoded_text = encode_for_web(text)
        local player_lang = language_codes_by_enum[players.get_language(sender)]
        local player_name = players.get_name(sender)
        if only_translate_foreign and player_lang == my_lang and players.user() ~= sender then
            return
        end
        -- credit to the original chat translator for the api code
        local translation
        if players_on_cooldown[sender] == nil then
            async_http.init("translate.googleapis.com", "/translate_a/single?client=gtx&sl=auto&tl=" .. iso_my_lang .."&dt=t&q=".. encoded_text, function(data)
                translation, original, source_lang = data:match("^%[%[%[\"(.-)\",\"(.-)\",.-,.-,.-]],.-,\"(.-)\"")
                local decoded_text = web_decode(translation)
                if source_lang == nil then
                    util.toast("Failed to translate a message from " .. player_name .. ": Incomplete return values.")
                    return
                end
                players_on_cooldown[sender] = true
                if get_iso_version_of_lang(source_lang) ~= iso_my_lang then
                    chat_scaleform.ADD_MESSAGE(player_name, decoded_text, "TRANSLATION", false, 24)
                end
                util.yield(1000)
                players_on_cooldown[sender] = nil
            end, function()
                util.toast("Failed to translate a message from " .. player_name .. ": Issue reaching Google API.")
            end)
            async_http.dispatch()
        else
            util.toast(player_name .. "sent a message, but is on cooldown from translations. Consider kicking this player if they are spamming the chat to prevent a possible temporary ban from Google translate.")
        end
    end
end)

util.keep_running()