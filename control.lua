require "defines"
require "util"

-- Notes
-- Give yourself some items
-- /c game.player.insert{name="assembling-machine-3",count=100}

-- TODO: How to get the number of request slots?

-- Name of the row headers we put in the UI
local filterUiElementName = "FilterFillRow"
local requestUiElementName = "RequestRow"

-- Button click dispatching
local Buttons = {}
local dispatch = {}

-- Initializes the world
function startup()
    (game or script).on_event(defines.events.on_tick, checkOpened)
    initButtons()
end

-- Listener for events clicked
function handleButton(event)
    local handler = dispatch[event.element.name]
    if handler then
        handler()
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

    if game ~= nil then
        game.on_event(defines.events.on_gui_click, handleButton)
    else
        script.on_event(defines.events.on_gui_click, handleButton)
    end
end

-- All containers in the game seem to have 10 columns
function getColumns()
    return 10
end

-- TODO: Implement Car, Tank when those get API support
function getRows()
    if game.player.opened.type == "cargo-wagon" then
        return 3
    else
        return nil
    end
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

    showOrHideFilterUI(game.player.opened ~= nil and canFilter(game.player.opened))
    showOrHideRequestUI(game.player.opened ~= nil and canRequest(game.player.opened))
end

-- Gets the name of the item at the given position, or nil if there
-- is no item at that position
function getItemAtPosition(n)
    local inv = game.player.opened.get_inventory(1)
    local isEmpty = not inv[n].valid_for_read
    if isEmpty then
        return nil
    else
        return inv[n].name
    end
end

-- Returns either the item at a position, or the filter
-- at the position if there isn't an item there
function getItemOrFilterAtPosition(n)
    local filter = game.player.opened.get_filter(n)
    if filter ~= nil then
        return filter
    else
        return getItemAtPosition(n)
    end
end

-- Set the filter of the opened UI to the given value, or clear
-- it if the given value is nil
function setFilter(value, pos)
    if value then
        game.player.opened.set_filter(value, pos)
    else
        game.player.opened.clear_filter(pos)
    end
end

-- Filtering: Clear all filters in the opened container
function filter_clearAll()
    local op = game.player.opened;
    local size = getRows() * getColumns()
    for i = 1, size do
        op.clear_filter(i)
    end
end

-- Filtering: Set the filters of the opened container to the
-- contents of each cell
function filter_setAll()
    local op = game.player.opened;
    local size = getRows() * getColumns()
    for i = 1, size do
        local desired = getItemAtPosition(i)
        setFilter(desired, i)
    end
end

-- Filtering: Filter all cells of the opened container with the
-- contents of the player's cursor stack, or the first item in the container,
-- or the first filter in the container
function filter_fillAll()
    -- Get the contents of the player's cursor stack, or the first cell
    local desired = (game.player.cursor_stack.valid_for_read and game.player.cursor_stack.name) or getItemOrFilterAtPosition(1)
    local size = getRows() * getColumns()
    local op = game.player.opened;
    for i = 1, size do
        local current = getItemAtPosition(i)
        if current and desired and current ~= desired then
            game.player.print({"", 'Skipped setting a filter on the cell occupied by ', {'item-name.' .. current}})
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
function filter_fillRight()
    -- N.B. Assumes all filterable containers are rectangular
    local columns = getColumns()
    local rows = getRows()
    for r = 1, rows do
        local desired = getItemOrFilterAtPosition(1 + (r - 1) * columns)
        for c = 1, columns do
            local i = c + (r - 1) * columns
            desired = getItemAtPosition(i) or desired
            setFilter(desired, i)
        end
    end
end

-- Filtering: Copies the filter settings of each cell to the cell(s) below it
function filter_fillDown()
    -- N.B. Assumes all filterable containers are rectangular
    local columns = getColumns()
    local rows = getRows()
    for c = 1, columns do
        local desired = getItemOrFilterAtPosition(c)
        for r = 1, rows do
            local i = c + (r - 1) * columns
            desired = getItemAtPosition(i) or desired
            setFilter(desired, c + (r - 1) * columns)
        end
    end
end

function multiply_filter(factor)
    for i = 1, 100 do
        local existing = game.player.opened.get_request_slot(i)
        game.player.opened.set_request_slot({ name =  existing.name, count = math.floor(existing.count * factor) }, i)
    end
