const InventoryContainer = Vue.createApp({
  // ==========================================
  // 1. DATOS REACTIVOS (STATE)
  // ==========================================
  data() {
    return this.getInitialState();
  },

  // ==========================================
  // 2. PROPIEDADES COMPUTADAS (CALCULADORES)
  // ==========================================
  computed: {
    playerWeight() {
      const weight = Object.values(this.playerInventory).reduce((total, item) => {
        if (item && item.amount !== undefined) {
          // Si no existe, usa el item.weight genérico.
          const itemWeight =
            item.info && item.info.weight !== undefined
              ? item.info.weight
              : item.weight !== undefined
                ? item.weight
                : 0;

          return total + itemWeight * item.amount;
        }
        return total;
      }, 0);
      return isNaN(weight) ? 0 : weight;
    },

    otherInventoryWeight() {
      const weight = Object.values(this.otherInventory).reduce((total, item) => {
        if (item && item.amount !== undefined) {
          // Misma lógica para el inventario secundario (suelo, maleteros, stashes)
          const itemWeight =
            item.info && item.info.weight !== undefined
              ? item.info.weight
              : item.weight !== undefined
                ? item.weight
                : 0;

          return total + itemWeight * item.amount;
        }
        return total;
      }, 0);
      return isNaN(weight) ? 0 : weight;
    },

    weightBarClass() {
      const weightPercentage = (this.playerWeight / this.maxWeight) * 100;
      if (weightPercentage < 50) return "low";
      if (weightPercentage < 75) return "medium";
      return "high";
    },

    otherWeightBarClass() {
      const weightPercentage =
        (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
      if (weightPercentage < 50) return "low";
      if (weightPercentage < 75) return "medium";
      return "high";
    },

    // Slots extra que otorga la mochila equipada en slot 101
    extraBackpackSlots() {
      const backpack = this.playerInventory[101];
      if (!backpack || !backpack.name) return 0;
      const name = backpack.name;
      if (name === "backpack_1") return 5;
      if (name === "backpack_2") return 10;
      if (name === "backpack_3") return 15;
      if (name === "backpack_4") return 20;
      return 0;
    },

    // Slots base: siempre fijos, nunca incluye los de mochila
    basePlayerSlots() {
      return this.baseSlots;
    },

    // Slots totales reales: base + mochila (reactivo en tiempo real)
    totalPlayerSlots() {
      return this.baseSlots + this.extraBackpackSlots;
    },

    extraSeats() {
      // Genera botones extra para vehículos con más de 4 plazas (Limusinas, Buses...)
      if (!this.vehicleData || this.vehicleData.seats <= 4) return [];
      let extras = [];
      // Los índices empiezan en 3 (porque -1, 0, 1, y 2 son los estándar)
      for (let i = 3; i <= this.vehicleData.seats - 2; i++) {
        extras.push(i);
      }
      return extras;
    },

    shouldCenterInventory() {
      return this.isOtherInventoryEmpty;
    },

    // Escanea la mochila buscando un ítem que sea tipo arma
    hasFirearm() {
      return Object.values(this.playerInventory).some(
        (item) =>
          item &&
          item.type === "weapon" &&
          item.name &&
          item.name.toLowerCase().startsWith("weapon_"),
      );
    },

    adminList() {
      if (!this.adminData || !this.adminCurrentCategory) return [];

      let list = this.adminData[this.adminCurrentCategory] || [];

      // Si el usuario ha escrito algo en el buscador
      if (this.adminSearchQuery.trim() !== "") {
        const query = this.adminSearchQuery.toLowerCase().trim();

        list = list.filter((item) => {
          if (this.adminCurrentCategory === "players") {
            // Busca por nombre, steam o ID
            return (
              item.name.toLowerCase().includes(query) ||
              item.steam.toLowerCase().includes(query) ||
              item.id.toString().includes(query)
            );
          } else {
            // Busca por ID en almacenes, maleteros y guanteras
            return item.toLowerCase().includes(query);
          }
        });
      }
      return list;
    },
  },

  // ==========================================
  // 3. VIGILANTES (WATCHERS)
  // ==========================================
  watch: {
    transferAmount(newVal) {
      if (newVal !== null && newVal < 0) this.transferAmount = 0;
    },
    // Watcher para actualizar totalSlots cuando cambia la mochila
    extraBackpackSlots(newVal) {
      this.totalSlots = this.baseSlots + newVal;
    },
  },

  // ==========================================
  // 4. MÉTODOS Y FUNCIONES
  // ==========================================
  methods: {
    /* ------------------------------------------------------------------
           A. NÚCLEO E INICIALIZACIÓN
           ------------------------------------------------------------------ */

    getInitialState() {
      return {
        // Config Options
        maxWeight: 0,
        totalSlots: 0,
        baseSlots: 0,
        // Escape Key
        isInventoryOpen: false,
        // Single pane
        isOtherInventoryEmpty: true,
        // Error handling
        errorSlot: null,
        // Player Inventory
        playerInventory: {},
        inventoryLabel: "Inventory",
        totalWeight: 0,
        // Other inventory
        otherInventory: {},
        otherInventoryName: "",
        otherInventoryLabel: "Drop",
        otherInventoryMaxWeight: 1000000,
        otherInventorySlots: 100,
        isShopInventory: false,
        // Where item is coming from
        inventory: "",
        // Context Menu
        showContextMenu: false,
        contextMenuPosition: { top: "0px", left: "0px" },
        contextMenuItem: null,
        activeSubmenu: null,
        isMenuOnLeft: false,
        isMenuOnTop: false,
        nearbyPlayers: [],
        // Modal de inspección
        showInspectModal: false,
        inspectingItem: null,
        inspectRotation: 0,
        inspectZoom: 1,
        // Hotbar
        showHotbar: false,
        hotbarItems: [],
        activeHotbarSlot: null,
        // Cola de notificaciones
        itemNotifications: [],
        // Required items box
        showRequiredItems: false,
        requiredItems: [],
        // Attachments
        selectedWeapon: null,
        showWeaponAttachments: false,
        selectedWeaponAttachments: [],
        wipDragOverSlot: null,
        wipErrorSlot: null,
        // --- ESTADO DE SIM (FASE 3) ---
        simCombineState: {
          isActive: false,
          sourceSlot: null,
          sourceInventory: null, // 'player' u 'other'
          sourceItemName: null, // 'phone' o 'sim_card'
        },
        // Un slot por cada tipo funcional de accesorio de qb-weapons
        // "types" = lista de attachmentType del config que pertenecen a este slot
        wipAttachmentSlots: [
          {
            type: "suppressor",
            label: "Silenciador",
            icon: "arcticons:adsilence",
            types: ["suppressor_attachment"],
          },
          {
            type: "barrel",
            label: "Cañón",
            icon: "mdi:pipe",
            types: ["barrel_attachment", "comp_attachment"],
          },
          {
            type: "grip",
            label: "Empuñadura",
            icon: "mdi:hand-back-right-outline",
            types: ["grip_attachment"],
          },
          {
            type: "flashlight",
            label: "Accesorio",
            icon: "mdi:flashlight",
            types: ["flashlight_attachment"],
          },
          {
            type: "scope",
            label: "Mira",
            icon: "f7:scope",
            types: [
              "smallscope_attachment",
              "medscope_attachment",
              "largescope_attachment",
              "holoscope_attachment",
              "advscope_attachment",
              "nvscope_attachment",
              "thermalscope_attachment",
            ],
          },
          { type: "clip", label: "Cargador", icon: "mdi:bullet", types: ["clip_attachment"] },
          {
            type: "drum",
            label: "Cargador de Tambor",
            icon: "mdi:cached",
            types: ["drum_attachment"],
          },
          {
            type: "camo",
            label: "Camuflaje",
            icon: "mdi:palette-outline",
            types: [
              "digicamo_attachment",
              "brushcamo_attachment",
              "woodcamo_attachment",
              "skullcamo_attachment",
              "sessantacamo_attachment",
              "perseuscamo_attachment",
              "leopardcamo_attachment",
              "zebracamo_attachment",
              "geocamo_attachment",
              "boomcamo_attachment",
              "patriotcamo_attachment",
              "luxuryfinish_attachment",
            ],
          },
        ],
        // Dragging and dropping
        currentlyDraggingItem: null,
        currentlyDraggingSlot: null,
        dragStartX: 0,
        dragStartY: 0,
        ghostElement: null,
        dragStartInventoryType: "player",
        transferAmount: null,
        isCtrlDrag: false,
        // Pestañas
        activeTab: localStorage.getItem("dp_inv_activeTab") || "inventory",
        isDriver: false,
        isInventoryReady: false,
        // Rockstar Editor Panel
        rockstarPanelOpen: false,
        // Administración
        isAdmin: false,
        adminData: null,
        adminCurrentCategory: null,
        adminSearchQuery: "",
        showAdminSearch: false,
        // Modo Cursor
        cursorModeActive: false,
        moveWhileOpen: false,
        // Control de Vehículos
        inVehicle: false,
        vehicleSeat: null,
        vehicleData: null,
        // Posicionamiento
        inventoryPosition: "bottom",
        isSettingsSelectOpen: false,
        selectDropdownStyle: {},
        // LISTA DE GUÍA Y CONTROLES
        inventoryGuideList: [
          {
            id: 1,
            key: "F2",
            title: "Abrir / Cerrar Menú",
            desc: "Abre y cierra la interfaz del inventario. (Esta tecla puede ser modificada a tu gusto en los ajustes de teclado de FiveM).",
          },
          {
            id: 2,
            key: "J",
            title: "Modo Cursor Libre",
            desc: "Desvincula la cámara del personaje y te permite utilizar el ratón de forma libre para mover ventanas y explorar la UI cómodamente.",
          },
          {
            id: 3,
            key: "Z",
            title: "Ver Cinturón (Hotbar)",
            desc: "Muestra visualmente en pantalla los ítems que tienes asignados a los bolsillos rápidos (1 al 5) sin necesidad de abrir el inventario.",
          },
          {
            id: 4,
            key: "1 - 5",
            title: "Bolsillos Rápidos",
            desc: "Pulsa los números del teclado para equipar armas o usar ítems que hayas asignado previamente en la barra inferior de tu inventario.",
          },
          {
            id: 5,
            key: "HOVER",
            title: "Información y Detalles",
            desc: "Deja el cursor del ratón sobre cualquier ítem para ver su tarjeta de información técnica, peso, estado de degradación, durabilidad y descripción.",
          },
          {
            id: 6,
            key: "ARRASTRAR",
            title: "Mover y Organizar",
            desc: "Mantén el Click Izquierdo sobre un ítem y muévelo a otro slot, a un maletero, o a una guantera para reorganizar tu equipo.",
          },
          {
            id: 7,
            key: "DRAG OUT",
            title: "Tirar al Suelo",
            desc: "Mantén pulsado un ítem y suéltalo fuera de los límites de las ventanas del inventario para tirarlo físicamente al suelo.",
          },
          {
            id: 8,
            key: "CLICK DER.",
            title: "Menú Contextual",
            desc: "Haz click derecho sobre un ítem para desplegar opciones avanzadas: Usar, Dar a jugador cercano, Tirar, Inspeccionar arma, etc.",
          },
          {
            id: 9,
            key: "CLICK DER. (RÁPIDO)",
            title: "Transferencia Rápida",
            desc: "Teniendo un maletero, alijo o el suelo abierto, haz click derecho sobre un ítem para pasarlo instantáneamente de un inventario a otro.",
          },
          {
            id: 10,
            key: "SHIFT + CLICK IZQ.",
            title: "Dividir Cantidades",
            desc: "Al mantener presionada la tecla Shift mientras haces click sobre un ítem apilado, separarás la mitad exacta de la cantidad actual.",
          },
          {
            id: 11,
            key: "DOBLE CLICK",
            title: "Uso Instantáneo",
            desc: "Haz doble click izquierdo rápido sobre cualquier ítem consumible (agua, comida) o arma para usarlo o equiparlo al instante sin menús.",
          },
          {
            id: 12,
            key: "CTRL + ARRASTRAR",
            title: "Split Dinámico",
            desc: "Mantén pulsado CTRL al arrastrar (o al hacer click derecho rápido) un ítem para mover exactamente la mitad de su cantidad al destino indicado.",
          },
        ],
        // Sonidos del inventario
        uiSoundsEnabled: true,
        currentSoundType: "inv",
        // Buscadores de Inventario
        playerSearchQuery: "",
        showPlayerSearch: false,
        otherSearchQuery: "",
        showOtherSearch: false,
        // Radio
        hasVehicleRadio: false,
      };
    },

    openInventory(data) {
      if (this.showHotbar) this.toggleHotbar(false);

      this.inventoryPosition = data.invPosition || "bottom";

      this.isInventoryOpen = true;
      this.maxWeight = data.maxweight;
      this.totalSlots = data.slots;
      this.baseSlots = data.slots;

      this.isDriver = data.isDriver || false;
      this.inVehicle = data.inVehicle || false;
      this.vehicleSeat = data.vehicleSeat !== undefined ? data.vehicleSeat : null;
      this.vehicleData = data.vehData || null;

      this.inventoryLabel = data.playerName ? data.playerName.toUpperCase() : "INVENTARIO";

      this.playerInventory = {};
      this.otherInventory = {};

      this.isAdmin = data.isAdmin || false;

      this.moveWhileOpen = data.moveWhileOpen || false;

      // 1. Cargar inventario del jugador
      if (data.inventory) {
        if (Array.isArray(data.inventory)) {
          data.inventory.forEach((item) => {
            if (item && item.slot) this.playerInventory[item.slot] = item;
          });
        } else if (typeof data.inventory === "object") {
          for (const key in data.inventory) {
            const item = data.inventory[key];
            if (item && item.slot) this.playerInventory[item.slot] = item;
          }
        }
      }

      // 2. Cargar otro inventario (maletero, stash, suelo)
      if (data.other) {
        if (data.other && data.other.inventory) {
          if (Array.isArray(data.other.inventory)) {
            data.other.inventory.forEach((item) => {
              if (item && item.slot) this.otherInventory[item.slot] = item;
            });
          } else if (typeof data.other.inventory === "object") {
            for (const key in data.other.inventory) {
              const item = data.other.inventory[key];
              if (item && item.slot) this.otherInventory[item.slot] = item;
            }
          }
        }

        this.otherInventoryName = data.other.name;
        this.otherInventoryLabel = data.other.label;
        this.otherInventoryMaxWeight = data.other.maxweight;
        this.otherInventorySlots = data.other.slots;

        if (this.otherInventoryName.startsWith("shop-")) {
          this.isShopInventory = true;
        } else {
          this.isShopInventory = false;
        }

        this.isOtherInventoryEmpty = false;
      }

      // 3. SEGURIDAD Y MEMORIA DE PESTAÑAS (Se comprueba DESPUÉS de cargar los items)
      // Leemos la tab guardada con la clave correcta
      const savedTab = localStorage.getItem("dp_inv_activeTab") || "inventory";

      // Si estamos abriendo un inventario externo (Cachear, Maletero, Suelo...), forzamos la pestaña principal
      if (data.other) {
        this.activeTab = "inventory";
      }
      // Si es solo nuestro inventario, intentamos restaurar la tab guardada con validaciones de seguridad
      else if (savedTab === "weapons") {
        this.activeTab = this.hasFirearm ? "weapons" : "inventory";
      } else if (savedTab === "vehicle") {
        this.activeTab = this.isDriver ? "vehicle" : "inventory";
      } else {
        this.activeTab = savedTab;
      }

      // i la pestaña restaurada es la de admin, pedimos los datos al instante
      if (this.activeTab === "admin" && this.isAdmin) {
        this.adminCurrentCategory = null; // Nos aseguramos de mostrar el menú principal
        this.fetchAdminData();
      }

      this.$nextTick(() => {
        this.isInventoryReady = true;
      });
    },

    updateInventory(data) {
      // 1. Limpiamos la tabla actual
      this.playerInventory = {};

      // 2. Cargamos los nuevos ítems
      if (data.inventory) {
        if (Array.isArray(data.inventory)) {
          data.inventory.forEach((item) => {
            if (item && item.slot) this.playerInventory[item.slot] = item;
          });
        } else if (typeof data.inventory === "object") {
          for (const key in data.inventory) {
            const item = data.inventory[key];
            if (item && item.slot) this.playerInventory[item.slot] = item;
          }
        }
      }

      // 3. ¡MAGIA! Si estamos en medio de una combinación de SIM (visualmente),
      //    la cancelamos porque el servidor ya ha hecho la magia.
      if (this.simCombineState.isActive) {
        this.cancelSimCombine();
      }
    },

    async closeInventory() {
      if (document.activeElement) document.activeElement.blur();
      window.getSelection().removeAllRanges();

      this.clearDragData();
      let inventoryName = this.otherInventoryName;
      this.isInventoryReady = false;

      // Guardar preferencias y NOTIFICACIONES antes de purgar el estado
      let currentSoundState = this.uiSoundsEnabled;
      let currentMoveState = this.moveWhileOpen;
      let currentNotifications = this.itemNotifications;

      Object.assign(this, this.getInitialState());

      // Restaurar preferencias y NOTIFICACIONES
      this.uiSoundsEnabled = currentSoundState;
      this.moveWhileOpen = currentMoveState;
      this.itemNotifications = currentNotifications;

      try {
        await axios.post("https://DP-Inventory/CloseInventory", { name: inventoryName });
      } catch (error) {
        console.error("Error closing inventory:", error);
      }
    },

    /* ------------------------------------------------------------------
           B. UTILIDADES Y OBTENEDORES DE DATOS (HELPERS)
           ------------------------------------------------------------------ */

    clearTransferAmount() {
      this.transferAmount = null;
    },

    togglePlayerSearch() {
      if (this.showPlayerSearch) {
        this.showPlayerSearch = false;
        this.playerSearchQuery = "";
      } else {
        this.showPlayerSearch = true;
        this.$nextTick(() => {
          const input = document.getElementById("player-search-input");
          if (input) input.focus();
        });
      }
    },

    toggleOtherSearch() {
      if (this.showOtherSearch) {
        this.showOtherSearch = false;
        this.otherSearchQuery = "";
      } else {
        this.showOtherSearch = true;
        this.$nextTick(() => {
          const input = document.getElementById("other-search-input");
          if (input) input.focus();
        });
      }
    },

    matchesSearch(item, query) {
      // Si el buscador está vacío o cerrado, todo brilla con normalidad
      if (!query || query.trim() === "") return true;

      // Si hay una búsqueda activa pero el slot está vacío, se oscurece
      if (!item) return false;

      // Comprobamos si el nombre técnico o la etiqueta coinciden
      const lowerQuery = query.toLowerCase().trim();
      const labelMatch = item.label && item.label.toLowerCase().includes(lowerQuery);
      const nameMatch = item.name && item.name.toLowerCase().includes(lowerQuery);

      return labelMatch || nameMatch;
    },

    // SISTEMA INTELIGENTE DE DURABILIDAD
    getMaxQuality(itemName) {
      return itemName === "armor" ? 50 : 100; // El armor básico maxea en 50
    },

    isItemDamaged(item) {
      if (!item || !item.name) return false;
      if (item.name === "armor" || item.name === "heavyarmor") {
        const maxQ = this.getMaxQuality(item.name);
        const currentQ =
          item.info && item.info.quality !== undefined ? item.info.quality : maxQ;
        return currentQ < maxQ; // Si tiene menos de SU máximo, está dañado
      }
      return false;
    },

    getDurabilityPercentage(item) {
      if (!item || !item.info || item.info.quality === undefined) return 100;
      const maxQ = this.getMaxQuality(item.name);
      let percentage = (item.info.quality / maxQ) * 100;
      return Math.min(Math.max(percentage, 0), 100); // Nunca pasa de 100% ni baja de 0%
    },

    getDurabilityClass(item) {
      const percentage = this.getDurabilityPercentage(item);
      if (percentage > 75) return "high";
      if (percentage > 25) return "medium";
      return "low";
    },

    changeTab(tabName) {
      this.animateContainerHeight(() => {
        this.playSound("tab");
        this.activeTab = tabName;
        localStorage.setItem("dp_inv_activeTab", tabName);

        // Si es el panel de admin, SIEMPRE pide los datos actualizados de fondo
        if (tabName === "admin") {
          this.adminCurrentCategory = null;
          this.fetchAdminData();
        }
      });
    },

    doAction(actionType) {
      // Si es un botón de vehículo y no tiene permiso por su asiento, no hace nada
      if (actionType.startsWith("veh_") && !this.canAccessVehicleAction(actionType)) return;

      this.playSound("click");

      // El botón de Rockstar Editor abre el sub-panel, no cierra el inventario
      if (actionType === "rockstar") {
        this.animateContainerHeight(() => {
          this.rockstarPanelOpen = true;
        });
        return;
      }

      // Enviamos la acción al client de FiveM
      axios
        .post("https://DP-Inventory/PerformAction", { action: actionType })
        .catch((error) => console.error("Error realizando acción:", error));

      // Cerramos el inventario si es Cachear
      if (actionType === "cachear") {
        this.closeInventory();
      }
    },

    closeRockstarPanel() {
      this.animateContainerHeight(() => {
        this.rockstarPanelOpen = false;
      });
    },

    doRockstarAction(actionType) {
      axios
        .post("https://DP-Inventory/PerformAction", { action: actionType })
        .catch((error) => console.error("Error realizando acción Rockstar:", error));

      // Estas acciones cierran el inventario para que FiveM tome el control
      if (actionType === "rockstar_editor") {
        this.closeInventory();
      }
    },

    saveInventoryPosition() {
      axios
        .post("https://DP-Inventory/SaveInventoryPosition", {
          position: this.inventoryPosition,
        })
        .catch((e) => console.error(e));
    },

    toggleSettingsSelect(event) {
      this.isSettingsSelectOpen = !this.isSettingsSelectOpen;

      if (this.isSettingsSelectOpen) {
        // Sacamos las coordenadas exactas del botón en tu monitor
        const rect = event.currentTarget.getBoundingClientRect();

        // Calculamos si hay espacio debajo (necesitamos al menos 150px para el menú)
        const spaceBelow = window.innerHeight - rect.bottom;
        const dropUp = spaceBelow < 150;

        // Hacemos que el menú sea un 120% más ancho que el botón
        const menuWidth = rect.width;

        // Estilos base (Fijo a la pantalla y alineado a la derecha del botón)
        this.selectDropdownStyle = {
          position: "fixed",
          left: rect.right - menuWidth + "px",
          width: menuWidth + "px",
          zIndex: 999999, // Por encima de todo
        };

        // ¡LA MAGIA DE LA DIRECCIÓN!
        if (dropUp) {
          // Si no cabe abajo, lo pegamos por encima del botón
          this.selectDropdownStyle.bottom = window.innerHeight - rect.top + 5 + "px";
          this.selectDropdownStyle.top = "auto";
        } else {
          // Si cabe, lo pegamos por debajo
          this.selectDropdownStyle.top = rect.bottom + 5 + "px";
          this.selectDropdownStyle.bottom = "auto";
        }
      }
    },

    closeDropdowns() {
      this.isSettingsSelectOpen = false;
    },

    setInventoryPosition(val) {
      this.inventoryPosition = val;
      this.saveInventoryPosition();
      this.isSettingsSelectOpen = false;
    },

    getPositionLabel(val) {
      const labels = { bottom: "Abajo", top: "Arriba", left: "Izquierda", right: "Derecha" };
      return labels[val] || "Abajo";
    },

    // Generador visual del Tooltip de la Guía (Estilo Premium)
    generateGuideTooltip(info) {
      return `
                <div style="padding: 4px; min-width: 220px; max-width: 280px; font-family: inherit; height: auto; white-space: normal;">
                    <div style="display: flex; align-items: center; gap: 8px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 8px; margin-bottom: 8px;">
                        <span style="background: rgba(255,255,255,0.1); padding: 2px 6px; border-radius: 4px; font-size: 10px; font-weight: 900; font-family: monospace; color: #fff; border: 1px solid rgba(255,255,255,0.2); white-space: nowrap;">
                            ${info.key}
                        </span>
                        <span style="font-size: 12px; font-weight: 800; color: #fff; text-transform: uppercase; letter-spacing: 0.5px;">
                            ${info.title}
                        </span>
                    </div>
                    <div style="font-size: 11px; color: #aaa; line-height: 1.5; font-weight: 500; white-space: normal; word-wrap: break-word; text-transform: none;">
                        ${info.desc}
                    </div>
                </div>
            `;
    },

    saveMovePreference() {
      axios
        .post("https://DP-Inventory/SaveMovePreference", { status: this.moveWhileOpen })
        .catch(() => {});
    },

    abrirRadioInventario() {
      // Avisamos a Lua para que cierre el inventario y abra la radio
      axios.post("https://DP-Inventory/abrirRadioDesdeInventario", {}).catch(() => {});
    },

    // Detector de clases de vehículos compatibles con Drift
    isValidDriftVehicle(vehClass) {
      if (vehClass === undefined || vehClass === null) return false;

      // Clases en GTA V que NO son coches de 4 ruedas:
      // 8: Motos | 13: Bicicletas | 14: Barcos | 15: Helicópteros | 16: Aviones | 21: Trenes
      const invalidClasses = [8, 13, 14, 15, 16, 21];

      // Devuelve TRUE si la clase NO está en la lista de inválidos
      return !invalidClasses.includes(vehClass);
    },

    // =========================================
    // MOTOR DE AUDIO DEL INVENTARIO
    // =========================================
    saveSoundPreference() {
      // Mandamos el estado al LUA para que lo guarde en la BD
      axios
        .post("https://DP-Inventory/SaveSoundPref", { status: this.uiSoundsEnabled })
        .catch(() => {});

      // Sonido de prueba si lo acabas de activar
      if (this.uiSoundsEnabled) this.playSound("click");
    },

    playSound(soundName) {
      if (!this.uiSoundsEnabled) return; // Si están apagados en ajustes, no suena nada

      const sounds = {
        click: { file: "sounds/click.mp3", vol: 0.5 },
        tab: { file: "sounds/tab.mp3", vol: 0.4 },
        drop: { file: "sounds/drop.mp3", vol: 0.6 },
        open_inv: { file: "sounds/open_inv.mp3", vol: 0.7 },
        close_inv: { file: "sounds/close_inv.mp3", vol: 0.7 },
        open_trunk: { file: "sounds/open_trunk.mp3", vol: 0.8 },
        close_trunk: { file: "sounds/close_trunk.mp3", vol: 0.8 },
        open_stash: { file: "sounds/open_stash.mp3", vol: 0.7 },
        close_stash: { file: "sounds/close_stash.mp3", vol: 0.7 },
      };

      const sound = sounds[soundName];
      if (sound) {
        let audio = new Audio(sound.file);
        audio.volume = sound.vol;
        audio.play().catch(() => {});
      }
    },

    // =========================================================
    // CEREBRO DE PERMISOS DE VEHÍCULO
    // =========================================================
    canAccessVehicleAction(action) {
      if (!this.inVehicle || !this.vehicleData) return false;

      // Clases sin ventanillas ni drift (Motos=8, Bicis=13, Barcos=14, Helis=15, Aviones=16, Trenes=21)
      const classNoWindows = [8, 13, 14, 15, 16, 21];
      const isNoWindowClass = classNoWindows.includes(this.vehicleData.vehClass);

      // ===============================================
      // 1. CHEQUEOS FÍSICOS (¿El coche tiene esa pieza?)
      // ===============================================
      if (action === "veh_drift" && isNoWindowClass) return false;
      if (action === "veh_anchor" && this.vehicleData.vehClass !== 14) return false;

      // Bloqueo maestro para motos, bicis, barcos, aviones... NO tienen puertas ni ventanas usables
      if (
        isNoWindowClass &&
        (action.startsWith("veh_door_") || action.startsWith("veh_win_"))
      ) {
        return false;
      }

      if (action === "veh_hood" && !this.vehicleData.hasDoor.hood) return false;
      if (action === "veh_trunk" && !this.vehicleData.hasDoor.trunk) return false;

      if (action === "veh_door_fl" && !this.vehicleData.hasDoor.fl) return false;
      if (action === "veh_door_fr" && !this.vehicleData.hasDoor.fr) return false;
      if (action === "veh_door_rl" && !this.vehicleData.hasDoor.rl) return false;
      if (action === "veh_door_rr" && !this.vehicleData.hasDoor.rr) return false;

      if (action === "veh_win_fl" && !this.vehicleData.hasDoor.fl) return false;
      if (action === "veh_win_fr" && !this.vehicleData.hasDoor.fr) return false;
      if (action === "veh_win_rl" && !this.vehicleData.hasDoor.rl) return false;
      if (action === "veh_win_rr" && !this.vehicleData.hasDoor.rr) return false;

      // Físicas de asientos estándar
      if (action === "veh_sit_di" && this.vehicleData.seats <= 1) return false;
      if (action === "veh_sit_dd" && this.vehicleData.seats <= 1) return false;
      if (action === "veh_sit_ti" && this.vehicleData.seats <= 2) return false;
      if (action === "veh_sit_td" && this.vehicleData.seats <= 3) return false;

      // Físicas de asientos extras (Ej: bus)
      if (
        action.startsWith("veh_sit_") &&
        !["di", "dd", "ti", "td"].some((s) => action.includes(s))
      ) {
        const seatId = parseInt(action.split("_").pop());
        if (seatId > this.vehicleData.seats - 2) return false;
      }

      // ===============================================
      // 2. PERMISOS DE ROL (¿Quién eres tú?)
      // ===============================================
      if (this.vehicleSeat === -1) return true; // Conductor puede todo lo que exista
      if (action.startsWith("veh_sit_")) return true; // Todos pueden moverse

      // Copiloto
      if (this.vehicleSeat === 0) {
        const allowed = ["veh_engine", "veh_radio", "veh_door_fr", "veh_win_fr"];
        return allowed.includes(action);
      }
      // Trasero Izquierdo
      if (this.vehicleSeat === 1) {
        return ["veh_door_rl", "veh_win_rl"].includes(action);
      }
      // Trasero Derecho
      if (this.vehicleSeat === 2) {
        return ["veh_door_rr", "veh_win_rr"].includes(action);
      }

      return false; // Bloquea todo lo demás para pasajeros
    },

    /* ------------------------------------------------------------------
           ANIMACIÓN SUAVE DE ALTURA (HEIGHT)
           ------------------------------------------------------------------ */
    animateContainerHeight(actionCallback) {
      const container = document.querySelector(".tab-content-animator");
      if (!container) {
        actionCallback();
        return;
      }

      // Mantenemos siempre el layout estable para evitar errores de cálculo
      container.style.overflow = "hidden";

      // 1. Fijar altura actual antes del cambio
      const oldHeight = container.offsetHeight;
      container.style.height = oldHeight + "px";
      container.style.transition = "none";
      void container.offsetHeight; // Forzar lectura (Reflow)

      // 2. Ejecutar la acción que cambia el contenido
      actionCallback();

      // 3. Esperar a que Vue actualice el HTML
      this.$nextTick(() => {
        // Medimos la nueva altura real (sin hacks ni clases falsas)
        container.style.height = "auto";
        const newHeight = container.offsetHeight;

        // Volvemos a la vieja para preparar la rampa de salida
        container.style.height = oldHeight + "px";
        void container.offsetHeight; // Reflow

        // 4. Activar transición a la velocidad perfecta
        container.style.transition = "height 0.5s cubic-bezier(0.4, 0, 0.2, 1)";
        container.style.height = newHeight + "px";

        // 5. PROTECCIÓN ANTI-SPAM
        if (this.heightAnimTimeout) clearTimeout(this.heightAnimTimeout);

        this.heightAnimTimeout = setTimeout(() => {
          // Quitamos la altura fija pero mantenemos el overflow intacto
          if (container.style.height === newHeight + "px") {
            container.style.height = "auto";
            container.style.transition = "none";
          }
        }, 500);
      });
    },

    // Captura cada letra que escribes y anima la lista
    updateSearch(event) {
      const newValue = event.target.value;
      this.animateContainerHeight(() => {
        this.adminSearchQuery = newValue;
      });
    },

    toggleAdminSearch() {
      if (this.showAdminSearch) {
        // Si lo cerramos, vaciamos el texto envuelto en la animación para que se expanda suave
        this.animateContainerHeight(() => {
          this.showAdminSearch = false;
          this.adminSearchQuery = "";
        });
      } else {
        // Si lo abrimos, solo mostramos el input y le damos focus
        this.showAdminSearch = true;
        this.$nextTick(() => {
          const searchInput = document.getElementById("admin-search-input");
          if (searchInput) searchInput.focus();
        });
      }
    },

    fetchAdminData() {
      // Pide los datos al servidor y los aplica instantáneamente sin animaciones de carga
      return axios
        .post("https://DP-Inventory/GetAdminMasterData", {})
        .then((res) => {
          if (res.data) this.adminData = res.data;
        })
        .catch((e) => console.error("Error cargando datos admin:", e));
    },

    returnToAdminMain() {
      this.animateContainerHeight(() => {
        this.adminCurrentCategory = null;
        this.adminSearchQuery = "";
        this.showAdminSearch = false;
        this.fetchAdminData();
      });
    },

    openAdminCategory(category) {
      if (!this.adminData) {
        // Si no hay datos, pedimos y luego animamos
        this.fetchAdminData().then(() => {
          this.animateContainerHeight(() => {
            this.adminCurrentCategory = category;
          });
        });
      } else {
        // Si ya hay datos, animamos al instante
        this.animateContainerHeight(() => {
          this.adminCurrentCategory = category;
        });
      }
    },

    getAdminCategoryIcon() {
      if (this.adminCurrentCategory === "players") return "mdi:account-group";
      if (this.adminCurrentCategory === "stashes") return "fluent-mdl2:packages";
      if (this.adminCurrentCategory === "trunks") return "mdi:speedometer-medium";
      if (this.adminCurrentCategory === "gloveboxes") return "mdi:toolbox";
      return "mdi:database";
    },

    forceOpenAdmin(item) {
      const isPlayer = !!item.name;
      const targetId = isPlayer ? item.id : item;

      axios.post("https://DP-Inventory/ForceOpenAdmin", {
        type: isPlayer ? "player" : "stash",
        id: targetId,
      });
    },

    getItemInSlot(slot, inventoryType) {
      if (inventoryType === "player") return this.playerInventory[slot] || null;
      if (inventoryType === "other") return this.otherInventory[slot] || null;
      return null;
    },

    getHotbarItemInSlot(slot) {
      return this.hotbarItems[slot - 1] || null;
    },

    getInventoryByType(inventoryType) {
      return inventoryType === "player" ? this.playerInventory : this.otherInventory;
    },

    findNextAvailableSlot(inventory) {
      for (let slot = 1; slot <= this.totalSlots; slot++) {
        if (!inventory[slot]) return slot;
      }
      return null;
    },

    formatKey(key) {
      const translations = {
        // Armas
        quality: "Calidad",
        ammo: "Munición",
        serie: "Nº de Serie",
        type: "Tipo",
        uses: "Usos",
        worth: "Valor",
        // Documentos / Personaje
        citizenid: "ID Ciudadano",
        firstname: "Nombre",
        lastname: "Apellido",
        birthdate: "Fecha de Nacimiento",
        gender: "Género",
        nationality: "Nacionalidad",
        url: "URL",
        // Genéricos
        description: "Descripción",
        expiry: "Caducidad",
        blood: "Grupo Sanguíneo",
        job: "Trabajo",
        callsign: "Indicativo",
      };
      return (
        translations[key.toLowerCase()] ||
        key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1)
      );
    },

    formatValue(key, value) {
      // Traduce géneros
      if (key === "gender") {
        return value == 0 ? "Masculino" : value == 1 ? "Femenino" : value;
      }
      // Traduce códigos de nacionalidad ISO -> nombre completo
      if (key === "nationality") {
        const countries = {
          af: "Afganistán",
          al: "Albania",
          de: "Alemania",
          ad: "Andorra",
          ao: "Angola",
          ag: "Antigua y Barbuda",
          sa: "Arabia Saudita",
          dz: "Argelia",
          ar: "Argentina",
          am: "Armenia",
          au: "Australia",
          at: "Austria",
          az: "Azerbaiyán",
          bs: "Bahamas",
          bh: "Baréin",
          bd: "Bangladés",
          bb: "Barbados",
          be: "Bélgica",
          bz: "Belice",
          bj: "Benín",
          bt: "Bután",
          by: "Bielorrusia",
          bo: "Bolivia",
          ba: "Bosnia y Herzegovina",
          bw: "Botsuana",
          br: "Brasil",
          bn: "Brunéi",
          bg: "Bulgaria",
          bf: "Burkina Faso",
          bi: "Burundi",
          cv: "Cabo Verde",
          kh: "Camboya",
          cm: "Camerún",
          ca: "Canadá",
          qa: "Catar",
          td: "Chad",
          cl: "Chile",
          cn: "China",
          cy: "Chipre",
          va: "Ciudad del Vaticano",
          co: "Colombia",
          km: "Comoras",
          cg: "Congo",
          cd: "Congo (RDC)",
          kp: "Corea del Norte",
          kr: "Corea del Sur",
          ci: "Costa de Marfil",
          cr: "Costa Rica",
          hr: "Croacia",
          cu: "Cuba",
          dk: "Dinamarca",
          dj: "Yibuti",
          dm: "Dominica",
          ec: "Ecuador",
          eg: "Egipto",
          sv: "El Salvador",
          ae: "Emiratos Árabes Unidos",
          er: "Eritrea",
          sk: "Eslovaquia",
          si: "Eslovenia",
          es: "España",
          us: "Estados Unidos",
          ee: "Estonia",
          et: "Etiopía",
          ph: "Filipinas",
          fi: "Finlandia",
          fj: "Fiyi",
          fr: "Francia",
          ga: "Gabón",
          gm: "Gambia",
          ge: "Georgia",
          gh: "Ghana",
          gd: "Granada",
          gr: "Grecia",
          gt: "Guatemala",
          gn: "Guinea",
          gw: "Guinea-Bisáu",
          gq: "Guinea Ecuatorial",
          gy: "Guyana",
          ht: "Haití",
          hn: "Honduras",
          hu: "Hungría",
          in: "India",
          id: "Indonesia",
          iq: "Irak",
          ir: "Irán",
          ie: "Irlanda",
          is: "Islandia",
          il: "Israel",
          it: "Italia",
          jm: "Jamaica",
          jp: "Japón",
          jo: "Jordania",
          kz: "Kazajistán",
          ke: "Kenia",
          kg: "Kirguistán",
          ki: "Kiribati",
          kw: "Kuwait",
          la: "Laos",
          ls: "Lesoto",
          lv: "Letonia",
          lb: "Líbano",
          lr: "Liberia",
          ly: "Libia",
          li: "Liechtenstein",
          lt: "Lituania",
          lu: "Luxemburgo",
          mk: "Macedonia del Norte",
          mg: "Madagascar",
          my: "Malasia",
          mw: "Malaui",
          mv: "Maldivas",
          ml: "Malí",
          mt: "Malta",
          ma: "Marruecos",
          mh: "Islas Marshall",
          mu: "Mauricio",
          mr: "Mauritania",
          mx: "México",
          fm: "Micronesia",
          md: "Moldavia",
          mc: "Mónaco",
          mn: "Mongolia",
          me: "Montenegro",
          mz: "Mozambique",
          mm: "Myanmar",
          na: "Namibia",
          nr: "Nauru",
          np: "Nepal",
          ni: "Nicaragua",
          ne: "Níger",
          ng: "Nigeria",
          no: "Noruega",
          nz: "Nueva Zelanda",
          om: "Omán",
          nl: "Países Bajos",
          pk: "Pakistán",
          pw: "Palaos",
          pa: "Panamá",
          pg: "Papúa Nueva Guinea",
          py: "Paraguay",
          pe: "Perú",
          pl: "Polonia",
          pt: "Portugal",
          gb: "Reino Unido",
          uk: "Reino Unido",
          cf: "República Centroafricana",
          cz: "República Checa",
          do: "República Dominicana",
          rw: "Ruanda",
          ro: "Rumanía",
          ru: "Rusia",
          ws: "Samoa",
          kn: "San Cristóbal y Nieves",
          sm: "San Marino",
          vc: "San Vicente y las Granadinas",
          lc: "Santa Lucía",
          st: "Santo Tomé y Príncipe",
          sn: "Senegal",
          rs: "Serbia",
          sc: "Seychelles",
          sl: "Sierra Leona",
          sg: "Singapur",
          so: "Somalia",
          lk: "Sri Lanka",
          sz: "Suazilandia",
          za: "Sudáfrica",
          sd: "Sudán",
          ss: "Sudán del Sur",
          se: "Suecia",
          ch: "Suiza",
          sr: "Surinam",
          th: "Tailandia",
          tz: "Tanzania",
          tj: "Tayikistán",
          tl: "Timor Oriental",
          tg: "Togo",
          to: "Tonga",
          tt: "Trinidad y Tobago",
          tn: "Túnez",
          tm: "Turkmenistán",
          tr: "Turquía",
          tv: "Tuvalu",
          ua: "Ucrania",
          ug: "Uganda",
          uy: "Uruguay",
          uz: "Uzbekistán",
          vu: "Vanuatu",
          ve: "Venezuela",
          vn: "Vietnam",
          ye: "Yemen",
          zm: "Zambia",
          zw: "Zimbabue",
        };
        return countries[String(value).toLowerCase()] || value;
      }
      return value;
    },

    /* ------------------------------------------------------------------
           C. EVENTOS DE RATÓN (CLICS Y CONTEXT MENU)
           ------------------------------------------------------------------ */

    containerMouseDownAction(event) {
      // Si estamos combinando y hacemos clic en el fondo, cancelamos
      if (
        this.simCombineState.isActive &&
        event.target.classList.contains("inventory-container")
      ) {
        this.cancelSimCombine();
      }

      // Quitar el focus del input si haces clic en cualquier otro lado
      if (event.target.tagName !== "INPUT") {
        if (document.activeElement && document.activeElement.tagName === "INPUT") {
          document.activeElement.blur();
        }
      }
      // Cerrar menú contextual si existe
      if (event.button === 0 && this.showContextMenu) {
        this.showContextMenu = false;
      }
    },

    handleMouseDown(event, slot, inventory) {
      if (event.button === 1) return; // Ignorar botón central del ratón
      event.preventDefault();

      // --- INTERCEPTOR DE MODO COMBINAR SIM ---
      if (this.simCombineState.isActive) {
        // Si es clic izquierdo o derecho sobre un ítem compatible
        if (this.isSimCompatible(slot, inventory)) {
          this.executeSimCombine(slot, inventory);
        } else {
          // Si clica en un sitio no válido, cancelamos el modo
          this.cancelSimCombine();
        }
        return;
      }

      const itemInSlot = this.getItemInSlot(slot, inventory);

      // Clic Izquierdo (Drag o Split)
      if (event.button === 0) {
        if (event.shiftKey && itemInSlot) {
          this.splitAndPlaceItem(itemInSlot, inventory);
        } else {
          this.startDrag(event, slot, inventory);
        }
      }

      // Clic Derecho (Comprar, Mover o Menú Contextual)
      else if (event.button === 2 && itemInSlot) {
        this.isCtrlDrag = event.ctrlKey;

        if (this.otherInventoryName.startsWith("shop-")) {
          this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
          this.isCtrlDrag = false;
          return;
        }
        if (!this.isOtherInventoryEmpty) {
          this.moveItemBetweenInventories(itemInSlot, inventory);
          this.isCtrlDrag = false;
        } else {
          this.showContextMenuOptions(event, itemInSlot);
          this.isCtrlDrag = false;
        }
      }
    },

    showContextMenuOptions(event, item) {
      event.preventDefault();
      if (
        this.contextMenuItem &&
        this.contextMenuItem.name === item.name &&
        this.showContextMenu
      ) {
        this.showContextMenu = false;
        this.contextMenuItem = null;
        this.activeSubmenu = null; // IMPORTANTE: limpiar el submenú al cerrar
      } else {
        if (item.inventory === "other") {
          let isDamagedArmor = false;
          if (item.name === "armor" || item.name === "heavyarmor") {
            const itemQ =
              item.info && item.info.quality !== undefined ? item.info.quality : 100;
            if (itemQ < 100) isDamagedArmor = true;
          }

          const matchingItemKey = Object.keys(this.playerInventory).find((key) => {
            const tItem = this.playerInventory[key];
            if (!tItem || tItem.name !== item.name) return false;
            if (tItem.name === "armor" || tItem.name === "heavyarmor") {
              const tQ =
                tItem.info && tItem.info.quality !== undefined ? tItem.info.quality : 100;
              if (tQ < 100) return false;
            }
            return true;
          });
          const matchingItem = this.playerInventory[matchingItemKey];

          if ((matchingItem && matchingItem.unique) || isDamagedArmor) {
            const newItemKey = Object.keys(this.playerInventory).length + 1;
            const newItem = { ...item, inventory: "player", amount: 1 };
            this.playerInventory[newItemKey] = newItem;
          } else if (matchingItem) {
            matchingItem.amount++;
          } else {
            const newItemKey = Object.keys(this.playerInventory).length + 1;
            const newItem = { ...item, inventory: "player", amount: 1 };
            this.playerInventory[newItemKey] = newItem;
          }
          item.amount--;

          if (item.amount <= 0) {
            const itemKey = Object.keys(this.otherInventory).find(
              (key) => this.otherInventory[key] === item,
            );
            if (itemKey) delete this.otherInventory[itemKey];
          }
        }

        // 1. Buscamos el recuadro del slot que acabas de clicar
        const slotElement = event.target.closest(".item-slot");
        const rect = slotElement
          ? slotElement.getBoundingClientRect()
          : {
              top: event.clientY,
              left: event.clientX,
              right: event.clientX,
              bottom: event.clientY,
            };

        const padding = 5;

        // Anclaje por defecto (Derecha y Arriba)
        let menuLeft = rect.right + padding;
        let menuTop = rect.top;

        // Usamos una estimación grande SOLO para saber si va a chocar con el borde de la pantalla
        const maxCollisionWidth = 320; // Espacio necesario para Menú + Submenú de jugadores
        const maxCollisionHeight = 220; // Altura máxima esperada

        // 2. Colisión Horizontal
        if (menuLeft + maxCollisionWidth > window.innerWidth) {
          this.isMenuOnLeft = true;
          menuLeft = rect.left - padding; // Lo anclamos al lado izquierdo del slot
        } else {
          this.isMenuOnLeft = false;
        }

        // 3. Colisión Vertical
        if (menuTop + maxCollisionHeight > window.innerHeight) {
          this.isMenuOnTop = true;
          menuTop = rect.bottom; // Lo anclamos a la base del slot
        } else {
          this.isMenuOnTop = false;
        }

        axios
          .post("https://DP-Inventory/GetNearbyPlayers", {})
          .then((response) => {
            this.nearbyPlayers = response.data || [];
          })
          .catch(() => {
            this.nearbyPlayers = [];
          });

        this.showContextMenu = true;
        this.contextMenuPosition = {
          top: `${menuTop}px`,
          left: `${menuLeft}px`,
        };
        this.contextMenuItem = item;
        this.activeSubmenu = null;
      }
    },

    /* ------------------------------------------------------------------
           MODAL DE INSPECCIÓN
           ------------------------------------------------------------------ */
    openInspectModal(item) {
      if (!item) return;
      this.playSound("open_inv");
      this.inspectingItem = item;
      this.inspectRotation = 0;
      this.inspectZoom = 1;
      this.showInspectModal = true;
      this.showContextMenu = false;
    },

    closeInspectModal() {
      this.playSound("close_inv");
      this.showInspectModal = false;
      setTimeout(() => {
        this.inspectingItem = null;
        this.inspectRotation = 0;
        this.inspectZoom = 1;
      }, 300);
    },

    // Control del zoom con la rueda del ratón
    handleInspectZoom(event) {
      const zoomSpeed = 0.15; // Qué tan rápido hace zoom en cada "click" de la rueda

      if (event.deltaY < 0) {
        // Rueda hacia arriba -> Acercar
        this.inspectZoom += zoomSpeed;
      } else {
        // Rueda hacia abajo -> Alejar
        this.inspectZoom -= zoomSpeed;
      }

      // LÍMITES DE ZOOM
      const maxZoom = 2.5; // Lo máximo que puede crecer
      const minZoom = 0.5; // Lo máximo que puede encoger

      if (this.inspectZoom > maxZoom) {
        this.inspectZoom = maxZoom;
      } else if (this.inspectZoom < minZoom) {
        this.inspectZoom = minZoom;
      }
    },

    /* ------------------------------------------------------------------
           D. SISTEMA DE ARRASTRE (DRAG & DROP)
           ------------------------------------------------------------------ */

    startDrag(event, slot, inventoryType) {
      event.preventDefault();
      const item = this.getItemInSlot(slot, inventoryType);
      if (!item) return;

      // --- NUEVO: Detectar si se está pulsando CTRL ---
      this.isCtrlDrag = event.ctrlKey;

      if (item && item.type === "weapon") {
        axios
          .post("https://DP-Inventory/HolsterWeapon", {
            item: item,
            slot: slot,
            inventory: inventoryType,
          })
          .catch((error) => {
            console.error("Error al notificar desequipamiento:", error);
          });
      }

      const slotElement = event.target.closest(".item-slot");
      if (!slotElement) return;

      const ghostElement = this.createGhostElement(slotElement);

      if (this.isCtrlDrag && item.amount > 1) {
        const amountElement = ghostElement.querySelector(".item-slot-amount p");
        if (amountElement) {
          amountElement.innerText = "x" + Math.ceil(item.amount / 2);
        }
      }

      document.body.appendChild(ghostElement);

      const offsetX = ghostElement.offsetWidth / 2;
      const offsetY = ghostElement.offsetHeight / 2;
      ghostElement.style.left = `${event.clientX - offsetX}px`;
      ghostElement.style.top = `${event.clientY - offsetY}px`;

      this.ghostElement = ghostElement;
      this.currentlyDraggingItem = item;
      this.currentlyDraggingSlot = slot;
      this.dragStartX = event.clientX;
      this.dragStartY = event.clientY;
      this.dragStartInventoryType = inventoryType;
      this.showContextMenu = false;
    },

    createGhostElement(slotElement) {
      const ghostElement = slotElement.cloneNode(true);
      ghostElement.style.position = "absolute";
      ghostElement.style.pointerEvents = "none";
      ghostElement.style.opacity = "0.7";
      ghostElement.style.zIndex = "1000";
      ghostElement.style.width = getComputedStyle(slotElement).width;
      ghostElement.style.height = getComputedStyle(slotElement).height;
      ghostElement.style.boxSizing = "border-box";
      ghostElement.style.transition = "none";
      ghostElement.style.animation = "none";

      return ghostElement;
    },

    drag(event) {
      if (!this.currentlyDraggingItem) return;
      const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
      const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
      this.ghostElement.style.left = `${centeredX}px`;
      this.ghostElement.style.top = `${centeredY}px`;
    },

    // Línea ~414 - endDrag
    endDrag(event) {
      if (!this.currentlyDraggingItem) return;

      const wasWeapon =
        this.currentlyDraggingItem && this.currentlyDraggingItem.type === "weapon";
      const elementsUnderCursor = document.elementsFromPoint(event.clientX, event.clientY);
      const playerSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList &&
          el.classList.contains("item-slot") &&
          el.closest(".player-inventory-section"),
      );
      const otherSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList &&
          el.classList.contains("item-slot") &&
          el.closest(".other-inventory-section"),
      );

      // Buscamos tanto el elemento directo como sus padres, por si el cursor cae sobre un hijo (img, span, etc.)
      let wipSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList && el.classList.contains("wip-real-slot") && el.dataset.attachmentType,
      );
      if (!wipSlotElement) {
        // Buscar en ancestros del primer elemento bajo cursor
        for (const el of elementsUnderCursor) {
          const parent = el.closest && el.closest(".wip-real-slot");
          if (parent && parent.dataset.attachmentType) {
            wipSlotElement = parent;
            break;
          }
        }
      }

      if (wipSlotElement && this.showWeaponAttachments) {
        const attachmentType = wipSlotElement.dataset.attachmentType;
        this.wipDragOverSlot = null;
        this.handleDropOnWipSlot(attachmentType);
      } else if (playerSlotElement && this.dragStartInventoryType === "wip") {
        // Arrastramos un accesorio DESDE el panel WIP HACIA el inventario → quitar
        const slotType = this.currentlyDraggingSlot.replace("__wip__", "");
        const attachment = this.getAttachmentByType(slotType);
        if (attachment) this.removeAttachment(attachment);
      } else if (playerSlotElement) {
        const targetSlot = Number(playerSlotElement.dataset.slot);
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === "player"
          )
        ) {
          this.handleDropOnPlayerSlot(targetSlot);
        }
      } else if (otherSlotElement) {
        const targetSlot = Number(otherSlotElement.dataset.slot);
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === "other"
          )
        ) {
          this.handleDropOnOtherSlot(targetSlot);
        }
      } else if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
        // ¿Estamos sobre CUALQUIER elemento de la UI?
        const isOverUI = elementsUnderCursor.some(
          (el) =>
            el.classList &&
            (el.classList.contains("inventory-section") ||
              el.classList.contains("tabs-sidebar") ||
              el.classList.contains("equipment-sidebar") ||
              el.classList.contains("hotbar-container")),
        );

        // Solo permite tirar el objeto si el ratón está fuera de todas las cajas negras
        if (!isOverUI) {
          this.handleDropOnInventoryContainer();
        }
      }

      // Si era un arma, aseguramos que sigue desequipada aunque el drag no terminó en un slot válido
      if (wasWeapon) {
        axios
          .post("https://DP-Inventory/HolsterWeapon", {
            item: this.currentlyDraggingItem,
            slot: this.currentlyDraggingSlot,
            inventory: this.dragStartInventoryType,
          })
          .catch((error) => {
            console.error("Error al notificar desequipamiento (endDrag):", error);
          });
      }

      this.clearDragData();
    },

    clearDragData() {
      if (this.ghostElement) {
        document.body.removeChild(this.ghostElement);
        this.ghostElement = null;
      }
      this.currentlyDraggingItem = null;
      this.currentlyDraggingSlot = null;
      this.isCtrlDrag = false;
    },

    /* ------------------------------------------------------------------
           E. LÓGICA DE MOVIMIENTO DE ÍTEMS (HANDLERS)
           ------------------------------------------------------------------ */

    handleDropOnPlayerSlot(targetSlot) {
      const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
      const targetSlotNumber = Number(targetSlot);

      // 1. VALIDACIÓN ESTRICTA PARA SLOTS DE EQUIPAMIENTO
      if (targetSlotNumber === 101 || targetSlotNumber === 102) {
        const validBackpacks = ["backpack_1", "backpack_2", "backpack_3", "backpack_4"];
        const validArmor = ["armor", "heavyarmor"];

        const isValid =
          targetSlotNumber === 101
            ? validBackpacks.includes(currentlyDraggingItem.name)
            : validArmor.includes(currentlyDraggingItem.name);

        if (!isValid) {
          this.inventoryError(currentlyDraggingSlot);
          return;
        }

        const targetInventory = this.getInventoryByType("player");
        const targetItem = targetInventory[targetSlotNumber];

        if (targetItem) {
          if (targetItem.name === currentlyDraggingItem.name) {
            this.inventoryError(currentlyDraggingSlot);
            return;
          }
          if (currentlyDraggingItem.amount > 1) {
            this.inventoryError(currentlyDraggingSlot);
            return;
          }
        }
      }

      // 2. LÓGICA ORIGINAL SI PASA LA VALIDACIÓN
      if (this.isShopInventory && this.dragStartInventoryType === "other") {
        const targetInventory = this.getInventoryByType("player");
        const targetItem = targetInventory[targetSlotNumber];

        if (
          (targetItem && targetItem.name !== currentlyDraggingItem.name) ||
          (targetItem &&
            targetItem.name === currentlyDraggingItem.name &&
            currentlyDraggingItem.unique)
        ) {
          this.inventoryError(currentlyDraggingSlot);
          return;
        }
        this.handlePurchase(
          targetSlot,
          currentlyDraggingSlot,
          currentlyDraggingItem,
          transferAmount,
        );
      } else {
        this.handleItemDrop("player", targetSlot);
      }
    },

    handleDropOnOtherSlot(targetSlot) {
      this.handleItemDrop("other", targetSlot);
    },

    async handleDropOnInventoryContainer() {
      if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
        let dropAmount =
          this.transferAmount && this.transferAmount > 0
            ? this.transferAmount
            : this.currentlyDraggingItem.amount;

        if (this.isCtrlDrag && this.currentlyDraggingItem.amount > 1) {
          dropAmount = Math.ceil(this.currentlyDraggingItem.amount / 2);
        }

        // Evitar que tire más de lo que tiene
        if (dropAmount > this.currentlyDraggingItem.amount) {
          dropAmount = this.currentlyDraggingItem.amount;
        }

        const newItem = {
          ...this.currentlyDraggingItem,
          amount: dropAmount,
          slot: 1,
          inventory: "other",
        };

        const draggingItem = this.currentlyDraggingItem;

        try {
          const response = await axios.post("https://DP-Inventory/DropItem", {
            ...newItem,
            fromSlot: this.currentlyDraggingSlot,
          });

          if (response.data) {
            this.otherInventory[1] = newItem;

            // Restar cantidad visualmente
            const draggingItemKey = Object.keys(this.playerInventory).find(
              (key) => this.playerInventory[key] === draggingItem,
            );
            if (draggingItemKey) {
              this.playerInventory[draggingItemKey].amount -= dropAmount;
              if (this.playerInventory[draggingItemKey].amount <= 0) {
                delete this.playerInventory[draggingItemKey];
              }
            }

            // Actualizar datos del drop en el suelo
            this.otherInventoryName = response.data.name || response.data;
            this.otherInventoryLabel = "Suelo";
            this.otherInventorySlots = response.data.slots || 100;
            this.otherInventoryMaxWeight = response.data.maxweight || 1200000;

            this.isOtherInventoryEmpty = false;
            this.clearDragData();
          }
        } catch (error) {
          this.inventoryError(this.currentlyDraggingSlot);
        }
      }
      this.clearDragData();
    },

    handleItemDrop(targetInventoryType, targetSlot) {
      try {
        const isShop = this.otherInventoryName.indexOf("shop-");
        if (
          this.dragStartInventoryType === "other" &&
          targetInventoryType === "other" &&
          isShop !== -1
        )
          return;

        const targetSlotNumber = parseInt(targetSlot, 10);
        if (isNaN(targetSlotNumber)) throw new Error("Invalid target slot number");

        const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
        const targetInventory = this.getInventoryByType(targetInventoryType);

        const sourceItem = sourceInventory[this.currentlyDraggingSlot];
        if (!sourceItem) throw new Error("No item in the source slot to transfer");

        let amountToTransfer =
          this.transferAmount && this.transferAmount > 0
            ? this.transferAmount
            : sourceItem.amount;

        if (this.isCtrlDrag && sourceItem.amount > 1) {
          amountToTransfer = Math.ceil(sourceItem.amount / 2);
        }

        if (
          targetInventoryType === "player" &&
          (targetSlotNumber === 101 || targetSlotNumber === 102)
        ) {
          amountToTransfer = 1;
        }

        if (sourceItem.amount < amountToTransfer)
          throw new Error("Insufficient amount of item in source inventory");

        if (targetInventoryType !== this.dragStartInventoryType) {
          if (targetInventoryType == "other") {
            const totalWeightAfterTransfer =
              this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
            if (totalWeightAfterTransfer > this.otherInventoryMaxWeight)
              throw new Error("Insufficient weight capacity in target inventory");
          } else if (targetInventoryType == "player") {
            const totalWeightAfterTransfer =
              this.playerWeight + sourceItem.weight * amountToTransfer;
            if (totalWeightAfterTransfer > this.maxWeight)
              throw new Error("Insufficient weight capacity in player inventory");
          }
        }

        const targetItem = targetInventory[targetSlotNumber];

        this.playSound("drop");

        if (targetItem) {
          // 1. Si los ítems se llaman EXACTAMENTE IGUAL
          if (sourceItem.name === targetItem.name) {
            // A) Si es un ítem único (DNIs, llaves), QBCore NO DEJA apilarlos.
            if (targetItem.unique) {
              this.inventoryError(this.currentlyDraggingSlot);
              return;
            }

            // B) ANTI-REPARACIÓN INTELIGENTE
            if (this.isItemDamaged(sourceItem) || this.isItemDamaged(targetItem)) {
              this.inventoryError(this.currentlyDraggingSlot);
              return; // Parpadeo rojo si alguno de los dos no está a SU MÁXIMO
            }

            // C) Si son normales y apilables (o 2 chalecos a su máximo), FUSIONAMOS
            targetItem.amount += amountToTransfer;
            sourceItem.amount -= amountToTransfer;
            if (sourceItem.amount <= 0) delete sourceInventory[this.currentlyDraggingSlot];

            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlotNumber,
              sourceItem.amount,
              amountToTransfer,
            );
          } else {
            // 2. ÍTEMS DISTINTOS: INTERCAMBIAR DE CASILLA (Swap Seguro Clonando)
            const clonedSource = { ...sourceItem, slot: targetSlotNumber };
            const clonedTarget = { ...targetItem, slot: this.currentlyDraggingSlot };

            targetInventory[targetSlotNumber] = clonedSource;
            sourceInventory[this.currentlyDraggingSlot] = clonedTarget;

            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlotNumber,
              clonedSource.amount,
              clonedTarget.amount,
            );
          }
        } else {
          // SI NO HAY ITEM EN EL DESTINO (Casilla vacía)
          sourceItem.amount -= amountToTransfer;
          if (sourceItem.amount <= 0) delete sourceInventory[this.currentlyDraggingSlot];

          targetInventory[targetSlotNumber] = {
            ...sourceItem,
            amount: amountToTransfer,
            slot: targetSlotNumber,
          };
          this.postInventoryData(
            this.dragStartInventoryType,
            targetInventoryType,
            this.currentlyDraggingSlot,
            targetSlotNumber,
            sourceItem.amount,
            amountToTransfer,
          );
        }
      } catch (error) {
        console.error(error.message);
        this.inventoryError(this.currentlyDraggingSlot);
      } finally {
        this.clearDragData();
      }
    },

    moveItemBetweenInventories(item, sourceInventoryType) {
      const sourceInventory =
        sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
      const targetInventory =
        sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
      const targetWeight =
        sourceInventoryType === "player" ? this.otherInventoryWeight : this.playerWeight;
      const maxTargetWeight =
        sourceInventoryType === "player" ? this.otherInventoryMaxWeight : this.maxWeight;

      const sourceItem = sourceInventory[item.slot];
      const amountToTransfer =
        this.transferAmount && this.transferAmount > 0
          ? this.transferAmount
          : sourceItem.amount;

      if (this.isCtrlDrag && sourceItem.amount > 1) {
        amountToTransfer = Math.ceil(sourceItem.amount / 2);
      }

      let targetSlot = null;

      if (!sourceItem || sourceItem.amount < amountToTransfer) {
        this.inventoryError(item.slot);
        return;
      }

      if (targetWeight + sourceItem.weight * amountToTransfer > maxTargetWeight) {
        this.inventoryError(item.slot);
        return;
      }

      this.playSound("drop");

      // ANTI-REPARACIÓN (Trata a los chalecos dañados como ÍTEMS ÚNICOS)
      let isDamagedArmor = false;
      if (item.name === "armor" || item.name === "heavyarmor") {
        const itemQ = item.info && item.info.quality !== undefined ? item.info.quality : 100;
        if (itemQ < 100) isDamagedArmor = true;
      }

      if (item.unique || isDamagedArmor) {
        targetSlot = this.findNextAvailableSlot(targetInventory);
        if (targetSlot === null) {
          this.inventoryError(item.slot);
          return;
        }

        const newItem = {
          ...item,
          inventory: sourceInventoryType === "player" ? "other" : "player",
          amount: amountToTransfer,
        };
        targetInventory[targetSlot] = newItem;
        newItem.slot = targetSlot;
      } else {
        const targetItemKey = Object.keys(targetInventory).find((key) => {
          const tItem = targetInventory[key];
          if (!tItem || tItem.name !== item.name) return false;

          // No apilamos sobre chalecos que ya estén dañados en el destino
          if (tItem.name === "armor" || tItem.name === "heavyarmor") {
            const tQ =
              tItem.info && tItem.info.quality !== undefined ? tItem.info.quality : 100;
            if (tQ < 100) return false;
          }
          return true;
        });
        const targetItem = targetInventory[targetItemKey];

        if (!targetItem) {
          targetSlot = this.findNextAvailableSlot(targetInventory);
          if (targetSlot === null) {
            this.inventoryError(item.slot);
            return;
          }
          const newItem = {
            ...item,
            inventory: sourceInventoryType === "player" ? "other" : "player",
            amount: amountToTransfer,
          };
          targetInventory[targetSlot] = newItem;
          newItem.slot = targetSlot;
        } else {
          targetItem.amount += amountToTransfer;
          targetSlot = targetItem.slot;
        }
      }

      sourceItem.amount -= amountToTransfer;
      if (sourceItem.amount <= 0) delete sourceInventory[item.slot];

      this.postInventoryData(
        sourceInventoryType,
        sourceInventoryType === "player" ? "other" : "player",
        item.slot,
        targetSlot,
        sourceItem.amount,
        amountToTransfer,
      );
    },

    /* ------------------------------------------------------------------
           SIM: LÓGICA DE COMBINACIÓN Y EXTRACCIÓN
           ------------------------------------------------------------------ */

    canCombineSim(item) {
      if (!item) return false;
      // Es un teléfono SIN sim, o es una SIM
      if (item.name === "phone" && !item.hasSim) return true;
      if (item.name === "sim_card") return true;
      return false;
    },

    canExtractSim(item) {
      if (!item) return false;
      // Es un teléfono CON sim
      return item.name === "phone" && item.hasSim === true;
    },

    startSimCombine(item, invType) {
      this.showContextMenu = false;
      if (!item) return;

      // Forzamos que sea un número puro
      const slotNum = parseInt(item.slot, 10);
      if (isNaN(slotNum)) {
        console.error("Slot inválido al iniciar combinación:", item.slot);
        return;
      }

      this.simCombineState = {
        isActive: true,
        sourceSlot: slotNum,
        sourceInventory: invType || "player",
        sourceItemName: item.name,
      };

      this.playSound("click");
    },

    cancelSimCombine() {
      if (!this.simCombineState.isActive) return;
      this.simCombineState = {
        isActive: false,
        sourceSlot: null,
        sourceInventory: null,
        sourceItemName: null,
      };
    },

    isSimCompatible(slot, inventoryType) {
      if (!this.simCombineState.isActive) return false;
      // El slot de origen no es un "target", es el "source"
      if (
        this.simCombineState.sourceSlot === slot &&
        this.simCombineState.sourceInventory === inventoryType
      ) {
        return false;
      }

      const item = this.getItemInSlot(slot, inventoryType);
      if (!item) return false;

      // Si el origen es un teléfono, el destino debe ser una SIM
      if (this.simCombineState.sourceItemName === "phone") {
        return item.name === "sim_card";
      }
      // Si el origen es una SIM, el destino debe ser un teléfono SIN SIM
      if (this.simCombineState.sourceItemName === "sim_card") {
        return item.name === "phone" && !item.hasSim;
      }
      return false;
    },

    executeSimCombine(targetSlot, targetInventory) {
      if (!this.simCombineState.isActive) return;

      const targetSlotNum = parseInt(targetSlot, 10);
      const sourceSlotNum = parseInt(this.simCombineState.sourceSlot, 10);

      if (isNaN(targetSlotNum) || isNaN(sourceSlotNum)) {
        this.cancelSimCombine();
        return;
      }

      let phoneSlot, simSlot;

      if (this.simCombineState.sourceItemName === "phone") {
        phoneSlot = sourceSlotNum;
        simSlot = targetSlotNum;
      } else {
        phoneSlot = targetSlotNum;
        simSlot = sourceSlotNum;
      }

      if (phoneSlot === simSlot) {
        this.cancelSimCombine();
        return;
      }

      // FORZAMOS EL ENVÍO CON JSON.STRINGIFY PARA EVITAR EL PROXY DE VUE
      const payload = JSON.stringify({
        phoneSlot: parseInt(phoneSlot),
        simSlot: parseInt(simSlot),
      });

      const originalText = this.inventoryLabel;
      this.inventoryLabel = "PROCESANDO...";
      this.cancelSimCombine();

      axios
        .post("https://DP-Inventory/DP-Inventory:combineSim", payload, {
          headers: { "Content-Type": "application/json" },
        })
        .then((response) => {
          if (response.data && response.data.success) {
            this.playSound("drop");
          } else {
            this.playSound("drop");
          }
        })
        .finally(() => {
          this.inventoryLabel = originalText;
        });
    },

    extractSim(item) {
      this.showContextMenu = false;
      if (!item || item.name !== "phone") return;

      const phoneSlot = parseInt(item.slot, 10);
      if (isNaN(phoneSlot)) return;

      const originalText = this.inventoryLabel;
      this.inventoryLabel = "EXTRAYENDO...";

      axios
        .post("https://DP-Inventory/DP-Inventory:splitSim", { phoneSlot: phoneSlot })
        .then((response) => {
          if (response.data && response.data.success) {
            this.playSound("drop");
          }
        })
        .catch((e) => console.error("Error extrayendo SIM:", e))
        .finally(() => {
          this.inventoryLabel = originalText;
        });
    },

    /* ------------------------------------------------------------------
           F. ACCIONES SECUNDARIAS (USAR, TIRAR, DAR, COMPRAR)
           ------------------------------------------------------------------ */

    async handlePurchase(targetSlot, sourceSlot, sourceItem, transferAmount) {
      try {
        const response = await axios.post("https://DP-Inventory/AttemptPurchase", {
          item: sourceItem,
          amount: transferAmount || sourceItem.amount,
          shop: this.otherInventoryName,
        });

        if (response.data) {
          const sourceInventory = this.getInventoryByType("other");
          const targetInventory = this.getInventoryByType("player");
          const amountToTransfer =
            transferAmount !== null ? transferAmount : sourceItem.amount;

          if (sourceItem.amount < amountToTransfer) {
            this.inventoryError(sourceSlot);
            return;
          }

          let targetItem = targetInventory[targetSlot];
          if (!targetItem || targetItem.name !== sourceItem.name) {
            let foundSlot = Object.keys(targetInventory).find((slot) => {
              const tItem = targetInventory[slot];
              if (tItem && tItem.name === sourceItem.name) {
                // ANTI-REPARACIÓN (Tiendas)
                if (tItem.name === "armor" || tItem.name === "heavyarmor") {
                  const tQ =
                    tItem.info && tItem.info.quality !== undefined ? tItem.info.quality : 100;
                  if (tQ < 100) return false;
                }
                return true;
              }
              return false;
            });

            if (foundSlot) {
              targetInventory[foundSlot].amount += amountToTransfer;
            } else {
              const targetInventoryKeys = Object.keys(targetInventory);
              if (targetInventoryKeys.length < this.totalSlots) {
                let freeSlot = Array.from({ length: this.totalSlots }, (_, i) => i + 1).find(
                  (i) => !(i in targetInventory),
                );
                targetInventory[freeSlot] = { ...sourceItem, amount: amountToTransfer };
              } else {
                this.inventoryError(sourceSlot);
                return;
              }
            }
          } else {
            // Si arrastras el item de la tienda directamente sobre tu chaleco dañado
            if (targetItem.name === "armor" || targetItem.name === "heavyarmor") {
              const targetQ =
                targetItem.info && targetItem.info.quality !== undefined
                  ? targetItem.info.quality
                  : 100;
              if (targetQ < 100) {
                this.inventoryError(sourceSlot);
                return;
              }
            }
            targetItem.amount += amountToTransfer;
          }
          sourceItem.amount -= amountToTransfer;
          if (sourceItem.amount <= 0) delete sourceInventory[sourceSlot];
        } else {
          this.inventoryError(sourceSlot);
        }
      } catch (error) {
        this.inventoryError(sourceSlot);
      }
    },

    async dropItem(item) {
      if (!item || !item.name) return;

      const playerItemKey = Object.keys(this.playerInventory).find(
        (key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot,
      );

      if (playerItemKey) {
        // Lógica de cantidad: Si el input está vacío o en 0, tira todo. Si tiene número, usa ese número.
        let amountToDrop =
          this.transferAmount && this.transferAmount > 0
            ? parseInt(this.transferAmount)
            : item.amount;

        // Validar que no intente tirar más de lo que tiene
        if (amountToDrop > item.amount) {
          axios.post("https://DP-Inventory/Notify", {
            message: `No tienes la suficiente cantidad para tirar. Tienes ${item.amount}.`,
            type: "error",
          });
          this.showContextMenu = false;
          return;
        }

        const newItem = { ...item, amount: amountToDrop, slot: 1, inventory: "other" };

        try {
          const response = await axios.post("https://DP-Inventory/DropItem", {
            ...newItem,
            fromSlot: item.slot,
          });

          if (response.data) {
            // Restar la cantidad visualmente en lugar de borrar el slot de golpe
            this.playerInventory[playerItemKey].amount -= amountToDrop;
            if (this.playerInventory[playerItemKey].amount <= 0) {
              delete this.playerInventory[playerItemKey];
            }

            this.playSound("drop");

            // Añadir el item al suelo (otherInventory)
            this.otherInventory[1] = newItem;

            // Actualizar la caja del "Suelo"
            this.otherInventoryName = response.data.name || response.data;
            this.otherInventoryLabel = "Suelo";
            this.otherInventorySlots = response.data.slots || 100;
            this.otherInventoryMaxWeight = response.data.maxweight || 1200000;

            this.isOtherInventoryEmpty = false;
            this.clearTransferAmount(); // Limpiamos el input de arriba
          }
        } catch (error) {
          this.inventoryError(item.slot);
        }
      }

      this.showContextMenu = false;
    },

    async useItem(item) {
      if (!item || item.useable === false) return;

      // Sistema de Auto-Equipar Chalecos (Slot 102) y Mochilas (Slot 101)
      const isArmor = item.name === "armor" || item.name === "heavyarmor";
      const isBackpack = item.name.startsWith("backpack_");
      const isWeapon = item.type === "weapon";

      if (isArmor || isBackpack) {
        const targetEquipSlot = isArmor ? 102 : 101;

        if (item.slot !== targetEquipSlot) {
          // Equipar: Mover de la mochila al slot de equipo
          if (this.playerInventory[targetEquipSlot]) {
            this.inventoryError(item.slot); // Ya hay uno puesto
            return;
          }

          let sourceItem = this.playerInventory[item.slot];
          sourceItem.amount -= 1; // Le restamos 1 visualmente
          let amountLeft = sourceItem.amount;

          // Clonamos 1 unidad visualmente en el slot 102/101
          this.playerInventory[targetEquipSlot] = {
            ...item,
            amount: 1,
            slot: targetEquipSlot,
          };

          if (sourceItem.amount <= 0) {
            delete this.playerInventory[item.slot];
          }

          // Le pasamos la info exacta al servidor
          this.postInventoryData(
            "player",
            "player",
            item.slot,
            targetEquipSlot,
            amountLeft,
            1,
          );
        } else {
          // Desequipar: Mover del slot de equipo a la mochila
          const nextSlot = this.findNextAvailableSlot(this.playerInventory);
          if (nextSlot !== null) {
            let sourceItem = this.playerInventory[targetEquipSlot];
            this.playerInventory[nextSlot] = { ...sourceItem, amount: 1, slot: nextSlot };
            delete this.playerInventory[targetEquipSlot];

            this.postInventoryData("player", "player", targetEquipSlot, nextSlot, 0, 1);
          } else {
            this.inventoryError(targetEquipSlot); // Inventario lleno, parpadea en rojo
          }
        }
        return; // Cortamos para evitar el UseItem por defecto del servidor
      }

      // MANEJO ESPECÍFICO PARA ARMAS
      if (isWeapon) {
        const playerItemKey = Object.keys(this.playerInventory).find(
          (key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot,
        );

        if (playerItemKey) {
          // Cerrar inventario inmediatamente para mejor experiencia
          this.closeInventory();

          // Pequeño delay para asegurar que la UI se cierra antes de equipar
          setTimeout(() => {
            axios
              .post("https://DP-Inventory/UseItem", {
                inventory: "player",
                item: item,
              })
              .catch((error) => {
                console.error("Error usando arma:", error);
              });
          }, 50);
        }
        this.showContextMenu = false;
        return;
      }

      // Lógica normal para el resto de items (comida, drogas, etc)
      const playerItemKey = Object.keys(this.playerInventory).find(
        (key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot,
      );

      if (playerItemKey) {
        axios
          .post("https://DP-Inventory/UseItem", {
            inventory: "player",
            item: item,
          })
          .then(() => {
            // ANTI-RACE CONDITION: Si es una mochila custom, NO cerramos la UI.
            // Esperamos a que el servidor mande la orden de abrir el Stash.
            if (item.shouldClose && !item.name.includes("custom_bag")) {
              this.closeInventory();
            }
          })
          .catch((error) => {
            console.error("Error using the item: ", error);
          });
      }
      this.showContextMenu = false;
    },

    async giveItem(item, targetPlayerId) {
      if (!item || !item.name) return;

      // Lógica de cantidad: Si está vacío, null o es 0, dar todo. Si tiene número, dar ese número.
      let amountToGive =
        this.transferAmount && this.transferAmount > 0
          ? parseInt(this.transferAmount)
          : item.amount;

      // Validar si el jugador está intentando dar más de lo que tiene
      if (amountToGive > item.amount) {
        // Notificación al LUA
        axios.post("https://DP-Inventory/Notify", {
          message: `No tienes la suficiente cantidad para dar. Tienes ${item.amount}.`,
          type: "error",
        });
        this.showContextMenu = false;
        return;
      }

      try {
        // Pasamos el targetPlayerId al LUA
        const response = await axios.post("https://DP-Inventory/GiveItem", {
          item: item,
          amount: amountToGive,
          target: targetPlayerId,
          slot: item.slot,
          info: item.info,
        });

        // Si el LUA confirma que se ha dado correctamente
        if (response.data) {
          this.playerInventory[item.slot].amount -= amountToGive;
          if (this.playerInventory[item.slot].amount <= 0) {
            delete this.playerInventory[item.slot];
          }
          this.clearTransferAmount(); // Limpiamos el input de arriba
        }
      } catch (error) {
        console.error("Error al dar el item:", error);
      }

      this.showContextMenu = false;
    },

    splitAndPlaceItem(item, inventoryType) {
      const inventoryRef =
        inventoryType === "player" ? this.playerInventory : this.otherInventory;
      if (item && item.amount > 1) {
        const originalSlot = Object.keys(inventoryRef).find(
          (key) => inventoryRef[key] === item,
        );
        if (originalSlot !== undefined) {
          const newItem = { ...item, amount: Math.ceil(item.amount / 2) };
          const nextSlot = this.findNextAvailableSlot(inventoryRef);
          if (nextSlot !== null) {
            inventoryRef[nextSlot] = newItem;
            inventoryRef[originalSlot] = { ...item, amount: Math.floor(item.amount / 2) };
            this.postInventoryData(
              inventoryType,
              inventoryType,
              originalSlot,
              nextSlot,
              item.amount,
              newItem.amount,
            );
          }
        }
      }
      this.showContextMenu = false;
    },

    /* ------------------------------------------------------------------
           G. ARMAS Y ACCESORIOS (WEAPONS)
           ------------------------------------------------------------------ */

    // Devuelve la definición del slot (de wipAttachmentSlots) que corresponde a un attachmentType del config
    getSlotDefForAttachmentType(attachmentType) {
      return (
        this.wipAttachmentSlots.find((s) => s.types && s.types.includes(attachmentType)) ||
        null
      );
    },

    // Devuelve el attachment equipado que pertenece al slotType dado
    // a.slotType viene de GetAttachmentSlotType() en Lua → coincide con slotDef.type
    getAttachmentByType(slotType) {
      return this.selectedWeaponAttachments.find((a) => a.slotType === slotType) || null;
    },

    // Error visual en un slot del panel WIP
    wipError(slotType) {
      this.wipErrorSlot = slotType;
      setTimeout(() => {
        this.wipErrorSlot = null;
      }, 600);
    },

    // MouseDown en un slot WIP ocupado → inicia drag del accesorio (para sacarlo al inventario)
    handleWipMouseDown(event, slotType) {
      if (event.button !== 0) return;
      event.preventDefault();
      event.stopPropagation();

      const attachment = this.getAttachmentByType(slotType);
      if (!attachment) return; // slot vacío, no hay nada que arrastrar

      // Construimos un item sintético para que el sistema de drag lo entienda
      const syntheticItem = {
        name: attachment.attachment,
        label: attachment.label,
        image: attachment.attachment + ".png",
        amount: 1,
        slot: "__wip__" + slotType, // slot especial para identificarlo en endDrag
        inventory: "wip",
        type: "item",
        weight: 0,
        info: {},
      };

      const slotElement = event.target.closest(".wip-real-slot");
      if (!slotElement) return;

      const ghostElement = this.createGhostElement(slotElement);
      document.body.appendChild(ghostElement);
      ghostElement.style.left = `${event.clientX - ghostElement.offsetWidth / 2}px`;
      ghostElement.style.top = `${event.clientY - ghostElement.offsetHeight / 2}px`;

      this.ghostElement = ghostElement;
      this.currentlyDraggingItem = syntheticItem;
      this.currentlyDraggingSlot = "__wip__" + slotType;
      this.dragStartX = event.clientX;
      this.dragStartY = event.clientY;
      this.dragStartInventoryType = "wip";
      this.showContextMenu = false;
    },

    // Gestiona soltar un item del inventario sobre un slot del panel WIP (equipar accesorio)
    handleDropOnWipSlot(slotType) {
      const item = this.currentlyDraggingItem;
      if (!item) return;

      // Solo se puede equipar desde el inventario del jugador
      if (this.dragStartInventoryType !== "player") {
        this.wipError(slotType);
        return;
      }

      // El slot ya tiene algo equipado → no permitir solapamiento
      if (this.getAttachmentByType(slotType)) {
        this.wipError(slotType);
        return;
      }

      axios
        .post(
          "https://DP-Inventory/AddAttachment",
          JSON.stringify({
            AttachmentItem: item,
            WeaponData: this.selectedWeapon,
            SlotType: slotType,
          }),
        )
        .then((response) => {
          const data = response.data;
          if (!data || data.success === false) {
            this.wipError(slotType);
            return;
          }

          // Actualizar lista de accesorios
          this.selectedWeaponAttachments = data.Attachments || this.selectedWeaponAttachments;
          this.selectedWeapon = data.WeaponData || this.selectedWeapon;

          // Quitar el item del inventario visualmente
          const slotKey = Object.keys(this.playerInventory).find(
            (k) => this.playerInventory[k] === item,
          );
          if (slotKey) {
            this.playerInventory[slotKey].amount -= 1;
            if (this.playerInventory[slotKey].amount <= 0) {
              delete this.playerInventory[slotKey];
            }
          }
        })
        .catch(() => this.wipError(slotType));
    },

    copySerial() {
      // Funciona desde el menú contextual Y desde el botón del panel WIP
      const item = this.showWeaponAttachments ? this.selectedWeapon : this.contextMenuItem;
      if (!item || !item.info || !item.info.serie) return;

      const el = document.createElement("textarea");
      el.value = item.info.serie;
      document.body.appendChild(el);
      el.select();
      document.execCommand("copy");
      document.body.removeChild(el);

      // Cierra el menú contextual (opcional, pero queda más limpio)
      this.showContextMenu = false;

      // Enviar notificación a QBCore
      axios
        .post("https://DP-Inventory/Notify", {
          message: "Has copiado el Nº de Serie exitosamente.",
          type: "success",
        })
        .catch((e) => console.error("Error enviando notificación:", e));
    },

    openWeaponAttachments() {
      if (!this.contextMenuItem) return;

      if (!this.showWeaponAttachments) {
        this.playSound("open_inv");
        this.selectedWeapon = this.contextMenuItem;
        this.showWeaponAttachments = true;

        axios
          .post(
            "https://DP-Inventory/GetWeaponData",
            JSON.stringify({
              weapon: this.selectedWeapon.name,
              ItemData: this.selectedWeapon,
            }),
          )
          .then((response) => {
            const data = response.data;
            if (data.AttachmentData !== null && data.AttachmentData !== undefined) {
              if (data.AttachmentData.length > 0) {
                this.selectedWeaponAttachments = data.AttachmentData;
              }
            }
          })
          .catch((error) => console.error(error));
      } else {
        this.playSound("close_inv");
        this.showWeaponAttachments = false;
        this.selectedWeapon = null;
        this.selectedWeaponAttachments = [];
      }
    },

    removeAttachment(attachment) {
      if (!this.selectedWeapon) return;

      const index = this.selectedWeaponAttachments.indexOf(attachment);
      if (index !== -1) {
        this.selectedWeaponAttachments.splice(index, 1);
      }

      axios
        .post(
          "https://DP-Inventory/RemoveAttachment",
          JSON.stringify({ AttachmentData: attachment, WeaponData: this.selectedWeapon }),
        )
        .then((response) => {
          this.selectedWeapon = response.data.WeaponData;
          if (response.data.Attachments) {
            this.selectedWeaponAttachments = response.data.Attachments;
          }
          const nextSlot = this.findNextAvailableSlot(this.playerInventory);
          if (nextSlot !== null) {
            response.data.itemInfo.amount = 1;
            this.playerInventory[nextSlot] = response.data.itemInfo;
          }
        })
        .catch((error) => {
          console.error(error);
          this.selectedWeaponAttachments.splice(index, 0, attachment);
        });
    },

    /* ------------------------------------------------------------------
           H. UI VISUAL, HOTBAR Y NOTIFICACIONES
           ------------------------------------------------------------------ */

    toggleHotbar(data) {
      if (data.open) {
        this.hotbarItems = data.items;
        this.showHotbar = true;
      } else {
        this.showHotbar = false;
        this.hotbarItems = [];
        this.activeHotbarSlot = null;
      }
    },

    setActiveSlot(slot) {
      if (this.activeHotbarSlot === slot) {
        this.activeHotbarSlot = null;
      } else {
        this.activeHotbarSlot = slot;
      }
    },

    showItemNotification(itemData) {
      // Guardamos el tipo crudo (para la clase CSS) y el texto traducido
      let rawAction = itemData.type;
      let translated = "ELIMINADO";

      if (rawAction === "add") translated = "RECIBIDO";
      else if (rawAction === "use") translated = "USADO";
      else if (rawAction === "equip") translated = "EQUIPADO";
      else if (rawAction === "holster") translated = "GUARDADO";

      const newNotif = {
        id: Date.now() + Math.random(),
        text: itemData.item.label,
        image: "images/" + itemData.item.image,
        action: rawAction, // <--- Nueva variable para la clase CSS
        translatedAction: translated, // <--- Nueva variable para el texto
        amount: itemData.amount || 1,
      };

      // Añadimos al inicio (arriba)
      this.itemNotifications.unshift(newNotif);

      // Máximo 5 cajas
      if (this.itemNotifications.length > 5) {
        this.itemNotifications.pop();
      }

      // Duración de 3 segundos
      setTimeout(() => {
        this.itemNotifications = this.itemNotifications.filter((n) => n.id !== newNotif.id);
      }, 3000);
    },

    showRequiredItem(data) {
      if (data.toggle) {
        this.requiredItems = data.items;
        this.showRequiredItems = true;
      } else {
        setTimeout(() => {
          this.showRequiredItems = false;
          this.requiredItems = [];
        }, 100);
      }
    },

    inventoryError(slot) {
      const slotElement = document.getElementById(`slot-${slot}`);
      if (slotElement) slotElement.style.backgroundColor = "red";

      axios.post("https://DP-Inventory/PlayDropFail", {}).catch((error) => {
        console.error("Error playing drop fail:", error);
      });

      setTimeout(() => {
        if (slotElement) slotElement.style.backgroundColor = "";
      }, 1000);
    },

    generateTooltipContent(item) {
      if (!item) return "";

      // 1. Determinar el icono automáticamente según el tipo de ítem
      let icon = "mdi:package-variant-closed"; // Por defecto
      if (item.type === "weapon" || item.name.startsWith("weapon_")) {
        icon = "mdi:pistol";
      } else if (item.name.includes("id_card") || item.name.includes("license")) {
        icon = "mdi:card-account-details";
      } else if (item.name.includes("phone") || item.name.includes("radio")) {
        icon = "mdi:cellphone";
      } else if (item.name === "money" || item.name === "cash") {
        icon = "mdi:cash-multiple";
      }

      // Calculamos el peso a mostrar priorizando el dinámico de la mochila
      const displayWeight =
        item.info && item.info.weight !== undefined
          ? item.info.weight
          : item.weight !== undefined && item.weight !== null
            ? item.weight
            : 0;

      // 2. Construir la Cabecera
      let content = `
                <div class="modern-tooltip-container">
                    <div class="modern-tooltip-header">
                        <div class="modern-tooltip-icon">
                            <iconify-icon icon="${icon}"></iconify-icon>
                        </div>
                        <div class="modern-tooltip-title">
                            <h2>${item.label}</h2>
                            <div class="modern-tooltip-weight">
                                <iconify-icon icon="mdi:weight"></iconify-icon>
                                ${(displayWeight / 1000).toFixed(1)} KG
                            </div>
                        </div>
                    </div>
                    <div class="modern-tooltip-body">
            `;

      // INYECCIÓN DE DATOS DE LA SIM EN EL TOOLTIP
      if (item.name === "phone") {
        if (item.hasSim && item.sim_number) {
          content += `
            <div class="modern-meta-row" style="margin-top: 5px; margin-bottom: 5px; background: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255, 255, 255, 0.3); border-radius: 4px; padding: 4px 8px;">
              <span class="meta-label" style="color: #ffffff;">SIM</span>
              <span class="meta-value" style="color: #ffffff; font-weight: bold;">${item.sim_number}</span>
            </div>
          `;
        } else {
          content += `
            <div class="modern-meta-row" style="margin-top: 5px; margin-bottom: 5px; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.15); border-radius: 4px; padding: 4px 8px;">
              <span class="meta-label" style="color: rgba(255,255,255,0.6);">SIM</span>
              <span class="meta-value" style="color: rgba(255,255,255,0.6); font-weight: bold;">SIN TARJETA</span>
            </div>
          `;
        }
      }

      // 3. Construir la Metadata (Información extra como Quality, Serie, Nombre...)
      if (item.info && Object.keys(item.info).length > 0 && item.info.display !== false) {
        content += `<div class="modern-tooltip-meta-grid">`;
        const keyOrder = [
          "quality",
          "ammo",
          "serie",
          "type",
          "uses",
          "worth",
          "firstname",
          "lastname",
          "birthdate",
          "gender",
          "nationality",
          "citizenid",
          "blood",
          "job",
          "callsign",
          "url",
        ];

        const sortedEntries = [
          ...keyOrder.filter((k) => k in item.info).map((k) => [k, item.info[k]]),
          ...Object.entries(item.info).filter(([k]) => !keyOrder.includes(k)),
        ];

        for (const [key, value] of sortedEntries) {
          // ==========================================
          // EXCEPCIÓN DP-PHONE: OCULTAR METADATOS SENSIBLES
          // ==========================================
          const isSensitivePhoneData =
            item.name === "phone" &&
            (key === "account_id" || key === "device_id" || key === "pin");

          // Añadimos el !isSensitivePhoneData para que ignore esos datos
          if (key !== "description" && key !== "display" && !isSensitivePhoneData) {
            let valueStr = this.formatValue(key, value);
            if (key === "attachments") {
              valueStr = Object.keys(value).length > 0 ? "Equipados" : "Ninguno";
            }

            // Formateamos la calidad para que salga con %
            if (key === "quality") {
              valueStr = `${value}%`;
            }

            // Cajas separadas: Izquierda (Gris/Key) - Derecha (Blanco/Value)
            content += `
                            <div class="modern-meta-row">
                                <span class="meta-label">${this.formatKey(key)}</span>
                                <span class="meta-value">${valueStr}</span>
                            </div>
                        `;
          }
        }
        content += `</div>`;
      }

      // 4. Construir la Descripción (Si la hay)
      const description =
        item.info && item.info.description
          ? item.info.description.replace(/\n/g, "<br>")
          : item.description
            ? item.description.replace(/\n/g, "<br>")
            : "";

      if (description) {
        content += `
                    <div class="modern-tooltip-desc">
                        ${description}
                    </div>
                `;
      }

      content += `</div></div>`; // Cierre del body y container
      return content;
    },

    /* ------------------------------------------------------------------
           I. RED / COMUNICACIÓN CON EL SERVIDOR (AXIOS)
           ------------------------------------------------------------------ */

    postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
      let fromInventoryName =
        fromInventory === "other" ? this.otherInventoryName : fromInventory;
      let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

      axios
        .post("https://DP-Inventory/SetInventoryData", {
          fromInventory: fromInventoryName,
          toInventory: toInventoryName,
          fromSlot,
          toSlot,
          fromAmount,
          toAmount,
        })
        .then(() => {
          this.clearDragData();
        })
        .catch((error) => {
          console.error("Error posting inventory data:", error);
        });
    },
  },

  // ==========================================
  // 5. CICLO DE VIDA (LIFECYCLE HOOKS)
  // ==========================================
  mounted() {
    // Escuchar teclas para cerrar inventario
    window.addEventListener("keydown", (event) => {
      const key = event.key;

      // 1. Cerrar inventario con ESC o F2
      if (key === "Escape" || key === "F2") {
        if (this.simCombineState.isActive) {
          // Si estamos combinando, ESC solo cancela el modo
          this.cancelSimCombine();
        } else if (this.isInventoryOpen) {
          this.closeInventory();
        }
      }

      // 2. MODO CURSOR (TECLA J)
      if (key.toLowerCase() === "j" && this.isInventoryOpen) {
        // Evitamos que se active si estás escribiendo en el buscador de admin o en la cantidad
        const activeTag = document.activeElement ? document.activeElement.tagName : "";
        if (activeTag === "INPUT" || activeTag === "TEXTAREA") return;

        // Invertimos el estado
        this.cursorModeActive = !this.cursorModeActive;

        // Por seguridad, cerramos submenús que pudieran quedarse flotando
        if (this.showContextMenu) this.showContextMenu = false;
        if (this.showInspectModal) this.closeInspectModal();

        // Avisamos a Lua para que nos devuelva el control del personaje
        axios.post("https://DP-Inventory/toggleCursorMode", {}).catch((e) => console.error(e));
      }
    });

    // Escuchar mensajes (NUI) enviados desde LUA (FiveM)
    window.addEventListener("message", (event) => {
      switch (event.data.action) {
        case "open":
          this.openInventory(event.data);

          // MOTOR DE SONIDOS (INTELIGENCIA DE APERTURA)
          let invName = (event.data.otherInventoryName || "").toLowerCase();

          if (invName.includes("trunk") || invName.includes("maletero")) {
            this.currentSoundType = "trunk";
            this.playSound("open_trunk");
          } else if (
            invName.includes("stash") ||
            invName.includes("glovebox") ||
            invName.includes("guantera") ||
            invName.includes("alijo") ||
            invName.includes("drop")
          ) {
            this.currentSoundType = "stash";
            this.playSound("open_stash");
          } else {
            this.currentSoundType = "inv";
            this.playSound("open_inv");
          }
          break;

        case "close":
          this.closeInventory();
          this.playSound("close_" + this.currentSoundType);
          this.currentSoundType = "inv";
          break;

        case "update":
          this.updateInventory(event.data);
          break;

        case "toggleHotbar":
          this.toggleHotbar(event.data);
          break;

        case "setActiveSlot":
          this.setActiveSlot(event.data.slot);
          break;

        case "itemBox":
          this.showItemNotification(event.data);
          break;

        case "requiredItem":
          this.showRequiredItem(event.data);
          break;

        // Cierra solo el inventario secundario (Suelos, maleteros, etc) de forma silenciosa
        case "forceCloseOther":
          if (!this.isOtherInventoryEmpty) {
            // Le decimos al servidor que quite el "cerrojo" de ese maletero o stash
            axios
              .post("https://DP-Inventory/CloseSecondaryInventory", {
                name: this.otherInventoryName,
              })
              .catch((e) => console.error(e));

            // Limpiamos la UI para que desaparezca la caja y se centre el inventario
            this.otherInventory = {};
            this.otherInventoryName = "";
            this.isOtherInventoryEmpty = true;
          }
          break;

        case "checkVehicleState":
          this.isDriver = event.data.isDriver;
          this.inVehicle = event.data.inVehicle;
          this.vehicleSeat = event.data.seat;
          this.vehicleData = event.data.vehData || null;

          // AHORA COMPROBAMOS inVehicle PARA NO ECHAR A LOS PASAJEROS
          if (this.activeTab === "vehicle" && !this.inVehicle) {
            this.changeTab("inventory");
          }

          const hasWeaponNow = Object.values(this.playerInventory).some(
            (item) =>
              item &&
              item.type === "weapon" &&
              item.name &&
              item.name.toLowerCase().startsWith("weapon_"),
          );

          // Solo actúa si el inventario ya está completamente abierto
          if (this.activeTab === "weapons" && !hasWeaponNow && this.isInventoryReady) {
            this.changeTab("inventory");
          }

          if (
            !event.data.inVehicle &&
            !this.isOtherInventoryEmpty &&
            this.otherInventoryName.startsWith("glovebox")
          ) {
            axios
              .post("https://DP-Inventory/CloseSecondaryInventory", {
                name: this.otherInventoryName,
              })
              .catch((e) => console.error(e));
            this.otherInventory = {};
            this.otherInventoryName = "";
            this.isOtherInventoryEmpty = true;
          }
          break;

        case "setSoundPref":
          this.uiSoundsEnabled = event.data.status;
          break;

        case "updateVehicleRadio":
          this.hasVehicleRadio = event.data.status;
          break;

        default:
          console.warn(`Unexpected action: ${event.data.action}`);
      }
    });

    // ==========================================
    // DETECTOR INTELIGENTE DE INPUTS (Para escribir)
    // ==========================================
    document.addEventListener("focusin", (e) => {
      const isTextInput =
        e.target.tagName === "TEXTAREA" ||
        (e.target.tagName === "INPUT" &&
          e.target.type !== "checkbox" &&
          e.target.type !== "radio");

      if (isTextInput) {
        axios.post("https://DP-Inventory/SetTypingFocus", { isTyping: true }).catch(() => {});
      }
    });

    document.addEventListener("focusout", (e) => {
      const isTextInput =
        e.target.tagName === "TEXTAREA" ||
        (e.target.tagName === "INPUT" &&
          e.target.type !== "checkbox" &&
          e.target.type !== "radio");

      if (isTextInput) {
        axios.post("https://DP-Inventory/SetTypingFocus", { isTyping: false }).catch(() => {});
      }
    });
  },

  beforeUnmount() {
    // Limpieza de eventos
    window.removeEventListener("mousemove", () => {});
    window.removeEventListener("keydown", () => {});
    window.removeEventListener("message", () => {});
  },
});

// Inicialización de la aplicación Vue
InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");
