-- =========================================================
--  KS-CHAT — KEOPS Studios
--  Serveur
-- =========================================================

local lastMessageAt = {}   -- [source] = GetGameTimer()
local lastAdAt = {}        -- [source] = os.time()
local lastPmPartner = {}   -- [source] = targetSource (pour /r côté serveur, log uniquement)

local VORPcore = nil
CreateThread(function()
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok then VORPcore = core end
end)

-- ---------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------

local NativeGetPlayerName = GetPlayerName
local function GetPlayerName(src)
    return NativeGetPlayerName(src) or ('Joueur ' .. src)
end

local function IsSpamming(src)
    local now = GetGameTimer()
    if lastMessageAt[src] and (now - lastMessageAt[src]) < Config.SpamCooldown then
        return true
    end
    lastMessageAt[src] = now
    return false
end

local function SanitizeText(text)
    text = text:sub(1, Config.MaxMessageLength)
    text = text:gsub('<', '&lt;'):gsub('>', '&gt;')

    if Config.Filter.BlockLinks then
        text = text:gsub('https?://%S+', '[lien retiré]')
    end

    for _, word in ipairs(Config.Filter.BannedWords) do
        if word ~= '' then
            text = text:gsub((word:gsub('%p', '%%%1')), string.rep('*', #word))
        end
    end

    return text
end

local function GetDistance(a, b)
    if not a or not b then return 9999.0 end
    return #(a - b)
end

local function GetNearbyPlayers(src, range)
    local list = { src }
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return list end
    local origin = GetEntityCoords(ped)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= src then
            local otherPed = GetPlayerPed(pid)
            if otherPed and otherPed ~= 0 then
                local dist = GetDistance(origin, GetEntityCoords(otherPed))
                if dist <= range then
                    list[#list + 1] = pid
                end
            end
        end
    end
    return list
end

local function IsStaff(src)
    if not VORPcore then return false end
    local ok, User = pcall(function() return VORPcore.getUser(src) end)
    if not ok or not User then return false end

    local group = nil
    local okGroup, result = pcall(function() return User.getGroup() end)
    if okGroup then group = result end

    if not group then return false end

    for _, staffGroup in ipairs(Config.StaffGroups) do
        if group == staffGroup then return true end
    end
    return false
end

local function GetOnlineStaff()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if IsStaff(pid) then list[#list + 1] = pid end
    end
    return list
end

local function PostDiscord(webhook, title, color, name, src, text)
    if not Config.Discord.Enabled or webhook == '' then return end

    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        username = Config.Discord.Username,
        avatar_url = Config.Discord.Avatar,
        embeds = {
            {
                title = title,
                description = text,
                color = color,
                footer = { text = ('%s (ID %s)'):format(name, src) },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function Send(target, template)
    TriggerClientEvent('chat:addMessage', target, { template = template })
end

local function SendToList(list, template)
    for _, pid in ipairs(list) do
        Send(pid, template)
    end
end

-- ---------------------------------------------------------
-- Chat principal (dire) — proximité
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:say', function(text)
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)

    -- Événement de compatibilité, annulable par d'autres resources (logs, anti-cheat...)
    local guard = { cancel = false }
    TriggerEvent('chatMessage', src, name, text, guard)
    if guard.cancel then return end

    local recipients = GetNearbyPlayers(src, Config.Ranges.say)
    local template = ('<div class="ks-msg ks-msg--say"><span class="ks-name">%s</span><span class="ks-text">%s</span></div>')
        :format(name, text)
    SendToList(recipients, template)
end)

-- ---------------------------------------------------------
-- /me
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:me', function(text)
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local recipients = GetNearbyPlayers(src, Config.Ranges.me)
    local template = ('<div class="ks-msg ks-msg--me">* %s %s *</div>'):format(name, text)
    SendToList(recipients, template)
end)

-- ---------------------------------------------------------
-- /do
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:do', function(text)
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local recipients = GetNearbyPlayers(src, Config.Ranges.doo)
    local template = ('<div class="ks-msg ks-msg--do">* %s <span class="ks-do-author">( %s )</span> *</div>'):format(text, name)
    SendToList(recipients, template)
end)

-- ---------------------------------------------------------
-- /ooc — global
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:ooc', function(text)
    if not Config.OOC.Enabled then return end
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--ooc"><span class="ks-tag">[HRP]</span> <span class="ks-name">%s</span><span class="ks-text">%s</span></div>')
        :format(name, text)

    for _, playerId in ipairs(GetPlayers()) do
        Send(tonumber(playerId), template)
    end

    PostDiscord(Config.Discord.WebhookOOC, 'Chat Hors-RP (Global)', 8092539, name, src, text)
end)

-- ---------------------------------------------------------
-- /b — Hors-RP local
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:looc', function(text)
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local recipients = GetNearbyPlayers(src, Config.Ranges.looc)
    local template = ('<div class="ks-msg ks-msg--looc"><span class="ks-tag">[B]</span> <span class="ks-name">%s</span><span class="ks-text">%s</span></div>')
        :format(name, text)
    SendToList(recipients, template)
end)

