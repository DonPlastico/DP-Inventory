-- ============================================================
--  DP-INVENTORY · locales/es.lua  –  Español
--
--  Para activar este idioma en el servidor:
--    setr qb_locale "es"   → en server.cfg
--
--  Si una clave no existe aquí, se usa automáticamente
--  la traducción del fallback (en.lua).
-- ============================================================
local Translations = {

    -- Barras de progreso
    progress = {
        ['snowballs'] = 'Recolectando bolas de nieve..'
    },

    -- Notificaciones del sistema de inventario
    notify = {
        ['failed'] = 'Fallido',
        ['canceled'] = 'Cancelado',
        ['vlocked'] = 'Vehículo Bloqueado',
        ['notowned'] = '¡No posees este objeto!',
        ['missitem'] = '¡No tienes este objeto!',
        ['nonb'] = '¡No hay nadie cerca!',
        ['noaccess'] = 'No Accesible',
        ['nosell'] = 'No puedes vender este objeto..',
        ['itemexist'] = 'El objeto no existe',
        ['notencash'] = 'No tienes suficiente dinero..',
        ['noitem'] = 'No tienes los objetos adecuados..',
        ['gsitem'] = '¿No puedes darte un objeto a ti mismo?',
        ['tftgitem'] = '¡Estás demasiado lejos para dar objetos!',
        ['infound'] = '¡Objeto que intentaste dar no encontrado!',
        ['iifound'] = '¡Objeto incorrecto encontrado, intenta de nuevo!',
        ['gitemrec'] = 'Recibiste ', -- Prefijo: "Recibiste 2x water_bottle"
        ['gitemfrom'] = ' De ', -- Sufijo:  "Recibiste X De NombreJugador"
        ['gitemyg'] = 'Diste ',
        ['gitinvfull'] = '¡El inventario del otro jugador está lleno!',
        ['giymif'] = '¡Tu inventario está lleno!',
        ['gitydhei'] = 'No tienes suficiente del objeto',
        ['gitydhitt'] = 'No tienes suficientes objetos para transferir',
        ['navt'] = 'No es un tipo válido..',
        ['anfoc'] = 'Argumentos no rellenados correctamente..',
        ['yhg'] = 'Has Dado ',
        ['cgitem'] = '¡No se puede dar el objeto!',
        ['idne'] = 'El Objeto No Existe',
        ['pdne'] = 'El Jugador No Está En Línea'
    },

    -- Descripciones de keybinds (menú de controles de GTA V)
    inf_mapping = {
        ['opn_inv'] = 'Abrir Inventario',
        ['tog_slots'] = 'Alterna ranuras de teclas',
        ['use_item'] = 'Usa el objeto en la ranura'
    },

    -- Etiquetas de menús y TextUI
    menu = {
        ['vending'] = 'Máquina Expendedora',
        ['bin'] = 'Abrir Contenedor de Basura',
        ['craft'] = 'Crear',
        ['o_bag'] = 'Abrir Bolsa'
    },

    -- Textos de interacción en pantalla (formato nativo GTA: ~color~)
    interaction = {
        ['craft'] = '~g~E~w~ - Fabricar'
    },

    -- ──────────────────────────────────────────────
    --  SISTEMA DE SIM
    --  Errores y mensajes de combinar/extraer SIM.
    -- ──────────────────────────────────────────────
    sim = {
        ['error_busy'] = 'Hay otra operación en curso. Espera un momento.',
        ['error_invalid'] = 'Acción inválida.',
        ['error_not_combinable'] = 'Estos ítems no se pueden combinar.',
        ['error_phone_no_imei'] = 'Este teléfono no tiene IMEI.',
        ['error_sim_not_activated'] = 'Esta SIM no está activada.',
        ['error_phone_has_sim'] = 'Este teléfono ya tiene una SIM.',
        ['error_sim_in_other_phone'] = 'Esta SIM ya está insertada en otro teléfono.',
        ['error_phone_no_sim'] = 'Este teléfono no tiene SIM.',
        ['error_no_space'] = 'No tienes espacio para la SIM.',
        ['error_internal'] = 'Ha ocurrido un error inesperado.'
    }
}

if GetConvar('qb_locale', 'en') == 'es' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang -- Usa en.lua si falta alguna clave
    })
end
