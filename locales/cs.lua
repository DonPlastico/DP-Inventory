-- ============================================================
--  DP-INVENTORY · locales/cs.lua  –  Čeština (Czech)
--
--  Para activar este idioma en el servidor:
--    setr qb_locale "cs"   → en server.cfg
--
--  Si una clave no existe aquí, se usa automáticamente
--  la traducción del fallback (en.lua).
-- ============================================================
local Translations = {

    -- Barras de progreso
    progress = {
        ['snowballs'] = 'Sbíráš sněhové koule..'
    },

    -- Notificaciones del sistema de inventario
    notify = {
        ['failed'] = 'Nepovedlo se',
        ['canceled'] = 'Zrušeno',
        ['vlocked'] = 'Vozidlo uzamčeno',
        ['notowned'] = 'Tento předmět nevlastníš!',
        ['missitem'] = 'Nemáš tento předmět!',
        ['nonb'] = 'Nikdo v okolí není!',
        ['noaccess'] = 'Nepřístupné',
        ['nosell'] = 'Tento předmět nemůžeš prodat.',
        ['itemexist'] = 'Předmět neexistuje',
        ['notencash'] = 'Nemáš dost hotovosti..',
        ['noitem'] = 'Nemáš správné předměty..',
        ['gsitem'] = 'Nemůžeš si dát předmět sám sobě?',
        ['tftgitem'] = 'Jsi příliš daleko na to, aby sis dal předmět!',
        ['infound'] = 'Předmět, který se snažíš dát, nebyl nalezen!',
        ['iifound'] = 'Nalezen nesprávný předmět, zkus to znovu!',
        ['gitemrec'] = 'Dostal jsi ', -- Prefijo: "Dostal jsi 2x water_bottle"
        ['gitemfrom'] = ' Od ', -- Sufijo:  "Dostal jsi X Od JménoHráče"
        ['gitemyg'] = 'Dal jsi ',
        ['gitinvfull'] = 'Inventář druhého hráče je plný!',
        ['giymif'] = 'Tvůj inventář je plný!',
        ['gitydhei'] = 'Nemáš dost tohoto předmětu',
        ['gitydhitt'] = 'Nemáš dost předmětů na přenos',
        ['navt'] = 'Neplatný typ..',
        ['anfoc'] = 'Argumenty nejsou správně vyplněny..',
        ['yhg'] = 'Dal jsi ',
        ['cgitem'] = 'Nelze dát předmět!',
        ['idne'] = 'Předmět neexistuje',
        ['pdne'] = 'Hráč není online'
    },

    -- Descripciones de keybinds (menú de controles de GTA V)
    inf_mapping = {
        ['opn_inv'] = 'Otevři inventář',
        ['tog_slots'] = 'Přepíná sloty klávesových zkratek',
        ['use_item'] = 'Používá předmět ve slotu '
    },

    -- Etiquetas de menús y TextUI
    menu = {
        ['vending'] = 'Automat',
        ['bin'] = 'Otevři kontejner',
        ['craft'] = 'Craft',
        ['o_bag'] = 'Otevři tašku'
    },

    -- Textos de interacción en pantalla (formato nativo GTA: ~color~)
    interaction = {
        ['craft'] = '~g~E~w~ - Craft'
    }
}

if GetConvar('qb_locale', 'en') == 'cs' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang -- Usa en.lua si falta alguna clave
    })
end