-- ---------------------------------------------------------
-- /ad — publicité serveur
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:ad', function(text)
    if not Config.Ad.Enabled then return end
    local src = source
    text = SanitizeText(text)
    if text == '' then return end

    local now = os.time()
    if lastAdAt[src] and (now - lastAdAt[src]) < Config.Ad.Cooldown then
        local remaining = Config.Ad.Cooldown - (now - lastAdAt[src])
        Send(src, ('<div class="ks-msg ks-msg--error">Attendez encore %d secondes avant votre prochaine publicité.</div>'):format(remaining))
        return
    end

    if Config.Ad.Price > 0 and VORPcore then
        local ok, User = pcall(function() return VORPcore.getUser(src) end)
        if ok and User then
            local Character = User.getUsedCharacter
            local okMoney, has = pcall(function() return Character.money >= Config.Ad.Price end)
            if okMoney and not has then
                Send(src, '<div class="ks-msg ks-msg--error">Vous n\'avez pas assez d\'argent pour publier une annonce.</div>')
                return
            end
            pcall(function()
                exports.vorp_core:subMoney(src, Config.Ad.Price, "Publicité")
            end)
        end
    end

    lastAdAt[src] = now
    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--ad"><span class="ks-tag">[PUB]</span> <span class="ks-name">%s</span><span class="ks-text">%s</span></div>')
        :format(name, text)

    for _, playerId in ipairs(GetPlayers()) do
        Send(tonumber(playerId), template)
    end
end)

-- ---------------------------------------------------------
-- /mp — message privé + /r (réponse)
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:pm', function(targetId, text)
    local src = source
    if IsSpamming(src) then return end
    text = SanitizeText(text)
    if text == '' then return end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) or GetPlayerPed(targetId) == 0 then
        Send(src, '<div class="ks-msg ks-msg--error">Joueur introuvable.</div>')
        return
    end

    local nameFrom = GetPlayerName(src)
    local nameTo = GetPlayerName(targetId)

    Send(src, ('<div class="ks-msg ks-msg--pm"><span class="ks-tag">[MP → %s]</span><span class="ks-text">%s</span></div>'):format(nameTo, text))
    Send(targetId, ('<div class="ks-msg ks-msg--pm"><span class="ks-tag">[MP de %s]</span><span class="ks-text">%s</span></div>'):format(nameFrom, text))

    TriggerClientEvent('ks-chat:setLastPm', targetId, src)
    TriggerClientEvent('ks-chat:setLastPm', src, targetId)

    lastPmPartner[src] = targetId
    lastPmPartner[targetId] = src
end)

-- ---------------------------------------------------------
-- /a — chat staff
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:admin', function(text)
    local src = source
    if not IsStaff(src) then
        Send(src, '<div class="ks-msg ks-msg--error">Commande réservée au staff.</div>')
        return
    end
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--admin"><span class="ks-tag">[STAFF]</span> <span class="ks-name">%s</span><span class="ks-text">%s</span></div>')
        :format(name, text)

    SendToList(GetOnlineStaff(), template)
    PostDiscord(Config.Discord.WebhookAdmin, 'Chat Staff', 16007990, name, src, text)
end)

-- ---------------------------------------------------------
-- /report
-- ---------------------------------------------------------

RegisterServerEvent('ks-chat:report', function(text)
    local src = source
    text = SanitizeText(text)
    if text == '' then return end

    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--report"><span class="ks-tag">[SIGNALEMENT]</span> <span class="ks-name">%s (ID %s)</span><span class="ks-text">%s</span></div>')
        :format(name, src, text)

    local staff = GetOnlineStaff()
    if #staff > 0 then
        SendToList(staff, template)
    end

    Send(src, '<div class="ks-msg ks-msg--success">Votre signalement a été envoyé au staff. Merci.</div>')
    PostDiscord(Config.Discord.WebhookReport, 'Nouveau signalement', 15105570, name, src, text)
end)

-- ---------------------------------------------------------
-- Messages système (connexion / déconnexion)
-- ---------------------------------------------------------

AddEventHandler('playerJoining', function()
    local src = source
    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--system">%s a rejoint le serveur.</div>'):format(name)
    for _, playerId in ipairs(GetPlayers()) do
        Send(tonumber(playerId), template)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local name = GetPlayerName(src)
    local template = ('<div class="ks-msg ks-msg--system">%s a quitté le serveur. <span class="ks-reason">(%s)</span></div>'):format(name, reason)
    for _, playerId in ipairs(GetPlayers()) do
        Send(tonumber(playerId), template)
    end
end)

-- ---------------------------------------------------------
-- Exports compatibles avec l'API du chat par défaut
-- ---------------------------------------------------------

exports('AddMessage', function(target, message)
    if type(message) == 'string' then
        message = { template = ('<div class="ks-msg ks-msg--system">%s</div>'):format(message) }
    end
    if target == -1 then
        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('chat:addMessage', tonumber(playerId), message)
        end
    else
        TriggerClientEvent('chat:addMessage', target, message)
    end
end)

exports('AddSuggestion', function(target, name, help, params)
    if target == -1 then
        TriggerClientEvent('chat:addSuggestion', -1, name, help, params)
    else
        TriggerClientEvent('chat:addSuggestion', target, name, help, params)
    end
end)

exports('RemoveSuggestion', function(target, name)
    TriggerClientEvent('chat:removeSuggestion', target, name)
end)

exports('AddTemplate', function(target, id, template)
    TriggerClientEvent('chat:addTemplate', target, id, template)
end)

exports('Clear', function(target)
    TriggerClientEvent('chat:clear', target or -1)
end)
