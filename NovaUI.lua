local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Theme = {
	Background = Color3.fromRGB(18, 18, 18),
	Header = Color3.fromRGB(24, 24, 24),
	Module = Color3.fromRGB(28, 28, 28),
	ModuleHover = Color3.fromRGB(36, 36, 36),
	Settings = Color3.fromRGB(22, 22, 22),
	Accent = Color3.fromRGB(38, 208, 124),
	Text = Color3.fromRGB(235, 235, 235),
	SubText = Color3.fromRGB(145, 145, 145),
	Track = Color3.fromRGB(50, 50, 50),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
}

local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function label(parent, text, size, color, align)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size or 13,
		Font = Theme.Font,
		TextColor3 = color or Theme.Text,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local Library = {}
Library.__index = Library
Library.Theme = Theme

local THEME_KEYS = { "Accent", "Background", "Header", "Module", "ModuleHover", "Settings", "Text", "SubText", "Track" }
local DefaultTheme = {}
for _, key in ipairs(THEME_KEYS) do DefaultTheme[key] = Theme[key] end
Library.Unloaded = false
Library.Labels = {} 
Library.Options = {} 

local signals = {}         
local unloadCallbacks = {} 
local instances = {}       

local Category = {}
Category.__index = Category

local Module = {}
Module.__index = Module

local function makeDraggable(lib, handle, target)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)
	lib:_connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			target.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
		end
	end)
	lib:_connect(UserInputService.InputEnded, function(input)
		if isPress(input) then dragging = false end
	end)
end

local function setDimmed(root, dimmed, store)
	if dimmed then
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("GuiObject") and not store[d] then
				local isText = d:IsA("TextLabel") or d:IsA("TextButton")
				store[d] = { bg = d.BackgroundTransparency, text = isText and d.TextTransparency or nil }
				d.BackgroundTransparency = 1 - (1 - d.BackgroundTransparency) * 0.45
				if isText then d.TextTransparency = 1 - (1 - d.TextTransparency) * 0.45 end
			end
		end
	else
		for d, o in pairs(store) do
			if d.Parent then
				d.BackgroundTransparency = o.bg
				if o.text then d.TextTransparency = o.text end
			end
		end
		table.clear(store)
	end
end

local function attachCommon(api, row, onDisable)
	local store = {}
	api.Disabled = false
	api.Visible = true
	function api:SetVisible(state)
		api.Visible = state and true or false
		row.Visible = api.Visible
	end
	function api:SetDisabled(state)
		api.Disabled = state and true or false
		setDimmed(row, api.Disabled, store)
		if onDisable then onDisable(api.Disabled) end
	end
	function api:SetValue(v, silent)
		return api:Set(v, silent)
	end
end

local function buildDivider(parent, order, args, bg)
	if type(args) == "string" then args = { Text = args } end
	args = args or {}
	local margin = args.Margin or 0
	local top = args.MarginTop or margin
	local bottom = args.MarginBottom or margin

	local row = create("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12 + top + bottom),
		LayoutOrder = order,
		Parent = parent,
	})
	local inner = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = row,
	})
	create("Frame", {
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = inner,
	})
	if args.Text and args.Text ~= "" then
		local text = label(inner, args.Text, 11, Theme.SubText, Enum.TextXAlignment.Center)
		text.BackgroundTransparency = 0
		text.BackgroundColor3 = bg
		text.AutomaticSize = Enum.AutomaticSize.X
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromOffset(0, 12)
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = text })
	end

	local api = {}
	function api:Destroy() row:Destroy() end
	function api:SetVisible(state) row.Visible = state and true or false end
	return api
end

local function toHex(c)
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function parseHex(str)
	str = (str:gsub("[#%s]", ""))
	if #str ~= 6 or not str:match("^%x+$") then return nil end
	return Color3.fromRGB(tonumber(str:sub(1, 2), 16), tonumber(str:sub(3, 4), 16), tonumber(str:sub(5, 6), 16))
end

local function safeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[NovaUI] ColorPicker callback error: " .. tostring(err)) end
end

