-- ============================================================
--  DP-INVENTORY · config/vehicles.lua
--  Configuración de capacidad de maleteros y guanteras por
--  clase de vehículo, y lista de vehículos con motor trasero.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VehicleStorage  – slots y peso por clase de vehículo
--  [2]  BackEngineVehicles – vehículos con motor trasero
-- ============================================================
-- ============================================================
--  [1] VehicleStorage
--  Define la capacidad de guantera (glovebox) y maletero (trunk)
--  para cada clase de vehículo de GTA V.
--
--  La clave es el número de clase devuelto por GetVehicleClass().
--  La entrada 'default' se usa si la clase no está definida aquí.
--
--  CLASES DE VEHÍCULO EN GTA V:
--    0  Compacts      8  Motorcycles    16 Planes
--    1  Sedans        9  Off-road       17 Service
--    2  SUVs         10  (no usada)     18 Emergency
--    3  Coupes       11  (no usada)     19 Military
--    4  Muscle       12  Vans           20 Commercial
--    5  SportsClass  13  Cycles         21 Trains
--    6  Sports       14  Boats          22 (Commercial 2)
--    7  Super        15  Helicopters
--
--  CAMPOS POR ENTRADA:
--    gloveboxSlots  → número de slots de la guantera
--    gloveboxWeight → peso máximo de la guantera
--    trunkSlots     → número de slots del maletero (0 = sin maletero)
--    trunkWeight    → peso máximo del maletero     (0 = sin maletero)
--
--  NOTAS ESPECIALES:
--    · Motos (8): usan la guantera como "alforjas" (35 slots). Sin maletero.
--    · Bicis (13): sin guantera ni maletero.
--    · Barcos (14): la guantera actúa como bodega (50 slots). Sin maletero.
--    · Helicópteros (15): guantera de gran capacidad (60 slots, 12t). Sin maletero.
--    · Trenes (21): sin inventario de ningún tipo.
-- ============================================================
VehicleStorage = {

    -- Valores por defecto: usados si la clase del vehículo no tiene entrada propia
    default = {
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 35,
        trunkWeight = 2000000
    },

    [0] = { -- Compacts (ej: Blista, Issi, Brioso)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20, -- Maletero pequeño
        trunkWeight = 2000000
    },
    [1] = { -- Sedans (ej: Tailgater, Stanier, Fugitive)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 40, -- Maletero amplio, típico de sedán
        trunkWeight = 2000000
    },
    [2] = { -- SUVs (ej: Granger, Baller, Cavalcade)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 50, -- El maletero más grande de los civiles comunes
        trunkWeight = 2000000
    },
    [3] = { -- Coupes (ej: Exemplar, Felon, Windsor)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 35,
        trunkWeight = 2000000
    },
    [4] = { -- Muscle (ej: Gauntlet, Sabre, Vigero)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 30,
        trunkWeight = 2000000
    },
    [5] = { -- Sports Classics (ej: Coquette, Monroe, Stirling)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 15, -- Maleteros pequeños por diseño clásico/deportivo
        trunkWeight = 2000000
    },
    [6] = { -- Sports (ej: Elegy, Jester, Sultan)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 15, -- Deportivos: maletero reducido
        trunkWeight = 2000000
    },
    [7] = { -- Super (ej: Zentorno, T20, Osiris)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 15, -- Superdeportivos: maletero mínimo
        trunkWeight = 2000000
    },
    [8] = { -- Motorcycles (ej: Bati, Hakuchou, Akuma)
        gloveboxSlots = 35, -- Las "alforjas" de la moto actúan como guantera
        gloveboxWeight = 1200000,
        trunkSlots = 0, -- Sin maletero
        trunkWeight = 0
    },
    [9] = { -- Off-road (ej: Bifta, Dubsta, Bravado)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 50, -- Vehículos todoterreno: gran capacidad de carga
        trunkWeight = 2000000
    },
    [12] = { -- Vans (ej: Burrito, Rumpo, Speedo)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 50, -- Furgonetas: mucho espacio de carga
        trunkWeight = 2000000
    },
    [13] = { -- Cycles (ej: Fixter, Cruiser, Scorcher)
        gloveboxSlots = 0, -- Las bicis no tienen guantera
        gloveboxWeight = 0,
        trunkSlots = 0, -- Ni maletero
        trunkWeight = 0
    },
    [14] = { -- Boats (ej: Dinghy, Speeder, Squalo)
        gloveboxSlots = 50, -- La "bodega" del barco actúa como guantera
        gloveboxWeight = 1200000,
        trunkSlots = 0, -- Sin maletero (no aplica en barcos)
        trunkWeight = 0
    },
    [15] = { -- Helicopters (ej: Maverick, Buzzard, Annihilator)
        gloveboxSlots = 60, -- Bodega amplia del helicóptero
        gloveboxWeight = 12000000, -- Peso muy elevado (helicópteros de transporte)
        trunkSlots = 0,
        trunkWeight = 0
    },
    [16] = { -- Planes (ej: Besra, Hydra, Luxor)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    },
    [17] = { -- Service (ej: Trash Truck, Tow Truck, Taxi)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    },
    [18] = { -- Emergency (ej: Police, Ambulance, Fire Truck)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    },
    [19] = { -- Military (ej: Rhino, Insurgent, Barracks)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    },
    [20] = { -- Commercial (ej: Hauler, Phantom, Packer)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    },
    [21] = { -- Trains (tren de GTA)
        gloveboxSlots = 0, -- El tren no tiene inventario
        gloveboxWeight = 0,
        trunkSlots = 0,
        trunkWeight = 0
    },
    [22] = { -- Commercial 2 / Industrial (ej: Stockade, Benson)
        gloveboxSlots = 10,
        gloveboxWeight = 1200000,
        trunkSlots = 20,
        trunkWeight = 2000000
    }
}

