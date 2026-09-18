type Function = (...any) -> ...any?

local function CheckReturnType(Result: any, Type: string)
	assert(typeof(Result) == Type, `didn't return a {Type}`)
end

local function FindFirstFunction(Name: string, Environment: {[string]: any}?): any
	local Value = Environment or getfenv()

	while Value ~= nil and Name ~= "" do
		local Library, NewName = string.match(Name, "^([^.]+)%.?(.*)$")
		Value = Value[Library or ""]
		Name = NewName or ""
	end

	return Value
end

local function CheckExist(FunctionName: string): any
	local Fn = FindFirstFunction(FunctionName)
	assert(Fn, `'{FunctionName}' does not exist, and is required for this test`)
	return Fn
end

local function FailedFind(Name: string)
	return `failed to find {Name}, retry this test`
end

local identifyexecutor = getfenv().identifyexecutor or function() return "Unknown Executor", "0.0.0" end
local ExecutorName: string = identifyexecutor() or "Unknown Executor"

local Tests: any = {


	getrenv = {
		Test = function()
			local getrenv: () -> {[string]: any} = getfenv().getrenv

			local ExpectedGlobals = {
				"delay", "elapsedTime", "printidentity", "settings", "spawn",
				"stats", "tick", "time", "typeof", "UserSettings", "version",
				"wait", "warn", "ypcall", "Enum", "game", "shared", "_G", "workspace",
			}

			local Environment = getrenv()

			for _, Global: string in ExpectedGlobals do
				assert(Environment[Global] ~= nil, `missing '{Global}'`)
			end
		end,
		ReturnType = "table"
	},

	getgenv = {
		Test = function()
			local getgenv: () -> {[string]: any} = getfenv().getgenv
			local Environment = getgenv()

			for FunctionName in getfenv() do
				assert(Environment[FunctionName], `missing '{FunctionName}'`)
			end
		end,
		ReturnType = "table",
	},

	gettenv = {
		Test = function()
			local gettenv: (thread | () -> ()) -> {[string]: any} = getfenv().gettenv

			local Success = pcall(gettenv, function() end)
			assert(not Success, "expected error when providing a non-thread value")

			local ThreadEnvironment = gettenv(task.spawn(function() end))
			CheckReturnType(ThreadEnvironment, "table")

			for FunctionName in ThreadEnvironment do
				assert(getfenv()[FunctionName], `Function does not contain all values in getfenv(). Missing value: {FunctionName}`)
			end
		end,
	},

	readfile = {
		Test = function()
			local readfile: (Path: string) -> string = getfenv().readfile

			local Success = pcall(readfile, "doesntexist.txt")
			assert(not Success, "expected an error when reading a file that doesn't exist")

			local writefile: (Path: string, Data: string) -> () = CheckExist("writefile")

			local GeneratedResult = tostring(math.random())
			local FileName = `File_{math.random()}.txt`

			writefile(FileName, GeneratedResult)

			local Result = readfile(FileName)

			local delfile: (Path: string) -> () = getfenv().delfile
			if delfile then delfile(FileName) end

			assert(Result == GeneratedResult, "Test file did not return what was written into it.")
		end
	},

	writefile = {
		Test = function()
			local writefile: (Path: string, Data: string) -> () = getfenv().writefile
			local readfile: (Path: string) -> string = CheckExist("readfile")

			local GeneratedResult = tostring(math.random())
			local FileName = `File_{math.random()}.txt`

			writefile(FileName, GeneratedResult)

			local Result = readfile(FileName)

			local delfile: (Path: string) -> () = getfenv().delfile
			if delfile then delfile(FileName) end

			assert(typeof(Result) == "string", "'readfile' failed to read the file, cannot continue test.")
			assert(Result == GeneratedResult, "'writefile' did not write to the file.")
		end
	},

	isfile = {
		Test = function()
			local isfile: (Path: string) -> boolean = getfenv().isfile
			local writefile: (Path: string, Data: string) -> () = CheckExist("writefile")

			local FileName = `File_{math.random()}.txt`
			writefile(FileName, "Test")

			local Exists = isfile(FileName)

			local delfile: (Path: string) -> () = getfenv().delfile
			if delfile then delfile(FileName) end

			assert(Exists, "failed to find the file")
		end
	},

	appendfile = {
		Test = function()
			local appendfile: (Path: string, Data: string) -> () = getfenv().appendfile
			local readfile: (Path: string) -> string = CheckExist("readfile")

			local GeneratedResult = tostring(math.random())
			local FileName = `File_{math.random()}.txt`

			local Success = pcall(appendfile, FileName, GeneratedResult)
			if not Success then
				CheckExist("writefile")(FileName, GeneratedResult)
			end

			assert(readfile(FileName) == GeneratedResult, "failed to create the file")

			appendfile(FileName, "Append")

			local HasAppend = readfile(FileName):find("Append")

			local delfile: (Path: string) -> () = getfenv().delfile
			if delfile then delfile(FileName) end

			assert(HasAppend, "failed to add to the existing file")
		end
	},

	listfiles = {
		Test = function()
			local listfiles: (Path: string) -> {string} = getfenv().listfiles
			local writefile: (Path: string, Data: string) -> () = CheckExist("writefile")
			local makefolder: (Path: string) -> () = CheckExist("makefolder")

			local FolderName = `Folder_{math.random()}`
			makefolder(FolderName)

			assert(typeof(listfiles(FolderName)) == "table", "Function did not return a table.")

			local GeneratedResult = tostring(math.random())
			local FileName = `{FolderName}\\{`File_{math.random()}.txt`}`

			writefile(FileName, GeneratedResult)

			local Result = listfiles(FolderName)

			local delfolder: (Path: string) -> () = getfenv().delfolder
			if delfolder then delfolder(FolderName) end

			assert(Result[1] == FileName, "Function did not find the written file.")
		end
	},

	delfile = {
		Test = function()
			local delfile: (Path: string) -> any? = getfenv().delfile
			local writefile: (Path: string, Data: string) -> () = CheckExist("writefile")
			local isfile: (Path: string) -> boolean = CheckExist("isfile")

			local FileName = `File_{math.random()}.txt`
			writefile(FileName, "Test")

			assert(isfile(FileName), "Failed to write to the file, cannot continue test.")
			delfile(FileName)
			assert(not isfile(FileName), "'isfile' returned true after file was meant to be deleted.")
		end
	},

	loadfile = {
		Test = function()
			local loadfile: (Path: string, ChunkName: string?) -> ((any?) -> (any?)?, string?) = getfenv().loadfile
			local writefile: (Path: string, Data: string) -> () = CheckExist("writefile")

			local FileName = `File_{math.random()}.txt`
			local GeneratedNumber = math.random()

			writefile(FileName, "local number = ...; return number + 1")

			local LoadedFunction, Error = loadfile(FileName)

			local delfile: (Path: string) -> () = getfenv().delfile
			if delfile then delfile(FileName) end

			local Result = assert(LoadedFunction, Error)(GeneratedNumber)
			assert(Result == GeneratedNumber + 1, "Function did not return the correct number.")
		end
	},

	makefolder = {
		Test = function()
			local makefolder: (Path: string) -> () = getfenv().makefolder
			local isfolder: (Path: string) -> boolean = CheckExist("isfolder")

			local FolderName = `Folder_{math.random()}`
			makefolder(FolderName)

			assert(isfolder(FolderName) == true, "failed to find folder after it was made")

			local delfolder: (Path: string) -> () = getfenv().delfolder
			if delfolder then delfolder(FolderName) end
		end
	},

	isfolder = {
		Test = function()
			local isfolder: (Path: string) -> boolean = getfenv().isfolder
			local makefolder: (Path: string) -> () = CheckExist("makefolder")

			assert(isfolder("???") == false, "didn't return false for non-existent folder")

			local FolderName = `Folder_{math.random()}`
			makefolder(FolderName)

			assert(isfolder(FolderName), "Folder was not found after it was made.")

			local delfolder: (Path: string) -> () = getfenv().delfolder
			if delfolder then delfolder(FolderName) end
		end
	},

	delfolder = {
		Test = function()
			local delfolder: (Path: string) -> () = getfenv().delfolder
			local makefolder: (Path: string) -> () = CheckExist("makefolder")
			local isfolder: (Path: string) -> boolean = CheckExist("isfolder")

			local FolderName = `Folder_{math.random()}`
			makefolder(FolderName)

			assert(isfolder(FolderName), "failed to find folder after it was made")
			delfolder(FolderName)
			assert(not isfolder(FolderName), "'isfolder' found the folder after it should've been deleted.")
		end
	},


	hookfunction = {
		Test = function()
			local hookfunction = getfenv().hookfunction
			local newcclosure = getfenv().newcclosure
			local restorefunction = getfenv().restorefunction

			do
				local function FirstFunction() return true end
				local function SecondFunction() end
				local ReturnedFunction = hookfunction(FirstFunction, SecondFunction)
				assert(ReturnedFunction() == true, "the returned function isn't giving the expected result when called")
			end

			do
				local function LuaClosure() return true end
				hookfunction(LuaClosure, tick)
				assert(type(LuaClosure()) == "number", "expected the LuaClosure to return a number when hooked as 'tick'")
			end

			if newcclosure then
				local function LuaClosure() end
				local NewCClosure = newcclosure(function() return true end)
				hookfunction(LuaClosure, NewCClosure)
				assert(LuaClosure() == true, "calling the LuaClosure did not return the NewCClosure's result")
			end

			if restorefunction then
				local CClosure1 = tostring :: any
				local CClosure2 = tonumber
				hookfunction(CClosure1, CClosure2)
				local TestResult = CClosure1("5") == 5
				restorefunction(CClosure1)
				assert(TestResult, "expected tostring to return a number when hooked as tonumber and given '5'")
			end

			if restorefunction then
				local CClosure = tonumber :: any
				local function LuaClosure() return true end
				hookfunction(CClosure, LuaClosure)
				local TestResult = CClosure() == true
				restorefunction(CClosure)
				assert(TestResult, "expected tonumber to return a boolean when hooked as a LuaClosure that returns true")
			end

			if restorefunction and newcclosure then
				local CClosure = table.create :: any
				local NewCClosure = newcclosure(function() return true end)
				hookfunction(CClosure, NewCClosure)
				local TestResult = CClosure() == true
				restorefunction(CClosure)
				assert(TestResult, "expected table.create to return a boolean when hooked as a NewCClosure that returns true")
			end

			if newcclosure then
				local NewCClosure1 = newcclosure(function() end)
				local NewCClosure2 = newcclosure(function() return true end)
				hookfunction(NewCClosure1, NewCClosure2)
				assert(NewCClosure1() == true, "expected NewCClosure to return a boolean when hooked as a NewCClosure that returns true")
			end

			if newcclosure then
				local NewCClosure = newcclosure(function() end)
				local function LuaClosure() return true end
				hookfunction(NewCClosure, LuaClosure)
				assert(NewCClosure() == true, "expected NewCClosure to return a boolean when hooked as a LuaClosure that returns true")
			end

			if newcclosure then
				local NewCClosure = newcclosure(function() end)
				hookfunction(NewCClosure, task.wait)
				assert(type(NewCClosure()) == "number", "expected NewCClosure to return a number when hooked as task.wait")
			end
		end
	},

	iscclosure = {
		Test = function()
			local iscclosure: (Function: (any?) -> ()) -> boolean = getfenv().iscclosure
			assert(iscclosure(assert) == true, "function 'assert' is a c closure")
			assert(not iscclosure(function() end), "A function created in the executor is not written in C.")
		end,
	},

	clonefunction = {
		Test = function()
			local clonefunction = getfenv().clonefunction
			local pcall: (Function: Function, Arg1: any, Arg2: any) -> (any?, any?) = getfenv().pcall

			local GeneratedNumber = math.random()
			local TestENV = {}

			local function Original() return GeneratedNumber end

			local PreviousENVClone = clonefunction(Original)
			setfenv(Original, TestENV)
			local Clone = clonefunction(Original)

			assert(Clone ~= Original, "Cloned and original function should not have the same reference.")
			assert(Clone() == Original(), "Cloned and original function should return the same value.")
			assert(getfenv(Clone) == TestENV, "didn't clone the function's environment")
			assert(getfenv(PreviousENVClone) ~= TestENV, "The ENV of the original function changed and the one of the cloned one is not the old one.")

			local InfoResultsOrder = {
				["Source"] = 1, ["Line"] = 2, ["Name"] = 3, ["Params"] = 4, ["VarArgs"] = 5
			}

			local OriginalInfo = {debug.info(Original, "slna")}
			local ClonedInfo = {debug.info(Clone, "slna")}
			local OldInfo = {}

			for CheckName, Position in pairs(InfoResultsOrder) do
				OldInfo[CheckName] = {Position, OriginalInfo[Position]}
			end

			for CheckName, ExtraCheckInfo in pairs(OldInfo) do
				local ClonedResult = ClonedInfo[ExtraCheckInfo[1]]
				local RealResult = ExtraCheckInfo[2]
				assert(ClonedResult == RealResult, `"{CheckName}" is not the same, it returned "{ClonedResult}" instead of "{RealResult}").`)
			end

			local WaitForChild = game.WaitForChild
			local NewWaitForChild = clonefunction(WaitForChild)
			assert(WaitForChild ~= NewWaitForChild, "Cloned and original C function should not have the same reference.")

			local Terrain = workspace:FindFirstChildWhichIsA("Terrain")
			local TerrainName = Terrain.Name :: any

			local Succes, Result = pcall(NewWaitForChild, workspace, TerrainName)
			assert(Succes, `new WaitForChild failed: "{Result}"`)
			assert(Result == Terrain, `new WaitForChild returns: "{Result}", but we need "{TerrainName}"`)
		end
	},

	newcclosure = {
		Test = function()
			local newcclosure = getfenv().newcclosure
			local function TestFunction() return "debunc" end
			local NewClosure = newcclosure(TestFunction)

			assert(debug.info(NewClosure, "s") == "[C]", `expected the returned closure to be in [C], got '{debug.info(NewClosure, "s")}'`)
			assert(NewClosure ~= TestFunction, "function returned is the same as the function given")
			assert(NewClosure() == "debunc", "failed to return the expected value")
		end,
	},

	isfunctionhooked = {
		Test = function()
			local isfunctionhooked = getfenv().isfunctionhooked
			local hookfunction = CheckExist("hookfunction")

			local function Test() return "debUNC Original" end

			assert(isfunctionhooked(Test) == false, "an unhooked function should return false")
			hookfunction(Test, function() return "debUNC Hooked" end)
			assert(isfunctionhooked(Test) == true, "a hooked function should return true")

			local restorefunction = getfenv().restorefunction
			if not restorefunction then return end

			restorefunction(Test)
			assert(isfunctionhooked(Test) == false, "a restored hooked function should return false")
		end,
	},

	checkcaller = {
		Test = function()
			local checkcaller = getfenv().checkcaller
			assert(checkcaller() == true, "should return true when called by the executor")

			local Success, CameraModule = pcall(function()
				return game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule.CameraModule
			end)
			assert(Success, "BaseCamera does not exist, go to a normal game.")

			local Success2, Camera = pcall(require, CameraModule.BaseCamera)
			assert(Success2, `failed to require BaseCamera with error: {Camera}`)

			local Old, Called = Camera.GetSubjectPosition, nil
			Camera.GetSubjectPosition = function(...)
				Camera.GetSubjectPosition = Old
				Called = checkcaller()
				return Old(...)
			end

			local StartTime = tick()
			while Called == nil and tick() - StartTime < 2 do task.wait() end

			Camera.GetSubjectPosition = Old
			assert(Called == false, "should return false when called by the CameraModule.BaseCamera")
		end,
	},

	getcallingscript = {
		Test = function()
			local getcallingscript = getfenv().getcallingscript

			local Success, CameraWrapper = pcall(
				require,
				game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule.CommonUtils.CameraWrapper
			)
			assert(Success, "your executor requires supporting 'require' in order to run this test")

			local GetCameraOriginal = CameraWrapper.getCamera
			local CallingScript

			CameraWrapper.getCamera = function(...)
				CallingScript = getcallingscript()
				CameraWrapper.getCamera = GetCameraOriginal
				return GetCameraOriginal(...)
			end

			task.wait()

			assert(CallingScript, "function returned nil in a case where it should've returned a script")
			assert(
				CallingScript.Name == "CameraModule",
				`the calling script of CameraWrapper.getCamera should be 'CameraModule', got '{CallingScript}'`
			)
		end,
		DisableOnDebug = true,
	},

	fireclickdetector = {
		Test = function()
			local fireclickdetector = getfenv().fireclickdetector
			local ClickDetector = Instance.new("ClickDetector")
			local WasClicked = false

			ClickDetector.MouseClick:Once(function(Player)
				if Player == game:GetService("Players").LocalPlayer then WasClicked = true end
			end)

			fireclickdetector(ClickDetector)

			local Start = tick()
			repeat task.wait() until WasClicked or tick() - Start >= 1

			assert(WasClicked, "connection was not fired")
		end
	},

	fireproximityprompt = {
		Test = function()
			local fireproximityprompt = getfenv().fireproximityprompt
			local Part = Instance.new("Part")
			Part.Parent = workspace

			local ProximityPrompt = Instance.new("ProximityPrompt")
			ProximityPrompt.Parent = Part

			local WasTriggered = false

			ProximityPrompt.Triggered:Once(function(Player)
				if Player == game:GetService("Players").LocalPlayer then WasTriggered = true end
			end)

			fireproximityprompt(ProximityPrompt)

			local Start = tick()
			repeat task.wait() until WasTriggered or tick() - Start >= 1

			Part:Destroy()
			assert(WasTriggered, "connection was not fired")
		end
	},

	firesignal = {
		Test = function()
			local firesignal = getfenv().firesignal
			local NumberValue = Instance.new("NumberValue")
			local GeneratedValue = math.random()
			local DidChange = false

			NumberValue.Changed:Once(function(Value)
				if Value == GeneratedValue then DidChange = true end
			end)

			firesignal(NumberValue.Changed, GeneratedValue)

			local Start = tick()
			repeat task.wait() until DidChange or tick() - Start >= 1

			assert(DidChange, "connection was not fired")
		end
	},

	getconnections = {
		Test = function()
			type Connections = {
				RBXScriptConnection & {
					Fire: (self: RBXScriptConnection, any?) -> ()
				}
			}

			local getconnections = getfenv().getconnections
			local NumberValue = Instance.new("NumberValue")
			local DidChange = false
			local GeneratedValue = math.random()

			NumberValue.Changed:Once(function(Value)
				assert(
					GeneratedValue == Value,
					`connection was fired but improper parameter given, expected number '{GeneratedValue}', got {typeof(Value)} '{Value}'`
				)
				if GeneratedValue == Value then DidChange = true end
			end)

			local Connections = getconnections(NumberValue.Changed)
			assert(typeof(Connections) == "table", `expected a table, got {typeof(Connections)}`)
			assert(#Connections == 1, `expected 1 connection in the table, got {#Connections}`)

			local ChangedConnection = Connections[1]
			assert(ChangedConnection.Fire, "expected method 'Fire' in the table")

			ChangedConnection:Fire(GeneratedValue)

			local Start = tick()
			repeat task.wait() until DidChange or tick() - Start >= 1

			assert(DidChange, "connection was not fired")
		end
	},

	firetouchinterest = {
		Test = function()
			local firetouchinterest = getfenv().firetouchinterest
			local FireTouch = Instance.new("Part")
			local WithPart = Instance.new("Part")

			FireTouch.Parent = workspace
			WithPart.Parent = workspace

			local Complete = false

			FireTouch.Touched:Connect(function(Part)
				if WithPart == Part then Complete = true end
			end)

			firetouchinterest(FireTouch, WithPart, 0)
			firetouchinterest(FireTouch, WithPart, 1)

			local Start = tick()
			repeat task.wait() until Complete or tick() - Start >= 5

			FireTouch:Destroy()
			WithPart:Destroy()

			assert(Complete, "failed to fire the touched event within 5 seconds")
		end,
		DisabledFor = {"Visual"}
	},

	replicatesignal = {
		Test = function()
			local replicatesignal = getfenv().replicatesignal

			local clickDetector = Instance.new("ClickDetector")
			local player = game.Players.LocalPlayer
			local Fired = false

			clickDetector.MouseActionReplicated:Once(function()
				Fired = true
			end)

			replicatesignal(clickDetector.MouseActionReplicated, player, 0)

			local Start = tick()
			repeat task.wait() until Fired or tick() - Start > 3

			clickDetector:Destroy()
			assert(Fired, "MouseActionReplicated was not fired within 3 seconds")
		end,
	},


	request = {
		Test = function()
			local request = getfenv().request

			local Result = request({
				Url = "https://httpbin.org/get",
				Method = "GET"
			})

			CheckReturnType(Result, "table")
			assert(Result.StatusCode == 200, `failed to request, StatusMessage: {Result.StatusMessage}, StatusCode: {Result.StatusCode}`)
			assert(Result.StatusMessage == "OK", `StatusMessage should be 'OK' when the StatusCode is 200`)

			local Body = Result.Body
			assert(typeof(Body) == "string", "expected a string from the Body")

			local Decoded = game:GetService("HttpService"):JSONDecode(Body)
			CheckReturnType(Decoded, "table")

			local DecodedHeaders = Decoded.headers
			assert(DecodedHeaders, "decoded body does not contain the headers")

			local Fingerprint
			for Header: string, Info in Decoded.headers do
				if not Header:lower():find("fingerprint") then continue end
				Fingerprint = Info
				break
			end

			assert(Fingerprint, `missing fingerprint (hwid) header: {game:GetService("HttpService"):JSONEncode(Decoded.headers)}`)
		end
	},

	["WebSocket.connect"] = {
		Test = function()
			local connect = getfenv().WebSocket.connect
			local WebSocket = connect("wss://echo.websocket.org")
			local Messaged = false

			WebSocket.OnMessage:Once(function() Messaged = true end)
			WebSocket:Send("debUNC")

			local Start = tick()
			repeat task.wait() until Messaged or tick() - Start >= 5

			assert(Messaged, "failed to receive message within 5 seconds")

			local Closed = false
			WebSocket.OnClose:Once(function() Closed = true end)
			WebSocket:Close()

			assert(Closed, "OnClose failed to fire when :Close() was called")
		end,
	},

	["game.HttpGet"] = {
		Test = function()
			local Success, Result = pcall(game.HttpGet, game, "https://awqbcduwendewbnzd.aaaaaa")

			assert(
				not Success or not Result or Result == "",
				"httpgetting a nonexistent website should return an error, nil, or an empty string"
			)

			local Result2 = game:HttpGet("https://raw.githubusercontent.com/alyssagithub/debUNC/refs/heads/main/debUNC.luau")
			assert(Result2:find("debUNC"), "failed to get the code of debUNC")
		end,
	},


	["cache.invalidate"] = {
		Test = function()
			local invalidate = getfenv().cache.invalidate
			local container = Instance.new("Folder")
			local part = Instance.new("Part", container)
			invalidate(container:FindFirstChild("Part"))
			assert(part ~= container:FindFirstChild("Part"), "Reference `part` could not be invalidated")
		end,
	},

	["cache.iscached"] = {
		Test = function()
			local iscached = getfenv().cache.iscached
			local invalidate = CheckExist("cache.invalidate")
			local part = Instance.new("Part")
			assert(iscached(part), "Part should be cached")
			invalidate(part)
			assert(not iscached(part), "Part should not be cached")
		end,
	},

	["cache.replace"] = {
		Test = function()
			local replace = getfenv().cache.replace
			local part = Instance.new("Part") :: Instance
			local fire = Instance.new("Fire") :: Instance
			replace(part, fire)
			assert(part ~= fire, "Part was not replaced with Fire")
		end,
	},


	hookmetamethod = {
		Test = function()
			local hookmetamethod = getfenv().hookmetamethod
			local OriginalIndx = function() end
			local Metatable = setmetatable({}, {__index = OriginalIndx})

			local Original = hookmetamethod(Metatable, "__index", function() return "debUNC" end)

			CheckReturnType(Original, "function")
			assert(Metatable.yay == "debUNC", "indexing the metatable failed to return the hooked value")
			assert(getmetatable(Metatable).__index == OriginalIndx, "function replaced the metamethod's function instead of it's proto")
		end,
	},

	getrawmetatable = {
		Test = function()
			local getrawmetatable = getfenv().getrawmetatable
			local Detector = newproxy(true)
			local DetectorMETA, IndxFunc

			local FakeMETA = {__index = function() return true end}

			do
				DetectorMETA = getmetatable(Detector)
				IndxFunc = (function()
					return (function() return error("first debUNC", 2) end)()
				end)
				DetectorMETA.__index = IndxFunc
				DetectorMETA.__metatable = FakeMETA
			end

			local RawDetectorMETA = getrawmetatable(Detector)

			assert(RawDetectorMETA == getrawmetatable(Detector), "did not even return 2 times the same thing")
			assert(RawDetectorMETA ~= FakeMETA, "its getmetatable with other name")
			assert(RawDetectorMETA == DetectorMETA, "failed to return original META")
			assert(rawequal(RawDetectorMETA, DetectorMETA), "failed to return original META and tried to fake it")
			assert(not table.isfrozen(RawDetectorMETA), "returned a read-only META")
			assert(IndxFunc == RawDetectorMETA.__index, "didnt return the original __index")

			local NewIndxFunc = `debUNC {math.random()}`
			DetectorMETA.__index = NewIndxFunc
			assert(NewIndxFunc == RawDetectorMETA.__index, `changed __index to {NewIndxFunc} but still returns the old one`)

			local Part1 = Instance.new("Part") :: any
			local Part2 = Instance.new("Part") :: any
			local Part1META = getrawmetatable(Part1)

			assert(Part1META == getrawmetatable(Part2), "did not return the same META for unmodified parts")
			assert(table.isfrozen(Part1META), "returned a non read-only Part META")

			for _, MetaType in {"__index", "__newindex", "__namecall", "__metatable"} do
				assert(Part1META[MetaType], `{MetaType} is not valid in a Part`)
			end

			local __index
			xpcall(function() return Part1[{}] end, function()
				__index = debug.info(2, "f")
			end)
			assert(Part1META["__index"] == __index, `__index did not give the expected value`)
		end,
		DisabledFor = {"Visual"}
	},

	setrawmetatable = {
		Test = function()
			local setrawmetatable = getfenv().setrawmetatable
			local LockedProxy = newproxy()

			assert(getmetatable(LockedProxy) == nil, "a new proxy shouldn't have a metatable")

			local MainMeta = {__call = function() return "debUNC" end}
			setrawmetatable(LockedProxy, MainMeta)

			assert(getmetatable(LockedProxy) == MainMeta, "the new proxy's metatable was not set to the expected one")

			local Success, Result = pcall(LockedProxy)
			assert(Success, `errored while attempting to call the new proxy, error: {Result}`)
			assert(Result == "debUNC", "calling the new proxy failed to return the expected value")
		end,
	},

	setreadonly = {
		Test = function()
			local setreadonly = getfenv().setreadonly
			local ReadOnlyTable = ColorSequence

			assert(table.isfrozen(ReadOnlyTable), "ColorSequence is not frozen.")

			local function ReadOnlyEditTest()
				local Succes = pcall(function() ReadOnlyTable[1] = "debUNC" end)
				if Succes then pcall(function() ReadOnlyTable[1] = nil end) end
				return Succes
			end

			assert(not ReadOnlyEditTest(), "should not be able to write to ColorSequence while frozen.")
			setreadonly(ReadOnlyTable, false)

			local Success, err = pcall(function() ColorSequence[123] = "debUNC" end)
			assert(Success, "failed to write after unfreezing: " .. tostring(err))
			pcall(function() table.remove(ReadOnlyTable, 123) end)

			assert(not table.isfrozen(ReadOnlyTable), "table still appears to be frozen after unfreezing.")
			setreadonly(ReadOnlyTable, true)

			local FinishTest = ReadOnlyEditTest()
			if not FinishTest then pcall(table.freeze, ReadOnlyTable) end

			assert(not FinishTest, "table did not become readonly again.")
		end,
	},

	require = {
		Test = function()
			local Module = game:FindFirstChildWhichIsA("ModuleScript", true)
			assert(Module, FailedFind("module"))

			local Success, Result = pcall(require, Module)
			assert(Success, `expected success when requiring '{Module.Name}', got error: {Result}`)
			assert(Result ~= nil, "expected a value to be returned, got nil")
		end
	},

	getloadedmodules = {
		Test = function()
			local getloadedmodules = getfenv().getloadedmodules
			local PlayerModule = game:GetService("StarterPlayer").StarterPlayerScripts.PlayerModule
			local LoadedModules = getloadedmodules()

			CheckReturnType(LoadedModules, "table")
			assert(not table.find(LoadedModules, PlayerModule), "StarterPlayerScripts.PlayerModule should not be in the returned table")

			local LocalPlayerModule = game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule
			assert(table.find(LoadedModules, LocalPlayerModule), "could not find 'PlayerScripts.PlayerModule' in the returned table")
		end,
		ReturnType = "table"
	},

	getscripts = {
		Test = function()
			local getscripts = getfenv().getscripts
			for _, CurrentScript: BaseScript | ModuleScript in getscripts() do
				assert(typeof(CurrentScript) == "Instance", `expected instance, got {typeof(CurrentScript)} '{CurrentScript}'`)
				local ClassCheck = CurrentScript:IsA("BaseScript") or CurrentScript:IsA("ModuleScript")
				assert(ClassCheck, `instance '{CurrentScript}' is not a script, ClassName: {CurrentScript.ClassName}`)
			end
		end,
		ReturnType = "table"
	},

	getsenv = {
		Test = function()
			local getsenv = getfenv().getsenv
			local requireFn = getfenv().require
			local setfenv = getfenv().setfenv

			local PlayerScripts = game:GetService("Players").LocalPlayer.PlayerScripts
			local CustomENV = {debUNC = true}

			local function CreateNewModuleTest(SetParent: boolean)
				local New = PlayerScripts.RbxCharacterSounds:Clone()
				local AtomicBinding = New and New:FindFirstChildWhichIsA("ModuleScript")
				assert(AtomicBinding, "Failed to locate 'AtomicBinding' ModuleScript in the cloned RbxCharacterSounds.")

				local NewAtomicBinding = requireFn(AtomicBinding)
				local Called = false

				NewAtomicBinding.new = function()
					if SetParent then New.Parent = nil end
					Called = true
					setfenv(2, CustomENV)
					return task.wait(9e9)
				end

				New.Parent = PlayerScripts

				local StartTime = tick()
				while not Called and tick() - StartTime < 2 do task.wait() end

				if not Called then New:Destroy() end
				return Called, New
			end

			local Called, NewSoundsScript = CreateNewModuleTest(false)
			assert(Called, "Script took too long to respond.")

			local ScriptENV = getsenv(NewSoundsScript)
			assert(ScriptENV, "getsenv returned nil.")
			assert(ScriptENV.script == NewSoundsScript, ".script doesn't point to the script being used in the function call")

			NewSoundsScript:Destroy()

			local Called2, NewSoundsNilScript = CreateNewModuleTest(true)
			assert(Called2, "Script took too long to respond when parent was nil.")

			local ScriptENV2 = getsenv(NewSoundsScript)
			assert(ScriptENV2, "getsenv returned nil when parent was nil.")

			NewSoundsNilScript:Destroy()
		end,
	},

	decompile = {
		Test = function()
			local decompile = getfenv().decompile
			local PlayerModule = game:GetService("StarterPlayer").StarterPlayerScripts.PlayerModule :: ModuleScript
			local Result = decompile(PlayerModule)

			CheckReturnType(Result, "string")
			assert(Result:find("__index"), "couldn't find '__index' in 'PlayerModule' decompiled")
			assert(Result:find("CameraModule"), "couldn't find 'CameraModule' in 'PlayerModule' decompiled")
		end,
	},

	loadstring = {
		Test = function()
			local Loaded = loadstring("return 'debunc'")
			assert(typeof(Loaded) == "function", `expected return type to be a function, got {typeof(Loaded)}`)
			assert(Loaded() == "debunc", "failed to return the expected value")
		end,
	},

	isscriptable = {
		Test = function()
			local isscriptable = getfenv().isscriptable
			assert(isscriptable(game, "Parent") == true, "game.Parent is scriptable")

			local Success1, Result1 = pcall(isscriptable, game, "SimulationRadius")
			assert(not Success1 or Result1 == false, "game.SimulationRadius is a hidden property, and isn't scriptable")

			local Success2, Result2 = pcall(isscriptable, game, "a")
			assert(not Success2 or not Result2, "game.a is not a valid property")
		end,
	},

	setfpscap = {
		Test = function()
			local setfpscap = getfenv().setfpscap

			local function GetCurrentFPS(): number
				return math.floor(1 / game:GetService("Stats").FrameTime)
			end

			local HighestFPS = 0
			local LastPeak = tick()

			while tick() - LastPeak <= 0.25 and task.wait() do
				local FPS = GetCurrentFPS()
				if FPS == math.huge then continue end
				if FPS > HighestFPS then HighestFPS = FPS; LastPeak = tick() end
			end

			local FPSCap = math.floor(HighestFPS / 6)
			setfpscap(FPSCap)

			local StartLoop = tick()
			local FPS
			local Timeout = 5

			repeat FPS = GetCurrentFPS(); task.wait() until FPS <= FPSCap or tick() - StartLoop >= Timeout

			setfpscap(0)
			assert(FPS <= FPSCap, `fps ({FPS}) did not go below {FPSCap} within {Timeout} seconds`)
		end
	},

	getfpscap = {
		Test = function()
			local getfpscap = getfenv().getfpscap
			local setfpscap = CheckExist("setfpscap")

			setfpscap(10)
			local Result = getfpscap()
			assert(Result == 10, `expected value '10', got '{Result}'`)

			setfpscap(0)
			local NewResult = getfpscap()
			assert(NewResult ~= Result, "set fps cap to 0, result stayed at 10")
		end,
	},

	base64encode = {
		Test = function()
			local base64encode = getfenv().base64encode
			local base64decode = CheckExist("base64decode")

			local GeneratedString = tostring(math.random())
			local Encoded = base64encode(GeneratedString)

			assert(Encoded ~= GeneratedString, "encoded result did not change from the original string")

			local Decoded = base64decode(Encoded)
			assert(Decoded == GeneratedString, "decoded result did not provide the original string")
		end
	},

	base64decode = {
		Test = function()
			local base64decode = getfenv().base64decode
			assert(base64decode("ZGVidW5j") == "debunc", "failed to decode a string encoded in base64")
		end,
	},

	lz4compress = {
		Test = function()
			local lz4compress = getfenv().lz4compress
			assert(lz4compress("debUNC") == "`debUNC", "failed to compress the string with lz4")
		end,
	},

	lz4decompress = {
		Test = function()
			local lz4decompress = getfenv().lz4decompress
			local String = "`debUNC"
			assert(lz4decompress(String, #String):find("debUNC"), "failed to decompress the string with lz4")
		end,
	},

	identifyexecutor = {
		Test = function()
			local identifyexecutor2 = getfenv().identifyexecutor
			local Name, Version = identifyexecutor2()
			assert(typeof(Name) == "string", "the first returned value, the executor's name, should be a string")
			assert(typeof(Version) == "string", "the second returned value, the executor's version, should be a string")
		end,
	},

	gethwid = {
		Test = function()
			local gethwid = getfenv().gethwid
			assert(typeof(gethwid()) == "string", "the returned value (user's hwid/fingerprint) should be a string")
		end,
	},

	isnetworkowner = {
		Test = function()
			local isnetworkowner = getfenv().isnetworkowner
			assert(isnetworkowner(game:GetService("Players").LocalPlayer.Character.HumanoidRootPart) == true, "should return true on the hrp")
		end,
	},

	getnamecallmethod = {
		Test = function()
			local getnamecallmethod = getfenv().getnamecallmethod
			local ProxyTest = newproxy(true)
			local Detected

			getmetatable(ProxyTest).__namecall = function()
				Detected = getnamecallmethod()
			end

			local Success, Result = pcall(function() ProxyTest:debUNC() end)
			local OutsideMethod = getnamecallmethod()

			assert(Success, `errored while attempting to call the new proxy with namecall, error: {Result}`)
			assert(Detected == "debUNC", `getnamecallmethod gave '{Detected}' instead of 'debUNC' inside __namecall`)
			assert(OutsideMethod == "debUNC", `getnamecallmethod gave '{OutsideMethod}' instead of 'debUNC' outside __namecall`)
		end,
	},

	cloneref = {
		Test = function()
			local cloneref = getfenv().cloneref
			local Part = Instance.new("Part")
			local ClonedReference = cloneref(Part) :: Part

			assert(ClonedReference ~= Part, "the cloned reference shouldn't be the same as the original reference")

			local NewPosition = Vector3.new(69, 67, 420)
			Part.Position = NewPosition

			assert(
				ClonedReference:GetPivot().Position == NewPosition,
				"setting the Position property of the original reference does not update the cloned reference"
			)
		end,
	},

	compareinstances = {
		Test = function()
			local compareinstances = getfenv().compareinstances
			local cloneref = CheckExist("cloneref")
			local part = Instance.new("Part")
			local clone = cloneref(part)
			assert(part ~= clone, "Clone should not be equal to original")
			assert(compareinstances(part, clone), "Clone should be equal to original when using compareinstances()")
		end,
	},


	["debug.getproto"] = {
		Test = function()
			local getproto = CheckExist("debug.getproto")
			local Proto = getproto(function()
				local function b() return "debUNC" end
			end, 1)
			assert(Proto, "didn't return anything")
		end,
	},

	["debug.getprotos"] = {
		Test = function()
			local getprotos = CheckExist("debug.getprotos")
			local Protos = getprotos(function()
				local function b() return "debUNC" end
			end)

			CheckReturnType(Protos, "table")
			local Proto = Protos[1]
			assert(Proto, "a proto doesn't exist in the first index of the returned table")
			assert(not Protos[2], "there should be nothing in the second index of the returned table, as only 1 proto exists")
		end,
	},

	["debug.getinfo"] = {
		Test = function()
			local getinfo = CheckExist("debug.getinfo")

			do
				local function DebuncIsBetterThanSunc() end
				local Info = getinfo(DebuncIsBetterThanSunc)
				assert(Info.what == "Lua", ".what should be 'Lua' when used on a Lua Function")
				assert(Info.name == "DebuncIsBetterThanSunc", ".name should reflect the name of the Lua Function")
			end

			do
				local Info = getinfo(task.wait)
				assert(Info.what == "C", ".what should be 'C' when used on a task.wait")
				assert(Info.name == "wait", ".name should be 'wait' when used on task.wait")
			end
		end,
	},
}


local NoTests: {[string | number]: any} = {
	"mouse1click", "mouse1press", "mouse1release",
	"mouse2click", "mouse2press", "mouse2release",
	"mousemoveabs", "mousemoverel", "mousescroll",
	"keypress", "keyrelease",
	"setclipboard", "queueonteleport",
	"sethiddenproperty", "setscriptable",
	"setthreadidentity", "setstack", "setrenderproperty",
	"restorefunction", "runonactor", "makewriteable",
	"filtergc", "runonthread", "setrbxclipboard",
	"getmenv", "setfflag",
	"Drawing.new", "isrenderobj", "getrenderproperty", "cleardrawcache",
	"crypt.hash", "crypt.generatebytes", "crypt.encrypt", "crypt.generatekey",
	"debug.getupvalues", "debug.getupvalue",
	"debug.getstack", "debug.setstack",
	"debug.setupvalue", "debug.setconstant",
	"rconsoleinfo", "rconsoleerr", "rconsoledestroy",
	"rconsolewarn", "rconsoleprint", "rconsolecreate",
	"raknet.addsendhook", "raknet.removesendhook",
	"raknet.addreceivehook", "raknet.removereceivehook",
	"raknet.send", "raknet.receive",

	gethiddenproperty      = {Parameters = {game:GetService("Players").LocalPlayer, "SimulationRadius"}, ReturnType = "number"},
	["debug.getregistry"]  = {ReturnType = "table"},
	gethui                 = {ReturnType = "Instance"},
	isrbxactive            = {ReturnType = "boolean"},
	iswindowactive         = {ReturnType = "boolean"},
	getgc                  = {ReturnType = "table"},
	getthreadidentity      = {ReturnType = "number"},
	comparefunctions       = {Parameters = {wait, wait}, ReturnType = "boolean"},
	isexecutorclosure      = {Parameters = {wait}, ReturnType = "boolean"},
	islclosure             = {Parameters = {wait}, ReturnType = "boolean"},
	["debug.getconstants"] = {Parameters = {function()end}, ReturnType = "table"},
	["debug.getconstant"]  = {Parameters = {function()local a; a = "hi"end, 1 :: any}, ReturnType = "string"},
	getscriptbytecode      = {Parameters = {game:FindFirstChildWhichIsA("LocalScript", true)}, ReturnType = "string"},
	getinstances           = {ReturnType = "table"},
	getscripthash          = {Parameters = {game:FindFirstChildWhichIsA("LocalScript", true)}, ReturnType = "string"},
	getscriptclosure       = {Parameters = {game:FindFirstChildWhichIsA("LocalScript", true)}, ReturnType = "function"},
	checkparallel          = {ReturnType = "boolean"},
	getfflag               = {Parameters = {"MaxFrameBufferSize"}, ReturnType = "string"},
	isnewcclosure          = {Parameters = {function()end}, ReturnType = "boolean"},
	getnilinstances        = {ReturnType = "table"},
	getrunningscripts      = {ReturnType = "table"},
	isparallel             = {ReturnType = "boolean"},
	getactors              = {ReturnType = "table"},
	getfunctionhash        = {Parameters = {function()end}, ReturnType = "string"},
	getactorthreads        = {ReturnType = "table"},
}

for Index, Info in NoTests do
	assert(not Tests[Index] and not Tests[Info], `A test for {Index} or {Info} already exists.`)
	if typeof(Index) == "string" then
		Tests[Index] = Info
	else
		Tests[Info] = {}
	end
end

local isfunctionhooked = getfenv().isfunctionhooked

if isfunctionhooked then
	if isfunctionhooked(pcall) then
		warn("[debUNC Module] pcall is hooked, some test results may be inaccurate.")
	end
	if isfunctionhooked(loadstring) then
		warn("[debUNC Module] loadstring is hooked, some test results may be inaccurate.")
	end
end

local Results: {[string]: boolean} = {}
local Pending = 0

local TotalTests = 0
for _ in Tests do TotalTests += 1 end

for Name: string, Info in Tests do
	Pending += 1

	task.spawn(function()
		local Success = pcall(function()
			local DisabledFor = Info.DisabledFor
			assert(
				not DisabledFor or not table.find(DisabledFor, ExecutorName),
				`disabled for {ExecutorName}`
			)

			local Fn = FindFirstFunction(Name)
			assert(Fn, "doesn't exist")
			assert(typeof(Fn) == "function", "doesn't have 'function' type")

			if isfunctionhooked then
				assert(isfunctionhooked(Fn) == false, "function is hooked and cannot be accurately tested")
			end

			if Info.ReturnType then
				CheckReturnType(Fn(table.unpack(Info.Parameters or {})), Info.ReturnType)
			end

			if Info.Test then
				Info.Test()
			end
		end)

		Results[Name] = Success
		Pending -= 1
	end)

	task.wait()
end

repeat task.wait() until Pending == 0

return Results