end

function requests_x2()
    pcall(multiply_filter, 2)
    informUserToReopenChest()
end
function requests_x5()
    pcall(multiply_filter, 5)
    informUserToReopenChest()
end
function requests_x10()
    pcall(multiply_filter, 10)
    informUserToReopenChest()
end
function requests_fill()
    local inventorySize = 0
    local inv = game.player.opened.get_inventory(1);

    function findSize()
        for i = 1, 1000 do
            local dummy = inv[i]
            inventorySize = i
        end
    end

    pcall(findSize)

    local totalStackRequests = 0
    function findRequestTotal()
        for i = 1, 1000 do
            local item = game.player.opened.get_request_slot(i)
            if item ~= nil then
                totalStackRequests = totalStackRequests + item.count / game.item_prototypes[item.name].stack_size
            end
        end
    end
    pcall(findRequestTotal)

    local factor = inventorySize / totalStackRequests

    pcall(multiply_filter, factor)
    informUserToReopenChest()
end
function requests_blueprint()
    -- Get some blueprint details
    -- Note: 1 entry per item
    -- game.player.opened.get_inventory(1)[1].get_blueprint_entities()[5].name
    local blueprint = nil;
    if game.player.cursor_stack.valid_for_read and game.player.cursor_stack.name == "blueprint" then
        blueprint = game.player.cursor_stack;
    elseif game.player.opened.get_inventory(1)[1].valid_for_read and game.player.opened.get_inventory(1)[1].name == "blueprint" then
        blueprint = game.player.opened.get_inventory(1)[1];
    else
        game.player.print('You must be holding a blueprint or have a blueprint in the first chest slot to use this button')
        return
    end

    function clearAllRequests()
        for i = 1, 1000 do
            game.player.opened.clear_request_slot(i)
        end
    end
    pcall(clearAllRequests)

    local lookup = {}
    local bp = blueprint.get_blueprint_entities()
    for k, v in ipairs(bp) do
        lookup[v.name] = (lookup[v.name] or 0) + 1
    end

    local i = 1
    for k, v in pairs(lookup) do
        game.player.opened.set_request_slot({name = k, count = v}, i)
        i = i + 1
    end

    informUserToReopenChest()
end

function informUserToReopenChest()
    game.player.print('Logistics requests updated, re-open chest to see changes (Factorio bug)')
end


-- 
function showOrHideUI(show, name, showFunc)
    local exists = game.player.gui.top[name] ~= nil;
    if exists ~= show then
        if show then
            game.player.gui.top.add({ type = "flow", name = name, direction = "horizontal" });
            showFunc(game.player.gui.top[name])
        else
            game.player.gui.top[name].destroy()
        end
    end
end

function showOrHideFilterUI(show)
    showOrHideUI(show, 'FilterRowName', showFilterUI)
end

function showFilterUI(myRow)
    myRow.add( { type = "button", caption = "Filters: " } )
    
    myRow.add( { type = "button", name = Buttons.Filter.All, caption = "Fill All" } )
    myRow.add( { type = "button", name = Buttons.Filter.Right, caption = "Fill Right" } )
    myRow.add( { type = "button", name = Buttons.Filter.Down, caption = "Fill Down" } )
    myRow.add( { type = "button", name = Buttons.Filter.Clear, caption = "Clear All" } )
    myRow.add( { type = "button", name = Buttons.Filter.Set, caption = "Set All" } )
end

function showOrHideRequestUI(show)
    showOrHideUI(show, 'RequestRowName', showRequestUI)
end

function showRequestUI(myRow)
    myRow.add( { type = "button", caption = "Requests: " } )
    
    myRow.add( { type = "button", name = Buttons.Requests.x2, caption = "x2" } )
    myRow.add( { type = "button", name = Buttons.Requests.x5, caption = "x5" } )
    myRow.add( { type = "button", name = Buttons.Requests.x10, caption = "x10" } )
    myRow.add( { type = "button", name = Buttons.Requests.Fill, caption = "Fill" } )
    myRow.add( { type = "button", name = Buttons.Requests.Blueprint, caption = "Blueprint" } )
end

if game ~= nil then
    game.on_load(startup)
elseif script ~= nil then
    script.on_load(startup)
end
