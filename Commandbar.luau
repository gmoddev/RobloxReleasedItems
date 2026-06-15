--!nolint

--[[
Not_Lowest
Fusion Command Bar
]]
--// no lint because of a random syntax warning
--// If you can read it all, congrats.
--// All of this was because I wanted autocomplete to not add a tab character even though it stripped it out anyway.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Nexus.Shared.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
local Observer = Fusion.Observer
local peek = Fusion.peek

local CommandBarController = {}
local COMMAND_INPUT_ACTION = "NexusCommandBarInput"
local COMMAND_BAR_CONTEXT = "CommandBar"
local METADATA_REFRESH_STALE_SECONDS = 10

local COLOR_KEYS = {
	"Primary",
	"Secondary",
	"Accent",
	"Text",
	"TextSecondary",
	"Success",
	"Warning",
	"Error",
	"Background",
	"Border"
}

local DEFAULT_THEME = {
	Name = "Midnight",
	Primary = Color3.fromRGB(25, 30, 40),
	Secondary = Color3.fromRGB(35, 42, 55),
	Accent = Color3.fromRGB(70, 130, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(180, 190, 200),
	Success = Color3.fromRGB(50, 200, 100),
	Warning = Color3.fromRGB(255, 180, 50),
	Error = Color3.fromRGB(255, 80, 80),
	Background = Color3.fromRGB(15, 20, 28),
	Border = Color3.fromRGB(50, 60, 75),
	Transparency = 0.1,
	CornerRadius = UDim.new(0, 8),
	AnimationSpeed = 0.25
}

local function ToColor3(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" then
		if value.Type == "Color3" and value.R ~= nil and value.G ~= nil and value.B ~= nil then
			return Color3.new(value.R, value.G, value.B)
		end
		if value[1] ~= nil and value[2] ~= nil and value[3] ~= nil then
			return Color3.fromRGB(value[1], value[2], value[3])
		end
	end
	return fallback
end

local function ToUDim(value, fallback)
	if typeof(value) == "UDim" then
		return value
	end
	if type(value) == "table" then
		if value.Type == "UDim" and value.Scale ~= nil and value.Offset ~= nil then
			return UDim.new(value.Scale, value.Offset)
		end
		if value[1] ~= nil and value[2] ~= nil then
			return UDim.new(value[1], value[2])
		end
	end
	return fallback
end

local function GetThemeColor(theme, key, fallback)
	if type(theme) ~= "table" then
		return fallback
	end
	return ToColor3(theme[key], fallback)
end

local function GetThemeNumber(theme, key, fallback)
	if type(theme) ~= "table" then
		return fallback
	end
	local value = theme[key]
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function NormalizeTheme(theme, previousTheme)
	local base = type(previousTheme) == "table" and previousTheme or DEFAULT_THEME
	local source = type(theme) == "table" and theme or {}
	local normalized = {}

	normalized.Name = source.Name or base.Name or DEFAULT_THEME.Name
	for _, key in ipairs(COLOR_KEYS) do
		normalized[key] = GetThemeColor(source, key, GetThemeColor(base, key, DEFAULT_THEME[key]))
	end

	normalized.Transparency = GetThemeNumber(source, "Transparency", GetThemeNumber(base, "Transparency", DEFAULT_THEME.Transparency))
	normalized.CornerRadius = ToUDim(source.CornerRadius, ToUDim(base.CornerRadius, DEFAULT_THEME.CornerRadius))
	normalized.AnimationSpeed = GetThemeNumber(source, "AnimationSpeed", GetThemeNumber(base, "AnimationSpeed", DEFAULT_THEME.AnimationSpeed))

	return normalized
end

local function SplitArgs(text: string): {string}
	local words = {}
	local current = ""
	local inQuotes = false
	local i = 1
	
	while i <= #text do
		local char = string.sub(text, i, i)
		if char == "\"" then
			inQuotes = not inQuotes
		elseif string.match(char, "%s") and not inQuotes then
			if current ~= "" then
				table.insert(words, current)
				current = ""
			end
		else
			current ..= char
		end
		i += 1
	end
	
	if current ~= "" then
		table.insert(words, current)
	end
	
	return words
end

local function FuzzyScore(query: string, candidate: string): number?
	query = string.lower(query)
	candidate = string.lower(candidate)

	if query == "" then
		return 0
	end

	local exactStart = string.find(candidate, query, 1, true)
	if exactStart then
		return exactStart
	end

	local score = 0
	local searchFrom = 1
	for i = 1, #query do
		local char = string.sub(query, i, i)
		local foundAt = string.find(candidate, char, searchFrom, true)
		if not foundAt then
			return nil
		end
		score += foundAt - searchFrom + 2
		searchFrom = foundAt + 1
	end

	return score + #candidate
end

local function CommandMatches(command, commandName: string): boolean
	if string.lower(command.Name or "") == commandName then
		return true
	end

	for _, alias in ipairs(command.Aliases or {}) do
		if string.lower(alias) == commandName then
			return true
		end
	end

	return false
end

local function ResolveExactCommand(allCommands, commandName: string)
	local resolvedCommand = nil
	local matchCount = 0

	for _, command in ipairs(allCommands) do
		if CommandMatches(command, commandName) then
			resolvedCommand = command
			matchCount += 1
		end
	end

	if matchCount == 1 then
		return resolvedCommand
	end
	return nil
end

local function FindCommand(allCommands, commandName: string)
	for _, command in ipairs(allCommands) do
		if CommandMatches(command, commandName) then
			return command
		end
	end
	return nil
end

local function GetInputContext(input: string, prefix: string)
	local body = string.sub(input, #prefix + 1)
	local words = SplitArgs(body)
	local hasTrailingSpace = string.match(body, "%s$") ~= nil
	local commandName = string.lower(words[1] or "")

	if commandName == "" then
		return {
			CommandName = "",
			Args = {},
			ActiveArgIndex = 0,
			ActiveArg = "",
			HasTrailingSpace = hasTrailingSpace
		}
	end

	local args = {}
	for i = 2, #words do
		table.insert(args, words[i])
	end

	local activeArgIndex = 0
	local activeArg = ""
	if hasTrailingSpace then
		activeArgIndex = #args + 1
	else
		activeArgIndex = #args
		activeArg = args[activeArgIndex] or ""
	end

	return {
		CommandName = commandName,
		Args = args,
		ActiveArgIndex = activeArgIndex,
		ActiveArg = activeArg,
		HasTrailingSpace = hasTrailingSpace
	}
end

local function FormatCommandUsage(prefix: string, command): string
	local usage = command.Usage or command.Name or ""
	if string.sub(usage, 1, #prefix) ~= prefix then
		usage = prefix .. usage
	end
	return usage
end

local function getRequiredArgumentCount(command): number
	local requiredCount = 0
	for _, argument in ipairs(command.Arguments or {}) do
		if argument.Required == true then
			requiredCount += 1
		end
	end
	return requiredCount
end

local function HasArguments(command): boolean
	return getRequiredArgumentCount(command) > 0
end

local function getIncompleteRequiredArgumentStatus(allCommands, input: string, prefix: string)
	if input == "" or string.sub(input, 1, #prefix) ~= prefix then
		return nil
	end

	local context = GetInputContext(input, prefix)
	if context.CommandName == "" then
		return nil
	end

	local command = ResolveExactCommand(allCommands, context.CommandName)
	if not command then
		return nil
	end

	local requiredArgumentCount = getRequiredArgumentCount(command)
	if requiredArgumentCount == 0 or #context.Args >= requiredArgumentCount then
		return nil
	end

	return {
		Command = command,
		Context = context,
		RequiredArgumentCount = requiredArgumentCount,
		MissingArgumentCount = requiredArgumentCount - #context.Args
	}
end

local function BuildCommandSuggestionText(prefix: string, command, actionText: string?): string
	local text = FormatCommandUsage(prefix, command)
	local description = command.Description or ""
	if description ~= "" then
		text = string.format("%s - %s", text, description)
	end
	if actionText and actionText ~= "" then
		text = string.format("%s (%s)", text, actionText)
	end
	return text
end

local function GetSmartExecutableCommand(allCommands, input: string, prefix: string)
	if input == "" or string.sub(input, 1, #prefix) ~= prefix then
		return nil
	end

	local context = GetInputContext(input, prefix)
	if context.CommandName == "" or context.HasTrailingSpace or #context.Args > 0 then
		return nil
	end

	local body = string.sub(input, #prefix + 1)
	if string.match(body, "^%S+$") == nil then
		return nil
	end
	if string.lower(body) ~= context.CommandName then
		return nil
	end

	local command = ResolveExactCommand(allCommands, context.CommandName)
	if not command or HasArguments(command) then
		return nil
	end

	return command
end

local function buildCommandNameCompletion(prefix: string, commandName: string, input: string, appendSpace: boolean?): string
	local body = string.sub(input, #prefix + 1)
	local _, commandEnd = string.find(body, "%S+")
	local completedCommand = prefix .. commandName
	if appendSpace then
		completedCommand ..= " "
	end

	if not commandEnd then
		return completedCommand
	end

	local rest = string.sub(body, commandEnd + 1)
	if rest == "" then
		return completedCommand
	end
	return prefix .. commandName .. rest
end

local function buildPlayerCompletion(prefix: string, commandName: string, args: {string}, activeArgIndex: number, playerName: string): string
	local completedArgs = table.clone(args)
	completedArgs[activeArgIndex] = playerName

	local parts = {prefix .. commandName}
	for _, arg in ipairs(completedArgs) do
		table.insert(parts, arg)
	end
	return table.concat(parts, " ") .. " "
end

local function buildArgumentCompletion(prefix: string, commandName: string, args: {string}, activeArgIndex: number, value: string): string
	local completedArgs = table.clone(args)
	completedArgs[activeArgIndex] = value
	
	local parts = {prefix .. commandName}
	for _, arg in ipairs(completedArgs) do
		table.insert(parts, arg)
	end
	return table.concat(parts, " ") .. " "
end

local function buildArgumentHint(prefix: string, command, argSpec)
	local usage = FormatCommandUsage(prefix, command)
	local argName = tostring(argSpec.Name or "argument")
	local typeName = tostring(argSpec.Type or "value")
	local requiredText = argSpec.Required and "required" or "optional"
	
	return {
		Kind = "argument",
		Text = string.format("%s - %s %s", usage, argName, requiredText),
		Description = typeName,
		Completion = nil,
		Score = 0
	}
end

local function errorText(result, fallback)
	if type(result) == "table" then
		return result.Error or result.Message or fallback
	end
	return fallback
end

local function sanitizeInputText(text: string): string
	return string.gsub(text, "[\t\r\n]", "")
end

function CommandBarController.new(Scope, theme, parent, deps)
	local NetworkController = deps.NetworkController
	local NotificationController = deps.NotificationController
	local InputBindingController = deps.InputBindingController
	local currentTheme = Value(Scope, NormalizeTheme(theme))
	local commandInput = Value(Scope, "")
	local isVisible = Value(Scope, false)
	local commands = Value(Scope, {})
	local commandHistory = Value(Scope, {})
	local historyIndex = Value(Scope, 0)
	local commandPrefix = Value(Scope, ":")
	local selectedSuggestionIndex = Value(Scope, 0)
	local commandInputActionBound = false
	local programmaticTextWrite: string? = nil
	local lastTabCompletionAt = 0
	local lastVerticalNavigationAt = 0
	local pendingTabFallbackId = 0
	local pendingVerticalFallbackId = 0
	local commandBarContextActive = false
	local metadataDirty = true
	local metadataDirtyReason = "InitialLoad"
	local commandsDirty = true
	local prefixDirty = true
	local commandRefreshInFlight = false
	local prefixRefreshInFlight = false
	local pendingCommandRefreshReason: string? = nil
	local pendingPrefixRefreshReason: string? = nil
	local commandRefreshRequestId = 0
	local prefixRefreshRequestId = 0
	local lastMetadataRefresh = 0
	local lastCommandsRefresh = 0
	local lastPrefixRefresh = 0
	local lastRefreshError: string? = nil
	local openAfterCommandRefresh = false
	local SetCommandInputActionBound
	local commandBar
	local syncCommandText
	local openCommandBar
	
	local function RefreshCommands(reason: string?)
		if commandRefreshInFlight then
			pendingCommandRefreshReason = reason or pendingCommandRefreshReason or metadataDirtyReason
			return false
		end

		commandRefreshInFlight = true
		commandRefreshRequestId += 1
		local requestId = commandRefreshRequestId

		NetworkController:Invoke("GetAllCommands"):andThen(function(data)
			if requestId ~= commandRefreshRequestId then
				return
			end
			if data and data.Success and type(data.Commands) == "table" then
				commands:set(data.Commands or {})
				commandsDirty = false
				lastCommandsRefresh = os.clock()
				lastMetadataRefresh = math.max(lastMetadataRefresh, lastCommandsRefresh)
				lastRefreshError = nil
			else
				lastRefreshError = errorText(data, "Failed to refresh commands")
			end
		end):catch(function(err)
			if requestId == commandRefreshRequestId then
				lastRefreshError = errorText(err, "Failed to refresh commands")
			end
		end):finally(function()
			if requestId ~= commandRefreshRequestId then
				return
			end

			commandRefreshInFlight = false

			if openAfterCommandRefresh then
				openAfterCommandRefresh = false
				if #peek(commands) > 0 then
					task.defer(function()
						if not peek(isVisible) then
							openCommandBar(false)
						end
					end)
				end
			end

			if pendingCommandRefreshReason then
				local nextReason = pendingCommandRefreshReason
				pendingCommandRefreshReason = nil
				commandsDirty = true
				task.defer(function()
					RefreshCommands(nextReason)
				end)
			end
		end)

		return true
	end
	
	local function RefreshPrefix(reason: string?)
		if prefixRefreshInFlight then
			pendingPrefixRefreshReason = reason or pendingPrefixRefreshReason or metadataDirtyReason
			return false
		end

		prefixRefreshInFlight = true
		prefixRefreshRequestId += 1
		local requestId = prefixRefreshRequestId

		NetworkController:Invoke("GetCommandPrefix"):andThen(function(data)
			if requestId ~= prefixRefreshRequestId then
				return
			end
			if data and data.Success and type(data.Prefix) == "string" and data.Prefix ~= "" then
				local oldPrefix = peek(commandPrefix)
				local newPrefix = data.Prefix
				commandPrefix:set(newPrefix)
				prefixDirty = false
				lastPrefixRefresh = os.clock()
				lastMetadataRefresh = math.max(lastMetadataRefresh, lastPrefixRefresh)
				lastRefreshError = nil

				local input = peek(commandInput)
				if input == "" or input == oldPrefix then
					syncCommandText(newPrefix, peek(isVisible))
				end
			else
				lastRefreshError = errorText(data, "Failed to refresh command prefix")
			end
		end):catch(function(err)
			if requestId == prefixRefreshRequestId then
				lastRefreshError = errorText(err, "Failed to refresh command prefix")
			end
		end):finally(function()
			if requestId ~= prefixRefreshRequestId then
				return
			end

			prefixRefreshInFlight = false

			if pendingPrefixRefreshReason then
				local nextReason = pendingPrefixRefreshReason
				pendingPrefixRefreshReason = nil
				prefixDirty = true
				task.defer(function()
					RefreshPrefix(nextReason)
				end)
			end
		end)

		return true
	end
	
	local function RefreshMetadata(reason: string?)
		local refreshReason = reason or metadataDirtyReason
		local commandStarted = RefreshCommands(refreshReason)
		local prefixStarted = RefreshPrefix(refreshReason)

		if commandStarted or prefixStarted then
			metadataDirty = false
			metadataDirtyReason = nil
		end

		return commandStarted or prefixStarted
	end

	-- kinky
	local function MarkMetadataDirty(reason: string?)
		local dirtyReason = reason or "Unknown"
		metadataDirty = true
		metadataDirtyReason = dirtyReason

		if dirtyReason == "PrefixChanged" or dirtyReason == "SettingsChanged" then
			prefixDirty = true
		elseif dirtyReason == "CommandsChanged" or dirtyReason == "PluginLoaded" or dirtyReason == "PluginUnloaded" then
			commandsDirty = true
		else
			commandsDirty = true
			prefixDirty = true
		end
	end

	local function ShouldRefreshMetadata(): boolean
		if metadataDirty or commandsDirty or prefixDirty then
			return true
		end

		local now = os.clock()
		return lastMetadataRefresh == 0 or now - lastMetadataRefresh >= METADATA_REFRESH_STALE_SECONDS
	end

	local suggestions = Computed(Scope, function(use)
		local input: string = use(commandInput)
		local prefix = use(commandPrefix)
		if not input or input == "" or string.sub(input, 1, #prefix) ~= prefix then
			return {}
		end
		
		local allCommands = use(commands)
		local context = GetInputContext(input, prefix)
		local activeCommand = FindCommand(allCommands, context.CommandName)
		local matches = {}

		if activeCommand then
			if context.ActiveArgIndex == 0 then
				local actionText = if HasArguments(activeCommand) then "Enter/Complete: Complete" else "Enter/Complete: Execute"
				return {{
					Kind = "command",
					Text = BuildCommandSuggestionText(prefix, activeCommand, actionText),
					Completion = prefix .. activeCommand.Name .. (if HasArguments(activeCommand) then " " else ""),
					Score = 0
				}}
			end
			
			local argSpec = (activeCommand.Arguments or {})[context.ActiveArgIndex]
			if argSpec and argSpec.Type == "player" then
				for _, player in ipairs(Players:GetPlayers()) do
					local nameScore = FuzzyScore(context.ActiveArg, player.Name)
					local displayScore = FuzzyScore(context.ActiveArg, player.DisplayName)
					local score = math.min(nameScore or math.huge, displayScore or math.huge)

					if score < math.huge then
						table.insert(matches, {
							Kind = "player",
							Text = string.format("%s (@%s)", player.DisplayName, player.Name),
							Description = argSpec.Name or "player",
							Completion = buildPlayerCompletion(prefix, activeCommand.Name, context.Args, context.ActiveArgIndex, player.Name),
							Score = score
						})
					end
				end

				table.sort(matches, function(a, b)
					if a.Score == b.Score then
						return a.Text < b.Text
					end
					return a.Score < b.Score
				end)

				while #matches > 5 do
					table.remove(matches)
				end
				return matches
			elseif argSpec and argSpec.Type == "duration" then
				local durationOptions = {"30s", "5m", "1h", "1d", "7d"}
				for _, option in ipairs(durationOptions) do
					local score = FuzzyScore(context.ActiveArg, option)
					if score then
						table.insert(matches, {
							Kind = "duration",
							Text = string.format("%s - duration", option),
							Description = argSpec.Name or "duration",
							Completion = buildArgumentCompletion(prefix, activeCommand.Name, context.Args, context.ActiveArgIndex, option),
							Score = score
						})
					end
				end
				table.sort(matches, function(a, b)
					return a.Score < b.Score
				end)
				return matches
			elseif argSpec then
				return {buildArgumentHint(prefix, activeCommand, argSpec)}
			elseif context.CommandName ~= "" then
				return {{
					Kind = "usage",
					Text = FormatCommandUsage(prefix, activeCommand),
					Description = activeCommand.Description or "",
					Completion = nil,
					Score = 0
				}}
			end
		end
		
		for _, cmd in ipairs(allCommands) do
			if string.find(string.lower(cmd.Name or ""), context.CommandName, 1, true) then
				table.insert(matches, {
					Kind = "command",
					Text = string.format("%s%s - %s", prefix, cmd.Name, cmd.Description or ""),
					Completion = buildCommandNameCompletion(prefix, cmd.Name, input, HasArguments(cmd))
				})
				if #matches >= 5 then break end
			end
		end
		
		return matches
	end)
	
	local function getCommandTextBox(): TextBox?
		if not commandBar then
			return nil
		end
		return commandBar:FindFirstChildWhichIsA("TextBox", true)
	end

	local function setCaretToEnd(textBox: TextBox)
		pcall(function()
			textBox.CursorPosition = #textBox.Text + 1
		end)
	end

	function syncCommandText(text: string, shouldFocus: boolean?)
		text = sanitizeInputText(text)
		programmaticTextWrite = text
		commandInput:set(text)
		task.defer(function()
			local textBox = getCommandTextBox()
			if not textBox then
				return
			end
			if textBox.Text ~= text then
				textBox.Text = text
			end
			if shouldFocus then
				if not peek(isVisible) then
					return
				end
				textBox:CaptureFocus()
			end
			setCaretToEnd(textBox)
		end)
	end

	RefreshMetadata("InitialLoad")

	local function clampSelectedSuggestionIndex()
		local count = #peek(suggestions)
		if count == 0 then
			selectedSuggestionIndex:set(0)
			return
		end

		local selectedIndex = peek(selectedSuggestionIndex)
		if selectedIndex < 1 then
			selectedSuggestionIndex:set(1)
		elseif selectedIndex > count then
			selectedSuggestionIndex:set(count)
		end
	end

	local function resetSelectedSuggestion()
		task.defer(function()
			local count = #peek(suggestions)
			selectedSuggestionIndex:set(if count > 0 then 1 else 0)
		end)
	end

	local function releaseCommandInputFocus()
		local textBox = getCommandTextBox()
		local focusedTextBox = UserInputService:GetFocusedTextBox()
		if focusedTextBox and commandBar and focusedTextBox:IsDescendantOf(commandBar) then
			focusedTextBox:ReleaseFocus(false)
		end
		if textBox then
			textBox:ReleaseFocus(false)
		end
	end

	local function releaseCommandInputFocusDeferred()
		releaseCommandInputFocus()
		task.defer(function()
			if not peek(isVisible) then
				releaseCommandInputFocus()
			end
		end)
	end

	local function pushCommandBarContext()
		if commandBarContextActive or not InputBindingController then
			return
		end

		local ok = InputBindingController:PushContext(COMMAND_BAR_CONTEXT)
		commandBarContextActive = ok == true
	end

	local function popCommandBarContext()
		if not commandBarContextActive or not InputBindingController then
			return
		end

		InputBindingController:PopContext(COMMAND_BAR_CONTEXT)
		commandBarContextActive = false
	end

	local function closeCommandBar(clearInput: boolean?)
		if SetCommandInputActionBound then
			SetCommandInputActionBound(false)
		end
		pendingTabFallbackId += 1
		pendingVerticalFallbackId += 1
		isVisible:set(false)
		popCommandBarContext()
		selectedSuggestionIndex:set(0)
		if clearInput then
			syncCommandText("", false)
		end
		releaseCommandInputFocusDeferred()
	end

	local function focusCommandInput(cursorPosition: number?)
		task.defer(function()
			if not peek(isVisible) then
				return
			end
			local textBox = getCommandTextBox()
			if textBox then
				textBox:CaptureFocus()
				pcall(function()
					textBox.CursorPosition = cursorPosition or #peek(commandInput) + 1
				end)
			end
		end)
	end

	function openCommandBar(resetInput: boolean?)
		if ShouldRefreshMetadata() then
			RefreshMetadata("Open")
		end

		if #peek(commands) == 0 then
			openAfterCommandRefresh = true
			return
		end

		isVisible:set(true)
		pushCommandBarContext()
		resetSelectedSuggestion()
		if resetInput ~= false then
			syncCommandText(peek(commandPrefix), true)
		else
			focusCommandInput()
		end
	end

	local function executeCommand(): boolean
		local cmd = peek(commandInput)
		local prefix = peek(commandPrefix)
		if string.sub(cmd, 1, #prefix) ~= prefix then
			cmd = prefix .. cmd
		end

		if cmd == "" or string.match(string.sub(cmd, #prefix + 1), "^%s*$") then
			closeCommandBar(true)
			return true
		end

		local incompleteStatus = getIncompleteRequiredArgumentStatus(peek(commands), cmd, prefix)
		if incompleteStatus then
			local context = incompleteStatus.Context
			if #context.Args == 0 then
				syncCommandText(prefix .. incompleteStatus.Command.Name .. " ", true)
			elseif not context.HasTrailingSpace then
				syncCommandText(cmd .. " ", true)
			else
				focusCommandInput()
			end
			return false
		end
		
		local old = peek(commandHistory)
		local hist = table.clone(old)
		table.insert(hist, cmd)
		commandHistory:set(hist)
		historyIndex:set(#hist + 1)
		
		closeCommandBar(true)
		
		NetworkController:Invoke("ExecuteCommand", cmd):andThen(function(result)
			if result.Success then
				NotificationController:Show("Success", result.Message or "Command executed", 3)
			else
				NotificationController:Show("Error", result.Message or "Command failed", 4)
			end
		end):catch(function(err)
			NotificationController:Show("Error", errorText(err, "Failed to execute command"), 4)
		end)

		return true
	end

	local function getSelectedSuggestion()
		local currentSuggestions = peek(suggestions)
		local selectedIndex = peek(selectedSuggestionIndex)
		if selectedIndex < 1 or selectedIndex > #currentSuggestions then
			return nil
		end
		return currentSuggestions[selectedIndex]
	end

	local function acceptSelectedSuggestion(): boolean
		clampSelectedSuggestionIndex()
		local selectedSuggestion = getSelectedSuggestion()
		if selectedSuggestion and selectedSuggestion.Completion then
			syncCommandText(selectedSuggestion.Completion, true)
			return true
		end

		for index, suggestion in ipairs(peek(suggestions)) do
			if suggestion.Completion then
				selectedSuggestionIndex:set(index)
				syncCommandText(suggestion.Completion, true)
				return true
			end
		end

		return false
	end

	local function CompleteSingleSuggestionAndExecute(): boolean
		clampSelectedSuggestionIndex()

		local currentSuggestions = peek(suggestions)
		if #currentSuggestions ~= 1 then
			return false
		end

		local selectedSuggestion = getSelectedSuggestion() or currentSuggestions[1]
		if not selectedSuggestion or selectedSuggestion.Kind ~= "command" or not selectedSuggestion.Completion then
			return false
		end

		local prefix = peek(commandPrefix)
		local completion = selectedSuggestion.Completion
		if not GetSmartExecutableCommand(peek(commands), completion, prefix) then
			return false
		end

		syncCommandText(completion, false)
		executeCommand()
		return true
	end

	local function shouldNavigateSuggestions(): boolean
		if #peek(suggestions) == 0 then
			return false
		end

		local input = peek(commandInput)
		local prefix = peek(commandPrefix)
		if input == "" or string.sub(input, 1, #prefix) ~= prefix then
			return false
		end

		local context = GetInputContext(input, prefix)
		return context.CommandName ~= ""
	end

	local function moveSelectedSuggestion(delta: number): boolean
		if not shouldNavigateSuggestions() then
			return false
		end

		local count = #peek(suggestions)
		if count == 0 then
			selectedSuggestionIndex:set(0)
			return false
		end

		local selectedIndex = peek(selectedSuggestionIndex)
		if selectedIndex < 1 then
			selectedIndex = if delta > 0 then 0 else count + 1
		end

		selectedIndex += delta
		if selectedIndex < 1 then
			selectedIndex = count
		elseif selectedIndex > count then
			selectedIndex = 1
		end

		selectedSuggestionIndex:set(selectedIndex)
		return true
	end

	local function shouldCompleteSelectedCommandBeforeExecute(): boolean
		if not shouldNavigateSuggestions() then
			return false
		end

		clampSelectedSuggestionIndex()
		local selectedSuggestion = getSelectedSuggestion()
		if not selectedSuggestion then
			selectedSuggestion = peek(suggestions)[1]
		end
		if not selectedSuggestion or not selectedSuggestion.Completion or selectedSuggestion.Kind ~= "command" then
			return false
		end

		local input = peek(commandInput)
		local prefix = peek(commandPrefix)
		local body = string.sub(input, #prefix + 1)
		return string.match(body, "^%S*$") ~= nil
	end

	local function HandleCompleteExecute(completeAnySuggestion: boolean): boolean
		if GetSmartExecutableCommand(peek(commands), peek(commandInput), peek(commandPrefix)) then
			executeCommand()
			return true
		end

		if completeAnySuggestion then
			if CompleteSingleSuggestionAndExecute() then
				return true
			end
			return acceptSelectedSuggestion()
		end

		if CompleteSingleSuggestionAndExecute() then
			return true
		end

		if shouldCompleteSelectedCommandBeforeExecute() then
			return acceptSelectedSuggestion()
		end

		return false
	end

	local function TabComplete(): boolean
		local now = os.clock()
		if lastTabCompletionAt > 0 and now - lastTabCompletionAt < 0.05 then
			return true
		end
		lastTabCompletionAt = now
		return HandleCompleteExecute(true)
	end

	local function NavHistory(delta: number)
		local hist = peek(commandHistory)
		local idx = math.clamp(peek(historyIndex) + delta, 1, #hist + 1)
		historyIndex:set(idx)
		selectedSuggestionIndex:set(0)
		if hist[idx] then
			syncCommandText(hist[idx], true)
		else
			syncCommandText(peek(commandPrefix), true)
		end
	end

	local function Navigate(delta: number)
		lastVerticalNavigationAt = os.clock()
		if not moveSelectedSuggestion(delta) then
			NavHistory(delta)
		end
	end

	local function HandleInputAction(_, inputState, inputObject)
		if not peek(isVisible) then
			return Enum.ContextActionResult.Pass
		end

		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end

		local keyCode = inputObject.KeyCode
		if keyCode == Enum.KeyCode.Tab then
			TabComplete()
		elseif keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter then
			if HandleCompleteExecute(false) then
				return Enum.ContextActionResult.Sink
			end
			executeCommand()
		elseif keyCode == Enum.KeyCode.Up or keyCode == Enum.KeyCode.DPadUp then
			Navigate(-1)
		elseif keyCode == Enum.KeyCode.Down or keyCode == Enum.KeyCode.DPadDown then
			Navigate(1)
		end

		return Enum.ContextActionResult.Sink
	end

	function SetCommandInputActionBound(shouldBind: boolean)
		if shouldBind and not commandInputActionBound then
			ContextActionService:BindActionAtPriority(
				COMMAND_INPUT_ACTION,
				HandleInputAction,
				false,
				2000,
				Enum.KeyCode.Tab,
				Enum.KeyCode.Return,
				Enum.KeyCode.KeypadEnter,
				Enum.KeyCode.Up,
				Enum.KeyCode.Down,
				Enum.KeyCode.DPadUp,
				Enum.KeyCode.DPadDown
			)
			commandInputActionBound = true
		elseif not shouldBind and commandInputActionBound then
			ContextActionService:UnbindAction(COMMAND_INPUT_ACTION)
			commandInputActionBound = false
		end
	end
	
	commandBar = New(Scope, "Frame")({
		Size = UDim2.new(0.6, 0, 0, 48),
		Position = UDim2.new(0.2, 0, 0, 100),
		BackgroundColor3 = Computed(Scope, function(use)
			return GetThemeColor(use(currentTheme), "Secondary", DEFAULT_THEME.Secondary)
		end),
		BorderSizePixel = 0,
		Visible = isVisible,
		ZIndex = 100,
		[Children] = {
			New(Scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
			New(Scope, "UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12)
			}),
			
			New(Scope, "TextBox")({
				Name = "CommandInput",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = commandInput,
				PlaceholderText = Computed(Scope, function(use)
					return "Enter command (" .. use(commandPrefix) .. ")"
				end),
				TextColor3 = Computed(Scope, function(use)
					return GetThemeColor(use(currentTheme), "Text", DEFAULT_THEME.Text)
				end),
				PlaceholderColor3 = Computed(Scope, function(use)
					return GetThemeColor(use(currentTheme), "TextSecondary", DEFAULT_THEME.TextSecondary)
				end),
				Font = Enum.Font.Gotham,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				TextEditable = isVisible,
				MultiLine = false,
				[OnEvent "FocusLost"] = function(_enterPressed)
					clampSelectedSuggestionIndex()
				end,
				[OnChange "Text"] = function(newText)
					local sanitizedText = sanitizeInputText(newText)
					if sanitizedText ~= newText then
						if string.find(newText, "\t", 1, true) and TabComplete() then
							syncCommandText(peek(commandInput), true)
							return
						end
						selectedSuggestionIndex:set(0)
						syncCommandText(sanitizedText, true)
						return
					end
					if programmaticTextWrite == newText then
						programmaticTextWrite = nil
					else
						resetSelectedSuggestion()
					end
					commandInput:set(newText)
				end
			}),
			
			New(Scope, "Frame")({
				Size = Computed(Scope, function(use)
					local sugg = use(suggestions)
					return UDim2.new(1, 0, 0, math.max(1, #sugg * 36 + 8))
				end),
				Position = UDim2.new(0, 0, 1, 4),
				BackgroundColor3 = Computed(Scope, function(use)
					return GetThemeColor(use(currentTheme), "Secondary", DEFAULT_THEME.Secondary)
				end),
				BorderSizePixel = 0,
				Visible = Computed(Scope, function(use)
					return #use(suggestions) > 0
				end),
				[Children] = {
					New(Scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
					New(Scope, "UIPadding")({
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8)
					}),
					New(Scope, "UIListLayout")({
						Padding = UDim.new(0, 2)
					}),
					Computed(Scope, function(use)
						local sugg = use(suggestions)
						local activeTheme = use(currentTheme)
						local secondary = GetThemeColor(activeTheme, "Secondary", DEFAULT_THEME.Secondary)
						local accent = GetThemeColor(activeTheme, "Accent", DEFAULT_THEME.Accent)
						local border = GetThemeColor(activeTheme, "Border", DEFAULT_THEME.Border)
						local text = GetThemeColor(activeTheme, "Text", DEFAULT_THEME.Text)
						local cornerRadius = ToUDim(activeTheme.CornerRadius, DEFAULT_THEME.CornerRadius)
						local selectedIndex = use(selectedSuggestionIndex)
						local children = {}
						for i, suggestion in ipairs(sugg) do
							local isSelected = i == selectedIndex
							children[i] = New(Scope, "TextButton")({
								BackgroundColor3 = if isSelected then accent else secondary,
								BorderColor3 = border,
								BorderSizePixel = if isSelected then 1 else 0,
								Font = Enum.Font.GothamMedium,
								Text = suggestion.Text,
								TextColor3 = text,
								Size = UDim2.new(1, 0, 0, 32),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextSize = 13,
								TextTruncate = Enum.TextTruncate.AtEnd,
								[Children] = {
									New(Scope, "UICorner")({
										CornerRadius = cornerRadius
									})
								},
								[OnEvent "MouseEnter"] = function()
									selectedSuggestionIndex:set(i)
								end,
								[OnEvent "MouseButton1Click"] = function()
									if suggestion.Completion then
										selectedSuggestionIndex:set(i)
										syncCommandText(suggestion.Completion, true)
									end
								end
							})
						end
						return children
					end)
				}
			})
		}
	})
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if peek(isVisible) and input.KeyCode == Enum.KeyCode.Escape then
			closeCommandBar(true)
			return
		end

		if peek(isVisible) and input.KeyCode == Enum.KeyCode.Tab then
			local fallbackId = pendingTabFallbackId + 1
			pendingTabFallbackId = fallbackId
			task.defer(function()
				if pendingTabFallbackId ~= fallbackId then
					return
				end
				if os.clock() - lastTabCompletionAt < 0.05 then
					return
				end
				TabComplete()
			end)
			return
		end

		local verticalDelta
		if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.DPadUp then
			verticalDelta = -1
		elseif input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.DPadDown then
			verticalDelta = 1
		end

		if peek(isVisible) and verticalDelta then
			local fallbackId = pendingVerticalFallbackId + 1
			pendingVerticalFallbackId = fallbackId
			task.defer(function()
				if pendingVerticalFallbackId ~= fallbackId then
					return
				end
				if os.clock() - lastVerticalNavigationAt < 0.05 then
					return
				end
				Navigate(verticalDelta)
			end)
			return
		end

		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Slash then
			openCommandBar()
		end
	end)
	
	Observer(Scope, suggestions):onChange(function()
		clampSelectedSuggestionIndex()
	end)

	Observer(Scope, isVisible):onChange(function()
		if peek(isVisible) then
			pushCommandBarContext()
			SetCommandInputActionBound(true)
			resetSelectedSuggestion()
			focusCommandInput()
		else
			SetCommandInputActionBound(false)
			popCommandBarContext()
			releaseCommandInputFocusDeferred()
			selectedSuggestionIndex:set(0)
		end
	end)
	
	commandBar.Parent = parent
	
	local controller
	controller = {
		CommandBar = commandBar,
		SetVisible = function(visible)
			if visible then
				openCommandBar()
			else
				closeCommandBar(false)
			end
		end,
		Open = function()
			openCommandBar()
		end,
		Close = function(clearInput)
			closeCommandBar(clearInput ~= false)
		end,
		Complete = function()
			if not peek(isVisible) then
				return false
			end
			return TabComplete()
		end,
		IsVisible = function()
			return peek(isVisible)
		end,
		RefreshMetadata = function(_, reason)
			return RefreshMetadata(reason or "Manual")
		end,
		RefreshCommands = function(_, reason)
			return RefreshCommands(reason or "Manual")
		end,
		RefreshPrefix = function(_, reason)
			return RefreshPrefix(reason or "Manual")
		end,
		MarkMetadataDirty = function(_, reason)
			MarkMetadataDirty(reason)
		end,
		GetMetadataState = function()
			return {
				LastMetadataRefresh = lastMetadataRefresh,
				LastCommandsRefresh = lastCommandsRefresh,
				LastPrefixRefresh = lastPrefixRefresh,
				MetadataDirty = metadataDirty,
				MetadataDirtyReason = metadataDirtyReason,
				CommandsDirty = commandsDirty,
				PrefixDirty = prefixDirty,
				CommandCount = #peek(commands),
				Prefix = peek(commandPrefix),
				RefreshInFlight = commandRefreshInFlight or prefixRefreshInFlight,
				CommandsRefreshInFlight = commandRefreshInFlight,
				PrefixRefreshInFlight = prefixRefreshInFlight,
				LastRefreshError = lastRefreshError,
			}
		end,
		SetTheme = function(selfOrTheme, maybeTheme)
			local newTheme = if selfOrTheme == controller then maybeTheme else selfOrTheme
			if type(newTheme) ~= "table" then
				return
			end
			currentTheme:set(NormalizeTheme(newTheme, peek(currentTheme)))
		end
	}

	return controller
end

return CommandBarController
