require "util"

-- Name of the row headers we put in the UI
local filterUiElementName = "FilterFillRow"
local requestUiElementName = "RequestRow"

-- Button click dispatching
local Buttons = {}
local dispatch = {}

-- How many logistic request slots a requester chest has. Replace
-- with a function once the API can tell us this
-- TODO: How to get the number of request slots?
local REQUEST_SLOTS = 10

-- Initializes the world
function startup()
    script.on_event(defines.events.on_tick, checkOpened)
    initButtons()
end

-- Listener for events clicked
function handleButton(event)
    local handler = dispatch[event.element.name]
    if handler then
        handler(game.players[event.player_index])
    end
end

-- Initializes event handlers and button names
function initButtons()
    function register(category, name, func)
        local buttonName = category .. '_' .. name
        Buttons[category][name] = buttonName
        dispatch[buttonName] = func
    end
    -- Filtering
    Buttons.Filter = {}
    register('Filter', 'All', filter_fillAll)
    register('Filter', 'Right', filter_fillRight)
    register('Filter', 'Down', filter_fillDown)
    register('Filter', 'Clear', filter_clearAll)
    register('Filter', 'Set', filter_setAll)
    -- Logistic Requests
    Buttons.Requests = {}
    register('Requests', 'x2', requests_x2)
    register('Requests', 'x5', requests_x5)
    register('Requests', 'x10', requests_x10)
    register('Requests', 'Fill', requests_fill)
    register('Requests', 'Blueprint', requests_blueprint)

    script.on_event(defines.events.on_gui_click, handleButton)
end

-- TODO: Add Car, Tank when those get API support (or we get API support for detecting this programatically)
function canFilter(obj)
    return obj.type == "cargo-wagon"
end

-- TODO How to make this better?
function canRequest(obj)
    return obj.name == "logistic-chest-requester"
end

-- See if an applicable container is opened and show/hide the UI accordingly.
-- Some delay is imperceptible here, so only check this once every few ticks
-- to avoid performance impact

-- Initialize this to a nonzero number so every mod in the universe doesn't
-- do its expensive work on the same tick
local tickCounter = 6;
function checkOpened()
    tickCounter = tickCounter + 1
    -- 1/5 second delay doesn't seem to be noticeable
    if tickCounter == 12 then
        tickCounter = 0
    else
        return
    end

    for i, player in ipairs(game.players) do
        showOrHideFilterUI(player, player.opened ~= nil and canFilter(player.opened))
        showOrHideRequestUI(player, player.opened ~= nil and canRequest(player.opened))
    end
end

-- Gets the name of the item at the given position, or nil if there
-- is no item at that position
function getItemAtPosition(player, n)
    local inv = player.opened.get_inventory(1)
    local isEmpty = not inv[n].valid_for_read
    if isEmpty then
        return nil
    else
        return inv[n].name
    end
end

-- Returns either the item at a position, or the filter
-- at the position if there isn't an item there
function getItemOrFilterAtPosition(player, n)
    local filter = player.opened.get_filter(n)
    if filter ~= nil then
        return filter
    else
        return getItemAtPosition(player, n)
    end
end

-- Set the filter of the opened UI to the given value, or clear
-- it if the given value is nil
function setFilter(player, value, pos)
    if value then
        player.opened.set_filter(value, pos)
    else
        player.opened.clear_filter(pos)
    end
end

-- Filtering: Clear all filters in the opened container
function filter_clearAll(player)
    local op = player.opened;
    local size = #player.opened.get_inventory(1)
    for i = 1, size do
        op.clear_filter(i)
    end
end

-- Filtering: Set the filters of the opened container to the
-- contents of each cell
function filter_setAll(player)
    local op = player.opened;
    local size = #player.opened.get_inventory(1)
    for i = 1, size do
        local desired = getItemAtPosition(player, i)
        setFilter(player, desired, i)
    end
end

-- Filtering: Filter all cells of the opened container with the
-- contents of the player's cursor stack, or the first item in the container,
-- or the first filter in the container
function filter_fillAll(player)
    -- Get the contents of the player's cursor stack, or the first cell
    local desired = (player.cursor_stack.valid_for_read and player.cursor_stack.name) or getItemOrFilterAtPosition(player, 1)
    local size = #player.opened.get_inventory(1)
    local op = player.opened;
    for i = 1, size do
        local current = getItemAtPosition(player, i)
        if current and desired and current ~= desired then
            player.print({"", 'Skipped setting a filter on the cell occupied by ', {'item-name.' .. current}})
        else
            if desired then
                op.set_filter(desired, i)
            else
                op.clear_filter(i)
            end
        end
    end
end

-- Filtering: Copies the filter settings of each cell to the cell(s) to the right of it
function filter_fillRight(player)
    local columns = 10
    local size = #player.opened.get_inventory(1)
    local rows = math.ceil(size / columns)
    for r = 1, rows do
        local desired = getItemOrFilterAtPosition(player, 1 + (r - 1) * columns)
        for c = 1, columns do
            local i = c + (r - 1) * columns
            if i <= size then
                desired = getItemAtPosition(player, i) or desired
                setFilter(player, desired, i)
            end
        end
    end
end

