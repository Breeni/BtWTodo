local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

BtWTodoItemMixin = {}
function BtWTodoItemMixin:OnLoad()
    self:RegisterForDrag("LeftButton");
end
function BtWTodoItemMixin:Init(data)
	if self.type == "todo" then
		Internal.UnregisterEventsFor(self)
	end

	Mixin(self, data)

	if self.type == "todo" then
		self.todo:SetCharacter(self.character)
		self.todo:RegisterEventsFor(self, self.character:IsPlayer())
        Internal.RegisterEvent(self, "MODIFIER_STATE_CHANGED", "Update")
	end

	self:Update()
end
function BtWTodoItemMixin:Update()
	if self.type == "corner" then
		self:SetText("")
	elseif self.type == "character" then
		self:SetText(self.character:GetDisplayName())
		self:GetFontString():SetJustifyH("CENTER")
	elseif self.type == "title" then
		self:SetText(self.todo:GetName())
		self:GetFontString():SetJustifyH("LEFT")
	elseif self.type == "todo" then
		self.todo:SetCharacter(self.character)
		self:SetText(self.todo:GetText())
		self:GetFontString():SetJustifyH("CENTER")
	elseif self.type == "category" then
		self:SetText(self.category)
	end

	if self:IsMouseOver() and self:IsVisible() then
		self:OnEnter()
	end
end
function BtWTodoItemMixin:RegisterEvents(...)
    for i=1,select('#', ...) do
        Internal.RegisterEvent(self, (select(i, ...)), "Update")
    end
end
function BtWTodoItemMixin:OnClick(...)
	if self.type == "todo" and self.todo:SupportsClick() then
		self.todo:SetCharacter(self.character)
		self.todo:Click(...)
		self:Update()
	end
end
function BtWTodoItemMixin:OnDragStart()
	local frame = self:GetParent():GetParent():GetParent():GetParent()
	if frame.OnDragStart then
		frame.OnDragStart(frame)
	end
end
function BtWTodoItemMixin:OnDragStop()
	local frame = self:GetParent():GetParent():GetParent():GetParent()
	if frame.OnDragStop then
		frame.OnDragStop(frame)
	end
end
function BtWTodoItemMixin:OnEnter()
	if self.type == "todo" and self.todo:SupportsTooltip() then
		self.todo:SetCharacter(self.character)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		self.todo:UpdateTooltip(GameTooltip)
		GameTooltip:Show()
	end
end
function BtWTodoItemMixin:OnLeave()
	GameTooltip:Hide()
end

BtWTodoRowMixin = {}
function BtWTodoRowMixin:OnLoad()
    self:RegisterForDrag("LeftButton");
    self.pool = CreateFramePool("Button", self, "BtWTodoItemTemplate")

	PixelUtil.SetHeight(self.Left, 1)
	PixelUtil.SetPoint(self.Left, "LEFT", self, "LEFT", 0, -1);
	PixelUtil.SetPoint(self.Left, "RIGHT", self.Text, "LEFT", -10, -1);

	PixelUtil.SetHeight(self.Right, 1)
	PixelUtil.SetPoint(self.Right, "RIGHT", self, "RIGHT", 0, -1);
	PixelUtil.SetPoint(self.Right, "LEFT", self.Text, "RIGHT", 10, -1);
end
function BtWTodoRowMixin:Init(data, itemWidth)
	Mixin(self, data)
	self.itemWidth = itemWidth

	self:Update()
end
function BtWTodoRowMixin:GetCharacters()
	return {}
end
function BtWTodoRowMixin:Update()
	self.pool:ReleaseAll()

	if self.type == "category" then
		local category = External.GetCategory(self.category)
		self.Text:SetText(category.name)
		self.Text:SetTextColor(category.color:GetRGBA())
		self.Left:SetColorTexture(category.color:GetRGBA())
		self.Right:SetColorTexture(category.color:GetRGBA())
		self.Text:Show()
		self.Left:Show()
		self.Right:Show()
	elseif self.type == "character" then
		self.Text:SetText(self:GetCharacters()[1]:GetDisplayName())
		self.Text:SetTextColor(1, 1, 1, 1)
		self.Text:Show()
		self.Left:Hide()
		self.Right:Hide()
	elseif self.type == "characters" then
		local frame = self.pool:Acquire()
		frame:Init({ type = "corner" })
		frame:SetWidth(self.itemWidth)
		frame:SetPoint("LEFT")
		frame:Show()

		local previousFrame = frame
		for _,character in ipairs(self:GetCharacters()) do
			local frame = self.pool:Acquire()
			frame:Init({ type = "character", character = character })
			frame:SetWidth(self.itemWidth)
			frame:SetPoint("LEFT", previousFrame, "RIGHT")
			frame:Show()
			previousFrame = frame
		end
		self.Text:Hide()
		self.Left:Hide()
		self.Right:Hide()
	elseif self.type == "todos" then
		local frame = self.pool:Acquire()
		frame:Init({ type = "title", todo = self.todo })
		frame:SetWidth(self.itemWidth)
		frame:SetPoint("LEFT")
		frame:Show()

		local previousFrame = frame
		for _,character in ipairs(self:GetCharacters()) do
			local frame = self.pool:Acquire()
			frame:Init({ type = "todo", todo = self.todo, character = character })
			frame:SetWidth(self.itemWidth)
			frame:SetPoint("LEFT", previousFrame, "RIGHT")
			frame:Show()
			previousFrame = frame
		end
		self.Text:Hide()
		self.Left:Hide()
		self.Right:Hide()
	end
