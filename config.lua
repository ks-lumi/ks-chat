Config = {}

-- =========================================================
--  KS-CHAT — KEOPS Studios
--  Configuration générale
-- =========================================================

Config.Locale = 'fr' -- Langue de l'interface (fr / en)

-- Touche qui ouvre le chat (voir aussi RegisterKeyMapping dans client/cl_chat.lua)
Config.ChatKey = 'T'

-- Nombre de messages conservés à l'écran avant suppression des plus anciens
Config.MaxMessages = 100

-- Longueur maximale d'un message (caractères)
Config.MaxMessageLength = 200

-- Anti-spam : délai minimum entre deux messages (ms)
Config.SpamCooldown = 1200

-- Fait disparaître le chat après X secondes d'inactivité (0 = toujours visible)
Config.AutoHideDelay = 12000

-- Joue un son à la réception d'un message
Config.PlaySound = true

-- =========================================================
--  Portées RP (en mètres) — chat basé sur la proximité
-- =========================================================

Config.Ranges = {
    say   = 20.0, -- Chat principal (parler)
    me    = 20.0, -- /me
    doo   = 20.0, -- /do
    looc  = 25.0, -- /b (Hors-RP local)
}

-- =========================================================
--  Commandes
-- =========================================================

Config.Commands = {
    me         = 'me',
    doo        = 'do',
    ooc        = 'ooc',
    looc       = 'b',
    ad         = 'ad',
    pm         = 'mp',
    reply      = 'r',
    admin      = 'a',
    report     = 'report',
    clear      = 'clearchat',
    disconnect = 'disconnect', -- retour à l'écran de sélection de personnage
    announce   = 'annonce',    -- annonce admin (bandeau ks-announce)
}

-- /ad — publicité serveur
Config.Ad = {
    Enabled = true,
    Cooldown = 60,       -- secondes entre deux publicités par joueur
    Price = 0,           -- coût en $ (0 = gratuit). Nécessite vorp_core pour débiter.
    PriceAccount = 'money',
}

-- Chat Hors-RP global (/ooc)
Config.OOC = {
    Enabled = true,
}

-- =========================================================
--  Permissions Staff (groupes VORP autorisés pour /a et à voir les /report)
-- =========================================================

Config.StaffGroups = { 'admin', 'moderator', 'dev' }

-- =========================================================
--  Webhook Discord (laisser vide pour désactiver)
-- =========================================================

Config.Discord = {
    Enabled = false,
    WebhookOOC    = '', -- log du chat Hors-RP global
    WebhookAdmin  = '', -- log du chat staff /a
    WebhookReport = '', -- log des /report
    Avatar = 'https://keops-studios.com/favicon.png',
    Username = 'KS-Chat',
}

-- =========================================================
--  Filtre anti-spam de liens / mots interdits (optionnel)
-- =========================================================

Config.Filter = {
    BlockLinks = false,       -- bloque les URL dans le chat public (n'affecte pas /a)
    BannedWords = {
        -- 'motinterdit1', 'motinterdit2',
    },
}
