-- ============================================================
--  DP-INVENTORY · locales/de.lua  –  Deutsch
--
--  Para activar este idioma en el servidor:
--    setr qb_locale "de"   → en server.cfg
--
--  Si una clave no existe aquí, se usa automáticamente
--  la traducción del fallback (en.lua).
-- ============================================================
local Translations = {

    -- Barras de progreso
    progress = {
        ['snowballs'] = 'Schneebälle sammeln..'
    },

    -- Notificaciones del sistema de inventario
    notify = {
        ['failed'] = 'Fehlgeschlagen',
        ['canceled'] = 'Abgebrochen',
        ['vlocked'] = 'Fahrzeug verriegelt',
        ['notowned'] = 'Du besitzt diesen Gegenstand nicht!',
        ['missitem'] = 'Du hast diesen Gegenstand nicht!',
        ['nonb'] = 'Niemand in der Nähe!',
        ['noaccess'] = 'Nicht zugänglich',
        ['nosell'] = 'Du kannst diesen Gegenstand nicht verkaufen..',
        ['itemexist'] = 'Der Gegenstand existiert nicht',
        ['notencash'] = 'Du hast nicht genug Bargeld..',
        ['noitem'] = 'Du hast nicht die richtigen Gegenstände..',
        ['gsitem'] = 'Du kannst dir keinen Gegenstand geben?',
        ['tftgitem'] = 'Du bist zu weit weg, um Gegenstände zu geben!',
        ['infound'] = 'Der Gegenstand, den du geben wolltest, wurde nicht gefunden!',
        ['iifound'] = 'Falscher Gegenstand gefunden, versuche es erneut!',
        ['gitemrec'] = 'Du hast erhalten ', -- Prefijo: "Du hast erhalten 2x water_bottle"
        ['gitemfrom'] = ' Von ', -- Sufijo:  "Du hast erhalten X Von SpielerName"
        ['gitemyg'] = 'Du hast gegeben ',
        ['gitinvfull'] = 'Das Inventar des anderen Spielers ist voll!',
        ['giymif'] = 'Dein Inventar ist voll!',
        ['gitydhei'] = 'Du hast nicht genug von dem Gegenstand',
        ['gitydhitt'] = 'Du hast nicht genug Gegenstände zum Übertragen',
        ['navt'] = 'Ungültiger Typ..',
        ['anfoc'] = 'Argumente nicht korrekt ausgefüllt..',
        ['yhg'] = 'Du hast gegeben ',
        ['cgitem'] = 'Kann den Gegenstand nicht geben!',
        ['idne'] = 'Gegenstand existiert nicht',
        ['pdne'] = 'Spieler ist nicht online'
    },

    -- Descripciones de keybinds (menú de controles de GTA V)
    inf_mapping = {
        ['opn_inv'] = 'Inventar öffnen',
        ['tog_slots'] = 'Schaltet die belegten Slots um',
        ['use_item'] = 'Verwendet den Gegenstand im Slot '
    },

    -- Etiquetas de menús y TextUI
    menu = {
        ['vending'] = 'Verkaufsautomat',
        ['bin'] = 'Müllcontainer öffnen',
        ['craft'] = 'Herstellen',
        ['o_bag'] = 'Tasche öffnen'
    },

    -- Textos de interacción en pantalla (formato nativo GTA: ~color~)
    interaction = {
        ['craft'] = '~g~E~w~ - Herstellen'
    }
}

if GetConvar('qb_locale', 'en') == 'de' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang -- Usa en.lua si falta alguna clave
    })
end