-- Filtering: Copies the filter settings of each cell to the cell(s) below it
function filter_fillDown(player)
    local columns = 10
    local size = #player.opened.get_inventory(1)
    local rows = math.ceil(size / columns)
    for c = 1, columns do
        local desired = getItemOrFilterAtPosition(player, c)
        for r = 1, rows do
            local i = c + (r - 1) * columns
            if i <= size then
                desired = getItemAtPosition(player, i) or desired
                setFilter(player, desired, c + (r - 1) * columns)
            end
        end
    end
end

function multiply_filter(player, factor)
    local size = #player.opened.get_inventory(1)
    for i = 1, REQUEST_SLOTS do
        local existing = player.opened.get_request_slot(i)
        if existing ~= nil then
            player.opened.set_request_slot({ name =  existing.name, count = math.floor(existing.count * factor) }, i)
        end
    end
end

function requests_x2(player)
    multiply_filter(player, 2)
end
function requests_x5(player)
    multiply_filter(player, 5)
end
function requests_x10(player)
    multiply_filter(player, 10)
end
function requests_fill(player)
    local inv = player.opened.get_inventory(1)
    local inventorySize = #inv

    local totalStackRequests = 0

    -- Add up how many total stacks we need here
    for i = 1, REQUEST_SLOTS do
        local item = player.opened.get_request_slot(i)
        if item ~= nil then
            totalStackRequests = totalStackRequests + item.count / game.item_prototypes[item.name].stack_size
        end
    end

    local factor = inventorySize / totalStackRequests
    -- Go back and re-set each thing according to its rounded-up stack size
    for i = 1, REQUEST_SLOTS do
        local item = player.opened.get_request_slot(i)
        if item ~= nil then
            stacksToRequest = math.ceil(item.count / game.item_prototypes[item.name].stack_size)
            numberToRequest = stacksToRequest * game.item_prototypes[item.name].stack_size
            player.opened.set_request_slot({ name =  item.name, count = numberToRequest }, i)
        end
    end
end

function requests_blueprint(player)
    -- Get some blueprint details
    -- Note: 1 entry per item
    -- game.local_player.opened.get_inventory(1)[1].get_blueprint_entities()[5].name
    local blueprint = nil;
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == "blueprint" then
        blueprint = player.cursor_stack;
    elseif player.opened.get_inventory(1)[1].valid_for_read and player.opened.get_inventory(1)[1].name == "blueprint" then
        blueprint = player.opened.get_inventory(1)[1];
    else
        player.print('You must be holding a blueprint or have a blueprint in the first chest slot to use this button')
        return
    end

    -- Clear out all existing requests
    for i = 1, REQUEST_SLOTS do
        player.opened.clear_request_slot(i)
    end

    local bp = blueprint.get_blueprint_entities()

    if bp == nil then
        player.print('Blueprint has no pattern. Please use blueprint with pattern.')
        return
    end

    if #bp > REQUEST_SLOTS then
        -- BP has too many items to fit in the request set!
        player.print('Blueprint has more required items than would fit in the logistic request slots of this chest')
        return
    end

    -- Make a mapping from item name -> quantity needed
    local lookup = {}
    for k, v in ipairs(bp) do
        lookup[v.name] = (lookup[v.name] or 0) + 1
    end

    -- Set the requests in the chest
    local i = 1
    for k, v in pairs(lookup) do
        player.opened.set_request_slot({name = k, count = v}, i)
        i = i + 1
    end
end


-- UI management
function showOrHideUI(player, show, name, showFunc)
    local exists = player.gui.top[name] ~= nil;
    if exists ~= show then
        if show then
            player.gui.top.add({ type = "flow", name = name, direction = "horizontal" });
            showFunc(player.gui.top[name])
        else
            player.gui.top[name].destroy()
        end
    end
end

function showOrHideFilterUI(player, show)
    showOrHideUI(player, show, 'FilterRowName', showFilterUI)
end

function showFilterUI(myRow)
    myRow.add( { type = "button", caption = "Filters: " } )

    myRow.add( { type = "button", name = Buttons.Filter.All, caption = "Fill All" } )
    myRow.add( { type = "button", name = Buttons.Filter.Right, caption = "Fill Right" } )
    myRow.add( { type = "button", name = Buttons.Filter.Down, caption = "Fill Down" } )
    myRow.add( { type = "button", name = Buttons.Filter.Clear, caption = "Clear All" } )
    myRow.add( { type = "button", name = Buttons.Filter.Set, caption = "Set All" } )
end

function showOrHideRequestUI(player, show)
    showOrHideUI(player, show, 'RequestRowName', showRequestUI)
end

function showRequestUI(myRow)
    myRow.add( { type = "button", caption = "Requests: " } )

    myRow.add( { type = "button", name = Buttons.Requests.x2, caption = "x2" } )
    myRow.add( { type = "button", name = Buttons.Requests.x5, caption = "x5" } )
    myRow.add( { type = "button", name = Buttons.Requests.x10, caption = "x10" } )
    myRow.add( { type = "button", name = Buttons.Requests.Fill, caption = "Fill" } )
    myRow.add( { type = "button", name = Buttons.Requests.Blueprint, caption = "Blueprint" } )
end

script.on_init(startup)
script.on_load(startup)
