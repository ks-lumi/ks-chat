-- =========================================================
--  KS-CHAT — KEOPS Studios
--  Client
-- =========================================================

local isChatOpen = false
local suggestions = {}      -- [name] = { help = "", params = {} }
local commandHistory = {}
local lastPmSource = nil

-- Le chat ne s'affiche qu'une fois le personnage réellement sélectionné
-- et chargé en jeu (pas pendant l'écran de sélection de personnage).
local characterReady = false
local function MarkCharacterReady()
    characterReady = true
end
-- Les deux événements sont écoutés : `vorp_core:Client:OnPlayerSpawned`
-- (déclenché par vorp_core/client/spawnplayer.lua une fois le fondu de
-- spawn terminé et le joueur réellement jouable) est le signal le plus
-- fiable, mais on garde `vorp:SelectedCharacter` en complément par
-- compatibilité si jamais l'un des deux ne se déclenche pas.
RegisterNetEvent('vorp_core:Client:OnPlayerSpawned', MarkCharacterReady)
RegisterNetEvent('vorp:SelectedCharacter', MarkCharacterReady)

-- ---------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------

local function OpenChat()
    if not characterReady then return end
    if isChatOpen then return end
    isChatOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'ks-chat:focus', focus = true })
end

local function CloseChat()
    if not isChatOpen then return end
    isChatOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'ks-chat:focus', focus = false })
end

RegisterKeyMapping('ks_chat_open', 'Ouvrir le chat', 'keyboard', Config.ChatKey)
RegisterCommand('ks_chat_open', function()
    OpenChat()
end, false)

-- KEOPS Studios : `vorpcharacter:selectCharacter` (déclenché par
-- vorp_character à l'ouverture de l'écran de sélection — connexion
-- initiale OU retour via /disconnect) doit au contraire repasser
-- characterReady à false et fermer le chat s'il était ouvert, sinon il
-- resterait affiché/utilisable par-dessus l'écran de sélection lors d'un
-- /disconnect en cours de jeu.
RegisterNetEvent('vorpcharacter:selectCharacter', function()
    characterReady = false
    CloseChat()
end)

-- ---------------------------------------------------------
-- Suggestions (API compatible avec le chat FiveM/RedM par défaut)
-- ---------------------------------------------------------

local function PushSuggestions()
    local list = {}
    for name, data in pairs(suggestions) do
        list[#list + 1] = { name = name, help = data.help, params = data.params }
    end
    SendNUIMessage({ type = 'ks-chat:suggestions', suggestions = list })
end

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    name = name:gsub('^/', '')
    suggestions[name] = { help = help or '', params = params or {} }
    PushSuggestions()
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    name = name:gsub('^/', '')
    suggestions[name] = nil
    PushSuggestions()
end)

local function RegisterLocalSuggestion(name, help, params)
    suggestions[name] = { help = help, params = params or {} }
end

-- ---------------------------------------------------------
-- Affichage des messages (API compatible chat:addMessage / chat:addTemplate / chat:clear)
-- ---------------------------------------------------------

RegisterNetEvent('chat:addMessage', function(msg)
    if not characterReady then return end
    SendNUIMessage({ type = 'ks-chat:message', message = msg })
end)

RegisterNetEvent('chat:addTemplate', function(id, template)
    if not characterReady then return end
    SendNUIMessage({ type = 'ks-chat:template', id = id, template = template })
end)

RegisterNetEvent('chat:clear', function()
    SendNUIMessage({ type = 'ks-chat:clear' })
end)

RegisterNetEvent('ks-chat:setLastPm', function(src)
    lastPmSource = src
end)

-- ---------------------------------------------------------
-- Callbacks NUI
-- ---------------------------------------------------------