local function addColorPicker(owner, id, opts)
	if type(id) == "table" then opts, id = id, nil end
	opts = opts or {}
	local lib = owner._lib
	local hasTrans = opts.Transparency ~= nil
	local resizable = opts.Resizable ~= false
	local callbacks = {}

	local h, s, v = (opts.Default or Color3.new(1, 1, 1)):ToHSV()
	local transparency = hasTrans and math.clamp(opts.Transparency, 0, 1) or nil

	local api = { Disabled = false, IsOpen = false }
	local swatch, popup, sv, svCursor, hueBar, hueCursor, transBar, transFill, transCursor, hexBox
	local conns = {}

	local function refresh()
		local color = Color3.fromHSV(h, s, v)
		api.Value, api.Transparency, api.Hue, api.Sat, api.Vib = color, transparency, h, s, v
		swatch.BackgroundColor3 = color
		if popup then
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			svCursor.Position = UDim2.fromScale(s, 1 - v)
			hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
			if hasTrans then
				transFill.BackgroundColor3 = color
				transCursor.Position = UDim2.new(transparency, 0, 0.5, 0)
			end
			if not hexBox:IsFocused() then hexBox.Text = toHex(color) end
		end
	end

	local function fire(silent)
		refresh()
		if silent then return end
		if opts.Callback then safeCall(opts.Callback, api.Value, api.Transparency) end
		if opts.Changed then safeCall(opts.Changed, api.Value, api.Transparency) end
		for _, cb in ipairs(callbacks) do safeCall(cb, api.Value, api.Transparency) end
	end

	
	local parent = owner._cpPrepare()
	local offset = owner._cpOffset
	local anchorY = owner._cpAnchorY
	swatch = create("TextButton", {
		Name = "ColorPicker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHSV(h, s, v),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, anchorY),
		Position = UDim2.new(1, -offset, anchorY, anchorY == 0 and 1 or 0),
		Size = UDim2.fromOffset(24, 14),
		Parent = parent,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 3) }),
		create("UIStroke", { Color = Theme.Track, Thickness = 1 }),
	})
	swatch:SetAttribute("NoTheme", true) 
	owner._cpOffset = offset + 30
	owner._cpReserve(owner._cpOffset)

	local function ensurePopup()
		if popup then return end
		
		local extra = hasTrans and 20 or 0
		popup = create("Frame", {
			Name = "ColorPickerDialog",
			BackgroundColor3 = Theme.Settings,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(220, 262 + extra),
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 100,
			Parent = lib.Root,
		}, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

		
		local bar = create("Frame", {
			BackgroundColor3 = Theme.Header,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 36),
			Parent = popup,
		})
		local title = label(bar, opts.Title or "Color", 14, Theme.Text)
		title.Font = Theme.FontBold
		title.Position = UDim2.fromOffset(12, 0)
		title.Size = UDim2.new(1, -48, 1, 0)
		create("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			Parent = bar,
		})
		local close = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "×",
			TextSize = 20,
			Font = Theme.FontBold,
			TextColor3 = Theme.SubText,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 34, 1, -2),
			Parent = bar,
		})
		close.MouseEnter:Connect(function() tween(close, { TextColor3 = Theme.Text }) end)
		close.MouseLeave:Connect(function() tween(close, { TextColor3 = Theme.SubText }) end)
		close.MouseButton1Click:Connect(function() api:Close() end)
		makeDraggable(lib, bar, popup)

		
		local botHue = hasTrans and 66 or 46 
		local svMinus = 46 + botHue + 20
		sv = create("Frame", {
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 46),
			Size = UDim2.new(1, -24, 1, -svMinus),
			Parent = popup,
		}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = sv,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 4) }),
			create("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
		})
		create("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = sv,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 4) }),
			create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
		})
		svCursor = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = sv,
		}, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }),
		})

		
		local keys = {}
		for i = 0, 6 do
			table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
		end
		hueBar = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -botHue),
			Size = UDim2.new(1, -24, 0, 10),
			Parent = popup,
		}, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			create("UIGradient", { Color = ColorSequence.new(keys) }),
		})
		hueCursor = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(14, 14),
			Parent = hueBar,
		}, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }),
		})

		
		if hasTrans then
			transBar = create("Frame", {
				BackgroundColor3 = Theme.Track,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -46),
				Size = UDim2.new(1, -24, 0, 10),
				Parent = popup,
			}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			transFill = create("Frame", {
				BackgroundColor3 = Color3.fromHSV(h, s, v),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = transBar,
			}, {
				create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				create("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
			})
			transCursor = create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(14, 14),
				Parent = transBar,
			}, {
				create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }),
			})
		end

		
		hexBox = create("TextBox", {
			Text = toHex(Color3.fromHSV(h, s, v)),
			PlaceholderText = "#RRGGBB",
			PlaceholderColor3 = Theme.SubText,
			ClearTextOnFocus = false,
			Font = Theme.Font,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = Theme.Module,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.new(1, -24, 0, 24),
			Parent = popup,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 4) }),
			create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		})
		hexBox.FocusLost:Connect(function()
			local c = parseHex(hexBox.Text)
			if c then
				api:SetValueRGB(c)
			else
				hexBox.Text = toHex(api.Value)
			end
		end)

		
		sv:SetAttribute("NoTheme", true)
		hueBar:SetAttribute("NoTheme", true)
		if transBar then transBar:SetAttribute("NoTheme", true) end

		
		local mode, resizeStart, sizeStart = nil, nil, nil
		local function ratio(frame, input)
			return math.clamp((input.Position.X - frame.AbsolutePosition.X) / math.max(frame.AbsoluteSize.X, 1), 0, 1),
				math.clamp((input.Position.Y - frame.AbsolutePosition.Y) / math.max(frame.AbsoluteSize.Y, 1), 0, 1)
		end
		local function apply(input)
			if mode == "sv" then
				local rx, ry = ratio(sv, input)
				s, v = rx, 1 - ry
			elseif mode == "hue" then
				h = math.min((ratio(hueBar, input)), 0.9999)
			elseif mode == "trans" then
				transparency = (ratio(transBar, input))
			end
			fire()
		end
		local function bind(frame, m)
			frame.InputBegan:Connect(function(input)
				if isPress(input) then
					mode = m
					apply(input)
				end
			end)
		end
		bind(sv, "sv")
		bind(hueBar, "hue")
		if hasTrans then bind(transBar, "trans") end

		if resizable then
			local grip = create("TextLabel", {
				BackgroundTransparency = 1,
				Text = "◢",
				TextSize = 10,
				Font = Theme.Font,
				TextColor3 = Theme.SubText,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(12, 12),
				Parent = popup,
			})
			grip.InputBegan:Connect(function(input)
				if isPress(input) then
					resizeStart = input.Position
					sizeStart = Vector2.new(popup.Size.X.Offset, popup.Size.Y.Offset)
				end
			end)
		end

		table.insert(conns, lib:_connect(UserInputService.InputChanged, function(input)
			if not isMove(input) then return end
			if mode then
				apply(input)
			elseif resizeStart then
				local d = input.Position - resizeStart
				popup.Size = UDim2.fromOffset(
					math.max(180, sizeStart.X + d.X),
					math.max(hasTrans and 280 or 260, sizeStart.Y + d.Y)
				)
			end
		end))
		table.insert(conns, lib:_connect(UserInputService.InputEnded, function(input)
			if isPress(input) then
				mode, resizeStart = nil, nil
			end
		end))

		refresh()
	end

	
	function api._ownerShown()
		local inst = swatch
		while inst and inst ~= lib.Root do
			if inst:IsA("GuiObject") and not inst.Visible then return false end
			inst = inst.Parent
		end
		return inst == lib.Root
	end

	function api:Open()
		ensurePopup()
		if lib._openPicker and lib._openPicker ~= api then lib._openPicker:Close() end
		local root = lib.Root.AbsoluteSize
		local abs = swatch.AbsolutePosition
		local w, ht = popup.Size.X.Offset, popup.Size.Y.Offset
		popup.Position = UDim2.fromOffset(
			math.clamp(abs.X + 30, 0, math.max(root.X - w, 0)),
			math.clamp(abs.Y, 0, math.max(root.Y - ht, 0))
		)
		popup.Visible = true
		api.IsOpen = true
		lib._openPicker = api
	end

	function api:Close()
		if popup then popup.Visible = false end
		api.IsOpen = false
		if lib._openPicker == api then lib._openPicker = nil end
	end

	
	function api:SetValue(hsv, newTransparency, silent)
		h = math.clamp(hsv.H or hsv.h or hsv[1] or h, 0, 1)
		s = math.clamp(hsv.S or hsv.s or hsv[2] or s, 0, 1)
		v = math.clamp(hsv.V or hsv.v or hsv[3] or v, 0, 1)
		if type(newTransparency) == "number" then transparency = math.clamp(newTransparency, 0, 1) end
		fire(silent)
	end

	
	function api:SetValueRGB(color, newTransparency, silent)
		local nh, ns, nv = color:ToHSV()
		if ns > 0 and nv > 0 then h = nh end 
		s, v = ns, nv
		if type(newTransparency) == "number" then transparency = math.clamp(newTransparency, 0, 1) end
		fire(silent)
	end

	function api:OnChanged(fn)
		assert(type(fn) == "function", "OnChanged requires a function")
		table.insert(callbacks, fn)
	end

	function api:Destroy()
		for _, c in ipairs(conns) do c:Disconnect() end
		conns = {}
		api:Close()
		if popup then popup:Destroy() end
		swatch:Destroy()
		if id and Library.Options[id] == api then Library.Options[id] = nil end
	end

	swatch.MouseButton1Click:Connect(function()
		if owner.Disabled then return end
		if api.IsOpen then api:Close() else api:Open() end
	end)

	refresh()
	if id then Library.Options[id] = api end
	return api
