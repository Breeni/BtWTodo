--[[
    Current system for configuration:
    BtWTodoConfigPanel handles config for the UI, including todo list, characters, item size and auto adding current player
    refresh function clones the data for the ui profiles as well as category data and stores them within the frame
    Todos and Characters are stored as data providers for their scrollboxes
    Categories are stored as a table, id => { id = string|number, name = string, color = ColorMixin }, name/color affects all profiles
    okay function stores the data back into the saved variables
    default function SHOULD revert either one or more profiles back to the default layout?
    cancel function just closes the frame, no need to actually do anything since refresh is called when the panel is shown again
    should the changes show in the normal ui?

    BtWTodoConfigTodoPanel handles config for the todo items, including states and functions
    BtWTodoConfigTodoPanel works by cloning todo items, but only as they are edited
    refresh function clears the cache of cloned todo items
    okay function saves the cache of cloned items back into the BtWTodoData saved variable
    default function SHOULD revert the currently selected todo back to default if its a preregisted todo?
    cancel function just closes the frame
    should the changes show in the normal ui?
]]

local ADDON_NAME, Internal = ...
local L = Internal.L
local External = _G[ADDON_NAME]

BTWTODO = "BtWTodo"
BTWTODO_SUBTEXT = " "

BTWTODO_WINDOWS = L["Windows"]
BTWTODO_WINDOWS_SUBTEXT = L["These options allow you to customize the different frames, changing which todos and characters are displayed."]
BTWTODO_ADD_TODO = L["Add Todo"]
BTWTODO_ADD_TODO_SUBTEXT = L["Search for a todo to add below"]
BTWTODO_ADD_CATEGORY = L["Add Category"]
BTWTODO_ADD_CATEGORY_SUBTEXT = L["Enter the name of the category below"]
BTWTODO_ADD_CHARACTER = L["Add Character"]
BTWTODO_ADD_CHARACTER_SUBTEXT = L["Search for a character to add"]
BTWTODO_AUTO_ADD_PLAYER = L["Auto Add Player"]
BTWTODO_CHANGE_COLOR = L["Change Color"]
BTWTODO_CHANGE_NAME_COLOR = L["Change Name/Color"]

BTWTODO_LIST = L["List"]
BTWTODO_BUTTON_SIZE = L["Button Size"]

BTWTODO_LISTS = L["Lists"]
BTWTODO_LISTS_SUBTEXT = L["Create and edit lists for choosing which todos to display."]
BTWTODO_NEW_LIST = L["New List"]

BTWTODO_TODOS = L["Todos"]
BTWTODO_TODOS_SUBTEXT = L["These options allow you to customize your todos, select a todo from the drop down menu below to begin."]
BTWTODO_ADD_STATE = L["Add State"]
BTWTODO_COMPLETED = GOAL_COMPLETED
BTWTODO_TEXT = LOCALE_TEXT_LABEL
BTWTODO_CLICK = L["Click"]
BTWTODO_TOOLTIP = L["Tooltip"]
BTWTODO_BASIC = L["Basic"]
BTWTODO_ADVANCED = EFFECTS_LABEL
BTWTODO_NEW_TODO = L["New Todo"]
BTWTODO_ADD_ITEM = L["Add %s"]
BTWTODO_TOGGLE_VISIBILITY = L["Toggle Visibility"]
BTWTODO_REVERT = L["Revert"]
BTWTODO_REVERT_TODO = L["Revert To-do"]
BTWTODO_UPDATED_MESSAGE = L["The selected to-do has been updated since you edited it. Click here if you wish to change to the updated version, |cFFFF0000the changes you made will be lost|r."]
BTWTODO_REVERT_MESSAGE = L["Revert this to-do back to it's default version, |cFFFF0000any changes you made will be lost|r"]
BTWTODO_CHANGE_LOG = L["Change Log:"]

BTWTODO_CHARACTERS = L["Characters"]
BTWTODO_CHARACTERS_SUBTEXT = L["These options allow you to customize your characters, changing which are displayed, and removed old characters."]

BTWTODO_CLONE = L["Clone"]

BTWTODO_MINIMAP_ICON = L["Show Minimap Icon"]

--@debug@
local debug = print
--@end-debug@
--[===[@non-debug@
local debug = function () end
--@end-non-debug@]===]

local function IterateLists()
    local tbl = {}
    for id,todo in pairs(BtWTodoConfigListsPanel.lists) do
        tbl[id] = todo
    end
    for id,todo in Internal.IterateLists() do
        if not tbl[id] then
            tbl[id] = todo
        end
    end
    return next, tbl, nil
end
local function GetList(id)
    local list = BtWTodoConfigListsPanel.lists[id]
    if not list then
        list = Internal.GetList(id)
    end
    return list
end

--  [[  Add Item Overlay  ]]

BtWTodoAutoCompleteButtonMixin = {}
function BtWTodoAutoCompleteButtonMixin:Set(name, isSelected)
    self:SetText(name)
    if isSelected then
        self:LockHighlight();
    else
        self:UnlockHighlight();
    end
end
function BtWTodoAutoCompleteButtonMixin:OnClick()
    self:GetParent():OnButtonClick(self:GetID())
end

BtWTodoAddFrameAutoCompleteListMixin = {}
function BtWTodoAddFrameAutoCompleteListMixin:OnLoad()
	BackdropTemplateMixin.OnBackdropLoaded(self)
    self.items = {}
    self.maxButtons = 4
    self.selectedIndex = 1
    self.Buttons = {}
end
function BtWTodoAddFrameAutoCompleteListMixin:SetOnButtonClick(callback)
    self.onButtonClick = callback
end
function BtWTodoAddFrameAutoCompleteListMixin:OnButtonClick(index)
    if self.onButtonClick then
        self.onButtonClick(self, self.items[index]:gsub("|[cC][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", ""):gsub("|[rR]", ""))
    end
end
function BtWTodoAddFrameAutoCompleteListMixin:GetSelectedIndex()
    return self.selectedIndex
end
function BtWTodoAddFrameAutoCompleteListMixin:SetSelectedIndex(index)
    self.selectedIndex = tonumber(index) or 1
    self:Update()
end
function BtWTodoAddFrameAutoCompleteListMixin:SetItems(items)
    self.items = items
    self:Update()
end
function BtWTodoAddFrameAutoCompleteListMixin:GetItems()
    return self.items
end
function BtWTodoAddFrameAutoCompleteListMixin:GetButton(index)
    return self.Buttons[index]
end
function BtWTodoAddFrameAutoCompleteListMixin:SetMaxButtons(count)
    self.maxButtons = tonumber(count) or 4
    self:Update()