-- ============================================================
--  [2] BackEngineVehicles
--  Lista de modelos de vehículos que tienen el motor en la
--  parte TRASERA (motor trasero / mid-engine).
--
--  En GTA V, estos coches tienen el maletero en la parte
--  DELANTERA (capó). Por eso el sistema usa la puerta 4
--  (capó) en lugar de la puerta 5 (maletero trasero) para
--  abrirlos. Esto afecta a:
--    · client/vehicles.lua → OpenTrunk / CloseTrunk
--    · client/vehicles.lua → TextUI de proximidad al maletero
--    · client/main_client.lua → callback vehicleCheck
--
--  Para añadir un vehículo personalizado con motor trasero,
--  basta con añadir su nombre de modelo en minúsculas aquí.
-- ============================================================

BackEngineVehicles = {
    -- ── Vehículos base de GTA V ──
    ['ninef'] = true,
    ['ninef2'] = true,
    ['tenf'] = true,
    ['tenf2'] = true,
    ['vd_tenfrally'] = true,
    ['adder'] = true,
    ['nero'] = true,
    ['nero2'] = true,
    ['vagner'] = true,
    ['t20'] = true,
    ['infernus'] = true,
    ['zentorno'] = true,
    ['reaper'] = true,
    ['comet2'] = true,
    ['comet3'] = true,
    ['comet4'] = true,
    ['comet5'] = true,
    ['comet6'] = true,
    ['comet7'] = true,
    ['apollo'] = true,
    ['neon'] = true,
    ['jester'] = true,
    ['jester2'] = true,
    ['cheetah'] = true,
    ['cheetah2'] = true,
    ['prototipo'] = true,
    ['turismor'] = true,
    ['pfister811'] = true,
    ['ardent'] = true,
    ['tempesta'] = true,
    ['vacca'] = true,
    ['bullet'] = true,
    ['osiris'] = true,
    ['entityxf'] = true,
    ['entity2'] = true,
    ['entity3'] = true,
    ['turismo2'] = true,
    ['fmj'] = true,
    ['re7b'] = true,
    ['tyrus'] = true,
    ['italigtb'] = true,
    ['italigtb2'] = true,
    ['italirsx'] = true,
    ['penetrator'] = true,
    ['monroe'] = true,
    ['stingergt'] = true,
    ['bifta'] = true,
    ['raptor'] = true,
    ['gp1'] = true,
    ['autarch'] = true,
    ['khamelion'] = true,
    ['tyrant'] = true
}