end

function Library.new(opts)
	opts = opts or {}
	if Library.Unloaded then
		error("NovaUI has been unloaded and cannot create new windows")
	end
	local self = setmetatable({}, Library)
	table.insert(instances, self)
	self.Connections = {}
	self.Categories = {}
	self.Pages = {}
	self.CurrentPage = nil
	self.Modules = {}
	self.Listening = false
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

	self.Gui = create("ScreenGui", {
		Name = opts.Name or "NovaUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		Parent = gethui(),
	})

	self.Root = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = opts.StartOpen ~= false,
		Parent = self.Gui,
	})

	self.NotifyHolder = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(250, 400),
		Parent = self.Gui,
	}, {
		create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
		}),
	})

	if opts.Search ~= false then self:_buildSearch() end
	self:_buildPageMenu()
	
	local _saveName = (opts.Name or "NovaUI"):gsub("[^%w%-_]", "_")
	local _configDir = "NovaUI/" .. _saveName .. "/configs"
	local _themeDir  = "NovaUI/" .. _saveName .. "/themes"

	
	if not isfolder("NovaUI") then makefolder("NovaUI") end
	if not isfolder("NovaUI/" .. _saveName) then makefolder("NovaUI/" .. _saveName) end
	if not isfolder(_configDir) then makefolder(_configDir) end
	if not isfolder(_themeDir)  then makefolder(_themeDir)  end

	
	local function _serializeOptions()
		local data = {}
		for id, opt in pairs(Library.Options) do
			
			if not id:find("^Theme_") then
				local ok, v = pcall(function() return opt:Get() end)
				if ok then data[id] = v end
			end
		end
		
		for _, inst in ipairs(instances) do
			if inst == self then
				for _, mod in ipairs(inst.Modules or {}) do
					if mod.Name and mod.Enabled ~= nil then
						data["__mod_" .. mod.Name] = mod.Enabled
					end
				end
			end
		end
		return game:GetService("HttpService"):JSONEncode(data)
	end

	
	local function _deserializeOptions(raw)
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(raw)
		end)
		if not ok or type(data) ~= "table" then
			warn("[NovaUI] Failed to parse config file") return
		end
		for id, v in pairs(data) do
			if id:find("^__mod_") then
				local modName = id:sub(7)
				for _, inst in ipairs(instances) do
					if inst == self then
						for _, mod in ipairs(inst.Modules or {}) do
							if mod.Name == modName and type(v) == "boolean" then
								mod:SetEnabled(v)
							end
						end
					end
				end
			else
				local opt = Library.Options[id]
				if opt then
					pcall(function() opt:SetValue(v) end)
				end
			end
		end
	end

	
	local function _listFiles(dir)
		local names = {}
		for _, path in ipairs(listfiles(dir)) do
			local name = path:match("([^/\\]+)%.json$")
			if name then table.insert(names, name) end
		end
		table.sort(names)
		return names
	end

	self.ConfigHandlers = {
		List = function()
			return _listFiles(_configDir)
		end,
		Create = function(name)
			local path = _configDir .. "/" .. name .. ".json"
			writefile(path, _serializeOptions())
		end,
		Save = function(name)
			local path = _configDir .. "/" .. name .. ".json"
			writefile(path, _serializeOptions())
		end,
		Load = function(name)
			local path = _configDir .. "/" .. name .. ".json"
			if not isfile(path) then
				warn("[NovaUI] Config not found: " .. name) return
			end
			_deserializeOptions(readfile(path))
		end,
		Delete = function(name)
			local path = _configDir .. "/" .. name .. ".json"
			if isfile(path) then delfile(path) end
		end,
	}

	self.ThemeHandlers = {
		List = function()
			return _listFiles(_themeDir)
		end,
		Create = function(name)
			local path = _themeDir .. "/" .. name .. ".json"
			local theme = Library:GetTheme()
			local data = {}
			for k, c in pairs(theme) do
				data[k] = { r = c.R, g = c.G, b = c.B }
			end
			writefile(path, game:GetService("HttpService"):JSONEncode(data))
		end,
		Save = function(name)
			local path = _themeDir .. "/" .. name .. ".json"
			local theme = Library:GetTheme()
			local data = {}
			for k, c in pairs(theme) do
				data[k] = { r = c.R, g = c.G, b = c.B }
			end
			writefile(path, game:GetService("HttpService"):JSONEncode(data))
		end,
		Load = function(name)
			local path = _themeDir .. "/" .. name .. ".json"
			if not isfile(path) then
				warn("[NovaUI] Theme not found: " .. name) return
			end
			local ok, data = pcall(function()
				return game:GetService("HttpService"):JSONDecode(readfile(path))
			end)
			if not ok or type(data) ~= "table" then
				warn("[NovaUI] Failed to parse theme file") return
			end
			for k, rgb in pairs(data) do
				local color = Color3.new(rgb.r or 1, rgb.g or 1, rgb.b or 1)
				Library:SetThemeColor(k, color)
				local picker = Library.Options["Theme_" .. k]
				if picker then picker:SetValueRGB(color, nil, true) end
			end
		end,
		Delete = function(name)
			local path = _themeDir .. "/" .. name .. ".json"
			if isfile(path) then delfile(path) end
		end,
	}

	self:_buildConfigsPage(self:AddPage("Configs"))
	self:_buildThemesPage(self:AddPage("Themes"))

	self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
		if self.Listening or gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
			return
		end
		for _, m in ipairs(self.Modules) do
			if m.Bindable and m.Keybind and m.Keybind == input.KeyCode then
				m:Activate()
			end
		end
	end)

	return self