end
function BtWTodoRowMixin:OnDragStart()
	local frame = self:GetParent():GetParent():GetParent()
	if frame.OnDragStart then
		frame.OnDragStart(frame)
	end
end
function BtWTodoRowMixin:OnDragStop()
	local frame = self:GetParent():GetParent():GetParent()
	if frame.OnDragStop then
		frame.OnDragStop(frame)
	end
end

BtWTodoScrollRowMixin = {}
function BtWTodoScrollRowMixin:GetCharacters()
	return self:GetParent():GetParent():GetParent():GetCharacters()
end


BtWTodoViewMixin = {}
function BtWTodoViewMixin:OnLoad()
	local view = CreateScrollBoxListLinearView();
	view:SetElementExtent(self:GetItemHeight())
	view:SetElementInitializer("Button", "BtWTodoScrollRowTemplate", function(list, elementData)
		list:Init(elementData, self:GetItemWidth());
		list:SetHeight(self:GetItemHeight())
	end);

	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);
end
function BtWTodoViewMixin:UpdateView()
	if self:GetCharacters() == nil or self:GetTodos() == nil then
		return
	end

	local listDatas = {};
	if #self:GetCharacters() == 1 then
		listDatas[#listDatas+1] = { type = "character" }
	else
		listDatas[#listDatas+1] = { type = "characters" }
	end

	local previousCategory = nil
	for _,todo in ipairs(self:GetTodos()) do
		if todo.category ~= previousCategory then
			listDatas[#listDatas+1] = { category = todo.category, type = "category" }
			previousCategory = todo.category
		end

		listDatas[#listDatas+1] = { todo = todo, type = "todos" }
	end

	self.ScrollBar:Hide()
	if self.ScrollBar:IsShown() then
		self:SetWidth((self:GetCharacterCount() + 1) * self:GetItemWidth() + self:GetPaddingHorizontal() + 20) -- 20 is the gap/width for scrollbar
	else
		self:SetWidth((self:GetCharacterCount() + 1) * self:GetItemWidth() + self:GetPaddingHorizontal())
	end
	self:SetHeight(#listDatas * self:GetItemHeight() + self:GetPaddingVertical())

	local dataProvider = CreateDataProvider(listDatas);
	self.ScrollBox:SetDataProvider(dataProvider);
end
function BtWTodoViewMixin:Update()
	self.ScrollBox:ForEachFrame(function(list)
		list:Update();
	end);
end
function BtWTodoViewMixin:SetPadding(top, left, bottom, right)
	top = math.max(top, 0)
	left = math.max(left, 0)
	bottom = math.max(bottom, 0)
	right = math.max(right, 0)

	self.paddingHorizontal = left + right
	self.paddingVertical = top + bottom

	self.ScrollBox:SetPoint("TOPLEFT", left, -top)
	self.ScrollBox:SetPoint("BOTTOMRIGHT", -right, bottom)

	self.ScrollBar:SetPoint("TOPRIGHT", -right + 20, -top + 10)
	self.ScrollBar:SetPoint("BOTTOM", 0, bottom - 10)
end
function BtWTodoViewMixin:GetPaddingHorizontal()
	return self.paddingHorizontal or 1
end
function BtWTodoViewMixin:GetPaddingVertical()
	return self.paddingVertical or 1
end
function BtWTodoViewMixin:SetItemSize(w, h)
	self:SetItemWidth(w)
	self:SetItemHeight(h)
end
function BtWTodoViewMixin:SetItemWidth(value)
	self.itemWidth = math.max(value, 1)
end
function BtWTodoViewMixin:GetItemWidth()
	return self.itemWidth or 1
end
function BtWTodoViewMixin:SetItemHeight(value)
	self.itemHeight = math.max(value, 1)
end
function BtWTodoViewMixin:GetItemHeight()
	return self.itemHeight or 1
end
function BtWTodoViewMixin:SetCharacters(characters)
	self.characters = characters
	self:UpdateView()
end
function BtWTodoViewMixin:GetCharacters()
	return self.characters
end
function BtWTodoViewMixin:GetCharacterCount()
	return #self.characters
end
function BtWTodoViewMixin:SetTodos(todos)
	self.todos = todos
	self:UpdateView()
end
function BtWTodoViewMixin:GetTodos()
	return self.todos
end
function BtWTodoViewMixin:GetTodoCount()
	return #self.todos
end

BtWTodoDraggableViewMixin = {}
function BtWTodoDraggableViewMixin:OnLoad()
    self:RegisterForDrag("LeftButton");
	BtWTodoViewMixin.OnLoad(self)
end
function BtWTodoDraggableViewMixin:OnDragStart()
    self:StartMoving();
end
function BtWTodoDraggableViewMixin:OnDragStop()
    self:StopMovingOrSizing();
end

local frames = {}
BtWTodoFrameMixin = {}
function BtWTodoFrameMixin:OnLoad()
	frames[#frames+1] = self
	BtWTodoDraggableViewMixin.OnLoad(self)
	self:SetItemSize(self.itemWidth or 100, self.itemHeight or 24)
	self:SetPadding(self.paddingTop or 12, self.paddingLeft or 16, self.paddingBottom or 12, self.paddingRight or 16)
end
function BtWTodoFrameMixin:OnShow()
	BtWTodoWindows[self.id].show = true
    self:Init()
end
function BtWTodoFrameMixin:OnHide()
	BtWTodoWindows[self.id].show = nil
end
function BtWTodoFrameMixin:SetList(id)
	local list = Internal.GetList(id)
	if not list then
		error("Unknown list " .. tostring(id))
	end

	local todos = {}
	for _,item in ipairs(list.todos) do
		if not item.hidden then
			local todo = External.CreateTodoByID(item.id)
			todo.category = item.category
			todos[#todos+1] = todo
		end
	end
	self:SetTodos(todos)
end
function BtWTodoFrameMixin:Init()
	if not self.initialized then
		local settings = BtWTodoWindows[self.id]
		if not settings then
			error("Missing settings for window " .. tostring(self.id))
		end

		self:SetItemSize(settings.itemWidth or 100, settings.itemHeight or 24)

		local characters = {}
		local addedPlayer = false
		for _,character in ipairs(settings.characters) do
			local result
			if character == "PLAYER" then
				result = Internal.GetPlayer()
			else
				result = Internal.GetCharacter(character)
			end

			if not result:IsPlayer() or not addedPlayer then
				characters[#characters+1] = result
				if result:IsPlayer() then
					addedPlayer = true
				end
			end
		end
		self:SetCharacters(characters)

		self:SetList(settings.list)
		self.initialized = true
	end
end

BtWTodoMainFrameMixin = {}
function BtWTodoMainFrameMixin:OnLoad()
	BtWTodoFrameMixin.OnLoad(self)
	self.TitleText:SetText(ADDON_NAME)
	self.TitleText:SetHeight(24)
	
    tinsert(UISpecialFrames, self:GetName());
end

BtWTodoTooltipFrameMixin = {}
function BtWTodoTooltipFrameMixin:OnLoad()
	BackdropTemplateMixin.OnBackdropLoaded(self)
	BtWTodoFrameMixin.OnLoad(self)
end

function External.ToggleMainFrame()
	BtWTodoMainFrame:SetShown(not BtWTodoMainFrame:IsShown())
end
function External.ToggleSmallFrame()
	BtWTodoSmallFrame:SetShown(not BtWTodoSmallFrame:IsShown())
end

Internal.RegisterEvent("FRAME_CHANGED", function (event, id)
	for _,frame in ipairs(frames) do
		if frame.id and BtWTodoWindows[frame.id] then
			frame.initialized = nil
			frame:Init()
		end
	end
end)
Internal.RegisterEvent("LIST_CHANGED", function (event, id)
	for _,frame in ipairs(frames) do
		if frame.id and BtWTodoWindows[frame.id] and BtWTodoWindows[frame.id].list == id then
			frame:SetList(id)
		end
	end
end)
Internal.RegisterEvent("TODOS_CHANGED", function ()
	for _,frame in ipairs(frames) do
		-- Should just refresh individual todos not entire frame
		if frame.id and BtWTodoWindows[frame.id] then
			frame:SetList(BtWTodoWindows[frame.id].list)
		end
	end
end)

local function ADDON_LOADED(_, addon)
    if addon == ADDON_NAME then
		-- We do this in 2 steps incase someone wipes BtWTodoWindows
		if not BtWTodoWindows then
            BtWTodoWindows = {}
        end
        if not BtWTodoWindows.tooltip then
            BtWTodoWindows.tooltip = {
				list = "btwtodo:default",
				characters = {},
				addPlayer = true,
				itemWidth = 120,
				itemHeight = 24,
			}
        end
        if not BtWTodoWindows.main then
            BtWTodoWindows.main = {
				show = false,
				list = "btwtodo:default",
				characters = {},
				addPlayer = true,
				itemWidth = 120,
				itemHeight = 24,
			}
        end
        if not BtWTodoWindows.small then
            BtWTodoWindows.small = {
				show = true,
				list = "btwtodo:default",
				characters = {"PLAYER"},
				itemWidth = 120,
				itemHeight = 24,
			}
        end

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED)

Internal.RegisterEvent("PLAYER_LOGIN", function ()
	for _,settings in pairs(BtWTodoWindows) do
		if settings.addPlayer then
			local player = Internal.GetPlayer()
			if not tContains(settings.characters, player.key) then
				tinsert(settings.characters, player.key)
			end
		end
	end

	if BtWTodoWindows.main.show then
		BtWTodoMainFrame:Show()
	end
	if BtWTodoWindows.small.show then
		BtWTodoSmallFrame:Show()
	end
end)
