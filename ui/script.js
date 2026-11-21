const InventoryContainer = Vue.createApp({
  data() {
    return this.getInitialState();
  },

  computed: {
    playerWeight() {
      const weight = Object.values(this.playerInventory).reduce((total, item) => {
        if (item && item.amount !== undefined) {
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

    bagInventoryWeight() {
      const weight = Object.values(this.bagInventory).reduce((total, item) => {
        if (item && item.amount !== undefined) {
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

    bagWeightBarClass() {
      if (!this.bagInventoryMaxWeight) return "low";
      const weightPercentage = (this.bagInventoryWeight / this.bagInventoryMaxWeight) * 100;
      if (weightPercentage < 50) return "low";
      if (weightPercentage < 75) return "medium";
      return "high";
    },

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

    basePlayerSlots() {
      return this.baseSlots;
    },

    totalPlayerSlots() {
      return this.baseSlots + this.extraBackpackSlots;
    },

    extraSeats() {
      if (!this.vehicleData || this.vehicleData.seats <= 4) return [];
      let extras = [];

      for (let i = 3; i <= this.vehicleData.seats - 2; i++) {
        extras.push(i);
      }
      return extras;
    },

    shouldCenterInventory() {
      return false;
    },

    visibleOtherSlots() {
      if (!this.otherInventoryName || !this.otherInventoryName.startsWith("drop-")) {
        return this.otherInventorySlots;
      }

      const maxSlots = this.otherInventorySlots || 100;
      const minSlots = Math.min(20, maxSlots);

      let highestSlot = 0;
      let usedCount = 0;
      for (const key in this.otherInventory) {
        if (this.otherInventory[key]) {
          usedCount++;
          const s = Number(key);
          if (s > highestSlot) highestSlot = s;
        }
      }

      let slots = minSlots;
      if (usedCount >= minSlots || highestSlot >= minSlots) {
        const neededRows = Math.ceil(Math.max(highestSlot, usedCount) / 5) + 1;
        slots = Math.min(neededRows * 5, maxSlots);
      }
      return slots;
    },

    panelPlacementPlan() {
      const playerRows =
        Math.ceil((this.basePlayerSlots || 0) / 5) +
        Math.ceil((this.extraBackpackSlots || 0) / 5);
      const otherRows = !this.isOtherInventoryEmpty
        ? Math.ceil((this.visibleOtherSlots || 0) / 5)
        : 0;
      const bagRows = !this.isBagInventoryEmpty
        ? Math.ceil((this.bagInventorySlots || 0) / 5)
        : 0;

      const rowVh = 6.1;

      const basePlayerVh = 13.5 + (this.extraBackpackSlots > 0 ? 3.2 : 0) + playerRows * rowVh;
      const otherVh = !this.isOtherInventoryEmpty ? 11.5 + otherRows * rowVh : 0;
      const bagVh = !this.isBagInventoryEmpty ? 11.5 + bagRows * rowVh : 0;

      const hasOther = !this.isOtherInventoryEmpty;
      const hasBag = !this.isBagInventoryEmpty;

      if (!hasOther && !hasBag) {
        return {
          mode: "single",
          containerLayout: "bottom",
          otherPlacement: "none",
          bagPlacement: "none",
        };
      }

      if (hasOther && !hasBag) {
        if (basePlayerVh + otherVh + 1.5 <= 98.5) {
          return {
            mode: "two-vertical",
            containerLayout: "bottom",
            otherPlacement: "stacked",
            bagPlacement: "none",
          };
        }
        return {
          mode: "two-parallel",
          containerLayout: "left",
          otherPlacement: "left",
          bagPlacement: "none",
        };
      }

      if (!hasOther && hasBag) {
        if (basePlayerVh + bagVh + 1.5 <= 98.5) {
          return {
            mode: "two-vertical",
            containerLayout: "bottom",
            otherPlacement: "none",
            bagPlacement: "stacked",
          };
        }
        return {
          mode: "two-parallel",
          containerLayout: "left",
          otherPlacement: "none",
          bagPlacement: "left",
        };
      }

      if (basePlayerVh + otherVh + bagVh + 2.5 <= 98.5) {
        return {
          mode: "three-vertical",
          containerLayout: "bottom",
          otherPlacement: "stacked",
          bagPlacement: "stacked",
        };
      }

      if (otherVh + bagVh + 2.0 <= 97.5) {
        return {
          mode: "inv-right-pair-mid",
          containerLayout: "left",
          otherPlacement: "stacked",
          bagPlacement: "stacked",
        };
      }

      return {
        mode: "one-one-one",
        containerLayout: "left",
        otherPlacement: "left",
        bagPlacement: "left",
      };
    },

    effectiveInventoryPosition() {
      return this.panelPlacementPlan.containerLayout;
    },

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

      if (this.adminSearchQuery.trim() !== "") {
        const query = this.adminSearchQuery.toLowerCase().trim();

        list = list.filter((item) => {
          if (this.adminCurrentCategory === "players") {
            return (
              item.name.toLowerCase().includes(query) ||
              item.steam.toLowerCase().includes(query) ||
              item.id.toString().includes(query)
            );
          } else {
            return item.toLowerCase().includes(query);
          }
        });
      }
      return list;
    },
  },

  watch: {
    transferAmount(newVal) {
      if (newVal !== null && newVal < 0) this.transferAmount = 0;
    },

    extraBackpackSlots(newVal) {
      this.totalSlots = this.baseSlots + newVal;
    },
  },

  methods: {
    getInitialState() {
      return {
        maxWeight: 0,
        totalSlots: 0,
        baseSlots: 0,
        isInventoryOpen: false,
        isClosingInventory: false,
        isOtherInventoryEmpty: true,
        errorSlot: null,
        failedImages: {},
        playerInventory: {},
        inventoryLabel: "Inventory",
        totalWeight: 0,
        otherInventory: {},
        otherInventoryName: "",
        otherInventoryLabel: "Drop",
        otherInventoryMaxWeight: 1000000,
        otherInventorySlots: 100,
        isShopInventory: false,
        bagInventory: {},
        bagInventoryName: "",
        bagInventoryLabel: "",
        bagInventoryMaxWeight: 0,
        bagInventorySlots: 0,
        isBagInventoryEmpty: true,
        inventory: "",
        showContextMenu: false,
        contextMenuPosition: { top: "0px", left: "0px" },
        contextMenuItem: null,
        activeSubmenu: null,
        isMenuOnLeft: false,
        isMenuOnTop: false,
        nearbyPlayers: [],
        showInspectModal: false,
        inspectingItem: null,
        inspectRotation: 0,
        inspectZoom: 1,
        showHotbar: false,
        hotbarItems: [],
        activeHotbarSlot: null,
        itemNotifications: [],
        showRequiredItems: false,
        requiredItems: [],
        selectedWeapon: null,
        showWeaponAttachments: false,
        selectedWeaponAttachments: [],
        wipDragOverSlot: null,
        wipErrorSlot: null,
        simCombineState: {
          isActive: false,
          sourceSlot: null,
          sourceInventory: null,
          sourceItemName: null,
        },
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
        currentlyDraggingItem: null,
        currentlyDraggingSlot: null,
        dragStartX: 0,
        dragStartY: 0,
        ghostElement: null,
        dragStartInventoryType: "player",
        transferAmount: null,
        isCtrlDrag: false,
        activeTab: localStorage.getItem("dp_inv_activeTab") || "inventory",
        isDriver: false,
        isInventoryReady: false,
        rockstarPanelOpen: false,
        isAdmin: false,
        adminData: null,
        adminCurrentCategory: null,
        adminSearchQuery: "",
        showAdminSearch: false,
        cursorModeActive: false,
        moveWhileOpen: false,
        inVehicle: false,
        vehicleSeat: null,
        vehicleData: null,
        inventoryPosition: "left",
        isSettingsSelectOpen: false,
        selectDropdownStyle: {},
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
            key: "CTRL + CLICK IZQ.",
            title: "Transferencia Rápida",
            desc: "Teniendo un maletero, mochila, alijo o el suelo abierto, mantén CTRL y haz click izquierdo sobre un ítem para pasarlo instantáneamente al otro inventario.",
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

        uiSoundsEnabled: true,
        currentSoundType: "inv",
        playerSearchQuery: "",
        showPlayerSearch: false,
        otherSearchQuery: "",
        showOtherSearch: false,
        bagSearchQuery: "",
        showBagSearch: false,
        hasVehicleRadio: false,
        bagPreviewCache: {},
        bagPreviewPending: {},
        revealMaps: {},
        revealingSlots: {},
        revealSaveTimers: {},
      };
    },

    openInventory(data) {
      if (this.showHotbar) this.toggleHotbar(false);

      this.inventoryPosition = data.invPosition || "left";

      this.isInventoryOpen = true;
      this.isClosingInventory = false;
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
      this.bagInventory = {};
      this.bagInventoryName = "";
      this.bagInventoryLabel = "";
      this.bagInventoryMaxWeight = 0;
      this.bagInventorySlots = 0;
      this.isBagInventoryEmpty = true;
      this.isAdmin = data.isAdmin || false;
      this.moveWhileOpen = data.moveWhileOpen || false;

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
        if (this.otherInventoryName && !this.isShopInventory) {
          this.loadRevealMap(this.otherInventoryName);
        }
      }

      const savedTab = localStorage.getItem("dp_inv_activeTab") || "inventory";

      if (data.other) {
        this.activeTab = "inventory";
      } else if (savedTab === "weapons") {
        this.activeTab = this.hasFirearm ? "weapons" : "inventory";
      } else if (savedTab === "vehicle") {
        this.activeTab = this.isDriver ? "vehicle" : "inventory";
      } else {
        this.activeTab = savedTab;
      }

      if (this.activeTab === "admin" && this.isAdmin) {
        this.adminCurrentCategory = null;
        this.fetchAdminData();
      }

      this.$nextTick(() => {
        this.isInventoryReady = true;
      });
    },

    openBagInventory(data) {
      this.bagPreviewCache = {};
      this.bagPreviewPending = {};
      if (this.showHotbar) this.toggleHotbar(false);
      if (data.invPosition) this.inventoryPosition = data.invPosition;
      this.isInventoryOpen = true;
      this.isClosingInventory = false;
      if (data.maxweight !== undefined) this.maxWeight = data.maxweight;
      if (data.slots !== undefined) {
        this.totalSlots = data.slots;
        this.baseSlots = data.slots;
      }
      if (data.playerName) {
        this.inventoryLabel = data.playerName.toUpperCase();
      }
      if (data.isAdmin !== undefined) this.isAdmin = data.isAdmin;
      if (data.moveWhileOpen !== undefined) this.moveWhileOpen = data.moveWhileOpen;

      if (data.inventory) {
        this.playerInventory = {};
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

      this.bagInventory = {};
      if (data.bag) {
        if (data.bag.inventory) {
          if (Array.isArray(data.bag.inventory)) {
            data.bag.inventory.forEach((item) => {
              if (item && item.slot) this.bagInventory[item.slot] = item;
            });
          } else if (typeof data.bag.inventory === "object") {
            for (const key in data.bag.inventory) {
              const item = data.bag.inventory[key];
              if (item && item.slot) this.bagInventory[item.slot] = item;
            }
          }
        }
        this.bagInventoryName = data.bag.name || "";
        this.bagInventoryLabel = data.bag.label || "Mochila";
        this.bagInventoryMaxWeight = data.bag.maxweight || 0;
        this.bagInventorySlots = data.bag.slots || 0;
        this.isBagInventoryEmpty = false;
        if (this.bagInventoryName) {
          this.loadRevealMap(this.bagInventoryName);
        }
      }

      if (this.isOtherInventoryEmpty) {
        this.activeTab = "inventory";
      }

      this.$nextTick(() => {
        this.isInventoryReady = true;
      });
    },

    updateInventory(data) {
      this.playerInventory = {};

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

      if (this.simCombineState.isActive) {
        this.cancelSimCombine();
      }
    },

    async closeInventory() {
      if (this.isClosingInventory) return;
      this.isClosingInventory = true;

      this.bagPreviewCache = {};
      this.bagPreviewPending = {};
      if (document.activeElement) document.activeElement.blur();
      window.getSelection().removeAllRanges();

      this.clearDragData();
      let inventoryName = this.otherInventoryName;
      let bagInventoryName = this.bagInventoryName;
      this.isInventoryReady = false;

      // Finalizar reveals pendientes y guardar KVP ANTES de resetear estado
      if (this.revealingSlots) {
        Object.keys(this.revealingSlots).forEach((key) => {
          const parts = key.split(":");
          if (parts.length < 2) return;
          const slot = parts[parts.length - 1];
          const invId = parts.slice(0, -1).join(":");
          if (invId) this.markSlotRevealed(invId, slot);
        });
      }
      this.flushAllRevealMaps();

      let currentSoundState = this.uiSoundsEnabled;
      let currentMoveState = this.moveWhileOpen;
      let currentNotifications = this.itemNotifications;
      // IMPORTANTE: no perder el progreso de descubrimiento entre aperturas
      let currentRevealMaps = this.revealMaps || {};

      Object.assign(this, this.getInitialState());

      this.uiSoundsEnabled = currentSoundState;
      this.moveWhileOpen = currentMoveState;
      this.itemNotifications = currentNotifications;
      this.revealMaps = currentRevealMaps;
      this.isClosingInventory = true;

      try {
        await axios.post("https://DP-Inventory/CloseInventory", {
          name: inventoryName,
          bagName: bagInventoryName,
        });
      } catch (error) {
        console.error("Error closing inventory:", error);
      } finally {
        this.isClosingInventory = false;
      }
    },

    isImageMissing(img) {
      if (
        !img ||
        img === "empty.png" ||
        img === "images/empty.png" ||
        img === "images/undefined" ||
        img === "images/null" ||
        img.endsWith("/empty.png")
      ) {
        return true;
      }
      return !!this.failedImages[img];
    },

    handleImageError(img) {
      if (img) {
        this.failedImages[img] = true;
      }
    },

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

    toggleBagSearch() {
      if (this.showBagSearch) {
        this.showBagSearch = false;
        this.bagSearchQuery = "";
      } else {
        this.showBagSearch = true;
        this.$nextTick(() => {
          const input = document.getElementById("bag-search-input");
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
      if (!query || query.trim() === "") return true;

      if (!item) return false;

      const lowerQuery = query.toLowerCase().trim();
      const labelMatch = item.label && item.label.toLowerCase().includes(lowerQuery);
      const nameMatch = item.name && item.name.toLowerCase().includes(lowerQuery);

      return labelMatch || nameMatch;
    },

    getMaxQuality(itemName) {
      return itemName === "armor" ? 50 : 100;
    },

    isItemDamaged(item) {
      if (!item || !item.name) return false;
      if (item.name === "armor" || item.name === "heavyarmor") {
        const maxQ = this.getMaxQuality(item.name);
        const currentQ =
          item.info && item.info.quality !== undefined ? item.info.quality : maxQ;
        return currentQ < maxQ;
      }
      return false;
    },

    getDurabilityPercentage(item) {
      if (!item || !item.info || item.info.quality === undefined) return 100;
      const maxQ = this.getMaxQuality(item.name);
      let percentage = (item.info.quality / maxQ) * 100;
      return Math.min(Math.max(percentage, 0), 100);
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

        if (tabName === "admin") {
          this.adminCurrentCategory = null;
          this.fetchAdminData();
        }
      });
    },

    doAction(actionType) {
      if (actionType.startsWith("veh_") && !this.canAccessVehicleAction(actionType)) return;

      this.playSound("click");

      if (actionType === "rockstar") {
        this.animateContainerHeight(() => {
          this.rockstarPanelOpen = true;
        });
        return;
      }

      axios
        .post("https://DP-Inventory/PerformAction", { action: actionType })
        .catch((error) => console.error("Error realizando acción:", error));

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
        const rect = event.currentTarget.getBoundingClientRect();

        const spaceBelow = window.innerHeight - rect.bottom;
        const dropUp = spaceBelow < 150;

        const menuWidth = rect.width;

        this.selectDropdownStyle = {
          position: "fixed",
          left: rect.right - menuWidth + "px",
          width: menuWidth + "px",
          zIndex: 999999,
        };

        if (dropUp) {
          this.selectDropdownStyle.bottom = window.innerHeight - rect.top + 5 + "px";
          this.selectDropdownStyle.top = "auto";
        } else {
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
      axios.post("https://DP-Inventory/abrirRadioDesdeInventario", {}).catch(() => {});
    },

    isValidDriftVehicle(vehClass) {
      if (vehClass === undefined || vehClass === null) return false;

      const invalidClasses = [8, 13, 14, 15, 16, 21];

      return !invalidClasses.includes(vehClass);
    },

    saveSoundPreference() {
      axios
        .post("https://DP-Inventory/SaveSoundPref", { status: this.uiSoundsEnabled })
        .catch(() => {});

      if (this.uiSoundsEnabled) this.playSound("click");
    },

    playSound(soundName) {
      if (!this.uiSoundsEnabled) return;

      axios.post("https://DP-Inventory/PlayUISound", { sound: soundName }).catch(() => {});
    },

    canAccessVehicleAction(action) {
      if (!this.inVehicle || !this.vehicleData) return false;

      const classNoWindows = [8, 13, 14, 15, 16, 21];
      const isNoWindowClass = classNoWindows.includes(this.vehicleData.vehClass);

      if (action === "veh_drift" && isNoWindowClass) return false;
      if (action === "veh_anchor" && this.vehicleData.vehClass !== 14) return false;

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

      if (action === "veh_sit_di" && this.vehicleData.seats <= 1) return false;
      if (action === "veh_sit_dd" && this.vehicleData.seats <= 1) return false;
      if (action === "veh_sit_ti" && this.vehicleData.seats <= 2) return false;
      if (action === "veh_sit_td" && this.vehicleData.seats <= 3) return false;

      if (
        action.startsWith("veh_sit_") &&
        !["di", "dd", "ti", "td"].some((s) => action.includes(s))
      ) {
        const seatId = parseInt(action.split("_").pop());
        if (seatId > this.vehicleData.seats - 2) return false;
      }

      if (this.vehicleSeat === -1) return true;
      if (action.startsWith("veh_sit_")) return true;

      if (this.vehicleSeat === 0) {
        const allowed = ["veh_engine", "veh_radio", "veh_door_fr", "veh_win_fr"];
        return allowed.includes(action);
      }

      if (this.vehicleSeat === 1) {
        return ["veh_door_rl", "veh_win_rl"].includes(action);
      }

      if (this.vehicleSeat === 2) {
        return ["veh_door_rr", "veh_win_rr"].includes(action);
      }

      return false;
    },

    animateContainerHeight(actionCallback) {
      const container = document.querySelector(".tab-content-animator");
      if (!container) {
        actionCallback();
        return;
      }

      container.style.overflow = "hidden";

      const oldHeight = container.offsetHeight;
      container.style.height = oldHeight + "px";
      container.style.transition = "none";
      void container.offsetHeight;

      actionCallback();

      this.$nextTick(() => {
        container.style.height = "auto";
        const newHeight = container.offsetHeight;

        container.style.height = oldHeight + "px";
        void container.offsetHeight;

        container.style.transition = "height 0.5s cubic-bezier(0.4, 0, 0.2, 1)";
        container.style.height = newHeight + "px";

        if (this.heightAnimTimeout) clearTimeout(this.heightAnimTimeout);

        this.heightAnimTimeout = setTimeout(() => {
          if (container.style.height === newHeight + "px") {
            container.style.height = "auto";
            container.style.transition = "none";
          }
        }, 500);
      });
    },

    updateSearch(event) {
      const newValue = event.target.value;
      this.animateContainerHeight(() => {
        this.adminSearchQuery = newValue;
      });
    },

    toggleAdminSearch() {
      if (this.showAdminSearch) {
        this.animateContainerHeight(() => {
          this.showAdminSearch = false;
          this.adminSearchQuery = "";
        });
      } else {
        this.showAdminSearch = true;
        this.$nextTick(() => {
          const searchInput = document.getElementById("admin-search-input");
          if (searchInput) searchInput.focus();
        });
      }
    },

    fetchAdminData() {
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
        this.fetchAdminData().then(() => {
          this.animateContainerHeight(() => {
            this.adminCurrentCategory = category;
          });
        });
      } else {
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
      if (inventoryType === "bag") return this.bagInventory[slot] || null;
      return null;
    },

    getHotbarItemInSlot(slot) {
      return this.hotbarItems[slot - 1] || null;
    },

    getInventoryByType(inventoryType) {
      if (inventoryType === "player") return this.playerInventory;
      if (inventoryType === "bag") return this.bagInventory;
      return this.otherInventory;
    },

    findNextAvailableSlot(inventory) {
      for (let slot = 1; slot <= this.totalSlots; slot++) {
        if (!inventory[slot]) return slot;
      }
      return null;
    },

    formatKey(key) {
      const translations = {
        quality: "Calidad",
        ammo: "Munición",
        serie: "Nº de Serie",
        type: "Tipo",
        uses: "Usos",
        worth: "Valor",

        citizenid: "ID Ciudadano",
        firstname: "Nombre",
        lastname: "Apellido",
        birthdate: "Fecha de Nacimiento",
        gender: "Género",
        nationality: "Nacionalidad",
        url: "URL",

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
      if (key === "gender") {
        return value == 0 ? "Masculino" : value == 1 ? "Femenino" : value;
      }

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

    containerMouseDownAction(event) {
      if (
        this.simCombineState.isActive &&
        event.target.classList.contains("inventory-container")
      ) {
        this.cancelSimCombine();
      }

      if (event.target.tagName !== "INPUT") {
        if (document.activeElement && document.activeElement.tagName === "INPUT") {
          document.activeElement.blur();
        }
      }

      if (event.button === 0 && this.showContextMenu) {
        this.showContextMenu = false;
      }
    },

    handleMouseDown(event, slot, inventory) {
      if (event.button === 1) return;
      event.preventDefault();

      if (this.simCombineState.isActive) {
        if (this.isSimCompatible(slot, inventory)) {
          this.executeSimCombine(slot, inventory);
        } else {
          this.cancelSimCombine();
        }
        return;
      }

      const itemInSlot = this.getItemInSlot(slot, inventory);

      // Slot oculto: solo se puede desvelar con click izquierdo
      if (itemInSlot && this.isSlotFogged(slot, inventory)) {
        if (event.button === 0) {
          this.tryRevealSlot(slot, inventory);
        }
        return;
      }

      if (event.button === 0) {
        if (
          event.ctrlKey &&
          itemInSlot &&
          ((!this.isOtherInventoryEmpty && !this.otherInventoryName.startsWith("shop-")) ||
            !this.isBagInventoryEmpty)
        ) {
          this.moveItemBetweenInventories(itemInSlot, inventory);
        } else if (event.shiftKey && itemInSlot) {
          this.splitAndPlaceItem(itemInSlot, inventory);
        } else {
          this.startDrag(event, slot, inventory);
        }
      } else if (event.button === 2 && itemInSlot) {
        if (this.otherInventoryName.startsWith("shop-")) {
          this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
          return;
        }
        this.showContextMenuOptions(event, itemInSlot);
      } else if (event.button === 2 && itemInSlot) {
        if (this.otherInventoryName.startsWith("shop-")) {
          this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
          return;
        }
        if (event.ctrlKey && !this.isOtherInventoryEmpty) {
          this.isCtrlDrag = false;
          this.moveItemBetweenInventories(itemInSlot, inventory);
        } else {
          this.showContextMenuOptions(event, itemInSlot);
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
        this.activeSubmenu = null;
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

        let menuLeft = rect.right + padding;
        let menuTop = rect.top;

        const maxCollisionWidth = 320;
        const maxCollisionHeight = 220;

        if (item.slot < 101 && menuLeft + maxCollisionWidth > window.innerWidth) {
          this.isMenuOnLeft = true;
          menuLeft = rect.left - padding;
        } else {
          this.isMenuOnLeft = false;
        }

        if (menuTop + maxCollisionHeight > window.innerHeight || item.slot >= 101) {
          this.isMenuOnTop = true;
          menuTop = rect.bottom;
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

    handleInspectZoom(event) {
      const zoomSpeed = 0.15;

      if (event.deltaY < 0) {
        this.inspectZoom += zoomSpeed;
      } else {
        this.inspectZoom -= zoomSpeed;
      }

      const maxZoom = 2.5;
      const minZoom = 0.5;

      if (this.inspectZoom > maxZoom) {
        this.inspectZoom = maxZoom;
      } else if (this.inspectZoom < minZoom) {
        this.inspectZoom = minZoom;
      }
    },

    startDrag(event, slot, inventoryType) {
      event.preventDefault();
      const item = this.getItemInSlot(slot, inventoryType);
      if (!item) return;

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
      const bagSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList &&
          el.classList.contains("item-slot") &&
          el.closest(".bag-inventory-section"),
      );

      let wipSlotElement = elementsUnderCursor.find(
        (el) =>
          el.classList && el.classList.contains("wip-real-slot") && el.dataset.attachmentType,
      );
      if (!wipSlotElement) {
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
      } else if (bagSlotElement) {
        const targetSlot = Number(bagSlotElement.dataset.slot);
        if (
          targetSlot &&
          !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "bag")
        ) {
          this.handleItemDrop("bag", targetSlot);
        }
      } else if (
        this.isOtherInventoryEmpty &&
        this.isBagInventoryEmpty &&
        this.dragStartInventoryType === "player"
      ) {
        const isOverUI = elementsUnderCursor.some(
          (el) =>
            el.classList &&
            (el.classList.contains("inventory-section") ||
              el.classList.contains("tabs-sidebar") ||
              el.classList.contains("bag-inventory-section") ||
              el.classList.contains("equipment-sidebar") ||
              el.classList.contains("hotbar-container")),
        );

        if (!isOverUI) {
          this.handleDropOnInventoryContainer();
        }
      }

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

    handleDropOnPlayerSlot(targetSlot) {
      const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
      const targetSlotNumber = Number(targetSlot);

      if (targetSlotNumber === 101 || targetSlotNumber === 102 || targetSlotNumber === 103) {
        const validBackpacks = ["backpack_1", "backpack_2", "backpack_3", "backpack_4"];
        const validArmor = ["armor", "heavyarmor"];

        let isValid = false;
        if (targetSlotNumber === 101) {
          isValid = validBackpacks.includes(currentlyDraggingItem.name);
        } else if (targetSlotNumber === 102) {
          isValid = validArmor.includes(currentlyDraggingItem.name);
        } else if (targetSlotNumber === 103) {
          isValid = currentlyDraggingItem.name === "phone";
        }

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

            const draggingItemKey = Object.keys(this.playerInventory).find(
              (key) => this.playerInventory[key] === draggingItem,
            );
            if (draggingItemKey) {
              this.playerInventory[draggingItemKey].amount -= dropAmount;
              if (this.playerInventory[draggingItemKey].amount <= 0) {
                delete this.playerInventory[draggingItemKey];
              }
            }

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
          (targetSlotNumber === 101 || targetSlotNumber === 102 || targetSlotNumber === 103)
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
          } else if (targetInventoryType == "bag") {
            if (this.bagInventoryMaxWeight > 0) {
              const totalWeightAfterTransfer =
                this.bagInventoryWeight + sourceItem.weight * amountToTransfer;
              if (totalWeightAfterTransfer > this.bagInventoryMaxWeight)
                throw new Error("Insufficient weight capacity in bag inventory");
            }
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
          if (sourceItem.name === targetItem.name) {
            if (targetItem.unique) {
              this.inventoryError(this.currentlyDraggingSlot);
              return;
            }

            if (this.isItemDamaged(sourceItem) || this.isItemDamaged(targetItem)) {
              this.inventoryError(this.currentlyDraggingSlot);
              return;
            }

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
      const targetInventoryType =
        sourceInventoryType === "bag"
          ? "player"
          : !this.isBagInventoryEmpty &&
              sourceInventoryType === "player" &&
              this.isOtherInventoryEmpty
            ? "bag"
            : sourceInventoryType === "player"
              ? "other"
              : "player";

      const sourceInventory = this.getInventoryByType(sourceInventoryType);
      const targetInventory = this.getInventoryByType(targetInventoryType);
      const targetWeight =
        targetInventoryType === "bag"
          ? this.bagInventoryWeight
          : targetInventoryType === "other"
            ? this.otherInventoryWeight
            : this.playerWeight;

      const maxTargetWeight =
        targetInventoryType === "bag"
          ? this.bagInventoryMaxWeight || 1000000
          : targetInventoryType === "other"
            ? this.otherInventoryMaxWeight
            : this.maxWeight;

      const sourceItem = sourceInventory[item.slot];
      const amountToTransfer =
        this.transferAmount && this.transferAmount > 0
          ? this.transferAmount
          : sourceItem.amount;

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
        targetInventoryType,
        item.slot,
        targetSlot,
        sourceItem.amount,
        amountToTransfer,
      );
    },

    canCombineSim(item) {
      if (!item) return false;

      if (item.name === "phone" && !item.hasSim) return true;
      if (item.name === "sim_card") return true;
      return false;
    },

    canExtractSim(item) {
      if (!item) return false;

      return item.name === "phone" && item.hasSim === true;
    },

    startSimCombine(item, invType) {
      this.showContextMenu = false;
      if (!item) return;

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

      if (
        this.simCombineState.sourceSlot === slot &&
        this.simCombineState.sourceInventory === inventoryType
      ) {
        return false;
      }

      const item = this.getItemInSlot(slot, inventoryType);
      if (!item) return false;

      if (this.simCombineState.sourceItemName === "phone") {
        return item.name === "sim_card";
      }

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
        let amountToDrop =
          this.transferAmount && this.transferAmount > 0
            ? parseInt(this.transferAmount)
            : item.amount;

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
            this.playerInventory[playerItemKey].amount -= amountToDrop;
            if (this.playerInventory[playerItemKey].amount <= 0) {
              delete this.playerInventory[playerItemKey];
            }

            this.playSound("drop");

            this.otherInventory[1] = newItem;

            this.otherInventoryName = response.data.name || response.data;
            this.otherInventoryLabel = "Suelo";
            this.otherInventorySlots = response.data.slots || 100;
            this.otherInventoryMaxWeight = response.data.maxweight || 1200000;

            this.isOtherInventoryEmpty = false;
            this.clearTransferAmount();
          }
        } catch (error) {
          this.inventoryError(item.slot);
        }
      }

      this.showContextMenu = false;
    },

    async useItem(item) {
      if (!item || item.useable === false) return;

      const isArmor = item.name === "armor" || item.name === "heavyarmor";
      const isBackpack = item.name.startsWith("backpack_");
      const isWeapon = item.type === "weapon";

      if (isArmor || isBackpack) {
        const targetEquipSlot = isArmor ? 102 : 101;

        if (item.slot !== targetEquipSlot) {
          if (this.playerInventory[targetEquipSlot]) {
            this.inventoryError(item.slot);
            return;
          }

          let sourceItem = this.playerInventory[item.slot];
          sourceItem.amount -= 1;
          let amountLeft = sourceItem.amount;

          this.playerInventory[targetEquipSlot] = {
            ...item,
            amount: 1,
            slot: targetEquipSlot,
          };

          if (sourceItem.amount <= 0) {
            delete this.playerInventory[item.slot];
          }

          this.postInventoryData(
            "player",
            "player",
            item.slot,
            targetEquipSlot,
            amountLeft,
            1,
          );
        } else {
          const nextSlot = this.findNextAvailableSlot(this.playerInventory);
          if (nextSlot !== null) {
            let sourceItem = this.playerInventory[targetEquipSlot];
            this.playerInventory[nextSlot] = { ...sourceItem, amount: 1, slot: nextSlot };
            delete this.playerInventory[targetEquipSlot];

            this.postInventoryData("player", "player", targetEquipSlot, nextSlot, 0, 1);
          } else {
            this.inventoryError(targetEquipSlot);
          }
        }
        return;
      }

      if (isWeapon) {
        const playerItemKey = Object.keys(this.playerInventory).find(
          (key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot,
        );

        if (playerItemKey) {
          this.closeInventory();

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

      let amountToGive =
        this.transferAmount && this.transferAmount > 0
          ? parseInt(this.transferAmount)
          : item.amount;

      if (amountToGive > item.amount) {
        axios.post("https://DP-Inventory/Notify", {
          message: `No tienes la suficiente cantidad para dar. Tienes ${item.amount}.`,
          type: "error",
        });
        this.showContextMenu = false;
        return;
      }

      try {
        const response = await axios.post("https://DP-Inventory/GiveItem", {
          item: item,
          amount: amountToGive,
          target: targetPlayerId,
          slot: item.slot,
          info: item.info,
        });

        if (response.data) {
          this.playerInventory[item.slot].amount -= amountToGive;
          if (this.playerInventory[item.slot].amount <= 0) {
            delete this.playerInventory[item.slot];
          }
          this.clearTransferAmount();
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

    getSlotDefForAttachmentType(attachmentType) {
      return (
        this.wipAttachmentSlots.find((s) => s.types && s.types.includes(attachmentType)) ||
        null
      );
    },

    getAttachmentByType(slotType) {
      return this.selectedWeaponAttachments.find((a) => a.slotType === slotType) || null;
    },

    wipError(slotType) {
      this.wipErrorSlot = slotType;
      setTimeout(() => {
        this.wipErrorSlot = null;
      }, 600);
    },

    handleWipMouseDown(event, slotType) {
      if (event.button !== 0) return;
      event.preventDefault();
      event.stopPropagation();

      const attachment = this.getAttachmentByType(slotType);
      if (!attachment) return;

      const syntheticItem = {
        name: attachment.attachment,
        label: attachment.label,
        image: attachment.attachment + ".png",
        amount: 1,
        slot: "__wip__" + slotType,
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

    handleDropOnWipSlot(slotType) {
      const item = this.currentlyDraggingItem;
      if (!item) return;

      if (this.dragStartInventoryType !== "player") {
        this.wipError(slotType);
        return;
      }

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

          this.selectedWeaponAttachments = data.Attachments || this.selectedWeaponAttachments;
          this.selectedWeapon = data.WeaponData || this.selectedWeapon;

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
      const item = this.showWeaponAttachments ? this.selectedWeapon : this.contextMenuItem;
      if (!item || !item.info || !item.info.serie) return;

      const el = document.createElement("textarea");
      el.value = item.info.serie;
      document.body.appendChild(el);
      el.select();
      document.execCommand("copy");
      document.body.removeChild(el);

      this.showContextMenu = false;

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
        action: rawAction,
        translatedAction: translated,
        amount: itemData.amount || 1,
      };

      this.itemNotifications.unshift(newNotif);

      if (this.itemNotifications.length > 5) {
        this.itemNotifications.pop();
      }

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

    generateWeightTooltip(currentWeight, maxWeight) {
      const currentKg = (currentWeight / 1000).toFixed(1);
      const maxKg = (maxWeight / 1000).toFixed(1);
      const pct =
        maxWeight > 0 ? Math.min(Math.round((currentWeight / maxWeight) * 100), 100) : 0;

      return `
        <div class="modern-tooltip-container" style="min-width: 170px;">
          <div class="modern-tooltip-header" style="padding: 10px 12px; gap: 10px; border-bottom: none;">
            <div class="modern-tooltip-title">
              <h2 style="font-size: 1.1vh; letter-spacing: 0.6px;">CAPACIDAD</h2>
              <div class="modern-tooltip-weight" style="margin-top: 2px;">
                ${currentKg} / ${maxKg} KG
              </div>
            </div>
            <div style="margin-left: auto; font-size: 1.05vh; font-weight: 800; color: #ffffff; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.15); padding: 2px 6px; border-radius: 4px;">
              ${pct}%
            </div>
          </div>
        </div>
      `;
    },

    generateTooltipContent(item) {
      if (!item) return "";

      let icon = "mdi:package-variant-closed";
      if (item.type === "weapon" || item.name.startsWith("weapon_")) {
        icon = "mdi:pistol";
      } else if (item.name.includes("id_card") || item.name.includes("license")) {
        icon = "mdi:card-account-details";
      } else if (item.name.includes("phone") || item.name.includes("radio")) {
        icon = "mdi:cellphone";
      } else if (item.name === "money" || item.name === "cash") {
        icon = "mdi:cash-multiple";
      }

      const displayWeight =
        item.info && item.info.weight !== undefined
          ? item.info.weight
          : item.weight !== undefined && item.weight !== null
            ? item.weight
            : 0;

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
          const isSensitivePhoneData =
            item.name === "phone" &&
            (key === "account_id" || key === "device_id" || key === "pin");

          if (
            key !== "description" &&
            key !== "display" &&
            key !== "bagid" &&
            key !== "weight" &&
            !isSensitivePhoneData
          ) {
            let valueStr = this.formatValue(key, value);
            if (key === "attachments") {
              valueStr = Object.keys(value).length > 0 ? "Equipados" : "Ninguno";
            }

            if (key === "quality") {
              valueStr = `${value}%`;
            }

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

      // Preview de contenido de mochila (bagid)
      if (item.info && item.info.bagid) {
        const bagId = item.info.bagid;
        const cache = this.bagPreviewCache[bagId];
        content += `<div class="bag-preview-block" data-bag-preview="${bagId}">`;
        if (cache) {
          content += this.renderBagPreviewHtml(cache);
          // refrescar en background por si cambió el contenido
          this.scheduleBagPreview(bagId);
        } else {
          content += `
            <div class="bag-preview-header">
              <span>Contenido</span>
              <span class="bag-preview-count">…</span>
            </div>
            <div class="bag-preview-loading">
              <div class="bag-preview-spinner"></div>
              <span>Cargando...</span>
            </div>
          `;
          this.scheduleBagPreview(bagId);
        }
        content += `</div>`;
      }

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

      content += `</div></div>`;
      return content;
    },

    getInventoryId(invType) {
      if (invType === "other") return this.otherInventoryName || "";
      if (invType === "bag") return this.bagInventoryName || "";
      return "";
    },

    shouldFogInventory(invType) {
      if (invType === "player") return false;
      if (invType === "other") {
        if (this.isShopInventory) return false;
        const n = (this.otherInventoryName || "").toLowerCase();
        if (n.startsWith("shop-")) return false;
        return !!this.otherInventoryName;
      }
      if (invType === "bag") return !!this.bagInventoryName;
      return false;
    },

    isSlotRevealed(slot, invType) {
      if (!this.shouldFogInventory(invType)) return true;
      const invId = this.getInventoryId(invType);
      if (!invId) return true;
      const map = this.revealMaps[invId];
      if (!map) return false;
      return !!map[String(slot)];
    },

    isSlotFogged(slot, invType) {
      if (!this.shouldFogInventory(invType)) return false;
      const item = this.getItemInSlot(slot, invType);
      if (!item) return false;
      return !this.isSlotRevealed(slot, invType);
    },

    isSlotRevealing(slot, invType) {
      const invId = this.getInventoryId(invType);
      if (!invId) return false;
      return !!this.revealingSlots[invId + ":" + slot];
    },

    loadRevealMap(invId) {
      if (!invId) return Promise.resolve({});
      // Siempre pedir KVP y fusionar con memoria (memoria gana en slots ya revelados)
      return axios
        .post("https://DP-Inventory/GetRevealMap", { invId })
        .then((res) => {
          const fromKvp =
            res.data && typeof res.data === "object" && !Array.isArray(res.data)
              ? res.data
              : {};
          const current = this.revealMaps[invId] || {};
          const merged = { ...fromKvp, ...current };
          this.revealMaps = { ...this.revealMaps, [invId]: merged };
          return merged;
        })
        .catch(() => {
          if (!this.revealMaps[invId]) {
            this.revealMaps = { ...this.revealMaps, [invId]: {} };
          }
          return this.revealMaps[invId];
        });
    },

    saveRevealMap(invId) {
      if (!invId) return;
      if (!this.revealSaveTimers) this.revealSaveTimers = {};
      // Debounce: evita que saves concurrentes se pisen al clickar rápido
      if (this.revealSaveTimers[invId]) {
        clearTimeout(this.revealSaveTimers[invId]);
      }
      this.revealSaveTimers[invId] = setTimeout(() => {
        const map = this.revealMaps[invId] || {};
        axios.post("https://DP-Inventory/SaveRevealMap", { invId, map }).catch(() => {});
        delete this.revealSaveTimers[invId];
      }, 200);
    },

    flushRevealMap(invId) {
      if (!invId) return;
      if (this.revealSaveTimers && this.revealSaveTimers[invId]) {
        clearTimeout(this.revealSaveTimers[invId]);
        delete this.revealSaveTimers[invId];
      }
      const map = this.revealMaps[invId] || {};
      // fire-and-forget inmediato (cierre de inventario)
      axios.post("https://DP-Inventory/SaveRevealMap", { invId, map }).catch(() => {});
    },

    flushAllRevealMaps() {
      const ids = Object.keys(this.revealMaps || {});
      ids.forEach((id) => this.flushRevealMap(id));
    },

    markSlotRevealed(invId, slot) {
      if (!invId) return;
      const key = String(slot);
      const prev = this.revealMaps[invId] || {};
      if (prev[key]) {
        // ya estaba; igual debounced save por si KVP no se escribió
        this.saveRevealMap(invId);
        return;
      }
      this.revealMaps = {
        ...this.revealMaps,
        [invId]: { ...prev, [key]: true },
      };
      this.saveRevealMap(invId);
    },

    markSlotsRevealed(invId, slots) {
      if (!invId || !slots || !slots.length) return;
      const prev = this.revealMaps[invId] || {};
      const next = { ...prev };
      slots.forEach((s) => {
        next[String(s)] = true;
      });
      this.revealMaps = { ...this.revealMaps, [invId]: next };
      this.saveRevealMap(invId);
    },

    tryRevealSlot(slot, invType) {
      if (!this.isSlotFogged(slot, invType)) return;
      if (this.isSlotRevealing(slot, invType)) return;
      const invId = this.getInventoryId(invType);
      if (!invId) return;
      const key = invId + ":" + slot;
      this.revealingSlots = { ...this.revealingSlots, [key]: true };
      const delay = 280 + Math.floor(Math.random() * 220);
      setTimeout(() => {
        this.markSlotRevealed(invId, slot);
        const next = { ...this.revealingSlots };
        delete next[key];
        this.revealingSlots = next;
      }, delay);
    },

    isBagItem(item) {
      return !!(item && item.info && item.info.bagid);
    },

    scheduleBagPreview(bagId) {
      if (!bagId) return;
      if (this.bagPreviewPending[bagId]) return;
      this.bagPreviewPending[bagId] = true;

      // 1) KVP local por bagId (instantáneo, único por mochila)
      axios
        .post("https://DP-Inventory/GetBagPreviewKvp", { bagId })
        .then((res) => {
          if (res.data && res.data.items !== undefined) {
            this.bagPreviewCache[bagId] = res.data;
            this.patchBagPreviewTooltips(bagId, res.data);
          }
        })
        .catch(() => {})
        .finally(() => {
          // 2) Refresco real desde servidor (rápido)
          setTimeout(() => this.fetchBagPreview(bagId), 80);
        });
    },

    fetchBagPreview(bagId) {
      axios
        .post("https://DP-Inventory/GetBagPreview", { bagId })
        .then((response) => {
          const data = response.data;
          this.bagPreviewPending[bagId] = false;
          if (!data || data === false) {
            const empty = { items: [], used: 0, slots: 0, weight: 0, maxweight: 0 };
            this.bagPreviewCache[bagId] = empty;
            this.patchBagPreviewTooltips(bagId, empty);
            return;
          }
          // Solo este bagId
          this.bagPreviewCache[bagId] = data;
          this.patchBagPreviewTooltips(bagId, data);
          // Guardar KVP por bagId
          axios
            .post("https://DP-Inventory/SaveBagPreviewKvp", { bagId, data })
            .catch(() => {});
        })
        .catch(() => {
          this.bagPreviewPending[bagId] = false;
        });
    },

    renderBagPreviewHtml(data) {
      const used = data.used || 0;
      const slots = Math.max(data.slots || 0, used);
      const countLabel = slots > 0 ? used + "/" + slots : String(used);

      let html =
        '<div class="bag-preview-header"><span>Contenido</span><span class="bag-preview-count">' +
        countLabel +
        "</span></div>";

      const maxShow = Math.min(slots > 0 ? slots : Math.max(used, 4), 20);
      const bySlot = {};
      if (data.items && data.items.length) {
        data.items.forEach((it, idx) => {
          const s = it.slot || idx + 1;
          bySlot[s] = it;
        });
      }

      html += '<div class="bag-preview-grid">';
      for (let i = 1; i <= maxShow; i++) {
        // SOLO por slot real — sin fallback por índice (evita duplicados)
        const it = bySlot[i];
        if (it && it.name) {
          const amt = it.amount > 1 ? '<span class="amt">x' + it.amount + "</span>" : "";
          const img = it.image || it.name + ".png";
          html +=
            '<div class="bag-preview-slot"><img src="images/' +
            img +
            '" alt="" />' +
            amt +
            "</div>";
        } else {
          html += '<div class="bag-preview-slot bag-preview-slot--empty"></div>';
        }
      }
      html += "</div>";
      return html;
    },

    patchBagPreviewTooltips(bagId, data) {
      // Solo nodos de ESTE bagId (nunca mezclar mochilas)
      const nodes = document.querySelectorAll('[data-bag-preview="' + bagId + '"]');
      const html = this.renderBagPreviewHtml(data);
      nodes.forEach((el) => {
        el.innerHTML = html;
      });
    },

    postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
      let fromInventoryName =
        fromInventory === "other"
          ? this.otherInventoryName
          : fromInventory === "bag"
            ? this.bagInventoryName
            : fromInventory;
      let toInventoryName =
        toInventory === "other"
          ? this.otherInventoryName
          : toInventory === "bag"
            ? this.bagInventoryName
            : toInventory;

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
          if (fromInventory === "player" && toInventory !== "player") {
            const destId =
              toInventory === "other"
                ? this.otherInventoryName
                : toInventory === "bag"
                  ? this.bagInventoryName
                  : toInventoryName;
            if (destId) this.markSlotRevealed(destId, toSlot);
          }
          this.clearDragData();
        })
        .catch((error) => {
          console.error("Error posting inventory data:", error);
        });
    },
  },

  mounted() {
    window.addEventListener("keydown", (event) => {
      const key = event.key;

      if (key === "Escape" || key === "F2") {
        if (this.isClosingInventory) return;
        if (this.simCombineState.isActive) {
          this.cancelSimCombine();
        } else if (this.isInventoryOpen) {
          this.closeInventory();
        }
      }
    });

    window.addEventListener("message", (event) => {
      switch (event.data.action) {
        case "openBag":
          this.openBagInventory(event.data);
          this.currentSoundType = "stash";
          this.playSound("open_stash");
          break;

        case "open":
          this.openInventory(event.data);

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

        case "forceCloseOther":
          if (!this.isOtherInventoryEmpty) {
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

        case "checkVehicleState":
          this.isDriver = event.data.isDriver;
          this.inVehicle = event.data.inVehicle;
          this.vehicleSeat = event.data.seat;
          this.vehicleData = event.data.vehData || null;

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
    window.removeEventListener("mousemove", () => {});
    window.removeEventListener("keydown", () => {});
    window.removeEventListener("message", () => {});
  },
});

InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");