end

function Library:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self.Connections, c)
	return c
end

function Library:_buildSearch()
	self.SearchQuery = ""
	local bar = create("Frame", {
		Name = "SearchBar",
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(276, 40),
		Parent = self.Root,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	
	local icon = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(18, 14),
		Parent = bar,
	})
	for i, w in ipairs({ 18, 12, 15 }) do
		create("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, (i - 1) * 6),
			Size = UDim2.fromOffset(w, 2),
			Parent = icon,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	
	create("Frame", {
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 44, 0.5, 0),
		Size = UDim2.fromOffset(1, 18),
		Parent = bar,
	})

	
	local mag = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Parent = bar,
	})
	create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(11, 11),
		Parent = mag,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		create("UIStroke", { Color = Theme.SubText, Thickness = 1.5 }),
	})
	create("Frame", {
		BackgroundColor3 = Theme.SubText,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(13, 13),
		Rotation = 45,
		Size = UDim2.fromOffset(6, 2),
		Parent = mag,
	})

	local box = create("TextBox", {
		Name = "SearchBox",
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search",
		PlaceholderColor3 = Theme.SubText,
		ClearTextOnFocus = false,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -56 - 40, 1, 0),
		Parent = bar,
	})
	box:GetPropertyChangedSignal("Text"):Connect(function()
		self:_applySearch(box.Text)
	end)

	self.SearchBar = bar
	self.SearchBox = box
end

function Library:_applySearch(query)
	query = string.lower(query or "")
	self.SearchQuery = query
	for _, cat in ipairs(self.Categories) do
		local any = false
		for _, m in ipairs(cat.Modules) do
			local match = query == "" or string.find(string.lower(m.Name), query, 1, true) ~= nil
			m._searchHidden = not match
			m.Frame.Visible = m.Visible and match
			if match then any = true end
		end
		cat._searchHidden = query ~= "" and not any
	end
	self:_refreshPanels()
end

function Library:Search(text)
	text = tostring(text or "")
	if self.SearchBox then
		self.SearchBox.Text = text
	else
		self:_applySearch(text)
	end
end

function Library:_checkPicker()
	local picker = self._openPicker
	if picker and not picker._ownerShown() then picker:Close() end
end

function Library:_refreshPanels()
	for _, cat in ipairs(self.Categories) do
		cat.Panel.Visible = cat.IsOpen and not cat._searchHidden and self.CurrentPage == nil
	end
	for name, page in pairs(self.Pages) do
		page.Panel.Visible = self.CurrentPage == name
	end
	self:_checkPicker()
end

local function safeRun(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[NovaUI] page callback error: " .. tostring(err)) end
end

function Library:_buildPageMenu()
	local btnX = self.SearchBar and 146 or -20
	local btn = create("TextButton", {
		Name = "PageButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, btnX, 0, 16),
		Size = UDim2.fromOffset(40, 40),
		Parent = self.Root,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local dots = {}
	for i = 1, 3 do
		dots[i] = create("Frame", {
			BackgroundColor3 = Theme.SubText,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 7),
			Size = UDim2.fromOffset(4, 4),
			Parent = btn,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	local menu = create("Frame", {
		Name = "PageMenu",
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, btnX + 40, 0, 62),
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Visible = false,
		Parent = self.Root,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 6) }),
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.ModuleHover }) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Background }) end)
	btn.MouseButton1Click:Connect(function()
		menu.Visible = not menu.Visible
		self:_updatePageMenu()
	end)

	self.PageButton = btn
	self.PageMenu = menu
	self._pageDots = dots
	self._pageEntries = {}
	self._pageOrder = 0
end

function Library:_updatePageMenu()
	local active = self.PageMenu.Visible or self.CurrentPage ~= nil
	for _, dot in ipairs(self._pageDots) do
		tween(dot, { BackgroundColor3 = active and Theme.Accent or Theme.SubText })
	end
	for name, e in pairs(self._pageEntries) do
		tween(e.label, { TextColor3 = self.CurrentPage == name and Theme.Accent or Theme.SubText })
	end
end

function Library:AddPage(name, options)
	options = options or {}
	local lib = self
	local page = self:AddCategory(name, {
		Page = true,
		Width = options.Width or 320,
		Placeholder = options.Placeholder or "Nothing here yet",
	})
	page.IsPage = true
	self.Pages[name] = page

	function page:Open() lib:OpenPage(name) end
	function page:Close() if lib.CurrentPage == name then lib:ClosePage() end end
	function page:Toggle()
		if lib.CurrentPage == name then lib:ClosePage() else lib:OpenPage(name) end
	end

	self._pageOrder += 1
	local entry = create("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = self._pageOrder,
		Parent = self.PageMenu,
	})
	local entryLabel = label(entry, name, 13, Theme.SubText)
	entryLabel.Position = UDim2.fromOffset(14, 0)
	entryLabel.Size = UDim2.new(1, -28, 1, 0)
	entry.MouseEnter:Connect(function() tween(entry, { BackgroundColor3 = Theme.ModuleHover }) end)
	entry.MouseLeave:Connect(function() tween(entry, { BackgroundColor3 = Theme.Background }) end)
	entry.MouseButton1Click:Connect(function()
		self.PageMenu.Visible = false
		page:Toggle()
		self:_updatePageMenu()
	end)
	self._pageEntries[name] = { entry = entry, label = entryLabel }

	return page
end

function Library:OpenPage(name)
	local page = self.Pages[name]
	if not page then
		warn("[NovaUI] Page not found: " .. tostring(name))
		return
	end
	if self.CurrentPage == name then return end

	local previous = self.CurrentPage and self.Pages[self.CurrentPage]
	self.CurrentPage = name

	local root = self.Root.AbsoluteSize
	page.Panel.Position = UDim2.fromOffset(math.max((root.X - page.Panel.Size.X.Offset) / 2, 0), 72)

	self:_refreshPanels()
	self.PageMenu.Visible = false
	self:_updatePageMenu()

	if previous then safeRun(previous.OnClose, previous) end
	safeRun(page.OnOpen, page)
end

function Library:ClosePage()
	local name = self.CurrentPage
	if not name then return end
	self.CurrentPage = nil
	self:_refreshPanels()
	self:_updatePageMenu()
	local page = self.Pages[name]
	if page then safeRun(page.OnClose, page) end
end