RegisterNUICallback('ks-chat:submit', function(data, cb)
    CloseChat()
    local text = data.message and data.message:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if text ~= '' then
        commandHistory[#commandHistory + 1] = text

        if text:sub(1, 1) == '/' then
            local cmd = text:match('^/(%S+)')
            if cmd == Config.Commands.reply and lastPmSource == nil then
                TriggerEvent('chat:addMessage', {
                    template = '<div class="ks-msg ks-msg--error">Personne à qui répondre pour le moment.</div>'
                })
            else
                ExecuteCommand(text:sub(2))
            end
        else
            TriggerServerEvent('ks-chat:say', text)
        end
    end

    cb('ok')
end)

RegisterNUICallback('ks-chat:close', function(_, cb)
    CloseChat()
    cb('ok')
end)

RegisterNUICallback('ks-chat:getHistory', function(_, cb)
    cb(commandHistory)
end)

-- ---------------------------------------------------------
-- Commandes RP
-- ---------------------------------------------------------

RegisterCommand(Config.Commands.me, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:me', text)
end, false)
RegisterLocalSuggestion(Config.Commands.me, "Décrit une action à la 3e personne (RP)", { { name = 'texte', help = "L'action à décrire" } })

RegisterCommand(Config.Commands.doo, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:do', text)
end, false)
RegisterLocalSuggestion(Config.Commands.doo, 'Décrit une scène/un objet visible autour de vous (RP)', { { name = 'texte', help = 'La description' } })

RegisterCommand(Config.Commands.ooc, function(_, args)
    if not Config.OOC.Enabled then return end
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:ooc', text)
end, false)
RegisterLocalSuggestion(Config.Commands.ooc, 'Message Hors-RP visible par tout le serveur', { { name = 'texte', help = 'Votre message' } })

RegisterCommand(Config.Commands.looc, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:looc', text)
end, false)
RegisterLocalSuggestion(Config.Commands.looc, 'Message Hors-RP visible uniquement à proximité', { { name = 'texte', help = 'Votre message' } })

RegisterCommand(Config.Commands.ad, function(_, args)
    if not Config.Ad.Enabled then return end
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:ad', text)
end, false)
RegisterLocalSuggestion(Config.Commands.ad, 'Publie une annonce visible par tout le serveur', { { name = 'texte', help = 'Le texte de votre publicité' } })

RegisterCommand(Config.Commands.pm, function(_, args)
    local target = tonumber(args[1])
    table.remove(args, 1)
    local text = table.concat(args, ' ')
    if not target or text == '' then
        TriggerEvent('chat:addMessage', { template = '<div class="ks-msg ks-msg--error">Utilisation : /mp [id] [message]</div>' })
        return
    end
    TriggerServerEvent('ks-chat:pm', target, text)
end, false)
RegisterLocalSuggestion(Config.Commands.pm, 'Envoie un message privé à un joueur', {
    { name = 'id',      help = 'ID serveur du joueur' },
    { name = 'message', help = 'Votre message' }
})

RegisterCommand(Config.Commands.reply, function(_, args)
    if not lastPmSource then return end
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:pm', lastPmSource, text)
end, false)
RegisterLocalSuggestion(Config.Commands.reply, 'Répond au dernier message privé reçu', { { name = 'message', help = 'Votre réponse' } })

RegisterCommand(Config.Commands.admin, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:admin', text)
end, false)
RegisterLocalSuggestion(Config.Commands.admin, "Chat privé réservé au staff", { { name = 'texte', help = 'Votre message' } })

RegisterCommand(Config.Commands.report, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('ks-chat:report', text)
end, false)
RegisterLocalSuggestion(Config.Commands.report, 'Signale un problème au staff en ligne', { { name = 'texte', help = 'Décrivez votre problème' } })

RegisterCommand(Config.Commands.clear, function()
    TriggerEvent('chat:clear')
end, false)
RegisterLocalSuggestion(Config.Commands.clear, 'Vide votre fenêtre de chat (local uniquement)')

-- KEOPS Studios : retour à l'écran de sélection de personnage sans
-- déconnexion du serveur. Chemin non standard côté VORP (voir les
-- commentaires côté serveur, vorp_character/server/server.lua et
-- vorp_core/server/class/user.lua) : accepté en connaissance de cause.
RegisterCommand(Config.Commands.disconnect, function()
    TriggerServerEvent('vorpcharacter:ks:returnToSelection')
end, false)
RegisterLocalSuggestion(Config.Commands.disconnect, 'Retourne à l\'écran de sélection de personnage')

-- KEOPS Studios : annonce admin (bandeau ks-announce). Réutilise
-- directement l'event serveur de vorp_admin (vorp_admin:announce), donc
-- la même vérification de permission (allow_announce) et le même
-- logging s'appliquent — pas de logique dupliquée ni de nouveau chemin
-- de permission à maintenir.
RegisterCommand(Config.Commands.announce, function(_, args)
    local text = table.concat(args, ' ')
    if text == '' then return end
    TriggerServerEvent('vorp_admin:announce', text)
end, false)
RegisterLocalSuggestion(Config.Commands.announce, 'Diffuse une annonce admin (bandeau) à tout le serveur', { { name = 'texte', help = 'Le texte de l\'annonce' } })

CreateThread(function()
    Wait(500)
    PushSuggestions()
    SendNUIMessage({
        type = 'ks-chat:init',
        locale = Config.Locale,
        autoHideDelay = Config.AutoHideDelay,
        playSound = Config.PlaySound,
        maxMessages = Config.MaxMessages,
        maxLength = Config.MaxMessageLength,
    })
end)

-- ---------------------------------------------------------
-- Fermeture forcée si le joueur meurt/se déconnecte du menu, etc.
-- ---------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SetNuiFocus(false, false)
    end
end)
