/* ==========================================================================
   DP-INVENTORY: VUE.JS MAIN SCRIPT
   Organizado por módulos y funciones para fácil lectura
   ========================================================================== */

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
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        otherInventoryWeight() {
            const weight = Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
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
            const weightPercentage = (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
            if (weightPercentage < 50) return "low";
            if (weightPercentage < 75) return "medium";
            return "high";
        },
        shouldCenterInventory() {
            return this.isOtherInventoryEmpty;
        },
        // Escanea la mochila buscando un ítem que sea tipo arma
        hasFirearm() {
            return Object.values(this.playerInventory).some(item =>
                item && item.type === 'weapon' && item.name && item.name.toLowerCase().startsWith('weapon_')
            );
        }
    },

    // ==========================================
    // 3. VIGILANTES (WATCHERS)
    // ==========================================
    watch: {
        transferAmount(newVal) {
            // Permetem 0 o buit. Només evitem que posin números negatius.
            if (newVal !== null && newVal < 0) this.transferAmount = 0;
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
                // Notification box
                showNotification: false,
                notificationText: "",
                notificationImage: "",
                notificationType: "added",
                notificationAmount: 1,
                // Required items box
                showRequiredItems: false,
                requiredItems: [],
                // Attachments
                selectedWeapon: null,
                showWeaponAttachments: false,
                selectedWeaponAttachments: [],
                wipDragOverSlot: null,
                wipErrorSlot: null,
                // Un slot por cada tipo funcional de accesorio de qb-weapons
                // "types" = lista de attachmentType del config que pertenecen a este slot
                wipAttachmentSlots: [
                    { type: 'suppressor', label: 'Silenciador', icon: 'arcticons:adsilence', types: ['suppressor_attachment'] },
                    { type: 'barrel', label: 'Cañón', icon: 'mdi:pipe', types: ['barrel_attachment', 'comp_attachment'] },
                    { type: 'grip', label: 'Empuñadura', icon: 'mdi:hand-back-right-outline', types: ['grip_attachment'] },
                    { type: 'flashlight', label: 'Accesorio', icon: 'mdi:flashlight', types: ['flashlight_attachment'] },
                    { type: 'scope', label: 'Mira', icon: 'f7:scope', types: ['smallscope_attachment', 'medscope_attachment', 'largescope_attachment', 'holoscope_attachment', 'advscope_attachment', 'nvscope_attachment', 'thermalscope_attachment'] },
                    { type: 'clip', label: 'Cargador', icon: 'mdi:bullet', types: ['clip_attachment'] },
                    { type: 'drum', label: 'Cargador Drum', icon: 'mdi:cached', types: ['drum_attachment'] },
                    { type: 'camo', label: 'Camuflaje', icon: 'mdi:palette-outline', types: ['digicamo_attachment', 'brushcamo_attachment', 'woodcamo_attachment', 'skullcamo_attachment', 'sessantacamo_attachment', 'perseuscamo_attachment', 'leopardcamo_attachment', 'zebracamo_attachment', 'geocamo_attachment', 'boomcamo_attachment', 'patriotcamo_attachment', 'luxuryfinish_attachment'] },
                ],
                // Dragging and dropping
                currentlyDraggingItem: null,
                currentlyDraggingSlot: null,
                dragStartX: 0,
                dragStartY: 0,
                ghostElement: null,
                dragStartInventoryType: "player",
                transferAmount: null,
                // Pestañas
                activeTab: localStorage.getItem('dp_inv_activeTab') || 'inventory',
                isDriver: false,
                isInventoryReady: false,
            };
        },

        openInventory(data) {
            if (this.showHotbar) this.toggleHotbar(false);

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight;
            this.totalSlots = data.slots;
            this.isDriver = data.isDriver || false;
            this.inventoryLabel = data.playerName ? data.playerName.toUpperCase() : "INVENTARIO";

            this.playerInventory = {};
            this.otherInventory = {};

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
            const savedTab = localStorage.getItem('dp_inv_activeTab') || 'inventory';

            // Intentamos restaurar la tab guardada, con validaciones de seguridad
            if (savedTab === 'weapons') {
                // Solo restauramos 'weapons' si el jugador tiene armas en el inventario
                this.activeTab = this.hasFirearm ? 'weapons' : 'inventory';
            } else if (savedTab === 'vehicle') {
                // Solo restauramos 'vehicle' si el jugador es conductor
                this.activeTab = this.isDriver ? 'vehicle' : 'inventory';
            } else {
                // Para el resto de tabs (inventory, etc.) las restauramos directamente
                this.activeTab = savedTab;
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
        },

        async closeInventory() {
            if (document.activeElement) document.activeElement.blur();
            window.getSelection().removeAllRanges();

            this.clearDragData();
            let inventoryName = this.otherInventoryName;
            this.isInventoryReady = false;
            Object.assign(this, this.getInitialState());

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

        // SISTEMA INTELIGENTE DE DURABILIDAD
        getMaxQuality(itemName) {
            return itemName === 'armor' ? 50 : 100; // El armor básico maxea en 50
        },
        isItemDamaged(item) {
            if (!item || !item.name) return false;
            if (item.name === 'armor' || item.name === 'heavyarmor') {
                const maxQ = this.getMaxQuality(item.name);
                const currentQ = (item.info && item.info.quality !== undefined) ? item.info.quality : maxQ;
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
            if (percentage > 75) return 'high';
            if (percentage > 25) return 'medium';
            return 'low';
        },

        changeTab(tabName) {
            this.activeTab = tabName;
            // Guardamos la última pestaña en la memoria del navegador de FiveM
            localStorage.setItem('dp_inv_activeTab', tabName);
        },

        doAction(actionType) {
            // Enviamos la acción al client de FiveM
            axios.post("https://DP-Inventory/PerformAction", { action: actionType })
                .catch((error) => console.error("Error realizando acción:", error));

            // Solo cerramos el inventario si es Rockstar o Documentos
            if (actionType === 'rockstar' || actionType === 'documentos') {
                this.closeInventory();
            }
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
            return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
        },


        /* ------------------------------------------------------------------
           C. EVENTOS DE RATÓN (CLICS Y CONTEXT MENU)
           ------------------------------------------------------------------ */

        containerMouseDownAction(event) {
            // Quitar el focus del input si haces clic en cualquier otro lado
            if (event.target.tagName !== 'INPUT') {
                if (document.activeElement && document.activeElement.tagName === 'INPUT') {
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
                if (this.otherInventoryName.startsWith("shop-")) {
                    this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
                    return;
                }
                if (!this.isOtherInventoryEmpty) {
                    this.moveItemBetweenInventories(itemInSlot, inventory);
                } else {
                    this.showContextMenuOptions(event, itemInSlot);
                }
            }
        },

        showContextMenuOptions(event, item) {
            event.preventDefault();
            if (this.contextMenuItem && this.contextMenuItem.name === item.name && this.showContextMenu) {
                this.showContextMenu = false;
                this.contextMenuItem = null;
                this.activeSubmenu = null; // IMPORTANTE: limpiar el submenú al cerrar
            } else {
                if (item.inventory === "other") {

                    let isDamagedArmor = false;
                    if (item.name === 'armor' || item.name === 'heavyarmor') {
                        const itemQ = (item.info && item.info.quality !== undefined) ? item.info.quality : 100;
                        if (itemQ < 100) isDamagedArmor = true;
                    }

                    const matchingItemKey = Object.keys(this.playerInventory).find((key) => {
                        const tItem = this.playerInventory[key];
                        if (!tItem || tItem.name !== item.name) return false;
                        if (tItem.name === 'armor' || tItem.name === 'heavyarmor') {
                            const tQ = (tItem.info && tItem.info.quality !== undefined) ? tItem.info.quality : 100;
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
                        const itemKey = Object.keys(this.otherInventory).find((key) => this.otherInventory[key] === item);
                        if (itemKey) delete this.otherInventory[itemKey];
                    }
                }

                // 1. Buscamos el recuadro del slot que acabas de clicar
                const slotElement = event.target.closest('.item-slot');
                const rect = slotElement ? slotElement.getBoundingClientRect() : { top: event.clientY, left: event.clientX, right: event.clientX, bottom: event.clientY };

                const padding = 5;

                // Anclaje por defecto (Derecha y Arriba)
                let menuLeft = rect.right + padding;
                let menuTop = rect.top;

                // Usamos una estimación grande SOLO para saber si va a chocar con el borde de la pantalla
                const maxCollisionWidth = 320;  // Espacio necesario para Menú + Submenú de jugadores
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

                axios.post("https://DP-Inventory/GetNearbyPlayers", {}).then((response) => {
                    this.nearbyPlayers = response.data || [];
                }).catch(() => {
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
            this.inspectingItem = item;
            this.inspectRotation = 0;
            this.inspectZoom = 1;
            this.showInspectModal = true;
            this.showContextMenu = false;
        },

        closeInspectModal() {
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

            if (item && item.type === 'weapon') {
                axios.post("https://DP-Inventory/HolsterWeapon", {
                    item: item,
                    slot: slot,
                    inventory: inventoryType
                }).catch(error => {
                    console.error("Error al notificar desequipamiento:", error);
                });
            }

            const slotElement = event.target.closest(".item-slot");
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
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

            const wasWeapon = this.currentlyDraggingItem && this.currentlyDraggingItem.type === 'weapon';
            const elementsUnderCursor = document.elementsFromPoint(event.clientX, event.clientY);
            const playerSlotElement = elementsUnderCursor.find((el) => el.classList && el.classList.contains("item-slot") && el.closest(".player-inventory-section"));
            const otherSlotElement = elementsUnderCursor.find((el) => el.classList && el.classList.contains("item-slot") && el.closest(".other-inventory-section"));

            // Buscamos tanto el elemento directo como sus padres, por si el cursor cae sobre un hijo (img, span, etc.)
            let wipSlotElement = elementsUnderCursor.find((el) =>
                el.classList && el.classList.contains("wip-real-slot") && el.dataset.attachmentType
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
            } else if (playerSlotElement && this.dragStartInventoryType === 'wip') {
                // Arrastramos un accesorio DESDE el panel WIP HACIA el inventario → quitar
                const slotType = this.currentlyDraggingSlot.replace('__wip__', '');
                const attachment = this.getAttachmentByType(slotType);
                if (attachment) this.removeAttachment(attachment);
            } else if (playerSlotElement) {
                const targetSlot = Number(playerSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
            } else if (otherSlotElement) {
                const targetSlot = Number(otherSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
                    this.handleDropOnOtherSlot(targetSlot);
                }
            } else if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {

                // ¿Estamos sobre CUALQUIER elemento de la UI?
                const isOverUI = elementsUnderCursor.some((el) =>
                    el.classList && (
                        el.classList.contains("inventory-section") ||
                        el.classList.contains("tabs-sidebar") ||
                        el.classList.contains("equipment-sidebar") ||
                        el.classList.contains("hotbar-container")
                    )
                );

                // Solo permite tirar el objeto si el ratón está fuera de todas las cajas negras
                if (!isOverUI) {
                    this.handleDropOnInventoryContainer();
                }
            }

            // Si era un arma, aseguramos que sigue desequipada aunque el drag no terminó en un slot válido
            if (wasWeapon) {
                axios.post("https://DP-Inventory/HolsterWeapon", {
                    item: this.currentlyDraggingItem,
                    slot: this.currentlyDraggingSlot,
                    inventory: this.dragStartInventoryType
                }).catch(error => {
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
        },


        /* ------------------------------------------------------------------
           E. LÓGICA DE MOVIMIENTO DE ÍTEMS (HANDLERS)
           ------------------------------------------------------------------ */

        handleDropOnPlayerSlot(targetSlot) {
            const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
            const targetSlotNumber = Number(targetSlot);

            // 1. VALIDACIÓN ESTRICTA PARA SLOTS DE EQUIPAMIENTO
            if (targetSlotNumber === 101 || targetSlotNumber === 102) {
                const validBackpacks = ['backpack_1', 'backpack_2', 'backpack_3', 'backpack_4'];
                const validArmor = ['armor', 'heavyarmor'];

                const isValid = targetSlotNumber === 101
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

                if ((targetItem && targetItem.name !== currentlyDraggingItem.name) || (targetItem && targetItem.name === currentlyDraggingItem.name && currentlyDraggingItem.unique)) {
                    this.inventoryError(currentlyDraggingSlot);
                    return;
                }
                this.handlePurchase(targetSlot, currentlyDraggingSlot, currentlyDraggingItem, transferAmount);
            } else {
                this.handleItemDrop("player", targetSlot);
            }
        },

        handleDropOnOtherSlot(targetSlot) {
            this.handleItemDrop("other", targetSlot);
        },

        async handleDropOnInventoryContainer() {
            if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {

                let dropAmount = (this.transferAmount && this.transferAmount > 0) ? this.transferAmount : this.currentlyDraggingItem.amount;

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
                        const draggingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] === draggingItem);
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
                if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop !== -1) return;

                const targetSlotNumber = parseInt(targetSlot, 10);
                if (isNaN(targetSlotNumber)) throw new Error("Invalid target slot number");

                const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
                const targetInventory = this.getInventoryByType(targetInventoryType);

                const sourceItem = sourceInventory[this.currentlyDraggingSlot];
                if (!sourceItem) throw new Error("No item in the source slot to transfer");

                let amountToTransfer = (this.transferAmount && this.transferAmount > 0) ? this.transferAmount : sourceItem.amount;

                if (targetInventoryType === "player" && (targetSlotNumber === 101 || targetSlotNumber === 102)) {
                    amountToTransfer = 1;
                }

                if (sourceItem.amount < amountToTransfer) throw new Error("Insufficient amount of item in source inventory");

                if (targetInventoryType !== this.dragStartInventoryType) {
                    if (targetInventoryType == "other") {
                        const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
                        if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) throw new Error("Insufficient weight capacity in target inventory");
                    } else if (targetInventoryType == "player") {
                        const totalWeightAfterTransfer = this.playerWeight + sourceItem.weight * amountToTransfer;
                        if (totalWeightAfterTransfer > this.maxWeight) throw new Error("Insufficient weight capacity in player inventory");
                    }
                }

                const targetItem = targetInventory[targetSlotNumber];

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

                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);

                    } else {
                        // 2. ÍTEMS DISTINTOS: INTERCAMBIAR DE CASILLA (Swap Seguro Clonando)
                        const clonedSource = { ...sourceItem, slot: targetSlotNumber };
                        const clonedTarget = { ...targetItem, slot: this.currentlyDraggingSlot };

                        targetInventory[targetSlotNumber] = clonedSource;
                        sourceInventory[this.currentlyDraggingSlot] = clonedTarget;

                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, clonedSource.amount, clonedTarget.amount);
                    }
                } else {
                    // SI NO HAY ITEM EN EL DESTINO (Casilla vacía)
                    sourceItem.amount -= amountToTransfer;
                    if (sourceItem.amount <= 0) delete sourceInventory[this.currentlyDraggingSlot];

                    targetInventory[targetSlotNumber] = { ...sourceItem, amount: amountToTransfer, slot: targetSlotNumber };
                    this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
                }
            } catch (error) {
                console.error(error.message);
                this.inventoryError(this.currentlyDraggingSlot);
            } finally {
                this.clearDragData();
            }
        },

        moveItemBetweenInventories(item, sourceInventoryType) {
            const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
            const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
            const targetWeight = sourceInventoryType === "player" ? this.otherInventoryWeight : this.playerWeight;
            const maxTargetWeight = sourceInventoryType === "player" ? this.otherInventoryMaxWeight : this.maxWeight;

            const sourceItem = sourceInventory[item.slot];
            const amountToTransfer = (this.transferAmount && this.transferAmount > 0) ? this.transferAmount : sourceItem.amount;

            let targetSlot = null;

            if (!sourceItem || sourceItem.amount < amountToTransfer) {
                this.inventoryError(item.slot);
                return;
            }

            if (targetWeight + sourceItem.weight * amountToTransfer > maxTargetWeight) {
                this.inventoryError(item.slot);
                return;
            }

            // ANTI-REPARACIÓN (Trata a los chalecos dañados como ÍTEMS ÚNICOS)
            let isDamagedArmor = false;
            if (item.name === 'armor' || item.name === 'heavyarmor') {
                const itemQ = (item.info && item.info.quality !== undefined) ? item.info.quality : 100;
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
                    if (tItem.name === 'armor' || tItem.name === 'heavyarmor') {
                        const tQ = (tItem.info && tItem.info.quality !== undefined) ? tItem.info.quality : 100;
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

            this.postInventoryData(sourceInventoryType, sourceInventoryType === "player" ? "other" : "player", item.slot, targetSlot, sourceItem.amount, amountToTransfer);
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
                    const amountToTransfer = transferAmount !== null ? transferAmount : sourceItem.amount;

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
                                if (tItem.name === 'armor' || tItem.name === 'heavyarmor') {
                                    const tQ = (tItem.info && tItem.info.quality !== undefined) ? tItem.info.quality : 100;
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
                                let freeSlot = Array.from({ length: this.totalSlots }, (_, i) => i + 1).find((i) => !(i in targetInventory));
                                targetInventory[freeSlot] = { ...sourceItem, amount: amountToTransfer };
                            } else {
                                this.inventoryError(sourceSlot);
                                return;
                            }
                        }
                    } else {
                        // Si arrastras el item de la tienda directamente sobre tu chaleco dañado
                        if (targetItem.name === 'armor' || targetItem.name === 'heavyarmor') {
                            const targetQ = (targetItem.info && targetItem.info.quality !== undefined) ? targetItem.info.quality : 100;
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

            const playerItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot);

            if (playerItemKey) {
                // Lógica de cantidad: Si el input está vacío o en 0, tira todo. Si tiene número, usa ese número.
                let amountToDrop = (this.transferAmount && this.transferAmount > 0) ? parseInt(this.transferAmount) : item.amount;

                // Validar que no intente tirar más de lo que tiene
                if (amountToDrop > item.amount) {
                    axios.post("https://DP-Inventory/Notify", {
                        message: `No tienes la suficiente cantidad para tirar. Tienes ${item.amount}.`,
                        type: "error"
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
            const isArmor = (item.name === 'armor' || item.name === 'heavyarmor');
            const isBackpack = item.name.startsWith('backpack_');
            const isWeapon = item.type === 'weapon';

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
                    this.playerInventory[targetEquipSlot] = { ...item, amount: 1, slot: targetEquipSlot };

                    if (sourceItem.amount <= 0) {
                        delete this.playerInventory[item.slot];
                    }

                    // Le pasamos la info exacta al servidor
                    this.postInventoryData("player", "player", item.slot, targetEquipSlot, amountLeft, 1);

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
                const playerItemKey = Object.keys(this.playerInventory).find((key) =>
                    this.playerInventory[key] && this.playerInventory[key].slot === item.slot
                );

                if (playerItemKey) {
                    // Cerrar inventario inmediatamente para mejor experiencia
                    this.closeInventory();

                    // Pequeño delay para asegurar que la UI se cierra antes de equipar
                    setTimeout(() => {
                        axios.post("https://DP-Inventory/UseItem", {
                            inventory: "player",
                            item: item,
                        }).catch(error => {
                            console.error("Error usando arma:", error);
                        });
                    }, 50);
                }
                this.showContextMenu = false;
                return;
            }

            // Lógica normal para el resto de items (comida, drogas, etc)
            const playerItemKey = Object.keys(this.playerInventory).find((key) =>
                this.playerInventory[key] && this.playerInventory[key].slot === item.slot
            );

            if (playerItemKey) {
                axios.post("https://DP-Inventory/UseItem", {
                    inventory: "player",
                    item: item,
                }).then(() => {
                    if (item.shouldClose) this.closeInventory();
                }).catch((error) => {
                    console.error("Error using the item: ", error);
                });
            }
            this.showContextMenu = false;
        },

        async giveItem(item, targetPlayerId) {
            if (!item || !item.name) return;

            // Lógica de cantidad: Si está vacío, null o es 0, dar todo. Si tiene número, dar ese número.
            let amountToGive = (this.transferAmount && this.transferAmount > 0) ? parseInt(this.transferAmount) : item.amount;

            // Validar si el jugador está intentando dar más de lo que tiene
            if (amountToGive > item.amount) {
                // Notificación al LUA
                axios.post("https://DP-Inventory/Notify", {
                    message: `No tienes la suficiente cantidad para dar. Tienes ${item.amount}.`,
                    type: "error"
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
            const inventoryRef = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            if (item && item.amount > 1) {
                const originalSlot = Object.keys(inventoryRef).find((key) => inventoryRef[key] === item);
                if (originalSlot !== undefined) {
                    const newItem = { ...item, amount: Math.ceil(item.amount / 2) };
                    const nextSlot = this.findNextAvailableSlot(inventoryRef);
                    if (nextSlot !== null) {
                        inventoryRef[nextSlot] = newItem;
                        inventoryRef[originalSlot] = { ...item, amount: Math.floor(item.amount / 2) };
                        this.postInventoryData(inventoryType, inventoryType, originalSlot, nextSlot, item.amount, newItem.amount);
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
            return this.wipAttachmentSlots.find(s => s.types && s.types.includes(attachmentType)) || null;
        },

        // Devuelve el attachment equipado que pertenece al slotType dado
        // a.slotType viene de GetAttachmentSlotType() en Lua → coincide con slotDef.type
        getAttachmentByType(slotType) {
            return this.selectedWeaponAttachments.find(a => a.slotType === slotType) || null;
        },

        // Error visual en un slot del panel WIP
        wipError(slotType) {
            this.wipErrorSlot = slotType;
            setTimeout(() => { this.wipErrorSlot = null; }, 600);
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
                image: attachment.attachment + '.png',
                amount: 1,
                slot: '__wip__' + slotType,  // slot especial para identificarlo en endDrag
                inventory: 'wip',
                type: 'item',
                weight: 0,
                info: {},
            };

            const slotElement = event.target.closest('.wip-real-slot');
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);
            ghostElement.style.left = `${event.clientX - ghostElement.offsetWidth / 2}px`;
            ghostElement.style.top = `${event.clientY - ghostElement.offsetHeight / 2}px`;

            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = syntheticItem;
            this.currentlyDraggingSlot = '__wip__' + slotType;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = 'wip';
            this.showContextMenu = false;
        },

        // Gestiona soltar un item del inventario sobre un slot del panel WIP (equipar accesorio)
        handleDropOnWipSlot(slotType) {
            const item = this.currentlyDraggingItem;
            if (!item) return;

            // Solo se puede equipar desde el inventario del jugador
            if (this.dragStartInventoryType !== 'player') {
                this.wipError(slotType);
                return;
            }

            // El slot ya tiene algo equipado → no permitir solapamiento
            if (this.getAttachmentByType(slotType)) {
                this.wipError(slotType);
                return;
            }

            axios.post('https://DP-Inventory/AddAttachment', JSON.stringify({
                AttachmentItem: item,
                WeaponData: this.selectedWeapon,
                SlotType: slotType,
            }))
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
                        k => this.playerInventory[k] === item
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
        },

        openWeaponAttachments() {
            if (!this.contextMenuItem) return;

            if (!this.showWeaponAttachments) {
                this.selectedWeapon = this.contextMenuItem;
                this.showWeaponAttachments = true;

                axios.post("https://DP-Inventory/GetWeaponData", JSON.stringify({ weapon: this.selectedWeapon.name, ItemData: this.selectedWeapon }))
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

            axios.post("https://DP-Inventory/RemoveAttachment", JSON.stringify({ AttachmentData: attachment, WeaponData: this.selectedWeapon }))
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
            this.notificationText = itemData.item.label;
            this.notificationImage = "images/" + itemData.item.image;
            this.notificationType = itemData.type === "add" ? "Received" : itemData.type === "use" ? "Used" : "Removed";
            this.notificationAmount = itemData.amount || 1;
            this.showNotification = true;
            setTimeout(() => {
                this.showNotification = false;
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

            let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;
            const description = item.info && item.info.description ? item.info.description.replace(/\n/g, "<br>") : item.description ? item.description.replace(/\n/g, "<br>") : "No description available.";

            if (item.info && Object.keys(item.info).length > 0 && item.info.display !== false) {
                for (const [key, value] of Object.entries(item.info)) {
                    if (key !== "description" && key !== "display") {
                        let valueStr = value;
                        if (key === "attachments") {
                            valueStr = Object.keys(value).length > 0 ? "true" : "false";
                        }
                        content += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(key)}:</span> ${valueStr}</div>`;
                    }
                }
            }
            content += `<div class="tooltip-description">${description}</div>`;
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight !== undefined && item.weight !== null ? (item.weight / 1000).toFixed(1) : "N/A"}kg</div>`;
            content += `</div>`;
            return content;
        },


        /* ------------------------------------------------------------------
           I. RED / COMUNICACIÓN CON EL SERVIDOR (AXIOS)
           ------------------------------------------------------------------ */

        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            let fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios.post("https://DP-Inventory/SetInventoryData", {
                fromInventory: fromInventoryName,
                toInventory: toInventoryName,
                fromSlot,
                toSlot,
                fromAmount,
                toAmount,
            }).then(() => {
                this.clearDragData();
            }).catch((error) => {
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
            if (key === "Escape" || key === "Tab") {
                if (this.isInventoryOpen) {
                    this.closeInventory();
                }
            }
        });

        // Escuchar mensajes (NUI) enviados desde LUA (FiveM)
        window.addEventListener("message", (event) => {
            switch (event.data.action) {
                case "open":
                    this.openInventory(event.data);
                    break;
                case "close":
                    this.closeInventory();
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
                case "checkVehicleState":
                    this.isDriver = event.data.isDriver;

                    if (this.activeTab === 'vehicle' && !this.isDriver) {
                        this.changeTab('inventory');
                    }

                    const hasWeaponNow = Object.values(this.playerInventory).some(item =>
                        item && item.type === 'weapon' && item.name && item.name.toLowerCase().startsWith('weapon_')
                    );

                    // Solo actúa si el inventario ya está completamente abierto
                    if (this.activeTab === 'weapons' && !hasWeaponNow && this.isInventoryReady) {
                        this.changeTab('inventory');
                    }

                    if (!event.data.inVehicle && !this.isOtherInventoryEmpty && this.otherInventoryName.startsWith('glovebox')) {
                        axios.post("https://DP-Inventory/CloseSecondaryInventory", { name: this.otherInventoryName })
                            .catch(e => console.error(e));
                        this.otherInventory = {};
                        this.otherInventoryName = "";
                        this.isOtherInventoryEmpty = true;
                    }
                    break;

                default:
                    console.warn(`Unexpected action: ${event.data.action}`);
            }
        });
    },

    beforeUnmount() {
        // Limpieza de eventos
        window.removeEventListener("mousemove", () => { });
        window.removeEventListener("keydown", () => { });
        window.removeEventListener("message", () => { });
    },
});

// Inicialización de la aplicación Vue
InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");