local function recolor(old, new)
	local function walk(inst)
		if inst:GetAttribute("NoTheme") then return end
		if inst:IsA("GuiObject") then
			if inst.BackgroundColor3 == old then inst.BackgroundColor3 = new end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				if inst.TextColor3 == old then inst.TextColor3 = new end
				if inst:IsA("TextBox") and inst.PlaceholderColor3 == old then inst.PlaceholderColor3 = new end
			end
		elseif inst:IsA("UIStroke") and inst.Color == old then
			inst.Color = new
		end
		for _, child in ipairs(inst:GetChildren()) do walk(child) end
	end
	for _, window in ipairs(instances) do walk(window.Gui) end
end

function Library:SetThemeColor(key, color)
	local old = Theme[key]
	if typeof(old) ~= "Color3" or typeof(color) ~= "Color3" then
		warn("[NovaUI] Invalid theme key or color: " .. tostring(key))
		return
	end
	if old == color then return end
	Theme[key] = color
	recolor(old, color)
	safeRun(Library.OnThemeChanged, key, color)
end

function Library:GetTheme()
	local copy = {}
	for _, key in ipairs(THEME_KEYS) do copy[key] = Theme[key] end
	return copy
end

function Library:ResetTheme()
	for _, key in ipairs(THEME_KEYS) do
		Library:SetThemeColor(key, DefaultTheme[key])
		local picker = Library.Options["Theme_" .. key]
		if picker then picker:SetValueRGB(DefaultTheme[key], nil, true) end
	end
end

function Library:_buildManager(page, title, handlersKey, noun)
	local lib = self
	local sec = page:AddModule({ Name = title, Section = true })
	local nameBox = sec:AddTextbox({ Name = noun .. " name", Placeholder = "my-" .. string.lower(noun) })
	local list = sec:AddDropdown({ Name = noun, Options = {} })
	local status = sec:AddLabel({ Text = "", Size = 12 })

	
	local function call(key, ...)
		local fn = (lib[handlersKey] or {})[key]
		if type(fn) ~= "function" then
			status:SetText(key .. " not implemented (gui." .. handlersKey .. "." .. key .. ")")
			return false
		end
		local ok, result = pcall(fn, ...)
		if not ok then
			status:SetText(key .. " error")
			warn("[NovaUI] " .. handlersKey .. "." .. key .. " error: " .. tostring(result))
			return false
		end
		return true, result
	end

	local function refresh()
		local ok, names = call("List")
		if ok and type(names) == "table" then
			list:SetOptions(names)
			status:SetText("")
		end
	end

	local function selected()
		local name = list:Get()
		if name == nil then status:SetText("Please select a " .. noun) end
		return name
	end

	page:AddModule({ Name = "Create", Type = "Button", Bindable = false, Callback = function()
		local name = nameBox:Get()
		if name == "" then
			status:SetText("Please enter a " .. noun .. " name")
			return
		end
		if call("Create", name) then
			refresh()
			list:Set(name, true)
		end
	end })
	page:AddModule({ Name = "Save", Type = "Button", Bindable = false, Callback = function()
		local name = selected()
		if name then call("Save", name) end
	end })
	page:AddModule({ Name = "Load", Type = "Button", Bindable = false, Callback = function()
		local name = selected()
		if name then call("Load", name) end
	end })
	page:AddModule({ Name = "Delete", Type = "Button", Bindable = false, Callback = function()
		local name = selected()
		if name and call("Delete", name) then refresh() end
	end })
	page:AddModule({ Name = "Refresh", Type = "Button", Bindable = false, Callback = refresh })

	
	page.OnOpen = function()
		if type((lib[handlersKey] or {}).List) == "function" then refresh() end
	end

	return refresh
end

function Library:_buildConfigsPage(page)
	self._refreshConfigs = self:_buildManager(page, "Configs", "ConfigHandlers", "Config")
end

function Library:RefreshConfigs()
	if self._refreshConfigs then self._refreshConfigs() end
end

function Library:_buildThemesPage(page)
	local sec = page:AddModule({ Name = "Colors", Section = true })
	for _, key in ipairs(THEME_KEYS) do
		local row = sec:AddLabel({ Text = key, Size = 13 })
		row:AddColorPicker("Theme_" .. key, {
			Default = Theme[key],
			Title = key,
			Callback = function(color) Library:SetThemeColor(key, color) end,
		})
	end
	self._refreshThemes = self:_buildManager(page, "Themes", "ThemeHandlers", "Theme")
	page:AddModule({ Name = "Reset Theme", Type = "Button", Bindable = false, Callback = function()
		Library:ResetTheme()
	end })
end

function Library:RefreshThemes()
	if self._refreshThemes then self._refreshThemes() end
end

function Library:Toggle(state)
	if state == nil then state = not self.Root.Visible end
	self.Root.Visible = state
end

function Library:AddCategory(name, options)
	if typeof(options) == "UDim2" then options = { Position = options } end
	options = options or {}

	local cat = setmetatable({ Library = self, Name = name, Modules = {}, IsOpen = (not options.Page) and options.Open ~= false }, Category)
	local index = #self.Categories
	local position = options.Position or UDim2.fromOffset(30 + index * 215, 72) 

	local panel = create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(options.Width or 200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Visible = cat.IsOpen,
		Parent = self.Root,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 6) }),
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local header = create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 1,
		Parent = panel,
	})
	local title = label(header, name, 14, Theme.Text)
	title.Font = Theme.FontBold
	title.Position = UDim2.fromOffset(12, 0)
	title.Size = UDim2.new(1, -48, 1, 0)
	create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = header,
	})

	local collapse = create("TextButton", {
		BackgroundTransparency = 1,
		Text = "›",
		TextSize = 20,
		Font = Theme.FontBold,
		TextColor3 = Theme.SubText,
		Rotation = -90,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 34, 1, -2),
		Parent = header,
	})

	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = panel,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	
	makeDraggable(self, header, panel)
	local function toggleBody()
		body.Visible = not body.Visible
		tween(collapse, { Rotation = body.Visible and -90 or 90 })
	end
	if options.Page then
		
		collapse.Text = "×"
		collapse.Rotation = 0
		collapse.MouseButton1Click:Connect(function() self:ClosePage() end)
	else
		collapse.MouseButton1Click:Connect(toggleBody)
	end
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then toggleBody() end
	end)

	cat.Panel = panel
	cat.Body = body

	if options.Placeholder then
		local ph = label(body, options.Placeholder, 12, Theme.SubText, Enum.TextXAlignment.Center)
		ph.Name = "Placeholder"
		ph.Size = UDim2.new(1, 0, 0, 60)
		ph.LayoutOrder = 0
		cat._placeholder = ph 
	end

	if not options.Page then table.insert(self.Categories, cat) end
	return cat
