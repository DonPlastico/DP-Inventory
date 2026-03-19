-- ============================================================
--  DP-INVENTORY · locales/nl.lua  –  Nederlands (Dutch)
--
--  Para activar este idioma en el servidor:
--    setr qb_locale "nl"   → en server.cfg
--
--  Si una clave no existe aquí, se usa automáticamente
--  la traducción del fallback (en.lua).
-- ============================================================
local Translations = {

    -- Barras de progreso
    progress = {
        ['snowballs'] = 'Sneeuwballen verzamelen..'
    },

    -- Notificaciones del sistema de inventario
    notify = {
        ['failed'] = 'Mislukt',
        ['canceled'] = 'Geannuleerd',
        ['vlocked'] = 'Voertuig Vergrendeld',
        ['notowned'] = 'Dit item is niet van jou!',
        ['missitem'] = 'Je hebt dit item niet!',
        ['nonb'] = 'Niemand in de buurt!',
        ['noaccess'] = 'Geen toegang',
        ['nosell'] = 'Je kunt dit item niet verkopen..',
        ['itemexist'] = 'Item bestaat niet',
        ['notencash'] = 'Je hebt niet genoeg geld..',
        ['noitem'] = 'Je hebt niet de juiste items..',
        ['gsitem'] = 'Je kunt jezelf geen item geven?',
        ['tftgitem'] = 'Je bent te ver weg om items te geven!',
        ['infound'] = 'Het item dat je probeerde te geven is niet gevonden!',
        ['iifound'] = 'Onjuist item gevonden, probeer opnieuw!',
        ['gitemrec'] = 'Je hebt ontvangen ', -- Prefijo: "Je hebt ontvangen 2x water_bottle"
        ['gitemfrom'] = ' Van ', -- Sufijo:  "Je hebt ontvangen X Van SpelerNaam"
        ['gitemyg'] = 'Je hebt gegeven ',
        ['gitinvfull'] = 'De inventaris van de andere speler is vol!',
        ['giymif'] = 'Jouw inventaris is vol!',
        ['gitydhei'] = 'Je hebt niet genoeg van het item',
        ['gitydhitt'] = 'Je hebt niet genoeg items om over te dragen',
        ['navt'] = 'Geen geldig type..',
        ['anfoc'] = 'Argumenten niet correct ingevuld..',
        ['yhg'] = 'Je hebt gegeven ',
        ['cgitem'] = 'Kan item niet geven!',
        ['idne'] = 'Item bestaat niet',
        ['pdne'] = 'Speler is niet online'
    },

    -- Descripciones de keybinds (menú de controles de GTA V)
    inf_mapping = {
        ['opn_inv'] = 'Open Inventaris',
        ['tog_slots'] = 'Schakelt sleutelbind-slots om',
        ['use_item'] = 'Gebruikt het item in slot '
    },

    -- Etiquetas de menús y TextUI
    menu = {
        ['vending'] = 'Verkoopautomaat',
        ['bin'] = 'Open Prullenbak',
        ['craft'] = 'Maak',
        ['o_bag'] = 'Open Tas'
    },

    -- Textos de interacción en pantalla (formato nativo GTA: ~color~)
    interaction = {
        ['craft'] = '~g~E~w~ - Maken'
    }
}

if GetConvar('qb_locale', 'en') == 'nl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang -- Usa en.lua si falta alguna clave
    })
end
