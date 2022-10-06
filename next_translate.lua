-- thank you sapphire for scaleform help and also fixing google's/the regex's bullshit 

-- DEBUG 
local debug = false
-- END DEBUG 

util.ensure_package_is_installed("lua/ScaleformLib")
local chat_scaleform = require("lib.ScaleformLib")("multiplayer_chat")
chat_scaleform:draw_fullscreen()

-- example k,v value: "fr" = true
local whitelisted_langs = {}

local language_codes_by_enum = {
    [0]= "en",
    [1]= "fr",
    [2]= "de",
    [3]= "it",
    [4]= "es",
    [5]= "pt",
    [6]= "pl",
    [7]= "ru",
    [8]= "ko",
    [9]= "zh",
    [10] = "ja",
    [11] = "es",
    [12] = "zh"
}

for _, iso_code in pairs(language_codes_by_enum) do
    whitelisted_langs[iso_code] = true
end

local language_display_names_by_enum = {
    [0] = "English",
    [1] = "French",
    [2] = "German",
    [3] = "Italian",
    [4] = "Spanish",
    [5] = "Portuguese",
    [6] = "Polish",
    [7] = "Russian",
    [8] = "Korean",
    [9] = "Chinese (Traditional)",
    [10] = "Japanese",
    [11] = "Mexican",
    [12] = "Chinese (Simplified)"
}
local my_lang = lang.get_current()
if my_lang == "en-us" then 
    my_lang = "en"
end

local function encode_for_web(text)
    return string.gsub(text, "%s", "+")
end
local function web_decode(text)
    return string.gsub(text, "+", " ")
end

local do_translate = false
local only_translate_foreign = true
local players_on_cooldown = {}

local function google_translate(text, to_lang, pid, outgoing)
    if players_on_cooldown[pid] == nil then
        local encoded_text = encode_for_web(text)
        async_http.init("translate.googleapis.com", "/translate_a/single?client=gtx&sl=auto&tl=" .. to_lang .."&dt=t&q=".. encoded_text, function(data)
            translation, original, langs = data:match("^%[%[%[\"(.-)\",\"(.-)\",.-,.-,.-]],.-,\"(.-)\"")
            local decoded_text = web_decode(translation)
            if langs == nil then
                util.toast("Failed to translate message : Incomplete return values.")
                return
            end
            langs = string.split(langs, '_')
            if #langs < 2 then
                -- source and dest lang are the same (in like 90% of cases)
                return 
            end
            local from_lang = langs[1]
            local dest_lang = langs[2]
            -- dont translate non-whitelisted languages
            if not whitelisted_langs[from_lang] then
                return
            end
            if from_lang ~= to_lang then
                if not outgoing then
                    chat_scaleform.ADD_MESSAGE(players.get_name(pid), decoded_text, "TRANSLATION", false, 24)
                    players_on_cooldown[pid] = true
                    util.yield(1000)
                    players_on_cooldown[pid] = nil
                else
                    chat.send_message(decoded_text, false, true, true)
                end
            end
        end, function()
            util.toast("Failed to translate : Issue reaching Google API. If you think you are blocked, turn on a VPN or switch VPN servers.")
        end)
        async_http.dispatch()
    else
        util.toast(players.get_name(pid) .. " sent a message, but is on cooldown from translations. Consider kicking this player if they are spamming the chat to prevent a possible temporary ban from Google translate.")
    end
end

menu.toggle(menu.my_root(), "On", {"nexttranslateon"}, "Turns translating on/off", function(on)
    do_translate = on
end, false)


menu.toggle(menu.my_root(), "Only translate foreign game lang", {"nexttranslateforeign"}, "Only translates messages from users with a different game language, thus saving API calls. You should leave this on to prevent the chance of Google temporarily blocking your requests.", function(on)
    only_translate_foreign = on
end, true)

local outgoing_list = menu.list(menu.my_root(), "Send outgoing translation", {"nexttranslateout"}, "Send a translated, outgoing chat")
outgoing_list:divider("Select lang to translate to")
for lang_index, lang in pairs(language_display_names_by_enum) do
    local cmd = "translateto" .. string.lower(lang):gsub(' ', ''):gsub('%(', ''):gsub('%)', '')
    outgoing_list:action(lang, {cmd}, "", function()
        util.toast("Enter text to translate")
        menu.show_command_box(cmd .. " ")
    end, function(entry)
        if string.len(entry) > 254 then 
            util.toast("That text is too long to be sent in chat, nerd")
            return 
        end
        util.toast("Translating...")
        google_translate(entry, language_codes_by_enum[lang_index], players.user(), true)
    end)
end

local whitelist_list = menu.list(menu.my_root(), "Translation whitelist", {}, "Only translate languages toggled on in this list")
for id, iso_code in pairs(language_codes_by_enum) do
    whitelist_list:toggle(language_display_names_by_enum[id], {}, "", function(on)
        whitelisted_langs[iso_code] = on
    end, true)
end


menu.action(menu.my_root(), "Disclaimer", {}, "Disclaimer: Note that the Google Translate API, used to translate messages, is not supposed to be used like this, and while the script has multiple safeguards to limit API calls, you may receive a temporary IP-based ban for over-usage. The chances are slim, but you have been warned.", function() end)
async_http.init("pastebin.com", "/raw/nrMdhHwE", function(result)
    menu.hyperlink(menu.my_root(), "Join Discord", result, "")
end)
async_http.dispatch()

chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
    if do_translate and networked then
        local encoded_text = encode_for_web(text)
        local player_lang = language_codes_by_enum[players.get_language(sender)]
        if (only_translate_foreign and player_lang == my_lang) then
            return
        end
        if not debug then 
            if players.user() == sender then 
                return 
            end
        end
        -- credit to the original chat translator for the api code
        google_translate(encoded_text, my_lang, sender, false)
    end
end)

util.keep_running()