end

function Library:Notify(title, text, duration)
	duration = duration or 3
	local n = create("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = os.clock() * 1000,
		Parent = self.NotifyHolder,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local t = label(n, title or "", 13, Theme.Text)
	t.Font = Theme.FontBold
	t.Position = UDim2.fromOffset(12, 6)
	t.Size = UDim2.new(1, -24, 0, 16)
	t.TextTransparency = 1

	local d = label(n, text or "", 12, Theme.SubText)
	d.Position = UDim2.fromOffset(12, 24)
	d.Size = UDim2.new(1, -24, 0, 16)
	d.TextTransparency = 1

	local bar = create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = n,
	})

	tween(n, { BackgroundTransparency = 0.05 }, 0.25)
	tween(t, { TextTransparency = 0 }, 0.25)
	tween(d, { TextTransparency = 0 }, 0.25)
	tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, duration)

	task.delay(duration, function()
		tween(n, { BackgroundTransparency = 1 }, 0.25)
		tween(t, { TextTransparency = 1 }, 0.25)
		tween(d, { TextTransparency = 1 }, 0.25)
		tween(bar, { BackgroundTransparency = 1 }, 0.25)
		task.wait(0.3)
		n:Destroy()
	end)
end

function Library:OnUnload(callback)
	assert(type(callback) == "function", "OnUnload requires a function")
	if Library.Unloaded then
		task.spawn(callback) 
		return
	end
	table.insert(unloadCallbacks, callback)
end

function Library:GiveSignal(connection)
	if Library.Unloaded then
		if connection and connection.Connected then connection:Disconnect() end
		return connection
	end
	table.insert(signals, connection)
	return connection
end

function Library:Unload()
	if Library.Unloaded then return end
	Library.Unloaded = true

	for _, c in ipairs(signals) do
		if c and c.Connected then c:Disconnect() end
	end
	table.clear(signals)

	for _, cb in ipairs(unloadCallbacks) do
		local ok, err = pcall(cb)
		if not ok then warn("[NovaUI] OnUnload callback error: " .. tostring(err)) end
	end
	table.clear(unloadCallbacks)
	table.clear(Library.Labels)
	table.clear(Library.Options)

	for _, inst in ipairs(table.clone(instances)) do
		inst:Destroy()
	end
end

function Library:Destroy()
	if self == Library then
		return Library:Unload()
	end
	if self._destroyed then return end
	self._destroyed = true

	for _, c in ipairs(self.Connections) do
		if c.Connected then c:Disconnect() end
	end
	self.Connections = {}

	local i = table.find(instances, self)
	if i then table.remove(instances, i) end

	if self.Gui then self.Gui:Destroy() end
end

function Category:SetOpen(state)
	self.IsOpen = state and true or false
	self.Library:_refreshPanels()
end

function Category:_nextOrder()
	if self._placeholder then
		self._placeholder:Destroy()
		self._placeholder = nil
	end
	self._order = (self._order or 0) + 1
	return self._order
end

function Category:AddDivider(args)
	return buildDivider(self.Body, self:_nextOrder(), args, Theme.Background)
end

function Category:Open() self:SetOpen(true) end
function Category:Close() self:SetOpen(false) end
function Category:Toggle() self:SetOpen(not self.IsOpen) end

function Category:AddModule(opts)
	opts = opts or {}
	local lib = self.Library
	local module = setmetatable({
		Library = lib,
		Name = opts.Name or "Module",
		Enabled = false,
		Keybind = opts.Keybind,
		Bindable = opts.Bindable ~= false, 
		IsButton = opts.Type == "Button" or opts.Button == true, 
		Callback = opts.Callback or function() end,
		_order = 0,
		_expanded = false,
		Disabled = false,
		Visible = true,
	}, Module)

	local frame = create("Frame", {
		Name = module.Name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Body,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local button = create("TextButton", {
		Name = "Button",
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = frame,
	})
	local accent = create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, 0),
		Parent = button,
	})
	local nameLabel = label(button, module.Name, 13, Theme.SubText)
	nameLabel.Position = UDim2.fromOffset(12, 0)
	nameLabel.Size = UDim2.new(1, -44, 1, 0)

	local arrow = create("TextButton", {
		BackgroundTransparency = 1,
		Text = "›",
		TextSize = 20,
		Font = Theme.FontBold,
		TextColor3 = Theme.SubText,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 30, 1, 0),
		Visible = false,
		Parent = button,
	})

	local settings = create("Frame", {
		Name = "Settings",
		BackgroundColor3 = Theme.Settings,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 2,
		Parent = frame,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		}),
	})

	module.SettingsFrame = settings
	module._arrow = arrow
	module.Frame = frame
	module._nameLabel = nameLabel
	module:_buildKeybind()

	local function setExpanded(state)
		module._expanded = state
		settings.Visible = state
		lib:_checkPicker()
		tween(arrow, { Rotation = state and 90 or 0 })
	end

	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = Theme.ModuleHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Module })
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			module:Activate()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if arrow.Visible then setExpanded(not module._expanded) end
		end
	end)
	arrow.MouseButton1Click:Connect(function()
		setExpanded(not module._expanded)
	end)

	function module:_applyVisual()
		tween(accent, { BackgroundTransparency = self.Enabled and 0 or 1 })
		tween(nameLabel, { TextColor3 = self.Enabled and Theme.Accent or Theme.SubText })
	end

	function module:_flash()
		accent.BackgroundTransparency = 0
		nameLabel.TextColor3 = Theme.Text
		tween(accent, { BackgroundTransparency = 1 }, 0.3)
		tween(nameLabel, { TextColor3 = Theme.SubText }, 0.3)
	end

	table.insert(self.Modules, module)
	table.insert(lib.Modules, module)

	if lib.SearchQuery and lib.SearchQuery ~= "" then lib:_applySearch(lib.SearchQuery) end
	function module:SetExpanded(state) setExpanded(state and true or false) end
	if opts.Section then
		
		module.IsSection = true
		module.IsButton = true
		module.Bindable = false
		module._bindRow.Visible = false
		nameLabel.TextColor3 = Theme.Text
		accent.BackgroundTransparency = 0
	end
	if opts.Expanded or opts.Section then setExpanded(true) end
	if opts.Disabled then module:SetDisabled(true) end
	if opts.Visible == false then module:SetVisible(false) end
	if opts.Default and not module.IsButton then module:SetEnabled(true) end
	return module