end
function BtWTodoAddFrameAutoCompleteListMixin:Update()
    if #self.items == 0 then
        return self:Hide()
    end

    local count = min(self.maxButtons, #self.items)
    self.selectedIndex = max(1, min(self.selectedIndex, count))

    local width = 120
    for i=1,count do
        local button = self.Buttons[i]
        if not button then
            button = CreateFrame("Button", nil, self, "BtWTodoAutoCompleteButtonTemplate")
            if i == 1 then
                button:SetPoint("TOPLEFT", 0, -10)
            else
                button:SetPoint("TOPLEFT", self.Buttons[i-1], "BOTTOMLEFT", 0, 0)
            end
            self.Buttons[i] = button
        end
        button:SetID(i)
        button:Set(self.items[i], i == self:GetSelectedIndex())

        width = max(width, button:GetFontString():GetWidth() + 30)
		button:Enable();
        button:Show()
    end
    for i=count+1,#self.Buttons do
        self.Buttons[i]:Hide()
    end

    self:SetSize(width, self.Buttons[1]:GetHeight() * count + 20)
    self:Show()
end

BtWTodoAddFrameEditBoxMixin = {}
function BtWTodoAddFrameEditBoxMixin:OnLoad()
    self.addHighlightedText = true
    self.autoCompleteListFrame = nil
    self.autoCompleteList = {}
    self.selectedIndex = 0
end
function BtWTodoAddFrameEditBoxMixin:SetAutoCompleteListFrame(frame)
    self.autoCompleteListFrame = frame
    frame:SetItems(self.autoCompleteList)
    frame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
    frame:SetOnButtonClick(function (_, value)
        self:SetText(value)
        self:SetCursorPosition(strlen(value))
        frame:Hide()
    end)
end
function BtWTodoAddFrameEditBoxMixin:Wipe()
    wipe(self.autoCompleteList)
end
function BtWTodoAddFrameEditBoxMixin:UpdateAutoCompleteList()
	local text = self:GetText()
	local utf8Position = self:GetUTF8CursorPosition()

    wipe(self.autoCompleteList)
    self.autoCompleteCallback(self, self.autoCompleteList, text, 1, utf8Position)

    return #self.autoCompleteList > 0
end
function BtWTodoAddFrameEditBoxMixin:GetNumResults()
    return #self.autoCompleteList
end
function BtWTodoAddFrameEditBoxMixin:GetAutoCompleteList()
    return self.autoCompleteListFrame
end
function BtWTodoAddFrameEditBoxMixin:HasAutoCompleteList()
    return self.autoCompleteListFrame ~= nil
end
function BtWTodoAddFrameEditBoxMixin:GetSelectedIndex()
    if self:HasAutoCompleteList() then
        return self.autoCompleteListFrame:GetSelectedIndex()
    end
    return 0
end
function BtWTodoAddFrameEditBoxMixin:SetSelectedIndex(index)
    if self:HasAutoCompleteList() then
        self.autoCompleteListFrame:SetSelectedIndex(index)
    end
end
function BtWTodoAddFrameEditBoxMixin:HideAutoCompleteFrame()
    if self:HasAutoCompleteList() and not self.autoCompleteListFrame:IsMouseOver() then
        self.autoCompleteListFrame:Hide()
    end
end
function BtWTodoAddFrameEditBoxMixin:IncrementSelection(up)
    if self:HasAutoCompleteList() and self.autoCompleteListFrame:IsShown() then
        local selectedIndex = self:GetSelectedIndex()
        local numReturns = self:GetNumResults()
        if up then
            local nextNum = mod(selectedIndex - 1, numReturns)
            if nextNum <= 0 then
                nextNum = numReturns -- 1 indexed
            end
            self:SetSelectedIndex(nextNum)
        else
            local nextNum = mod(selectedIndex + 1, numReturns)
            if nextNum == 0 then
                nextNum = numReturns
            end
            self:SetSelectedIndex(nextNum)
        end
    end
end
function BtWTodoAddFrameEditBoxMixin:OnTabPressed()
    self:IncrementSelection(IsShiftKeyDown())
end
function BtWTodoAddFrameEditBoxMixin:OnArrowPressed(key)
	if key == "UP" then
        return self:IncrementSelection(true)
	elseif key == "DOWN" then
        return self:IncrementSelection(false)
	end
end
function BtWTodoAddFrameEditBoxMixin:OnEnterPressed()
    if self:HasAutoCompleteList() and self:GetAutoCompleteList():IsShown() then
        local selectedIndex = self:GetSelectedIndex()
        if selectedIndex ~= 0 then
            return self:GetAutoCompleteList():GetButton(selectedIndex):Click()
        end
    end
    if self.enterCallback then
        self.enterCallback(self, self:GetText())
    end
end
function BtWTodoAddFrameEditBoxMixin:OnTextChanged(userInput)
    if userInput then
		if self.disallowAutoComplete then
            self:HideAutoCompleteFrame()
        elseif self:HasAutoCompleteList() then
            self:UpdateAutoCompleteList()
            self.autoCompleteListFrame:Update()
		end
    end
    if self:GetText() == "" then
        self:HideAutoCompleteFrame()
    end
end
function BtWTodoAddFrameEditBoxMixin:OnKeyDown(key)
	if key == "BACKSPACE" then
		self.disallowAutoComplete = true;
	end
end
function BtWTodoAddFrameEditBoxMixin:OnKeyUp(key)
	if key == "BACKSPACE" then
		self.disallowAutoComplete = false;
	end
end
function BtWTodoAddFrameEditBoxMixin:SetAddHighlightedText(value)
    self.addHighlightedText = not not value
end
function BtWTodoAddFrameEditBoxMixin:AddHighlightedText(text)
    if not self.autoCompleteCallback then
        return
    end
	local utf8Position = self:GetUTF8CursorPosition()
    if utf8Position ~= strlenutf8(text) then
        return
    end

    if self:UpdateAutoCompleteList() then
        local newText = self.autoCompleteList[1]:gsub("|[cC][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", ""):gsub("|[rR]", "")
        self:SetText(newText);
        self:HighlightText(strlen(text), strlen(newText))
        self:SetCursorPosition(strlen(text))
    end
end
function BtWTodoAddFrameEditBoxMixin:OnChar()
    if self.disallowAutoComplete then
        self:HideAutoCompleteFrame()
    elseif self:HasAutoCompleteList() then
        self:UpdateAutoCompleteList()
        self.autoCompleteListFrame:Update()
    end
	if self.addHighlightedText and self:GetUTF8CursorPosition() == strlenutf8(self:GetText()) then
		self:AddHighlightedText(self:GetText());
	end
end
function BtWTodoAddFrameEditBoxMixin:OnEditFocusLost()
	self:HighlightText(0, 0);
    self:HideAutoCompleteFrame()
end
function BtWTodoAddFrameEditBoxMixin:OnEscapePressed()
    EditBox_ClearFocus(self)
    if self.escapeCallback then
        self.escapeCallback(self)
    end
end
function BtWTodoAddFrameEditBoxMixin:SetAutoCompleteCallback(callback)
    self.autoCompleteCallback = callback
end
function BtWTodoAddFrameEditBoxMixin:SetOnEnterCallback(callback)
    self.enterCallback = callback
end
function BtWTodoAddFrameEditBoxMixin:SetOnEscapePressed(callback)
    self.escapeCallback = callback
end

BtWTodoAddItemOverlayMixin = {}
function BtWTodoAddItemOverlayMixin:OnShow()
    self.EditBox:SetFocus()
    self.EditBox:SetAutoCompleteListFrame(self.AutoCompleteList)
end
function BtWTodoAddItemOverlayMixin:GetText()
    return self.EditBox:GetText()
end
function BtWTodoAddItemOverlayMixin:Clear()
    self.EditBox:SetText("")
    self.EditBox:Wipe()
end
function BtWTodoAddItemOverlayMixin:OnButtonClicked(button)
    if button.button == 1 then
        self.EditBox:OnEnterPressed()
    elseif button.button == 2 then
        self.EditBox:OnEscapePressed()
    end
end
function BtWTodoAddItemOverlayMixin:SetTitle(text, subtitle)
    if subtitle and subtitle ~= "" then
        self.Title:SetText(text)
        self.SubTitle:SetText(subtitle)
        self.SubTitle:Show()
        self.Title:SetPoint("CENTER", 0, 48)
    else
        self.Title:SetText(text)
        self.Title:SetPoint("CENTER", 0, 24)
        self.SubTitle:Hide()
    end
end
function BtWTodoAddItemOverlayMixin:SetAutoCompleteCallback(callback)
    self.EditBox:SetAutoCompleteCallback(callback)
end
function BtWTodoAddItemOverlayMixin:SetOnOkayCallback(callback)
    self.EditBox:SetOnEnterCallback(function (_, text)
        callback(self, text)
    end)
end
function BtWTodoAddItemOverlayMixin:SetOnCancelCallback(callback)
    self.EditBox:SetOnEscapePressed(callback)
end

--  [[  Drag Scroll Box  ]]

BtWTodoDragScrollBoxItemMixin = {}
function BtWTodoDragScrollBoxItemMixin:OnLoad()
    self:RegisterForDrag("LeftButton")
end
function BtWTodoDragScrollBoxItemMixin:OnDragStart()
    self:GetParent():GetParent():SetDragTarget(self.data.orderIndex)
end
function BtWTodoDragScrollBoxItemMixin:OnEnter()
    self:GetParent():GetParent():DragOver(self.data.orderIndex)
end

BtWTodoDragScrollBoxMixin = {}
function BtWTodoDragScrollBoxMixin:OnLoad()
    self.dragIndexes = {}
    ScrollBoxListMixin.OnLoad(self)
    self:RegisterEvent("GLOBAL_MOUSE_UP")
end
function BtWTodoDragScrollBoxMixin:OnEvent()
    self:SetDragRange(nil)
end
function BtWTodoDragScrollBoxMixin:GetDragRange()
    return unpack(self.dragIndexes)
end
function BtWTodoDragScrollBoxMixin:SetDragRange(startIndex, endIndex) -- Inclusive
    if startIndex == nil then
        wipe(self.dragIndexes)
        self:ForEachFrame(function (frame)
            frame.Drag:Hide()
        end)
        return
    end

    if startIndex > endIndex then -- Lowest first always
        startIndex, endIndex = endIndex, startIndex
    end

    local foundFrame = false
    for _,frame in ipairs(self:GetFrames()) do
        local orderIndex = frame:GetOrderIndex()
        if orderIndex >= startIndex and orderIndex <= endIndex then
            frame.Drag:Show()
            foundFrame = true
        elseif foundFrame then
            break
        end
    end

    self.dragIndexes = {startIndex, endIndex}
end
local function GetCategoryRange(self, orderIndex)
    local dataProvider = self:GetDataProvider()
    local index = orderIndex + 1
    local item = dataProvider:Find(index)
    while item and item.type ~= "category" do
        index = index + 1
        item = dataProvider:Find(index)
    end
    return index - 1
end
function BtWTodoDragScrollBoxMixin:SetDragTarget(orderIndex)
    local item = self:GetDataProvider():Find(orderIndex)
    if item == nil then
        error(self:GetName() .. ":SetDragFrame(orderIndex): orderIndex out of range")
    end
    if item.type == "category" then
        self:SetDragRange(orderIndex, GetCategoryRange(self, orderIndex))
    else
        self:SetDragRange(orderIndex, orderIndex)
    end
end
function BtWTodoDragScrollBoxMixin:DragOver(orderIndex)
    local startIndex, endIndex = unpack(self.dragIndexes)
    if not startIndex then
        return
    end

    if orderIndex >= startIndex and orderIndex <= endIndex then
        return
    end

    -- We modify the orderIndex values, but until we call Sort on the data provider they wont be updated
    local dataProvider = self:GetDataProvider()

    -- In situations where we are moving an entire category we need to move it before or after another category only
    local isCategory = startIndex ~= endIndex

    if orderIndex < startIndex then -- Moving items up
        local item = dataProvider:Find(orderIndex)
        if isCategory and item ~= nil and item.type ~= "category" then -- Drag up onto a category to put it before
            return
        end

        local index = orderIndex
        for i=startIndex,endIndex do
            local item = dataProvider:Find(i)
            item.orderIndex = index
            index = index + 1
        end
        self.dragIndexes = {orderIndex, orderIndex + endIndex - startIndex}

        local index = orderIndex
        local item = dataProvider:Find(index)
        while item and index < startIndex do
            item.orderIndex = endIndex - startIndex + 1 + index

            index = index + 1
            item = dataProvider:Find(index)
        end
    else
        local item = dataProvider:Find(orderIndex+1)
        if isCategory and item ~= nil and item.type ~= "category" then -- Drag down onto the last item before the end or a category
            return
        end

        local index = startIndex--  -- Needs to go before category
        for i=endIndex+1,orderIndex do
            local item = dataProvider:Find(i)
            item.orderIndex = index
            index = index + 1
        end
        
        local index = orderIndex-(endIndex - startIndex)
        for i=startIndex,endIndex do
            local item = dataProvider:Find(i)
            item.orderIndex = index
            index = index + 1
        end
        self.dragIndexes = {orderIndex-(endIndex - startIndex), orderIndex-(endIndex - startIndex) + endIndex - startIndex}
    end
    dataProvider:Sort()
end
function BtWTodoDragScrollBoxMixin:Remove(orderIndex)
    -- We modify the orderIndex values, but until we call Sort on the data provider they wont be updated
    local dataProvider = self:GetDataProvider()
    dataProvider:RemoveIndex(orderIndex)
	for index,elementData in dataProvider:Enumerate() do
		elementData.orderIndex = index -- Fix indexes
	end
    dataProvider:Sort()
end

--  [[  Config Panel  ]]
local ldbi = LibStub("LibDBIcon-1.0")

BtWTodoConfigPanelMixin = {}
function BtWTodoConfigPanelMixin:OnLoad()
    InterfaceOptions_AddCategory(self)
end
function BtWTodoConfigPanelMixin:SetMinimapIcon(checked)
    if checked then
        ldbi:Show(ADDON_NAME)
    else
        ldbi:Hide(ADDON_NAME)
    end
end
function BtWTodoConfigPanelMixin:okay()
    xpcall(function()
        BtWTodoDataBroker.show = self.MinimapIconButton:GetChecked()
        if BtWTodoDataBroker.show ~= false then
            ldbi:Show(ADDON_NAME)
        else
            ldbi:Hide(ADDON_NAME)
        end
    end, geterrorhandler())
end
function BtWTodoConfigPanelMixin:cancel()
    xpcall(function()
        if BtWTodoDataBroker.show ~= false then
            ldbi:Show(ADDON_NAME)
        else
            ldbi:Hide(ADDON_NAME)
        end
    end, geterrorhandler())
end
function BtWTodoConfigPanelMixin:default()
    xpcall(function()
        self.MinimapIconButton:SetChecked(true)
    end, geterrorhandler())
end
function BtWTodoConfigPanelMixin:refresh()
    xpcall(function()
        self.MinimapIconButton:SetChecked(BtWTodoDataBroker.show ~= false)
    end, geterrorhandler())
end

do
    local tbl = {}
    Internal.RegisterEvent("REGISTER_STATE_PROVIDER", function ()
        wipe(tbl)
    end)
	local function DropDownInit(self, level, menuList)
		local function OnClick(_, arg1, arg2, checked)
			self:SetSelected(arg1, arg2)
		end

        if tbl[1] == nil then
            for _,provider in Internal.IterateStateProviders() do
                tbl[#tbl+1] = provider
            end
            table.sort(tbl, function (a, b)
                if a:GetName() == b:GetName() then
                    return a:GetID() < b:GetID()
                end
                return a:GetName() < b:GetName()
            end)
        end

		local info = UIDropDownMenu_CreateInfo()
		if (level or 1) == 1 then
			info.func = OnClick
			info.notCheckable = true
            for _,provider in ipairs(tbl) do
                info.text = provider:GetName()
                info.arg1 = provider:GetID()
                UIDropDownMenu_AddButton(info, level)
            end
		end
	end

	BtWTodoStateProviderDropDownMixin = {}
	function BtWTodoStateProviderDropDownMixin:OnLoad()
	end
	function BtWTodoStateProviderDropDownMixin:OnShow()
		if not self.initialized then
			UIDropDownMenu_Initialize(self, DropDownInit, "MENU")
			self.initialized = true
		end
	end
	function BtWTodoStateProviderDropDownMixin:SetSelected(type, key)
		if self.onchange then
			self:onchange(type, key)
		end
	end
	function BtWTodoStateProviderDropDownMixin:SetScript(scriptType, handler)
		if scriptType == "OnChange" then
			self.onchange = handler
		else
			getmetatable(self).__index.SetScript(self, scriptType, handler)
		end
	end
end

--  [[  Todo States Input  ]]

BtWTodoConfigStatesInputItemMixin = {}
function BtWTodoConfigStatesInputItemMixin:OnLoad()
    self:RegisterForDrag("LeftButton")
end
function BtWTodoConfigStatesInputItemMixin:Init(state)
    self.state = state
    if state.GetDisplayName then
        local result = state:GetDisplayName(true)
        if type(result) == "function" then
            result(function (result)
                self.Text:SetText(result)
                self:SetWidth(self.Text:GetWidth() + 25 + 16)
            end)
        else
            self.Text:SetText(result)
        end
    else
        self.Text:SetText(state:GetUniqueKey())
    end
    self:SetWidth(self.Text:GetWidth() + 25 + 16)
end
function BtWTodoConfigStatesInputItemMixin:OnEnter()
    if not self:IsDragging() then
        self.RemoveButton.texture:SetDesaturated(false)
    end
end
function BtWTodoConfigStatesInputItemMixin:OnLeave()
    if not self:IsMouseOver() then
        self.RemoveButton.texture:SetDesaturated(true)
    end
end
function BtWTodoConfigStatesInputItemMixin:OnDragStart()
    self:GetParent():GetParent():OnDragStart()
end
function BtWTodoConfigStatesInputItemMixin:OnDragStop()
    self:GetParent():GetParent():OnDragStop()
end
function BtWTodoConfigStatesInputItemMixin:OnRemoveClick()
    self:GetParent():GetParent():Remove(self.state)
end

BtWTodoConfigStatesInputMixin = CreateFromMixins(Internal.ScriptHandlerMixin)
function BtWTodoConfigStatesInputMixin:OnLoad()
    Internal.ScriptHandlerMixin.OnLoad(self)
    self:RegisterSupportedScriptHandlers("OnAdd", "OnRemove")
    self:RegisterForDrag("LeftButton")
    self:EnableMouseWheel(true)
    self.pool = CreateFramePool("Frame", self:GetScrollChild(), "BtWTodoConfigStatesInputItemTemplate")
end
function BtWTodoConfigStatesInputMixin:Init(states)
    self.states = states

    self:SetHorizontalScroll(0)

    self:Update()

    self:UpdateScrollChildRect()
    self:SetHorizontalScroll(self:GetHorizontalScrollRange())
end
function BtWTodoConfigStatesInputMixin:Update()
    self.pool:ReleaseAll()
    local previousFrame
    for _,state in ipairs(self.states) do
        local frame = self.pool:Acquire()
        if previousFrame then
            frame:SetPoint("LEFT", previousFrame, "RIGHT", 5, 0)
        else
            frame:SetPoint("LEFT", 0, 0)
        end

        frame:Init(state)
        frame:Show()

        previousFrame = frame
    end
end
function BtWTodoConfigStatesInputMixin:Add(key)
    local frame = self:GetParent()
    local provider = Internal.GetStateProvider(key)
    if provider:RequiresID() then
        frame.AddItem:SetTitle(provider:GetAddTitle())
        frame.AddItem:SetAutoCompleteCallback(function (_, tbl, text, offset, length)
            provider:FillAutoComplete(tbl, text, offset, length)
        end)
        frame.AddItem:SetOnOkayCallback(function (_, text)
            local result = {provider:ParseInput(text)}
            local success = table.remove(result, 1)
            if not success then
                UIErrorsFrame:AddMessage(result[1] or format(L["Invalid %s"], provider:GetName()), 1.0, 0.1, 0.1, 1.0);
                return
            end
            if not result[1] then
                result[1] = tonumber(text) or text
            end

            local target = provider:Acquire(unpack(result))
            for _,state in ipairs(self.states) do
                if state:GetUniqueKey() == target:GetUniqueKey() then
                    return
                end
            end

            target.source = {
                type = provider:GetID(),
                id = table.remove(result, 1),
                values = #result > 0 and result or nil
            }

            self.states[target:GetUniqueKey()] = target
            self.states[#self.states+1] = target

            self:Update()

            self:UpdateScrollChildRect()
            self:SetHorizontalScroll(self:GetHorizontalScrollRange())

            self:RunScript("OnAdd", target, provider)

            frame.AddItem:Clear()
            frame.AddItem:Hide()
        end)
        frame.AddItem:Show()
    else
        local target = provider:Acquire()
        for _,state in ipairs(self.states) do
            if state:GetUniqueKey() == target:GetUniqueKey() then
                return
            end
        end

        self.states[target:GetUniqueKey()] = target
        self.states[#self.states+1] = target

        self:Update()

        self:UpdateScrollChildRect()
        self:SetHorizontalScroll(self:GetHorizontalScrollRange())

        self:RunScript("OnAdd", target, provider)
    end
end
function BtWTodoConfigStatesInputMixin:GetCount()
    return #self.states
end
function BtWTodoConfigStatesInputMixin:OnAddClick()
    self:Add()
end
function BtWTodoConfigStatesInputMixin:Remove(value)
    self.states[value:GetUniqueKey()] = nil
    for index,state in ipairs(self.states) do
        if state == value then
            table.remove(self.states, index)
        end
    end
    self:Update()

    self:UpdateScrollChildRect()
    self:SetHorizontalScroll(math.min(math.max(self:GetHorizontalScroll(), 0), self:GetHorizontalScrollRange()))
    self:RunScript("OnRemove", value)
end
function BtWTodoConfigStatesInputMixin:OnEnter()
end
function BtWTodoConfigStatesInputMixin:OnLeave()
end
function BtWTodoConfigStatesInputMixin:OnDragStart()
    self.scrollX, self.scrollY = self:GetHorizontalScroll(), self:GetVerticalScroll()
    self.mouseX, self.mouseY = GetCursorPosition()

    local scale = self:GetScrollChild():GetEffectiveScale()
    self.mouseX, self.mouseY = self.mouseX / scale, self.mouseY / scale

    self:SetScript("OnUpdate", self.OnDrag)
end
function BtWTodoConfigStatesInputMixin:OnDragStop()
    self:SetScript("OnUpdate", nil)
end
function BtWTodoConfigStatesInputMixin:OnDrag()
    local mouseX, mouseY = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    mouseX, mouseY = mouseX / scale, mouseY / scale

    local maxXScroll, maxYScroll = self:GetHorizontalScrollRange(), self:GetVerticalScrollRange()

    mouseX = min(max(self.mouseX + self.scrollX - mouseX, 0), maxXScroll)
    mouseY = min(max(mouseY - self.mouseY + self.scrollY, 0), maxYScroll)

    self:SetHorizontalScroll(mouseX)
    self:SetVerticalScroll(mouseY)
end
function BtWTodoConfigStatesInputMixin:OnMouseUp()
end
function BtWTodoConfigStatesInputMixin:OnMouseDown()
end
function BtWTodoConfigStatesInputMixin:OnMouseWheel(delta)
    local scroll = self:GetHorizontalScroll() + (30 * -delta)
    self:SetHorizontalScroll(math.min(math.max(scroll, 0), self:GetHorizontalScrollRange()))
end

--  [[  Lua Syntax Editor  ]]

local contextIncreasesIndents = {
    BLOCK = true,
    MULTILINE_COMMENT = true,
}
local contextDecreasesIndents = {
}
local function GetExpectedIndentForContext(context)
    local indent = 0
    for _,item in ipairs(context) do
        if contextIncreasesIndents[item] then
            indent = indent + 1
        elseif contextDecreasesIndents[item] then
            indent = indent - 1
        end
    end
    return indent
end
local TOKEN = {
    FORMATTING = "FORMATTING",
    NEWLINE = "NEWLINE",
    WHITESPACE = "WHITESPACE",
    STRING = "STRING", -- Contents of a string
    DOUBLE_QUOTE = "DOUBLE_QUOTE", -- Start/End of a double quoted string
    SINGLE_QUOTE = "SINGLE_QUOTE", -- Start/End of a single quoted string
    MULTILINE_QUOTE = "MULTILINE_QUOTE", -- Start/End of a multiline string [[ ... ]]
    MULTILINE_COMMENT_END = "MULTILINE_COMMENT_END", -- Start/End of a multiline comment --[[ ... ]]
    COMMENT = "COMMENT",
    IDENT = "IDENT",
    NUMBER = "NUMBER",
    CONCAT = "CONCAT",
}
local KEYWORDS = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}
local tokenColors = {
    ["local"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["return"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["if"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["then"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["elseif"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["else"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["while"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["for"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["do"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["end"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["function"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["break"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["and"] = CreateColor(0.275, 0.741, 0.875, 1),
    ["or"] = CreateColor(0.275, 0.741, 0.875, 1),
    COMMENT = CreateColor(0.4, 0.4, 0.4, 1),
    MULTILINE_COMMENT_END = CreateColor(0.4, 0.4, 0.4, 1),
    NUMBER = CreateColor(0.322, 0.824, 0.451, 1),
    STRING = CreateColor(0.898, 0.447, 0.333, 1),
    DOUBLE_QUOTE = CreateColor(0.898, 0.447, 0.333, 1),
    SINGLE_QUOTE = CreateColor(0.898, 0.447, 0.333, 1),
    MULTILINE_QUOTE = CreateColor(0.898, 0.447, 0.333, 1),
    CONCAT = CreateColor(0.91, 0.310, 0.392, 1),
}
local function GetNextToken(string, offset, lineEnd, context, multilineSize)
    local byte = strbyte(string, offset)
    -- if byte == 124 then -- Formatting
    --     local match = strmatch(string, "^|c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]", offset)
    --     if match then
    --         return TOKEN.FORMATTING, #match
    --     end
    --     match = strmatch(string, "^|r", offset)
    --     if match then
    --         return TOKEN.FORMATTING, #match
    --     end

    --     error("Unsupported formatting " .. string)
    -- elseif byte == 10 or byte == 13 then -- white space (new lines)
    --     local length = 1
    --     return TOKEN.NEWLINE, length
    -- else
    if byte == 32 or byte == 9 then -- white space
        local length = 1
        repeat
            byte = strbyte(string, offset + length)
            length = length + 1
        until byte ~= 32 and byte ~= 9

        return TOKEN.WHITESPACE, length - 1
    elseif context[#context] == "DOUBLE_QUOTED_STRING" then
        if byte == 34 then -- double quoted string
            return TOKEN.DOUBLE_QUOTE, 1
        else
            local content = strmatch(string, "^(.-[^\\])\"", offset)
            return TOKEN.STRING, #content
        end
    elseif context[#context] == "MULTILINE_COMMENT" then
        local commentEnd = strfind(string, "%]" .. strrep("=", multilineSize or 0) .. "%]", offset)
        if commentEnd == nil then
            return TOKEN.COMMENT, #string - offset
        elseif commentEnd == offset then
            return TOKEN.MULTILINE_COMMENT_END, (multilineSize or 0) + 2
        else
            return TOKEN.COMMENT, commentEnd - offset
        end
    else
        if byte == 34 then -- double quoted string
            return TOKEN.DOUBLE_QUOTE, 1
        elseif byte == 39 then -- single quoted string
            return TOKEN.SINGLE_QUOTE, 1
        -- elseif byte == 91 then -- maybe multi line string?
            -- return TOKEN.MULTILINE_QUOTE, 2+
        elseif byte == 46 and strbyte(string, offset + 1) == 46 then -- double dash
            return TOKEN.CONCAT, 2
        elseif byte == 45 and strbyte(string, offset + 1) == 45 then -- double dash
            local m = strmatch(string, "^%[([=]*)%[", offset + 2)
            if m ~= nil then -- Multi line comment start
                return TOKEN.MULTILINE_COMMENT_END, 4 + #m
            else
                return TOKEN.COMMENT, lineEnd - offset
            end
        else
            local number = strmatch(string, "^0[xX][A-F0-9]", offset)
            if number then
                return TOKEN.NUMBER, #number
            end
            local number = strmatch(string, "^%d+.%d+[eE][+-%d]%d", offset)
            if number then
                return TOKEN.NUMBER, #number
            end
            local number = strmatch(string, "^%d+.%d+", offset)
            if number then
                return TOKEN.NUMBER, #number
            end
            local number = strmatch(string, "^%d+", offset)
            if number then
                return TOKEN.NUMBER, #number
            end

            local word = strmatch(string, "^[%w]+", offset)
            if word then
                if KEYWORDS[word] then
                    return word, #word
                else
                    return TOKEN.IDENT, #word
                end
            else
                return strsub(string, offset, offset), 1
            end
        end
    end
end
BtWTodoConfigEditorMixin = CreateFromMixins(Internal.ScriptHandlerMixin)
function BtWTodoConfigEditorMixin:OnLoad()
    Internal.ScriptHandlerMixin.OnLoad(self)
    self:RegisterSupportedScriptHandlers("OnTextChanged", "OnChar", "OnEnterPressed", "OnTabPressed", "OnSpacePressed", "OnKeyUp")

    local scrollBar = self.ScrollBar;
    scrollBar:ClearAllPoints();
    scrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", -13, -11);
    scrollBar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", -13, 9);
    self.ScrollBar.ScrollDownButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, 4);
    self.ScrollBar.ScrollUpButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, -4);
    self.scrollBarHideable = 1;
    scrollBar:Hide();

    self.EditBox:SetWidth(self:GetWidth() - 18);

    self.initialContext = ".lua"
    self.lineBytes = {} -- Amount of bytes per line, including new line and formatting
    self.lineContexts = {} -- Stores the line ending context, these are dot separated strings that describe the state of the code at the end of the line
end
function BtWTodoConfigEditorMixin:SetInitialContext(context)
    if self.initialContext ~= context then
        self.initialContext = context
        self:Update()
    end
end
function BtWTodoConfigEditorMixin:SetText(text)
    wipe(self.lineBytes)
    wipe(self.lineContexts)
    self.EditBox:SetText(gsub(text, "\r\n", "\n"))
    self:SetCursorPosition(0)
    -- self.EditBox:SetFocus()
    self:Update()
    self.EditBox:SetFocus()
end
function BtWTodoConfigEditorMixin:GetDisplayText()
    return self.EditBox:GetDisplayText()
end
function BtWTodoConfigEditorMixin:GetText()
    return self.EditBox:GetText()
end
function BtWTodoConfigEditorMixin:GetCursorPosition()
    return self.EditBox:GetCursorPosition()
end
function BtWTodoConfigEditorMixin:SetCursorPosition(...)
    return self.EditBox:SetCursorPosition(...)
end
local function UpdateContext(context, token)
    if token == "if" then
        context[#context+1] = "IF"
        context[#context+1] = "CONDITION"
    elseif token == "while" then
        context[#context+1] = "WHILE"
        context[#context+1] = "CONDITION"
    elseif token == "for" then
        context[#context+1] = "FOR"
        context[#context+1] = "FOR_CONDITION"
    elseif token == "then" then
        if context[#context] == "CONDITION" then
            context[#context] = "BLOCK"
        end
    elseif token == "do" then
        if context[#context] == "FOR_CONDITION" and context[#context-1] == "FOR" then
            context[#context] = "BLOCK"
        elseif context[#context] == "CONDITION" and context[#context-1] == "CONDITION" then
            context[#context] = "BLOCK"
        elseif context[#context] == "BLOCK" then
            context[#context+1] = "BLOCK" -- do ... end for generic blocks is a thing
        else
            -- ERROR
        end
    elseif token == "elseif" then
        if context[#context] == "BLOCK" and context[#context-1] == "IF" then
            context[#context] = "CONDITION"
        else
            -- ERROR
        end
    elseif token == "else" then
        if context[#context] ~= "BLOCK" or context[#context-1] ~= "IF" then
            -- ERROR
        end
    elseif token == "repeat" then
        context[#context+1] = "REPEAT"
        context[#context+1] = "BLOCK"
    elseif token == "until" then
        if context[#context] == "BLOCK" and context[#context] == "BLOCK" then
            context[#context] = "UNTIL_CONDITION"
        else
            -- ERROR
        end
    elseif token == "end" then
        if context[#context] == "BLOCK" then
            context[#context] = nil
            if context[#context] == "IF" or context[#context] == "WHILE" or context[#context] == "FOR" then
                context[#context] = nil
            else
                debug(context[#context])
            end
        else
            -- ERROR
        end
    elseif token == TOKEN.MULTILINE_COMMENT_END then
        if context[#context] == "MULTILINE_COMMENT" then
            context[#context] = nil
        else
            context[#context+1] = "MULTILINE_COMMENT"
        end
    elseif token == TOKEN.DOUBLE_QUOTE then
        if context[#context] == "DOUBLE_QUOTED_STRING" then
            context[#context] = nil
        else
            context[#context+1] = "DOUBLE_QUOTED_STRING"
        end
    elseif token == TOKEN.SINGLE_QUOTE then
        if context[#context] == "SINGLE_QUOTED_STRING" then
            context[#context] = nil
        else
            context[#context+1] = "SINGLE_QUOTED_STRING"
        end
    end
end
local function UpdateLine(self, index, lineStart)
    local text = self:GetText() -- Text with formatting
    local cursor, cursorDiff = self:GetCursorPosition(), 0

    debug("GetCursorPosition", cursor)

    local context = {strsplit(".", self.lineContexts[index-1])} -- Context from before the line

    local lastLine = false
    local lineEnd = strfind(text, "\n", lineStart, true)
    if lineEnd == nil then
        lineEnd = #text + 1
        lastLine = true
    end

    -- If cursor is before the line we dont need to adjust it at all,
    -- and if its after the line we handle the adjustment at once
    local adjustCursor = cursor + 1 >= lineStart and cursor <= lineEnd
    local line
    if lastLine then
        line = strsub(text, lineStart)
    else
        line = strsub(text, lineStart, lineEnd + 1)
    end
    debug(line:gsub("|", "||"))
    line = line:gsub("|r", ""):gsub("|c[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]","") -- Line without formatting

    local relativeCursorOffset = 0
    if adjustCursor then
        relativeCursorOffset = cursor - (lineStart - 1)
        debug("relativeCursorOffset", relativeCursorOffset, cursor, lineStart)

        local cursorLine = strsub(text, lineStart, cursor)
        for content in gmatch(cursorLine, "|c[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]") do
            relativeCursorOffset = relativeCursorOffset - #content
        end
        for content in gmatch(cursorLine, "|r") do
            relativeCursorOffset = relativeCursorOffset - #content
        end

        debug("relativeCursorOffset", relativeCursorOffset)
    end

    local offset = 1
    local formatted = {}
    local indentFixed = false

    while offset < #line do
        local token, length = GetNextToken(line, offset, lineEnd, context, self.multilineSize)
        local content = strsub(line, offset, offset + length - 1)

        if not indentFixed then
            local indent = GetExpectedIndentForContext(context)
            if token ~= TOKEN.WHITESPACE then
                if token == "end" or token == "elseif" or token == "else" or token == TOKEN.MULTILINE_COMMENT_END then -- Reduce indent
                    indent = indent - 1
                end
                indent = indent * 4 -- @TODO custom indent
                formatted[#formatted+1] = strrep(" ", indent)

                if adjustCursor and offset <= relativeCursorOffset + 1 then -- Adjust cursor for indent
                    cursorDiff = cursorDiff + indent
                end
            else
                local token = GetNextToken(line, offset + length, lineEnd, context, self.multilineSize)
                if token == "end" or token == "elseif" or token == "else" or token == TOKEN.MULTILINE_COMMENT_END then -- Reduce indent
                    indent = indent - 1
                end
                indent = indent * 4 -- @TODO custom indent
                content = strrep(" ", indent)

                if adjustCursor then
                    if relativeCursorOffset + 1 >= offset + length then -- Cursor is after indent
                        debug(cursor, cursor - length + #content)
                        cursorDiff = cursorDiff - length + #content
                    elseif relativeCursorOffset + 1 >= offset then -- Cursor is within indent so set it to max end
                        cursorDiff = math.min(cursorDiff - length + #content, cursorDiff + (relativeCursorOffset - offset) + #content)
                    end
                end
            end
            indentFixed = true
        end

        -- debug(token, "[" .. content .. "]")

        local color = tokenColors[token]
        if token == TOKEN.MULTILINE_COMMENT_END then
            self.multilineSize = length - 4
        end
        if color then -- DONT COLOR WHITESPACES, it'll cause issues because length is wrong, and needs to be wrong
            local markup = color:GenerateHexColorMarkup()
            formatted[#formatted+1] = format("%s%s|r", markup, content)
            
            if adjustCursor then
                if relativeCursorOffset > offset - 1 then -- Adjust for the |c, place before if its cursor was at the start
                    cursorDiff = cursorDiff + #markup
                    debug("Adjust cursor for added ||c", cursorDiff)
                end
                if relativeCursorOffset >= offset - 1 + length then -- Adjust for the |r
                    cursorDiff = cursorDiff + 2
                    debug("Adjust cursor for added ||r", cursorDiff)
                end
            end
        else
            formatted[#formatted+1] = content
        end

        UpdateContext(context, token)

        offset = offset + length
    end

    formatted = table.concat(formatted, "")

    self.EditBox:HighlightText(lineStart - 1, lineEnd) -- -1 to highlight from BEFORE the first character
    -- if index == 3 then
    --     debug("[" .. formatted .. "]", lineStart, lineEnd)
    --     error("TEST")
    -- end
    self.EditBox:Insert(formatted)
    -- if index == 3 then
    --     debug("[" .. formatted .. "]", lineStart, lineEnd)
    --     error("TEST")
    -- end

    if cursor > lineEnd then
        debug("SetCursorPosition 3", cursor - (lineEnd - lineStart) + #formatted - 1)
        self:SetCursorPosition(cursor - (lineEnd - lineStart) + #formatted - 1)
    elseif cursor >= lineStart - 1 then
        debug("SetCursorPosition 2", lineStart - 1, relativeCursorOffset, cursorDiff)
        self:SetCursorPosition(lineStart - 1 + relativeCursorOffset + cursorDiff)
    else
        debug("SetCursorPosition 1", cursor)
        self:SetCursorPosition(cursor)
    end

    lineEnd = lineStart + #formatted - 1

    self.lineBytes[index] = lineEnd - lineStart + 1

    debug("lengths", lineEnd - lineStart)

    local context = table.concat(context, ".")
    local contextChanged = self.lineContexts[index] ~= context
    self.lineContexts[index] = context

    return true, lineEnd + 1, lastLine, contextChanged
end
function BtWTodoConfigEditorMixin:UpdateFromLine(index, endIndex)
    self.updating = true

    --@alpha@
    xpcall(function()
        index = index or 1
        local offset = 1
        for i=1,index-1 do
            offset = offset + self.lineBytes[i]
        end

        local _, lastLine, contextChanged
        repeat
            debug("UpdateFromLine", index, offset, self.EditBox:GetCursorPosition())
            _, offset, lastLine, contextChanged = UpdateLine(self, index, offset)
            debug("UpdateFromLine", index, offset, self.EditBox:GetCursorPosition(), lastLine, contextChanged)

            index = index + 1
        until lastLine or (not contextChanged and index > endIndex)

        if lastLine then
            while self.lineBytes[index] do
                table.remove(self.lineBytes, index)
                table.remove(self.lineContexts, index)
            end
        end
    end, geterrorhandler())

    debug("----------")
    --@end-alpha@

    self.updating = nil
end
function BtWTodoConfigEditorMixin:Update()
    self.lineContexts[0] = self.initialContext
    self:UpdateFromLine()
end
function BtWTodoConfigEditorMixin:GetLineForOffset(offset)
    local line = 1
    while self.lineBytes[line] ~= nil and offset > self.lineBytes[line] do
        offset = offset - self.lineBytes[line]
        line = line + 1
    end
    return line
end
function BtWTodoConfigEditorMixin:OnTextChanged(...)
    debug("OnTextChanged", ...)
    self:RunScript("OnTextChanged", ...)
end
function BtWTodoConfigEditorMixin:OnChar(text)
    -- if not self.updating then
    --     local offset = self.EditBox:GetCursorPosition()
    --     local line = self:GetLineForOffset(offset)

    --     self:UpdateFromLine(line)

    --     self:RunScript("OnChar", text)
    -- end
end
function BtWTodoConfigEditorMixin:OnSpacePressed(...)
    -- if not self.updating then
    --     local offset = self.EditBox:GetCursorPosition()
    --     local line = self:GetLineForOffset(offset)

    --     self.EditBox:Insert(" ")

    --     self:UpdateFromLine(line)

    --     self:RunScript("OnSpacePressed", ...)
    -- end
end
function BtWTodoConfigEditorMixin:OnEnterPressed(...)
    if not self.updating then
        local offset = self.EditBox:GetCursorPosition()
        local line = self:GetLineForOffset(offset)
        local indent = ""

        -- These are just to push the later values down so we dont have to redo every line
        tinsert(self.lineBytes, line, 0)
        tinsert(self.lineContexts, line, 0)
        self.EditBox:Insert("\n" .. indent)

        self:UpdateFromLine(line)

        self:RunScript("OnEnterPressed", ...)
    end
end
function BtWTodoConfigEditorMixin:OnTabPressed(...)
    if not self.updating then
        local offset = self.EditBox:GetCursorPosition()
        local line = self:GetLineForOffset(offset)

        self.EditBox:Insert("    ")

        self:UpdateFromLine(line)

        self:RunScript("OnTabPressed", ...)
    end
end
function BtWTodoConfigEditorMixin:OnKeyUp(key)
    if key == "BACKSPACE" or key == "DELETE" then
        local offset = self.EditBox:GetCursorPosition()
        local line = self:GetLineForOffset(offset)

        self:UpdateFromLine(line, line + 1)
    elseif key ~= "TAB" and key ~= "ENTER" and not IsModifierKeyDown() then
        local offset = self.EditBox:GetCursorPosition()
        local line = self:GetLineForOffset(offset)

        self:UpdateFromLine(line)
    end

    self:RunScript("OnKeyUp", key)
end

--  [[  Todo Config Panel  ]]

local FUNCTION_TAB_COMPLETED = 1
local FUNCTION_TAB_TEXT = 2
local FUNCTION_TAB_CLICK = 3
local FUNCTION_TAB_TOOLTIP = 4

local MODE_TAB_ADVANCED = 1
local MODE_TAB_BASIC = 2

BtWTodoConfigTodoPanelMixin = {}
function BtWTodoConfigTodoPanelMixin:OnLoad()
    self.todos = {} -- All todos currently being edited
    self.todo = nil -- Set to the table stored within self.todos when a todo is selected

    UIDropDownMenu_SetText(self.TodoDropDown, L["Select a todo to edit"]);
    UIDropDownMenu_SetWidth(self.TodoDropDown, 175);
    UIDropDownMenu_JustifyText(self.TodoDropDown, "LEFT");
    UIDropDownMenu_Initialize(self.TodoDropDown, function (_, level, menuList)
        if BtWTodoData == nil then
            return
        end

        local info = UIDropDownMenu_CreateInfo();
        info.func = function (_, arg1, arg2, checked)
            self:SetTodo(arg1)
        end

        local tbl = {}
        for _,todo in pairs(self.todos) do
            tbl[#tbl+1] = todo
        end
        for id,todo in Internal.IterateTodos() do
            if not self.todos[id] then
                tbl[#tbl+1] = todo
            end
        end
        table.sort(tbl, function (a, b)
            if a.name == b.name then
                return tostring(a.id) < tostring(b.id)
            end
            return a.name < b.name
        end)
        for _,todo in ipairs(tbl) do
            info.text = todo.registered and format("%s *", todo.name) or todo.name
            info.arg1 = todo.id
            info.checked = self.todo and self.todo.id == todo.id or false
            UIDropDownMenu_AddButton(info, level)
        end
    end);

    self.Name:SetScript("OnTextChanged", function (_)
        if self.todo == nil then
            return
        end

        self.todo.name = self.Name:GetText()
        UIDropDownMenu_SetText(self.TodoDropDown, self.todo.name)
    end)
    self.AddDropDown:SetScript("OnChange", function (_, key)
        if self.todo == nil then
            return
        end

        self.States:Add(key)
    end)
    self.States:SetScript("OnAdd", function (_, state)
        if self.todo == nil then
            return
        end

        self.AddStateText:SetShown(self.States:GetCount() <= 2)
        self:ValidateScript()

        --@TODO add defaults to Basic completed/text/click
    end)
    self.States:SetScript("OnRemove", function (_)
        self.AddStateText:SetShown(self.States:GetCount() <= 2)
        self:ValidateScript()
    end)
    self.Editor:SetScript("OnTextChanged", function (editor)
        if self.todo == nil then
            return
        end

        if self.editor == FUNCTION_TAB_COMPLETED then
            self.todo.completed = self.Editor:GetDisplayText()
        elseif self.editor == FUNCTION_TAB_TEXT then
            self.todo.text = self.Editor:GetDisplayText()
        elseif self.editor == FUNCTION_TAB_CLICK then
            self.todo.click = self.Editor:GetDisplayText()
        elseif self.editor == FUNCTION_TAB_TOOLTIP then
            self.todo.tooltip = self.Editor:GetDisplayText()
        end
        self:ValidateScript()
    end)

    self.AddItem:SetOnCancelCallback(function ()
        self.AddItem:Clear()
        self.AddItem:Hide()
    end)

    InterfaceOptions_AddCategory(self)

    PanelTemplates_UpdateTabs(self.FunctionTabHeader)
    PanelTemplates_UpdateTabs(self.ModeTabHeader)
end
function BtWTodoConfigTodoPanelMixin:ValidateScript()
    if not self.todo then
        return
    end

    local driver = self.todo.driver

    local func, err
    if self.editor == FUNCTION_TAB_COMPLETED then
        local source = self.todo.completed
        func, err = Internal.CreateStateDriverFunction(driver, "Completed", source, false)
    elseif self.editor == FUNCTION_TAB_TEXT then
        local source = self.todo.text
        func, err = Internal.CreateStateDriverFunction(driver, "Text", source, false, 'L')
    elseif self.editor == FUNCTION_TAB_CLICK then
        local source = self.todo.click
        func, err = Internal.CreateStateDriverFunction(driver, "Click", source, false, 'button')
    elseif self.editor == FUNCTION_TAB_TOOLTIP then
        local source = self.todo.tooltip
        func, err = Internal.CreateStateDriverFunction(driver, "Tooltip", source, false, 'L, tooltip')
    end
    if not func then
        self.ErrorText:SetText(err)
        self.ErrorText:Show()
        return
    end
    if self.editor == FUNCTION_TAB_COMPLETED then
        driver.completed = func
    elseif self.editor == FUNCTION_TAB_TEXT then
        driver.text = func
    elseif self.editor == FUNCTION_TAB_CLICK then
        driver.click = func
    elseif self.editor == FUNCTION_TAB_TOOLTIP then
        driver.tooltip = func
    end

    driver:SetCharacter(Internal.GetPlayer())
    local status, err = pcall(function ()
        if self.editor == FUNCTION_TAB_COMPLETED then
            driver.completed({
                GetName = function ()
                    return driver:GetName()
                end,
                IsFlaggedCompleted = function ()
                    return driver:IsFlaggedCompleted()
                end,
            }, driver:GetCharacter(), driver.states)
        elseif self.editor == FUNCTION_TAB_TEXT then
            driver.text({
                GetName = function ()
                    return driver:GetName()
                end,
                IsCompleted = function ()
                    return driver:IsCompleted()
                end,
                IsFlaggedCompleted = function ()
                    return driver:IsFlaggedCompleted()
                end,
            }, driver:GetCharacter(), driver.states, Internal.L)
        elseif self.editor == FUNCTION_TAB_CLICK then
            -- Not really sure what to do with this
            --[[
                driver.click({
                    GetName = function ()
                        return driver:GetName()
                    end,
                    IsCompleted = function ()
                        return driver:IsCompleted()
                    end,
                    IsFlaggedCompleted = function ()
                        return driver:IsFlaggedCompleted()
                    end,
                }, driver:GetCharacter(), driver.states, button)
            ]]
        elseif self.editor == FUNCTION_TAB_TOOLTIP then
            driver.tooltip({
                GetName = function ()
                    return driver:GetName()
                end,
                IsCompleted = function ()
                    return driver:IsCompleted()
                end,
                IsFlaggedCompleted = function ()
                    return driver:IsFlaggedCompleted()
                end,
            }, driver:GetCharacter(), driver.states, Internal.L, GameTooltip)
        end
    end)
    if not status then
        self.ErrorText:SetText(err)
        self.ErrorText:Show()
        return
    end

    self.ErrorText:Hide()
end
function BtWTodoConfigTodoPanelMixin:IsEdited()
    local registered = Internal.GetRegisteredTodo(self.todo.id)
    if not registered then
        return false
    end
    return not Internal.CompareTodos(self.todo, registered)
end
function BtWTodoConfigTodoPanelMixin:IsUpdated()
    return Internal.CheckTodoForUpdate(self.todo.id, self.todo.version)
end
function BtWTodoConfigTodoPanelMixin:SetTodo(id)
    if self.todos[id] then -- Already started editing
        self.todo = self.todos[id]
    else -- Read the saved todo and cache it locally for editing
        local tbl = Internal.GetTodo(id)
        if not tbl then
            error("Unknown todo " .. tostring(id))
        end

        local todo = {}
        todo.id = tbl.id
        todo.name = tbl.name
        todo.registered = tbl.registered

        todo.driver, todo.states = Internal.CreateStateDriver(tbl.id, "Editor", tbl.states, "", "", "", "")
        for index,state in ipairs(tbl.states) do
            todo.states[index].source = state
        end

        todo.completed = tbl.completed
        todo.text = tbl.text
        todo.click = tbl.click
        todo.tooltip = tbl.tooltip

        if type(id) == "string" then
            todo.version = tbl.version or 0
        end

        self.editor = self.editor or FUNCTION_TAB_COMPLETED
        self.mode = self.mode or MODE_TAB_ADVANCED

        self.todos[id] = todo
        self.todo = todo
    end

    UIDropDownMenu_SetText(self.TodoDropDown, self.todo.name)
    self.Name:SetText(self.todo.name)
    self.Name:SetCursorPosition(0)
    self.States:Init(self.todo.states)
    self.AddStateText:SetShown(self.States:GetCount() <= 2)

    self.Name:Show()
    self.RevertButton:Show()
    self.RevertButton:SetEnabled(self:IsEdited())

    self.States:Show()
    self.AddButton:Show()
    self.FunctionTabHeader:Show()
    self.ModeTabHeader:Show()
    self.Inset:Show()
    self.Editor:Show()
    self.ErrorText:Show()

    self:Update()

    -- I dont know why, but if we dont reset the first tabs anchor they wont show, these anchors are in the xml already
    self.ModeTabHeader.Tab1:ClearAllPoints()
    self.ModeTabHeader.Tab1:SetPoint("TOPRIGHT", 0, 0)

    self.FunctionTabHeader.Tab1:ClearAllPoints()
    self.FunctionTabHeader.Tab1:SetPoint("TOPLEFT", 0, 0)

    return self.todo.driver
end
function BtWTodoConfigTodoPanelMixin:AddTodo()
    local count = #BtWTodoData+1
    while self.todos[count] or BtWTodoData[count] do
        count = count + 1
    end
    local todo = {
        id = count,
        name = L["New Todo"],
        completed = "return self:IsFlaggedCompleted()",
        text = "return self:IsCompleted() and Images.COMPLETE or \"\"",
        click = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]],
        tooltip = "",
    }
    todo.driver, todo.states = Internal.CreateStateDriver(todo.id, "Editor", {}, "", "", "", "")

    self.editor = self.editor or FUNCTION_TAB_COMPLETED
    self.mode = self.mode or MODE_TAB_ADVANCED

    self.todos[count] = todo
    self:SetTodo(count)
    self.Name:SetFocus()
end
function BtWTodoConfigTodoPanelMixin:CloneTodo()
    if not self.todo then
        return
    end

    local count = #BtWTodoData+1
    while self.todos[count] or BtWTodoData[count] do
        count = count + 1
    end
    local todo = {
        id = count,
        name = format(L["%s (Clone)"], self.todo.name),
        completed = self.todo.completed,
        text = self.todo.text,
        click = self.todo.click,
        tooltip = self.todo.tooltip,
    }
    local states = {}
    for _,state in ipairs(self.todo.states) do
        states[#states+1] = CopyTable(state.source)
    end
    todo.driver, todo.states = Internal.CreateStateDriver(todo.id, "Editor", states, "", "", "", "")

    self.editor = self.editor or FUNCTION_TAB_COMPLETED
    self.mode = self.mode or MODE_TAB_ADVANCED

    self.todos[count] = todo
    self:SetTodo(count)
    self.Name:SetFocus()
end
function BtWTodoConfigTodoPanelMixin:RevertTodo()
    if not self.todo then
        return
    end

    local id = self.todo.id
    local tbl = Internal.GetRegisteredTodo(id)
    if not tbl then
        error("Unknown todo " .. tostring(id))
    end

    local todo = {}
    todo.id = tbl.id
    todo.name = tbl.name
    todo.registered = tbl.registered

    todo.driver, todo.states = Internal.CreateStateDriver(tbl.id, "Editor", tbl.states, "", "", "", "")
    for index,state in ipairs(tbl.states) do
        todo.states[index].source = state
    end

    todo.completed = tbl.completed
    todo.text = tbl.text
    todo.click = tbl.click
    todo.tooltip = tbl.tooltip

    if type(id) == "string" then
        todo.version = tbl.version or 0
    end

    self.editor = self.editor or FUNCTION_TAB_COMPLETED
    self.mode = self.mode or MODE_TAB_ADVANCED

    self.todos[id] = todo

    self:SetTodo(id)
end
function BtWTodoConfigTodoPanelMixin:GetTodoChangeLog()
    if not self.todo then
        return
    end

    return Internal.GetTodoChangeLog(self.todo.id)
end
function BtWTodoConfigTodoPanelMixin:Update()
    if self.todo == nil then
        return
    end

    PanelTemplates_SetTab(self.ModeTabHeader, self.mode)
    PanelTemplates_SetTab(self.FunctionTabHeader, self.editor)
    if self.mode == MODE_TAB_ADVANCED then
        if self.editor == FUNCTION_TAB_COMPLETED then
            self.Editor:SetText(self.todo.completed or "")
        elseif self.editor == FUNCTION_TAB_TEXT then
            self.Editor:SetText(self.todo.text or "")
        elseif self.editor == FUNCTION_TAB_CLICK then
            self.Editor:SetText(self.todo.click or "")
        elseif self.editor == FUNCTION_TAB_TOOLTIP then
            self.Editor:SetText(self.todo.tooltip or "")
        else
            error("Unknown editor " .. tostring(self.editor))
        end
        self.Editor:Show()
    elseif self.mode == MODE_TAB_BASIC then
        self.Editor:Hide()
        if self.editor == FUNCTION_TAB_COMPLETED then
        elseif self.editor == FUNCTION_TAB_TEXT then
        elseif self.editor == FUNCTION_TAB_CLICK then
        elseif self.editor == FUNCTION_TAB_TOOLTIP then
        else
            error("Unknown editor " .. tostring(self.editor))
        end
    end
    self:ValidateScript()
end
function BtWTodoConfigTodoPanelMixin:SetEditor(editor)
    self.editor = editor
    self:Update()
end
function BtWTodoConfigTodoPanelMixin:SetMode(mode)
    self.mode = mode
    self:Update()
end
function BtWTodoConfigTodoPanelMixin:IterateTodos()
    local tbl = {}
    local tmp = {}
    for _,todo in ipairs(self.todos) do
        tbl[#tbl+1] = todo
        tmp[todo.id] = true
    end
    for _,todo in Internal.IterateTodos() do
        if not tmp[todo.id] then
            tbl[#tbl+1] = todo
        end
    end
    table.sort(tbl, function (a, b)
        if a.name == b.name then
            -- Just want a consistent ordering, doesnt matter we are
            -- converting ints to strings prevents numerical ordering
            return tostring(a.id) < tostring(b.id)
        end
        return a.name < b.name
    end)

    return function (tbl, index)
        index = index + 1
        if tbl[index] then
            return index, tbl[index]
        end
    end, tbl, 0
end
function BtWTodoConfigTodoPanelMixin:okay()
    xpcall(function()
        for id,data in pairs(self.todos) do
            local tbl = {}
            tbl.id = id
            tbl.name = data.name

            tbl.states = {}
            for _,state in ipairs(data.states) do
                tbl.states[#tbl.states+1] = state.source
            end

            tbl.completed = data.completed
            tbl.text = data.text
            tbl.click = data.click
            tbl.tooltip = data.tooltip
            tbl.version = data.version

            Internal.SaveTodo(tbl)
        end

        External.TriggerEvent("TODOS_CHANGED")
    end, geterrorhandler())
end
function BtWTodoConfigTodoPanelMixin:cancel()
    xpcall(function()
        self.AddItem:Hide()
    end, geterrorhandler())
end
function BtWTodoConfigTodoPanelMixin:default()
    xpcall(function()
    end, geterrorhandler())
end
function BtWTodoConfigTodoPanelMixin:refresh()
    xpcall(function()
        wipe(self.todos)
        self.todo = nil

        UIDropDownMenu_SetText(self.TodoDropDown, L["Select a todo to edit"]);

        self.Name:Hide()
        self.RevertButton:Hide()
        self.States:Hide()
        self.AddButton:Hide()
        self.FunctionTabHeader:Hide()
        self.ModeTabHeader:Hide()
        self.Inset:Hide()
        self.Editor:Hide()
        self.AddStateText:Hide()
        self.ErrorText:Hide()
    end, geterrorhandler())
end

--  [[  Lists Panel  ]]

BtWTodoConfigTodoItemMixin = {}
function BtWTodoConfigTodoItemMixin:Init(data)
    self.data = data

    self.AddButton:SetShown(data.type == "category")
    self.VisibilityButton:SetShown(data.type == "todo")
    self.VisibilityButton.texture:SetTexture(data.hidden and 136315 or 136293)
    if data.type == "todo" then
        if BtWTodoConfigTodoPanel.todos[data.todo] then
            self:SetText(BtWTodoConfigTodoPanel.todos[data.todo].name)
        else
            self:SetText(External.GetTodoName(data.todo))
        end
        self.Text:SetTextColor(1, 1, 1, 1)
    elseif data.type == "category" then
        self:SetText(data.source.name)
        self.Text:SetTextColor(data.source.color:GetRGB())
    else
        error("Unknown data type " .. tostring(data.type))
    end
end
function BtWTodoConfigTodoItemMixin:Add()
    if self.data.type == "category" then
        local panel = self:GetParent():GetParent():GetParent()
        local addTodoCategory = self.data

        panel.AddItem:SetTitle(BTWTODO_ADD_TODO, BTWTODO_ADD_TODO_SUBTEXT)
        panel.AddItem:SetAutoCompleteCallback(function (_, tbl, text, offset, length)
            local text = strsub(text, offset, length):lower()
            for _,todo in BtWTodoConfigTodoPanel:IterateTodos() do
                local name = todo.name:lower()
                if #name >= #text and strsub(name, offset, length) == text then
                    tbl[#tbl+1] = todo.name
                end
            end
        end)
        panel.AddItem:SetOnOkayCallback(function ()
            local name = panel.AddItem:GetText()
            local lower = name:lower()
            local addTodo = nil
            for _,todo in BtWTodoConfigTodoPanel:IterateTodos() do
                if todo.name:lower() == lower then
                    addTodo = todo

                    break
                end
            end

            if addTodo then
                panel.AddItem:Clear()
                panel.AddItem:Hide()

                local list = panel:GetList()
                local dataProvider = list.todos
                for i=addTodoCategory.orderIndex+1,dataProvider:GetSize() do
                    local item = dataProvider:Find(i)
                    item.orderIndex = item.orderIndex+1
                end
                local elementData = { type = "todo", todo = addTodo.id, orderIndex = addTodoCategory.orderIndex+1 }
                dataProvider:Insert(elementData);
                panel.TodoScrollBox:ScrollToElementDataIndex(elementData.orderIndex + 1, ScrollBoxConstants.AlignNearest)
            else
                UIErrorsFrame:AddMessage(format(L["Unknown todo %s"], name), 1.0, 0.1, 0.1, 1.0);
            end
        end)
        panel.AddItem:Show()
    end
end
function BtWTodoConfigTodoItemMixin:ToggleVisibility()
    if self.data.type == "todo" then
        self.data.hidden = not self.data.hidden
        self.VisibilityButton.texture:SetTexture(self.data.hidden and 136315 or 136293)
    end
end
function BtWTodoConfigTodoItemMixin:Edit()
    if self.data.type == "todo" then
        InterfaceOptionsFrame_OpenToCategory(BTWTODO_TODOS)
        BtWTodoConfigTodoPanel:SetTodo(self.data.todo)
    elseif self.data.type == "category" then
        local source = self.data.source
        ColorPickerFrame.previousValues = { source.color:GetRGB() }
        ColorPickerFrame:SetColorRGB(source.color:GetRGB())
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = function ()
            source.color:SetRGBA(ColorPickerFrame:GetColorRGB())
            self.Text:SetTextColor(source.color:GetRGB())
        end
        ColorPickerFrame.cancelFunc = function (previousValues)
            source.color:SetRGBA(unpack(previousValues))
            self.Text:SetTextColor(source.color:GetRGB())
        end
        ColorPickerFrame:Hide() -- Incase its already visible
        ColorPickerFrame:Show()
    end
end
function BtWTodoConfigTodoItemMixin:Delete()
    self:GetParent():GetParent():Remove(self.data.orderIndex)
end

local function ListDropDown_Initialize(self, level, menuList)
    local frame = self:GetParent()
    local selected = frame:GetList()

	local info = UIDropDownMenu_CreateInfo();
    info.func = function (self, arg1, arg2, checked)
        frame:SetList(arg1)
    end

    local tbl = {}
    for _,item in IterateLists() do
        tbl[#tbl+1] = item
    end
    table.sort(tbl, function (a, b)
        if a.name == b.name then
            return tostring(a.id) < tostring(b.id)
        end
        return a.name < b.name
    end)
    for _,item in ipairs(tbl) do
        info.text = item.name or item.id
        info.arg1 = item.id
        info.checked = selected == item
        UIDropDownMenu_AddButton(info, level);
    end
end

BtWTodoConfigListsPanelMixin = {}
function BtWTodoConfigListsPanelMixin:OnLoad()
    self.lists = {}
    self.list = nil

    UIDropDownMenu_SetWidth(self.ListDropDown, 175);
    UIDropDownMenu_JustifyText(self.ListDropDown, "LEFT");
    UIDropDownMenu_Initialize(self.ListDropDown, ListDropDown_Initialize);

    self.Name:SetScript("OnTextChanged", function (_)
        if self.list == nil then
            return
        end

        self.list.name = self.Name:GetText()
        UIDropDownMenu_SetText(self.ListDropDown, self.list.name)
    end)

    do -- Todos
        local view = CreateScrollBoxListLinearView();
        view:SetElementExtent(30);
        view:SetElementInitializer("Button", "BtWTodoConfigTodoItemTemplate", function(button, elementData)
            button:Init(elementData);
            local startIndex, endIndex = self.TodoScrollBox:GetDragRange()
            button.Drag:SetShown(startIndex and elementData.orderIndex >= startIndex and elementData.orderIndex <= endIndex)
        end);
        ScrollUtil.InitScrollBoxListWithScrollBar(self.TodoScrollBox, self.TodoScrollBar, view);
    end

    self.AddItem:SetOnCancelCallback(function ()
        self.AddItem:Clear()
        self.AddItem:Hide()
    end)

    InterfaceOptions_AddCategory(self)
end
function BtWTodoConfigListsPanelMixin:GetList()
    return self.list
end
function BtWTodoConfigListsPanelMixin:SetList(id)
	self.list = self.lists[id]
	if not self.list then
        local tbl = Internal.GetList(id)
        if not tbl then
            error("Unknown list " .. tostring(id))
        end

        local list = {}

        list.id = tbl.id
        list.name = tbl.name
        list.version = tbl.version

        local listData = {};
        local previousCategory
        for _,item in ipairs(tbl.todos) do
            if previousCategory ~= item.category then
                listData[#listData+1] = { type = "category", category = item.category, source = self.categories[item.category], orderIndex = #listData+1 }
                previousCategory = item.category
            end
    
            listData[#listData+1] = { type = "todo", todo = item.id, hidden = item.hidden, version = item.version, orderIndex = #listData+1 }
        end

        local dataProvider = CreateDataProvider(listData);
        dataProvider:SetSortComparator(function (a, b)
            return a.orderIndex < b.orderIndex
        end, true)
        list.todos = dataProvider
        self.lists[id] = list
        self.list = list
	end

    UIDropDownMenu_SetText(self.ListDropDown, self.list.name)
    self.Name:SetText(self.list.name)
    self.Name:SetCursorPosition(0)
    self.TodoScrollBox:SetDataProvider(self.list.todos)
end
function BtWTodoConfigListsPanelMixin:AddList()
    local count = #BtWTodoLists+1
    while self.lists[count] or BtWTodoLists[count] do
        count = count + 1
    end
    local list = {
        id = count,
        name = L["New List"],
        todos = {},
    }

    local dataProvider = CreateDataProvider()
    dataProvider:SetSortComparator(function (a, b)
        return a.orderIndex < b.orderIndex
    end, true)
    list.todos = dataProvider

    self.lists[count] = list
    self:SetList(count)
    self.Name:SetFocus()
end
function BtWTodoConfigListsPanelMixin:CloneList()
    if not self.list then
        return
    end

    local count = #BtWTodoLists+1
    while self.lists[count] or BtWTodoLists[count] do
        count = count + 1
    end
    local list = {
        id = count,
        name = format(L["%s (Clone)"], self.list.name),
        todos = {},
    }

    local dataProvider = CreateDataProvider(self.list.todos.collection)
    dataProvider:SetSortComparator(function (a, b)
        return a.orderIndex < b.orderIndex
    end, true)
    list.todos = dataProvider

    self.lists[count] = list
    self:SetList(count)
    self.Name:SetFocus()
end
function BtWTodoConfigListsPanelMixin:GetCategoryByName(name)
    for id,category in pairs(self.categories) do
        if category.name == name then
            return category
        end
    end

    local category = { id = #self.categories+1, name = name, color = CreateColor(math.random(), math.random(), math.random(), 1) }
    self.categories[category.id] = category
    return category
end
function BtWTodoConfigListsPanelMixin:OnAddCategoryClicked()
    self.AddItem:SetTitle(BTWTODO_ADD_CATEGORY, BTWTODO_ADD_CATEGORY_SUBTEXT)
    self.AddItem:SetAutoCompleteCallback(function (_, tbl, text, offset, length)
        local text = strsub(text, offset, length):lower()
        for _,category in Internal.IterateCategories() do
            local name = category.name:lower()
            if #name >= #text and strsub(name, offset, length) == text then
                tbl[#tbl+1] = category.color:WrapTextInColorCode(category.name)
            end
        end
    end)
    self.AddItem:SetOnOkayCallback(function (_, text)
        local category = self:GetCategoryByName(text)

        local list = self:GetList()
        local dataProvider = list.todos
        local orderIndex = dataProvider:GetSize() + 1
        local elementData = { type = "category", category = category.id, source = category, orderIndex = orderIndex }
        dataProvider:Insert(elementData);
        self.TodoScrollBox:ScrollToElementDataIndex(orderIndex, ScrollBoxConstants.AlignNearest)

        self.AddItem:Clear()
        self.AddItem:Hide()
    end)
    self.AddItem:Show()
end
function BtWTodoConfigListsPanelMixin:okay()
    xpcall(function()
        do
            for id,category in pairs(self.categories) do
                External.UpdateCategory(id, category.name, category.color)
            end
        end

        for id,list in pairs(self.lists) do
            local categories, todos = {["none"] = 0}, {}
            local category = nil
            local categoryOrderIndex, orderIndex = 1, 1
            for _,item in list.todos:Enumerate() do
                if item.type == "category" then
                    categories[item.category] = categoryOrderIndex
                    categoryOrderIndex = categoryOrderIndex + 1

                    category = item.category
                else
                    todos[#todos+1] = { id = item.todo, category = category, hidden = item.hidden, version = item.version, orderIndex = orderIndex }
                    orderIndex = orderIndex + 1
                end
            end

            sort(todos, function (a, b)
                if a == nil and b == nil then
                    return false
                end
                if a == nil then
                    return true
                end
                if b == nil then
                    return false
                end

                if categories[a.category or "none"] ~= categories[b.category or "none"] then
                    return categories[a.category or "none"] < categories[b.category or "none"]
                end
                if a.orderIndex ~= b.orderIndex then
                    return a.orderIndex < b.orderIndex
                end
                return a.id < b.id
            end)

            if Internal.UpdateList({
                id = id,
                name = list.name,
                version = list.version,
                todos = todos,
            }) then
                External.TriggerEvent("LIST_CHANGED", id)
            end
        end
    end, geterrorhandler())
end
function BtWTodoConfigListsPanelMixin:cancel()
    xpcall(function()
        self.AddItem:Hide()
        -- If we live update lists we should reset them here
    end, geterrorhandler())
end
-- function BtWTodoConfigListsPanelMixin:default()
--     xpcall(function()
--     end, geterrorhandler())
-- end
function BtWTodoConfigListsPanelMixin:refresh()
    xpcall(function()
        do
            local categories = {}
            for id,category in Internal.IterateCategories() do
                categories[id] = category
            end
            self.categories = categories
        end

        wipe(self.lists)
        if self:IsShown() then
            self:SetList(BtWTodoWindows.main.list)
        end
    end, geterrorhandler())
end

--  [[  Windows Panel  ]]

BtWTodoConfigCharacterItemMixin = {}
function BtWTodoConfigCharacterItemMixin:Init(data)
    self.data = data

    if data.character == "PLAYER" then
        self:SetText(L["Current Player"])
    else
        local character = Internal.GetCharacter(data.character)
        self:SetText(character:GetDisplayName(true))
    end
    self.Text:SetTextColor(1, 1, 1, 1)
end
function BtWTodoConfigCharacterItemMixin:Delete()
    self:GetParent():GetParent():Remove(self.data.orderIndex)
end

local frameNames = {
    main = L["Main"],
    small = L["Small"],
    tooltip = L["Tooltip"],
}

BtWTodoConfigWindowsPanelMixin = {}
function BtWTodoConfigWindowsPanelMixin:OnLoad()
    self.frames = {}

    UIDropDownMenu_SetWidth(self.FrameDropDown, 175);
    UIDropDownMenu_JustifyText(self.FrameDropDown, "LEFT");
    UIDropDownMenu_Initialize(self.FrameDropDown, function (_, level, menuList)
        local selected = self:GetFrame()

        local info = UIDropDownMenu_CreateInfo();
        info.func = function (_, arg1, arg2, checked)
            self:SwitchFrame(arg1)
        end
    
        local tbl = {}
        for id in pairs(self.frames) do
            tbl[#tbl+1] = id
        end
        table.sort(tbl)
        for _,id in ipairs(tbl) do
            info.text = frameNames[id]
            info.arg1 = id
            info.checked = selected == self.frames[id];
            UIDropDownMenu_AddButton(info, level);
        end
    end);

    UIDropDownMenu_SetWidth(self.ListDropDown, 150);
    UIDropDownMenu_JustifyText(self.ListDropDown, "LEFT");
    UIDropDownMenu_Initialize(self.ListDropDown, function (_, level, menuList)
        if not self.frame then
            return
        end

        local selected = self.frame.list

        local info = UIDropDownMenu_CreateInfo();
        info.func = function (_, arg1, arg2, checked)
            self.frame.list = arg1
            UIDropDownMenu_SetText(self.ListDropDown, GetList(arg1).name)
        end

        local tbl = {}
        for _,item in IterateLists() do
            tbl[#tbl+1] = item
        end
        table.sort(tbl, function (a, b)
            if a.name == b.name then
                return tostring(a.id) < tostring(b.id)
            end
            return a.name < b.name
        end)
        for _,item in ipairs(tbl) do
            info.text = item.name or item.id
            info.arg1 = item.id
            info.checked = selected == item.id
            UIDropDownMenu_AddButton(info, level);
        end
    end);

    do -- Characters
        local view = CreateScrollBoxListLinearView();
        view:SetElementExtent(30);
        view:SetElementInitializer("Button", "BtWTodoConfigCharacterItemTemplate", function(button, elementData)
            button:Init(elementData);
            local startIndex, endIndex = self.CharacterScrollBox:GetDragRange()
            button.Drag:SetShown(startIndex and elementData.orderIndex >= startIndex and elementData.orderIndex <= endIndex)
        end);
        ScrollUtil.InitScrollBoxListWithScrollBar(self.CharacterScrollBox, self.CharacterScrollBar, view);
    end

    self.AddItem:SetOnCancelCallback(function ()
        self.AddItem:Clear()
        self.AddItem:Hide()
    end)

    InterfaceOptions_AddCategory(self)
end
function BtWTodoConfigWindowsPanelMixin:GetFrame()
    return self.frame
end
function BtWTodoConfigWindowsPanelMixin:SwitchFrame(id)
	local frame = self.frames[id]
	if not frame then
		error("Unknown frame " .. tostring(id))
	end

    self.frame = frame

    UIDropDownMenu_SetText(self.FrameDropDown, frameNames[id])
    UIDropDownMenu_SetText(self.ListDropDown, GetList(frame.list).name)
    self.CharacterScrollBox:SetDataProvider(frame.characters);
    self.ItemWidthEditBox:SetNumber(frame.itemWidth)
    self.ItemHeightEditBox:SetNumber(frame.itemHeight)
    self.AutoAddPlayerCheckbox:SetChecked(frame.addPlayer)
    self.ItemWidthEditBox:SetCursorPosition(0)
    self.ItemHeightEditBox:SetCursorPosition(0)
end
local currentPlayerMatch = {
    ["current player"] = true,
    ["player"] = true,
    [L["Current Player"]:lower()] = true,
    [L["Player"]:lower()] = true,
}
function BtWTodoConfigWindowsPanelMixin:OnAddCharacterClicked()
    self.AddItem:SetTitle(BTWTODO_ADD_CHARACTER, BTWTODO_ADD_CHARACTER_SUBTEXT)
    self.AddItem:SetAutoCompleteCallback(function (_, tbl, text, offset, length)
        local text = strsub(text, offset, length):lower()
        for _,character in Internal.IterateCharacters() do
            local name = character:GetDisplayName(true, true):lower()
            if #name >= #text and strsub(name, offset, length) == text then
                tbl[#tbl+1] = character:GetDisplayName(true, false)
            end
        end
    end)
    self.AddItem:SetOnOkayCallback(function (_, text)
        local key = nil
        if currentPlayerMatch[text:lower()] then
            key = "PLAYER"
        else
            local character = Internal.FindCharacter(text)
            if character == nil then
                UIErrorsFrame:AddMessage(format(L["Unknown character %s"], text), 1.0, 0.1, 0.1, 1.0);
                return
            end

            key = character.key
        end

        local frame = self:GetFrame()
        local dataProvider = frame.characters
        local orderIndex = dataProvider:GetSize() + 1
        local elementData = { type = "character", character = key, orderIndex = dataProvider:GetSize() + 1 }
        dataProvider:Insert(elementData);
        self.CharacterScrollBox:ScrollToElementDataIndex(orderIndex, ScrollBoxConstants.AlignNearest)

        self.AddItem:Clear()
        self.AddItem:Hide()
    end)
    self.AddItem:Show()
end
function BtWTodoConfigWindowsPanelMixin:ToggleAutoAddPlayer()
    local frame = self:GetFrame()
    if frame then
        frame.addPlayer = not frame.addPlayer
    end
end
function BtWTodoConfigWindowsPanelMixin:SetItemWidth(value)
    local frame = self:GetFrame()
    if frame then
        frame.itemWidth = value
    end
end
function BtWTodoConfigWindowsPanelMixin:SetItemHeight(value)
    local frame = self:GetFrame()
    if frame then
        frame.itemHeight = value
    end
end
function BtWTodoConfigWindowsPanelMixin:okay()
    xpcall(function()
        for id,frame in pairs(self.frames) do
            BtWTodoWindows[id].list = frame.list
            BtWTodoWindows[id].addPlayer = frame.addPlayer
            BtWTodoWindows[id].itemWidth = frame.itemWidth
            BtWTodoWindows[id].itemHeight = frame.itemHeight

            local characters = {}
            for _,item in frame.characters:Enumerate() do
                characters[#characters+1] = item.character
            end

            BtWTodoWindows[id].characters = characters

            External.TriggerEvent("FRAME_CHANGED", id)
        end
    end, geterrorhandler())
end
function BtWTodoConfigWindowsPanelMixin:cancel()
    xpcall(function()
        self.AddItem:Hide()
    end, geterrorhandler())
end
-- function BtWTodoConfigWindowsPanelMixin:default()
--     xpcall(function()
--     end, geterrorhandler())
-- end
function BtWTodoConfigWindowsPanelMixin:refresh()
    xpcall(function()
        for id,settings in pairs(BtWTodoWindows) do
            local result = {}

            result.list = settings.list
            result.addPlayer = settings.addPlayer
            result.itemWidth = settings.itemWidth or 120
            result.itemHeight = settings.itemHeight or 24

            do -- Characters
                local listData = {};
                for _,item in ipairs(settings.characters) do
                    listData[#listData+1] = { type = "character", character = item, orderIndex = #listData+1 }
                end

                local dataProvider = CreateDataProvider(listData);
                dataProvider:SetSortComparator(function (a, b)
                    return a.orderIndex < b.orderIndex
                end, true)
                result.characters = dataProvider
            end

            self.frames[id] = result
        end

        self:SwitchFrame("main")
    end, geterrorhandler())
end

function External.OpenConfiguration()
	if not InterfaceOptionsFrame:IsShown() then
        InterfaceOptionsFrame_Show()
    end
    InterfaceOptionsFrame_OpenToCategory(ADDON_NAME)
end