end

function Module:Activate()
	if self.Disabled then return end 
	if self.IsSection then
		self:SetExpanded(not self._expanded)
		return
	end
	if self.IsButton then
		self:Fire()
	else
		self:SetEnabled(not self.Enabled)
	end
end

function Module:Fire()
	if not self.IsButton then return end
	self:_flash()
	local ok, err = pcall(self.Callback)
	if not ok then warn("[NovaUI] " .. self.Name .. " callback error: " .. tostring(err)) end
end

function Module:SetEnabled(state, silent)
	if self.IsButton then return end
	state = state and true or false
	if self.Enabled == state then return end
	self.Enabled = state
	self:_applyVisual()
	if not silent then
		local ok, err = pcall(self.Callback, state)
		if not ok then warn("[NovaUI] " .. self.Name .. " callback error: " .. tostring(err)) end
	end
end

function Module:SetValue(state, silent)
	self:SetEnabled(state, silent)
end

function Module:GetValue()
	return self.Enabled
end

function Module:SetDisabled(state)
	self.Disabled = state and true or false
	local t = self.Disabled and 0.55 or 0
	self._nameLabel.TextTransparency = t
	self._arrow.TextTransparency = t
end

function Module:SetVisible(state)
	self.Visible = state and true or false
	self.Frame.Visible = self.Visible and not self._searchHidden
	self.Library:_checkPicker()
end

function Module:_nextOrder()
	self._order += 1
	self._arrow.Visible = true
	return self._order
end

function Module:AddLabel(a, b, c)
	local opts, id
	if type(a) == "table" then
		opts = a
	elseif type(a) == "string" and type(b) == "table" then
		id, opts = a, b
	else
		opts, id = { Text = a, DoesWrap = b }, c
	end

	local wrap = opts.DoesWrap ~= false
	local lbl = label(self.SettingsFrame, tostring(opts.Text or ""), opts.Size or 14, Theme.Text)
	lbl.Name = "Label"
	lbl.LayoutOrder = self:_nextOrder()
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.TextWrapped = wrap
	if not wrap then lbl.TextTruncate = Enum.TextTruncate.AtEnd end
	lbl.Visible = opts.Visible ~= false

	local root = lbl 

	local api = {}
	function api:SetText(text) lbl.Text = tostring(text or "") end
	function api:SetSize(size) lbl.TextSize = size end
	function api:SetVisible(state) root.Visible = state and true or false end
	function api:Destroy()
		if id and Library.Labels[id] == api then Library.Labels[id] = nil end
		root:Destroy()
	end

	
	api._lib = self.Library
	api._cpAnchorY = 0
	api._cpOffset = 0
	function api._cpPrepare()
		if root == lbl then
			local holder = create("Frame", {
				Name = "LabelHolder",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = lbl.LayoutOrder,
				Visible = lbl.Visible,
				Parent = lbl.Parent,
			})
			lbl.Parent = holder
			lbl.Visible = true
			root = holder
		end
		return root
	end
	function api._cpReserve(total) lbl.Size = UDim2.new(1, -(total + 4), 0, 0) end
	function api:AddColorPicker(pid, popts) return addColorPicker(api, pid, popts) end

	if id then Library.Labels[id] = api end
	return api
end

function Module:AddDivider(args)
	return buildDivider(self.SettingsFrame, self:_nextOrder(), args, Theme.Settings)
end

function Module:AddToggle(opts)
	local callback = opts.Callback or function() end
	local value = opts.Default and true or false

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = self:_nextOrder(),
		Parent = self.SettingsFrame,
	})
	local text = label(row, opts.Name or "Toggle", 12, Theme.Text)
	text.Size = UDim2.new(1, -44, 1, 0)

	local switch = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = value and Theme.Accent or Theme.Track,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(34, 16),
		Parent = row,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local knob = create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = value and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		Parent = switch,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	knob:SetAttribute("NoTheme", true) 

	local api = {}
	function api:Set(v, silent)
		value = v and true or false
		tween(switch, { BackgroundColor3 = value and Theme.Accent or Theme.Track })
		tween(knob, { Position = value and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		if not silent then callback(value) end
	end
	function api:Get() return value end

	switch.MouseButton1Click:Connect(function()
		if api.Disabled then return end
		api:Set(not value)
	end)
	attachCommon(api, row)

	
	api._lib = self.Library
	api._cpAnchorY = 0.5
	api._cpOffset = 40 
	function api._cpPrepare() return row end
	function api._cpReserve(total) text.Size = UDim2.new(1, -(total + 4), 1, 0) end
	function api:AddColorPicker(id, opts) return addColorPicker(api, id, opts) end

	return api
end

function Module:AddSlider(opts)
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Increment or 1
	local callback = opts.Callback or function() end
	local value = math.clamp(opts.Default or min, min, max)

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = self:_nextOrder(),
		Parent = self.SettingsFrame,
	})
	local text = label(row, opts.Name or "Slider", 12, Theme.Text)
	text.Size = UDim2.new(1, -50, 0, 16)
	local valueLabel = label(row, tostring(value), 12, Theme.SubText, Enum.TextXAlignment.Right)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)
	valueLabel.Size = UDim2.new(0, 50, 0, 16)

	local track = create("Frame", {
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = row,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local hit = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = row,
	})

	local api = {}
	local function render()
		local range = math.max(max - min, 1e-9)
		fill.Size = UDim2.fromScale((value - min) / range, 1)
		valueLabel.Text = tostring(value)
	end
	function api:Set(v, silent)
		v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
		value = tonumber(string.format("%.4f", v))
		render()
		if not silent then callback(value) end
	end
	function api:Get() return value end
	render()

	local dragging = false
	local function fromInput(input)
		local r = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		api:Set(min + (max - min) * r)
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) and not api.Disabled then
			dragging = true
			fromInput(input)
		end
	end)
	self.Library:_connect(UserInputService.InputChanged, function(input)
		if dragging and not api.Disabled and isMove(input) then fromInput(input) end
	end)
	self.Library:_connect(UserInputService.InputEnded, function(input)
		if isPress(input) then dragging = false end
	end)
	attachCommon(api, row)
	return api
end

function Module:AddButton(a, b)
	local opts
	if type(a) == "table" then
		opts = a
	else
		opts = { Text = a, Callback = b }
	end
	local callback = opts.Callback or opts.Func or function() end
	local doubleClick = opts.DoubleClick == true
	local text = tostring(opts.Text or opts.Name or "Button")

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = self:_nextOrder(),
		Parent = self.SettingsFrame,
	})
	local btn = create("TextButton", {
		Text = text,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Text,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

	local api = {}
	local armed, armToken = false, 0

	local function disarm()
		armed = false
		btn.Text = text
		tween(btn, { TextColor3 = Theme.Text })
	end

	function api:SetText(t)
		text = tostring(t or "")
		if not armed then btn.Text = text end
	end
	function api:Set(t) api:SetText(t) end 

	
	function api:Fire()
		local ok, err = pcall(callback)
		if not ok then warn("[NovaUI] button callback error: " .. tostring(err)) end
		btn.TextColor3 = Theme.Accent
		tween(btn, { TextColor3 = Theme.Text }, 0.3)
	end

	function api:Destroy() row:Destroy() end

	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.ModuleHover }) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Module }) end)
	btn.MouseButton1Click:Connect(function()
		if api.Disabled then return end
		if doubleClick and not armed then
			
			armed = true
			armToken += 1
			local token = armToken
			btn.Text = "Click again to confirm"
			btn.TextColor3 = Theme.Accent
			task.delay(2, function()
				if armed and armToken == token then disarm() end
			end)
			return
		end
		if armed then disarm() end
		api:Fire()
	end)

	attachCommon(api, row, function() if armed then disarm() end end)
	if opts.Disabled then api:SetDisabled(true) end
	if opts.Visible == false then api:SetVisible(false) end
	return api
end

function Module:AddTextbox(opts)
	opts = opts or {}
	local callback = opts.Callback or function() end
	local value = tostring(opts.Default or "")

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
		LayoutOrder = self:_nextOrder(),
		Parent = self.SettingsFrame,
	})
	local text = label(row, opts.Name or "Textbox", 12, Theme.Text)
	text.Size = UDim2.new(1, 0, 0, 16)
	local box = create("TextBox", {
		Text = value,
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Theme.SubText,
		ClearTextOnFocus = false,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = row,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 4) }),
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})

	local api = {}
	function api:Set(v, silent)
		value = tostring(v or "")
		box.Text = value
		if not silent then callback(value) end
	end
	function api:Get() return value end

	box.FocusLost:Connect(function()
		if api.Disabled then
			box.Text = value
			return
		end
		value = box.Text
		callback(value)
	end)

	attachCommon(api, row, function(disabled) box.TextEditable = not disabled end)
	return api
end

function Module:AddDropdown(opts)
	local options = opts.Options or {}
	local callback = opts.Callback or function() end
	local value = opts.Default or options[1]

	local container = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_nextOrder(),
		Parent = self.SettingsFrame,
	}, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })

	local head = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 1,
		Parent = container,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	local text = label(head, "", 12, Theme.Text)
	text.Position = UDim2.fromOffset(8, 0)
	text.Size = UDim2.new(1, -16, 1, 0)

	local list = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 2,
		Parent = container,
	}, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })

	local api = {}
	local function render()
		text.Text = (opts.Name or "Dropdown") .. ": " .. (value == nil and "None" or tostring(value))
	end
	function api:Set(v, silent)
		value = v
		render()
		if not silent then callback(value) end
	end
	function api:Get() return value end
	render()

	local function buildOptions()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, opt in ipairs(options) do
			local b = create("TextButton", {
				Text = tostring(opt),
				Font = Theme.Font,
				TextSize = 12,
				TextColor3 = Theme.SubText,
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Module,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = i,
				Parent = list,
			}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })
			b.MouseButton1Click:Connect(function()
				if api.Disabled then return end
				api:Set(opt)
				list.Visible = false
			end)
		end
	end
	buildOptions()

	
	function api:SetOptions(newOptions)
		options = newOptions or {}
		buildOptions()
		for _, o in ipairs(options) do
			if o == value then return end
		end
		value = options[1]
		render()
	end

	head.MouseButton1Click:Connect(function()
		if api.Disabled then return end
		list.Visible = not list.Visible
	end)
	attachCommon(api, container, function(disabled)
		if disabled then list.Visible = false end
	end)
	return api
end

function Module:_buildKeybind()
	local lib = self.Library
	local module = self
	self._arrow.Visible = self.Bindable
	if not self.Bindable then self.Keybind = nil end

	local row = create("Frame", {
		Visible = self.Bindable,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1000000, 
		Parent = self.SettingsFrame,
	})
	local text = label(row, "Bind", 12, Theme.Text)
	text.Size = UDim2.new(1, -96, 1, 0)

	local clear = create("TextButton", {
		Text = "×",
		Font = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(22, 20),
		Parent = row,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

	local btn = create("TextButton", {
		Font = Theme.Font,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Module,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.fromOffset(64, 20),
		Parent = row,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

	local api = { Callback = function() end }
	local function render()
		btn.Text = module.Keybind and module.Keybind.Name or "None"
		clear.Visible = module.Keybind ~= nil
	end
	function api:Set(key)
		module.Keybind = key
		render()
		api.Callback(key)
	end
	function api:Get() return module.Keybind end
	render()

	clear.MouseButton1Click:Connect(function()
		if api.Disabled then return end
		api:Set(nil)
	end)

	btn.MouseButton1Click:Connect(function()
		if api.Disabled or lib.Listening then return end
		lib.Listening = true
		btn.Text = "..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			conn:Disconnect()
			local key = input.KeyCode
			if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
				api:Set(nil)
			else
				api:Set(key)
			end
			task.defer(function() lib.Listening = false end)
		end)
	end)

	attachCommon(api, row)
	self.KeybindApi = api
	self._bindRow = row
end

function Module:SetBindable(state)
	state = state and true or false
	self.Bindable = state
	self._bindRow.Visible = state
	if not state then
		self.KeybindApi:Set(nil)
		if self._order == 0 then
			self._arrow.Visible = false
			self._expanded = false
			self.SettingsFrame.Visible = false
			self._arrow.Rotation = 0
		end
	else
		self._arrow.Visible = true
	end
end

function Module:AddKeybind(opts)
	opts = opts or {}
	local api = self.KeybindApi
	if opts.Callback then api.Callback = opts.Callback end
	if opts.Default then api:Set(opts.Default) end
	return api
end

return Library
