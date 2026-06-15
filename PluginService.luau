--[[
Not_Lowest
Plugin Service for Nexus
]]

local PluginService = {}
PluginService.__index = PluginService

local Changelog = require(script.Parent.Changelog)
local Credits = require(script.Parent.Credits)

local RESERVED_PLUGIN_NAMES = {
	Core = true,
	Custom = true,
}

local SUPPORTED_PAGE_RENDERERS = {
	InfoPage = true,
}

local SUPPORTED_DETACHED_PAGE_RENDERERS = {
	InfoPage = true,
}

local SUPPORTED_CORE_DETACHED_PAGE_RENDERERS = {
	InfoPage = true,
	CreditsPage = true,
	ChangelogPage = true,
}

local MAX_PAGE_ID_LENGTH = 80
local MAX_PAGE_NAME_LENGTH = 40
local MAX_PAGE_ICON_LENGTH = 12
local MAX_PAGE_SECTION_LENGTH = 40
local MAX_PAGE_TITLE_LENGTH = 80
local MAX_PAGE_DESCRIPTION_LENGTH = 500
local MAX_PAGE_LINES = 20
local MAX_PAGE_LINE_LENGTH = 200
local DEFAULT_PAGE_SECTION = "Plugins"
local DEFAULT_PAGE_PERMISSION = "plugins.view"
local DEFAULT_PLUGIN_PAGE_ORDER = 1000
local DEFAULT_DETACHED_PERMISSION = "plugins.view"
local DEFAULT_DETACHED_WIDTH = 520
local DEFAULT_DETACHED_HEIGHT = 360
local MIN_DETACHED_WIDTH = 280
local MIN_DETACHED_HEIGHT = 180
local MAX_DETACHED_WIDTH = 900
local MAX_DETACHED_HEIGHT = 700
local MAX_DIAGNOSTIC_ID_LENGTH = 80
local MAX_DIAGNOSTIC_TITLE_LENGTH = 60
local MAX_DIAGNOSTIC_ROWS = 30
local MAX_DIAGNOSTIC_LABEL_LENGTH = 60
local MAX_DIAGNOSTIC_VALUE_LENGTH = 160
local MAX_DIAGNOSTIC_STATUS_LENGTH = 20
local DEFAULT_DIAGNOSTIC_ORDER = 1000
local CORE_OWNER = "Core"
local COMMAND_METADATA_INVALIDATED_EVENT = "NexusCommandMetadataInvalidated"

local VALID_DIAGNOSTIC_STATUSES = {
	Ok = true,
	Warning = true,
	Error = true,
	Disabled = true,
	Unknown = true,
}

local function ShallowCopy(source)
	local copy = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			copy[key] = value
		end
	end
	return copy
end

local function CopyValue(value, depth, seen)
	local valueType = type(value)
	if value == nil or valueType == "boolean" or valueType == "number" or valueType == "string" then
		return value
	end
	if valueType ~= "table" or depth > 8 then
		return nil
	end

	seen = seen or {}
	if seen[value] then
		return nil
	end
	seen[value] = true

	local copy = {}
	for key, child in pairs(value) do
		local keyType = type(key)
		if keyType == "string" or keyType == "number" then
			local copiedChild = CopyValue(child, depth + 1, seen)
			if copiedChild ~= nil then
				copy[key] = copiedChild
			end
		end
	end

	seen[value] = nil
	return copy
end

local function GetPluginSource(pluginInstance)
	if pluginInstance:IsA("ModuleScript") then
		return pluginInstance
	end

	if pluginInstance:IsA("Folder") then
		local initModule = pluginInstance:FindFirstChild("init")
			or pluginInstance:FindFirstChild("init.luau")

		if initModule and initModule:IsA("ModuleScript") then
			return initModule
		end
	end

	return nil
end

local function SortByName(a, b)
	if a.Name == b.Name then
		return a.ClassName < b.ClassName
	end
	return a.Name < b.Name
end

local function SortStrings(values)
	table.sort(values, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return values
end

local function InsertUnique(values, seen, value)
	if type(value) ~= "string" or value == "" or seen[value] then
		return
	end

	seen[value] = true
	table.insert(values, value)
end

local function FireCommandMetadataInvalidated(NetworkService, reason: string, owner: string?)
	if not NetworkService or type(NetworkService.FireAllClients) ~= "function" then
		return
	end

	NetworkService:FireAllClients(COMMAND_METADATA_INVALIDATED_EVENT, reason, {
		Owner = owner,
	})
end

local function GetInstancePath(instance)
	local success, path = pcall(function()
		return instance:GetFullName()
	end)

	if success then
		return path
	end

	return instance.Name
end

local function trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function ValidateText(value, fieldName, maxLength, required)
	if value == nil then
		if required then
			return nil, ("%s is required"):format(fieldName)
		end
		return nil
	end

	if type(value) ~= "string" then
		return nil, ("%s must be a string"):format(fieldName)
	end

	local text = trim(value)
	if required and text == "" then
		return nil, ("%s must be a non-empty string"):format(fieldName)
	end
	if text ~= "" and #text > maxLength then
		return nil, ("%s exceeds %d characters"):format(fieldName, maxLength)
	end

	return text
end

local function isValidPageId(pageId)
	return type(pageId) == "string"
		and pageId ~= ""
		and #pageId <= MAX_PAGE_ID_LENGTH
		and pageId:match("^[%w_%.%-]+$") ~= nil
end

local function isValidDiagnosticId(sectionId)
	return type(sectionId) == "string"
		and sectionId ~= ""
		and #sectionId <= MAX_DIAGNOSTIC_ID_LENGTH
		and sectionId:match("^[%w_%.%-]+$") ~= nil
end

local function isValidSectionName(sectionName)
	return type(sectionName) == "string"
		and sectionName ~= ""
		and #sectionName <= MAX_PAGE_SECTION_LENGTH
		and sectionName:match("^[%w%s_%-]+$") ~= nil
end

local function SanitizeInfoPageData(data, pageName)
	if data == nil then
		data = {}
	end
	if type(data) ~= "table" then
		return nil, "Page Data must be a table when provided"
	end

	local title, titleError = ValidateText(data.Title, "Data.Title", MAX_PAGE_TITLE_LENGTH, false)
	if titleError then
		return nil, titleError
	end
	local description, descriptionError = ValidateText(data.Description, "Data.Description", MAX_PAGE_DESCRIPTION_LENGTH, false)
	if descriptionError then
		return nil, descriptionError
	end

	local lines = {}
	if data.Lines ~= nil then
		if type(data.Lines) ~= "table" then
			return nil, "Data.Lines must be a table"
		end
		if #data.Lines > MAX_PAGE_LINES then
			return nil, ("Data.Lines cannot contain more than %d entries"):format(MAX_PAGE_LINES)
		end

		for index, line in ipairs(data.Lines) do
			local text, lineError = ValidateText(line, ("Data.Lines[%d]"):format(index), MAX_PAGE_LINE_LENGTH, true)
			if lineError then
				return nil, lineError
			end
			table.insert(lines, text)
		end
	end

	return {
		Title = title or pageName,
		Description = description,
		Lines = lines,
	}
end

local function sanitizeStringArray(values, maxItems, maxLength)
	local result = {}
	if type(values) ~= "table" then
		return result
	end

	for index, value in ipairs(values) do
		if index > maxItems then
			break
		end
		if type(value) == "string" and value ~= "" then
			table.insert(result, value:sub(1, maxLength))
		end
	end

	return result
end

local function sanitizeCreditsData(data)
	if type(data) ~= "table" then
		data = {}
	end

	local version = {}
	if type(data.Version) == "table" then
		version = {
			Name = type(data.Version.Name) == "string" and data.Version.Name or nil,
			Version = type(data.Version.Version) == "string" and data.Version.Version or nil,
			Channel = type(data.Version.Channel) == "string" and data.Version.Channel or nil,
			Build = type(data.Version.Build) == "string" and data.Version.Build or nil,
			Commit = type(data.Version.Commit) == "string" and data.Version.Commit or nil,
		}
	end

	local authors = {}
	if type(data.Authors) == "table" then
		for index, author in ipairs(data.Authors) do
			if index > 20 then
				break
			end
			if type(author) == "table" and type(author.Name) == "string" and author.Name ~= "" then
				table.insert(authors, {
					Name = author.Name:sub(1, MAX_PAGE_LINE_LENGTH),
					Role = type(author.Role) == "string" and author.Role:sub(1, MAX_PAGE_LINE_LENGTH) or nil,
				})
			end
		end
	end

	local sections = {}
	if type(data.Sections) == "table" then
		for index, section in ipairs(data.Sections) do
			if index > 20 then
				break
			end
			if type(section) == "table" then
				table.insert(sections, {
					Title = type(section.Title) == "string" and section.Title:sub(1, MAX_PAGE_TITLE_LENGTH) or "Credits",
					Lines = sanitizeStringArray(section.Lines, 30, MAX_PAGE_LINE_LENGTH),
				})
			end
		end
	end

	return {
		Product = type(data.Product) == "string" and data.Product:sub(1, MAX_PAGE_TITLE_LENGTH) or "Nexus Admin Framework",
		Version = version,
		Authors = authors,
		Sections = sections,
	}
end

local function sanitizeChangeRows(rows)
	local sanitized = {}
	if type(rows) ~= "table" then
		return sanitized
	end

	for index, row in ipairs(rows) do
		if index > 40 then
			break
		end
		if type(row) == "table" and type(row.Text) == "string" then
			table.insert(sanitized, {
				Type = type(row.Type) == "string" and row.Type:sub(1, 30) or "Changed",
				Text = row.Text:sub(1, 500),
			})
		elseif type(row) == "string" and row ~= "" then
			table.insert(sanitized, {
				Type = "Changed",
				Text = row:sub(1, 500),
			})
		end
	end

	return sanitized
end

local function sanitizeChangelogData(data)
	if type(data) ~= "table" then
		data = {}
	end

	local version = {}
	if type(data.Version) == "table" then
		version = CopyValue(data.Version, 1, {}) or {}
	end

	local entries = {}
	if type(data.Entries) == "table" then
		for index, entry in ipairs(data.Entries) do
			if index > 60 then
				break
			end
			if type(entry) == "table" then
				table.insert(entries, {
					Version = type(entry.Version) == "string" and entry.Version:sub(1, 40) or "unknown",
					Date = type(entry.Date) == "string" and entry.Date:sub(1, 20) or "unknown",
					Title = type(entry.Title) == "string" and entry.Title:sub(1, MAX_PAGE_TITLE_LENGTH) or "Release notes",
					Type = type(entry.Type) == "string" and entry.Type:sub(1, 30) or "Changed",
					Categories = sanitizeStringArray(entry.Categories, 12, 40),
					Summary = type(entry.Summary) == "string" and entry.Summary:sub(1, MAX_PAGE_DESCRIPTION_LENGTH) or "",
					Changes = sanitizeChangeRows(entry.Changes),
					Migration = sanitizeChangeRows(entry.Migration),
					KnownIssues = sanitizeChangeRows(entry.KnownIssues),
					Breaking = entry.Breaking == true,
				})
			end
		end
	end

	return {
		Version = version,
		Entries = entries,
	}
end

local function buildChangelogData(includeInternal: boolean)
	return {
		Version = Changelog:GetCurrentVersion(),
		Entries = includeInternal and Changelog:GetAll() or Changelog:GetPublicEntries(),
	}
end

local function SanitizeDetachedPageData(renderer, data, pageName)
	if renderer == "InfoPage" then
		return SanitizeInfoPageData(data, pageName)
	end
	if renderer == "CreditsPage" then
		return sanitizeCreditsData(data)
	end
	if renderer == "ChangelogPage" then
		return sanitizeChangelogData(data)
	end

	return nil, ("Detached page Renderer %s is not supported"):format(tostring(renderer))
end

local function isSupportedDetachedRenderer(owner, renderer)
	if owner == CORE_OWNER then
		return SUPPORTED_CORE_DETACHED_PAGE_RENDERERS[renderer] == true
	end

	return SUPPORTED_DETACHED_PAGE_RENDERERS[renderer] == true
end

local function validateFiniteNumber(value, fieldName)
	if type(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge
	then
		return nil, ("%s must be a finite number"):format(fieldName)
	end

	return value
end

local function clampInteger(value, defaultValue, minValue, maxValue)
	if value == nil then
		return defaultValue
	end

	return math.clamp(math.floor(value), minValue, maxValue)
end

local function sanitizeDiagnosticValue(value)
	local valueType = type(value)
	if value == nil or valueType == "boolean" or valueType == "number" then
		return value
	end
	if valueType == "string" then
		if #value <= MAX_DIAGNOSTIC_VALUE_LENGTH then
			return value
		end
		return value:sub(1, MAX_DIAGNOSTIC_VALUE_LENGTH)
	end

	return ("[%s]"):format(valueType)
end

local function sanitizeDiagnosticRows(rows)
	local sanitized = {}
	if type(rows) ~= "table" then
		return sanitized
	end

	for index, row in ipairs(rows) do
		if index > MAX_DIAGNOSTIC_ROWS then
			break
		end
		if type(row) == "table" then
			local label = ValidateText(row.Label, "Diagnostic row Label", MAX_DIAGNOSTIC_LABEL_LENGTH, true)
			if label then
				local status = ValidateText(row.Status, "Diagnostic row Status", MAX_DIAGNOSTIC_STATUS_LENGTH, false) or "Unknown"
				if not VALID_DIAGNOSTIC_STATUSES[status] then
					status = "Unknown"
				end

				table.insert(sanitized, {
					Label = label,
					Value = sanitizeDiagnosticValue(row.Value),
					Status = status,
				})
			end
		end
	end

	return sanitized
end

local function CopyPluginPage(page)
	local data = {}
	if type(page.Data) == "table" then
		data.Title = page.Data.Title
		data.Description = page.Data.Description
		local lines = {}
		for _, line in ipairs(page.Data.Lines or {}) do
			table.insert(lines, line)
		end
		data.Lines = lines
	end

	return {
		Id = page.Id,
		Name = page.Name,
		Icon = page.Icon,
		Section = page.Section,
		Permission = page.Permission,
		LayoutOrder = page.LayoutOrder,
		Renderer = page.Renderer,
		Owner = page.Owner,
		Data = data,
	}
end

local function copyDetachedPage(page)
	local data = type(page.Data) == "table" and CopyValue(page.Data, 1, {}) or {}

	return {
		Id = page.Id,
		Name = page.Name,
		Title = page.Title,
		Permission = page.Permission,
		Renderer = page.Renderer,
		Owner = page.Owner,
		Width = page.Width,
		Height = page.Height,
		MinWidth = page.MinWidth,
		MinHeight = page.MinHeight,
		Singleton = page.Singleton,
		AutoCloseOnPluginUnload = page.AutoCloseOnPluginUnload,
		Order = page.Order,
		Category = page.Category,
		Data = data,
	}
end

local function copyDiagnosticsSection(section, rows, status)
	return {
		Id = section.Id,
		Title = section.Title,
		Order = section.Order,
		Owner = section.Owner,
		Status = status or "Unknown",
		Rows = rows or {},
	}
end

function PluginService.new(appOrContext)
	local services = appOrContext.Services or {}
	local runtime = appOrContext.Runtime or services.Runtime or appOrContext

	local self = setmetatable({}, PluginService)
	self.App = appOrContext
	self.Services = services
	self.PluginsFolder = appOrContext.PluginsFolder or runtime.PluginsFolder
	self.Registry = appOrContext.Registry or services.Registry or runtime.Registry
	self.HookBus = appOrContext.HookBus or services.HookBus or runtime.HookBus
	self.LoadedPlugins = {}
	self.LoadedOrder = {}
	self.Errors = {}
	return self
end

function PluginService:RecordError(pluginName: string, message: string)
	local entry = {
		Plugin = pluginName,
		Message = message,
	}
	table.insert(self.Errors, entry)
	warn(("Plugin %s: %s"):format(pluginName, message))
	return entry
end

function PluginService:ValidatePlugin(plugin)
	if type(plugin) ~= "table" then
		return nil, "Plugin module must return a table"
	end

	if type(plugin.Name) ~= "string" or plugin.Name == "" then
		return nil, "Plugin Name must be a non-empty string"
	end

	if RESERVED_PLUGIN_NAMES[plugin.Name] then
		return nil, ("Plugin Name %s is reserved"):format(plugin.Name)
	end

	if self.LoadedPlugins[plugin.Name] then
		return nil, ("Duplicate plugin name %s"):format(plugin.Name)
	end

	if plugin.Version ~= nil and type(plugin.Version) ~= "string" then
		return nil, "Plugin Version must be a string"
	end

	if plugin.Author ~= nil and type(plugin.Author) ~= "string" then
		return nil, "Plugin Author must be a string"
	end

	for _, lifecycleName in ipairs({"Init", "Start", "Stop"}) do
		if plugin[lifecycleName] ~= nil and type(plugin[lifecycleName]) ~= "function" then
			return nil, ("Plugin %s must be a function"):format(lifecycleName)
		end
	end

	plugin.Version = plugin.Version or "0.0.0"
	plugin.Author = plugin.Author or "Unknown"

	return plugin
end

function PluginService.CreateApi(pluginServiceSelf, pluginName: string)
	local pluginService = pluginServiceSelf
	local services = pluginServiceSelf.Services
	local registry = pluginServiceSelf.Registry
	local hookBus = pluginServiceSelf.HookBus

	local api = {}

	function api:RegisterCommand(command)
		local commandService = services.CommandService
		if not commandService or type(commandService.RegisterCommand) ~= "function" then
			return false, "CommandService is unavailable"
		end

		return commandService:RegisterCommand(command, pluginName)
	end

	function api:RegisterPermission(permissionName: string, metadata)
		if type(permissionName) ~= "string" or permissionName == "" then
			return false, "Permission name must be a non-empty string"
		end
		if metadata ~= nil and type(metadata) ~= "table" then
			return false, "Permission metadata must be a table"
		end
		if registry:Has("Permissions", permissionName) then
			return false, ("Permission %s is already registered"):format(permissionName)
		end

		local permissionData = ShallowCopy(metadata)
		permissionData.Name = permissionData.Name or permissionName
		registry:Register("Permissions", permissionName, permissionData, pluginName)

		local permissionService = services.PermissionService
		if permissionService and type(permissionService.ClearCache) == "function" then
			permissionService:ClearCache()
		end

		return true
	end

	function api:RegisterTheme(themeName: string, themeData)
		local ThemeService = services.ThemeService

		if ThemeService and type(ThemeService.RegisterTheme) == "function" then
			return ThemeService:RegisterTheme(themeName, themeData, pluginName)
		end
		if registry:Has("Themes", themeName) then
			return false, ("Theme %s is already registered"):format(themeName)
		end

		registry:Register("Themes", themeName, themeData, pluginName)
		return true
	end

	function api:ConnectHook(hookName: string, callback, priority: number?)
		if not hookBus then
			return nil, "HookBus is unavailable"
		end

		return hookBus:Connect(hookName, callback, priority, pluginName)
	end

	function api:RegisterNetworkHandler(actionName: string, handler, requiredPermission: string?)
		if type(actionName) ~= "string" or actionName == "" then
			return false, "Network action name must be a non-empty string"
		end
		if type(handler) ~= "function" then
			return false, "Network handler must be a function"
		end
		if requiredPermission ~= nil and (type(requiredPermission) ~= "string" or requiredPermission == "") then
			return false, "Network handler permission must be a non-empty string or nil"
		end

		local NetworkService = services.NetworkService
		if not NetworkService or type(NetworkService.RegisterHandler) ~= "function" then
			return false, "NetworkService is unavailable"
		end

		if type(NetworkService.GetHandlerOwner) == "function" then
			local existingOwner = NetworkService:GetHandlerOwner(actionName)
			if existingOwner and existingOwner ~= pluginName then
				return false, ("Network action %s is already registered by %s"):format(actionName, existingOwner)
			end
		end

		return NetworkService:RegisterHandler(actionName, handler, requiredPermission, pluginName)
	end

	function api:RegisterPage(pageDefinition)
		return pluginService:RegisterPage(pluginName, pageDefinition)
	end

	function api:RegisterDetachedPage(pageDefinition)
		return pluginService:RegisterDetachedPage(pluginName, pageDefinition)
	end

	function api:RegisterDiagnosticsSection(sectionDefinition)
		return pluginService:RegisterDiagnosticsSection(pluginName, sectionDefinition)
	end

	function api:RegisterSetting(settingDefinition)
		local SettingsService = services.SettingsService
		if not SettingsService or type(SettingsService.RegisterSetting) ~= "function" then
			return false, "SettingsService is unavailable"
		end

		return SettingsService:RegisterSetting(settingDefinition, pluginName)
	end

	function api:RegisterSettings(settingDefinitions)
		local SettingsService = services.SettingsService
		if not SettingsService or type(SettingsService.RegisterSettings) ~= "function" then
			return false, "SettingsService is unavailable"
		end

		return SettingsService:RegisterSettings(settingDefinitions, pluginName)
	end

	if services.MessagingService then
		function api:PublishMessage(topic: string, payload, options)
			local MessagingService = services.MessagingService
			if not MessagingService or type(MessagingService.Publish) ~= "function" then
				return false, "MessagingService is unavailable"
			end

			local messageOptions = ShallowCopy(options)
			messageOptions.Owner = pluginName
			messageOptions.PluginScoped = true

			return MessagingService:Publish(topic, payload, messageOptions)
		end

		function api:SubscribeMessage(topic: string, callback, options)
			local MessagingService = services.MessagingService
			if not MessagingService or type(MessagingService.Subscribe) ~= "function" then
				return nil, "MessagingService is unavailable"
			end

			local messageOptions = ShallowCopy(options)
			messageOptions.Owner = pluginName
			messageOptions.PluginScoped = true

			return MessagingService:Subscribe(topic, callback, messageOptions)
		end

		function api:RequestMessage(topic: string, payload, options)
			local MessagingService = services.MessagingService
			if not MessagingService or type(MessagingService.Request) ~= "function" then
				return nil, "MessagingService is unavailable"
			end

			local messageOptions = ShallowCopy(options)
			messageOptions.Owner = pluginName
			messageOptions.PluginScoped = true

			return MessagingService:Request(topic, payload, messageOptions)
		end

		function api:RespondMessage(requestId: string, payload)
			local MessagingService = services.MessagingService
			if not MessagingService or type(MessagingService.Respond) ~= "function" then
				return false, "MessagingService is unavailable"
			end

			return MessagingService:Respond(requestId, payload)
		end
	end

	function api:GetService(serviceName: string)
		if serviceName == "MessagingService" then
			return nil, "Use PublishMessage, SubscribeMessage, RequestMessage, and RespondMessage instead"
		end

		return services[serviceName]
	end

	function api:GetRegistry()
		return registry
	end

	function api:GetHookBus()
		return hookBus
	end

	function api:GetPluginName()
		return pluginName
	end

	return api
end

function PluginService:ValidateDiagnosticsSection(pluginName: string, sectionDefinition)
	if type(sectionDefinition) ~= "table" then
		return nil, "Diagnostics section definition must be a table"
	end

	local sectionId = trim(sectionDefinition.Id)
	if not isValidDiagnosticId(sectionId) then
		return nil, ("Diagnostics section Id must be 1-%d characters and contain only letters, numbers, '.', '-', or '_'"):format(MAX_DIAGNOSTIC_ID_LENGTH)
	end
	if sectionId:sub(1, #pluginName + 1) ~= pluginName .. "." then
		return nil, ("Diagnostics section Id must start with %s."):format(pluginName)
	end

	local title, titleError = ValidateText(sectionDefinition.Title, "Diagnostics section Title", MAX_DIAGNOSTIC_TITLE_LENGTH, true)
	if titleError then
		return nil, titleError
	end

	local order = DEFAULT_DIAGNOSTIC_ORDER
	if sectionDefinition.Order ~= nil then
		if type(sectionDefinition.Order) ~= "number"
			or sectionDefinition.Order ~= sectionDefinition.Order
			or sectionDefinition.Order == math.huge
			or sectionDefinition.Order == -math.huge
		then
			return nil, "Diagnostics section Order must be a finite number"
		end
		order = math.floor(sectionDefinition.Order)
	end

	local rows = sectionDefinition.Rows
	local rowsType = type(rows)
	if rowsType ~= "table" and rowsType ~= "function" then
		return nil, "Diagnostics section Rows must be a table or function"
	end

	return {
		Id = sectionId,
		Title = title,
		Order = order,
		Owner = pluginName,
		Rows = rows,
		IsDynamic = rowsType == "function",
	}
end

function PluginService:RegisterDiagnosticsSection(pluginName: string, sectionDefinition)
	if type(pluginName) ~= "string" or pluginName == "" then
		return false, "Plugin name must be a non-empty string"
	end
	if not self.Registry then
		return false, "Registry is unavailable"
	end

	local section, validationError = self:ValidateDiagnosticsSection(pluginName, sectionDefinition)
	if not section then
		return false, validationError
	end

	local existingOwner = self.Registry:GetOwner("PluginDiagnosticsSections", section.Id)
	if existingOwner and existingOwner ~= pluginName then
		return false, ("Plugin diagnostics section %s is already registered by %s"):format(section.Id, existingOwner)
	end

	self.Registry:Register("PluginDiagnosticsSections", section.Id, section, pluginName)
	return true
end

function PluginService:GetDiagnosticsSections()
	local sections = {}
	if not self.Registry then
		return sections
	end

	for _, section in pairs(self.Registry:GetAll("PluginDiagnosticsSections")) do
		local rows = {}
		local status = "Ok"

		if type(section.Rows) == "function" then
			local success, result = pcall(section.Rows)
			if success then
				rows = sanitizeDiagnosticRows(result)
			else
				status = "Error"
				rows = {
					{
						Label = "Rows",
						Value = sanitizeDiagnosticValue(tostring(result)),
						Status = "Error",
					},
				}
			end
		else
			rows = sanitizeDiagnosticRows(section.Rows)
		end

		table.insert(sections, copyDiagnosticsSection(section, rows, status))
	end

	table.sort(sections, function(a, b)
		if a.Order == b.Order then
			return a.Id < b.Id
		end
		return a.Order < b.Order
	end)

	return sections
end

function PluginService:ValidatePageDefinition(pluginName: string, pageDefinition)
	if type(pageDefinition) ~= "table" then
		return nil, "Page definition must be a table"
	end

	local pageId = trim(pageDefinition.Id)
	if not isValidPageId(pageId) then
		return nil, ("Page Id must be 1-%d characters and contain only letters, numbers, '.', '-', or '_'"):format(MAX_PAGE_ID_LENGTH)
	end

	local pageName, nameError = ValidateText(pageDefinition.Name, "Page Name", MAX_PAGE_NAME_LENGTH, true)
	if nameError then
		return nil, nameError
	end

	local icon = "[P]"
	if pageDefinition.Icon ~= nil then
		local iconText, iconError = ValidateText(pageDefinition.Icon, "Page Icon", MAX_PAGE_ICON_LENGTH, false)
		if iconError then
			return nil, iconError
		end
		if iconText and iconText ~= "" then
			icon = iconText
		end
	end

	local section = DEFAULT_PAGE_SECTION
	if pageDefinition.Section ~= nil then
		local sectionText, sectionError = ValidateText(pageDefinition.Section, "Page Section", MAX_PAGE_SECTION_LENGTH, false)
		if sectionError then
			return nil, sectionError
		end
		if sectionText and sectionText ~= "" then
			section = sectionText
		end
	end
	if not isValidSectionName(section) then
		return nil, ("Page Section must be 1-%d characters and contain only letters, numbers, spaces, '-', or '_'"):format(MAX_PAGE_SECTION_LENGTH)
	end

	local permission = DEFAULT_PAGE_PERMISSION
	if pageDefinition.Permission ~= nil then
		local permissionText, permissionError = ValidateText(pageDefinition.Permission, "Page Permission", 80, false)
		if permissionError then
			return nil, permissionError
		end
		if permissionText and permissionText ~= "" then
			permission = permissionText
		end
	end

	local layoutOrder = DEFAULT_PLUGIN_PAGE_ORDER
	if pageDefinition.LayoutOrder ~= nil then
		if type(pageDefinition.LayoutOrder) ~= "number"
			or pageDefinition.LayoutOrder ~= pageDefinition.LayoutOrder
			or pageDefinition.LayoutOrder == math.huge
			or pageDefinition.LayoutOrder == -math.huge
		then
			return nil, "Page LayoutOrder must be a finite number"
		end
		layoutOrder = math.floor(pageDefinition.LayoutOrder)
	end

	local renderer, rendererError = ValidateText(pageDefinition.Renderer, "Page Renderer", 40, true)
	if rendererError then
		return nil, rendererError
	end
	if not SUPPORTED_PAGE_RENDERERS[renderer] then
		return nil, ("Page Renderer %s is not supported"):format(renderer)
	end

	local data, dataError = SanitizeInfoPageData(pageDefinition.Data, pageName)
	if dataError then
		return nil, dataError
	end

	return {
		Id = pageId,
		Name = pageName,
		Icon = icon,
		Section = section,
		Permission = permission,
		LayoutOrder = layoutOrder,
		Renderer = renderer,
		Owner = pluginName,
		Data = data,
	}
end

function PluginService:RegisterPage(pluginName: string, pageDefinition)
	if type(pluginName) ~= "string" or pluginName == "" then
		return false, "Plugin name must be a non-empty string"
	end
	if not self.Registry then
		return false, "Registry is unavailable"
	end

	local page, validationError = self:ValidatePageDefinition(pluginName, pageDefinition)
	if not page then
		return false, validationError
	end

	local existingOwner = self.Registry:GetOwner("PluginPages", page.Id)
	if existingOwner and existingOwner ~= pluginName then
		return false, ("Plugin page %s is already registered by %s"):format(page.Id, existingOwner)
	end

	self.Registry:Register("PluginPages", page.Id, page, pluginName)
	return true
end

function PluginService:RegisterCoreDetachedPages()
	local creditsRegistered, creditsError = self:RegisterDetachedPage(CORE_OWNER, {
		Id = "Nexus.Credits",
		Name = "Credits",
		Title = "Nexus Credits",
		Renderer = "CreditsPage",
		Permission = "dashboard.view",
		Width = 560,
		Height = 420,
		Singleton = true,
		AutoCloseOnPluginUnload = false,
		Order = 10,
		Category = "System",
		Data = Credits:Get(),
	})
	if not creditsRegistered then
		self:RecordError(CORE_OWNER, ("Credits page registration failed: %s"):format(tostring(creditsError)))
	end

	local changelogRegistered, changelogError = self:RegisterDetachedPage(CORE_OWNER, {
		Id = "Nexus.Changelog",
		Name = "Changelog",
		Title = "Nexus Changelog",
		Renderer = "ChangelogPage",
		Permission = "dashboard.view",
		Width = 720,
		Height = 520,
		Singleton = true,
		AutoCloseOnPluginUnload = false,
		Order = 20,
		Category = "System",
		Data = buildChangelogData(false),
	})
	if not changelogRegistered then
		self:RecordError(CORE_OWNER, ("Changelog page registration failed: %s"):format(tostring(changelogError)))
	end

	return creditsRegistered and changelogRegistered
end

function PluginService:ValidateDetachedPageDefinition(owner: string, pageDefinition)
	if type(pageDefinition) ~= "table" then
		return nil, "Detached page definition must be a table"
	end

	local pageId = trim(pageDefinition.Id)
	if not isValidPageId(pageId) then
		return nil, ("Detached page Id must be 1-%d characters and contain only letters, numbers, '.', '-', or '_'"):format(MAX_PAGE_ID_LENGTH)
	end
	if owner ~= "Core" and pageId:sub(1, #owner + 1) ~= owner .. "." then
		return nil, ("Detached page Id must start with %s."):format(owner)
	end

	local pageName, nameError = ValidateText(pageDefinition.Name, "Detached page Name", MAX_PAGE_NAME_LENGTH, true)
	if nameError then
		return nil, nameError
	end

	local title = pageName
	if pageDefinition.Title ~= nil then
		local titleText, titleError = ValidateText(pageDefinition.Title, "Detached page Title", MAX_PAGE_TITLE_LENGTH, false)
		if titleError then
			return nil, titleError
		end
		if titleText and titleText ~= "" then
			title = titleText
		end
	end

	local permission = DEFAULT_DETACHED_PERMISSION
	if pageDefinition.Permission ~= nil then
		local permissionText, permissionError = ValidateText(pageDefinition.Permission, "Detached page Permission", 80, false)
		if permissionError then
			return nil, permissionError
		end
		if permissionText and permissionText ~= "" then
			permission = permissionText
		end
	end

	local renderer, rendererError = ValidateText(pageDefinition.Renderer, "Detached page Renderer", 40, true)
	if rendererError then
		return nil, rendererError
	end
	if not isSupportedDetachedRenderer(owner, renderer) then
		return nil, ("Detached page Renderer %s is not supported"):format(renderer)
	end

	local width = DEFAULT_DETACHED_WIDTH
	if pageDefinition.Width ~= nil then
		local value, valueError = validateFiniteNumber(pageDefinition.Width, "Detached page Width")
		if valueError then
			return nil, valueError
		end
		width = clampInteger(value, DEFAULT_DETACHED_WIDTH, MIN_DETACHED_WIDTH, MAX_DETACHED_WIDTH)
	end

	local height = DEFAULT_DETACHED_HEIGHT
	if pageDefinition.Height ~= nil then
		local value, valueError = validateFiniteNumber(pageDefinition.Height, "Detached page Height")
		if valueError then
			return nil, valueError
		end
		height = clampInteger(value, DEFAULT_DETACHED_HEIGHT, MIN_DETACHED_HEIGHT, MAX_DETACHED_HEIGHT)
	end

	local minWidth = MIN_DETACHED_WIDTH
	if pageDefinition.MinWidth ~= nil then
		local value, valueError = validateFiniteNumber(pageDefinition.MinWidth, "Detached page MinWidth")
		if valueError then
			return nil, valueError
		end
		minWidth = clampInteger(value, MIN_DETACHED_WIDTH, MIN_DETACHED_WIDTH, width)
	end

	local minHeight = MIN_DETACHED_HEIGHT
	if pageDefinition.MinHeight ~= nil then
		local value, valueError = validateFiniteNumber(pageDefinition.MinHeight, "Detached page MinHeight")
		if valueError then
			return nil, valueError
		end
		minHeight = clampInteger(value, MIN_DETACHED_HEIGHT, MIN_DETACHED_HEIGHT, height)
	end

	local order = DEFAULT_PLUGIN_PAGE_ORDER
	if pageDefinition.Order ~= nil then
		local value, valueError = validateFiniteNumber(pageDefinition.Order, "Detached page Order")
		if valueError then
			return nil, valueError
		end
		order = math.floor(value)
	end

	local category = nil
	if pageDefinition.Category ~= nil then
		local categoryText, categoryError = ValidateText(pageDefinition.Category, "Detached page Category", MAX_PAGE_SECTION_LENGTH, false)
		if categoryError then
			return nil, categoryError
		end
		if categoryText and categoryText ~= "" then
			category = categoryText
		end
	end

	local data, dataError = SanitizeDetachedPageData(renderer, pageDefinition.Data, pageName)
	if dataError then
		return nil, dataError
	end

	return {
		Id = pageId,
		Name = pageName,
		Title = title,
		Permission = permission,
		Renderer = renderer,
		Owner = owner,
		Width = width,
		Height = height,
		MinWidth = minWidth,
		MinHeight = minHeight,
		Singleton = pageDefinition.Singleton ~= false,
		AutoCloseOnPluginUnload = pageDefinition.AutoCloseOnPluginUnload ~= false,
		Order = order,
		Category = category,
		Data = data,
	}
end

function PluginService:RegisterDetachedPage(owner: string, pageDefinition)
	if type(owner) ~= "string" or owner == "" then
		return false, "Owner must be a non-empty string"
	end
	if not self.Registry then
		return false, "Registry is unavailable"
	end

	local page, validationError = self:ValidateDetachedPageDefinition(owner, pageDefinition)
	if not page then
		return false, validationError
	end

	local existingOwner = self.Registry:GetOwner("DetachedPages", page.Id)
	if existingOwner and existingOwner ~= owner then
		return false, ("Detached page %s is already registered by %s"):format(page.Id, existingOwner)
	end

	self.Registry:Register("DetachedPages", page.Id, page, owner)
	return true
end

function PluginService:GetDetachedPages()
	local pages = {}
	if not self.Registry then
		return pages
	end

	for _, page in pairs(self.Registry:GetAll("DetachedPages")) do
		table.insert(pages, copyDetachedPage(page))
	end

	table.sort(pages, function(a, b)
		if a.Order == b.Order then
			return a.Id < b.Id
		end
		return a.Order < b.Order
	end)

	return pages
end

function PluginService:GetDetachedPage(id: string)
	if type(id) ~= "string" or id == "" or not self.Registry then
		return nil
	end

	local page = self.Registry:Get("DetachedPages", id)
	if not page then
		return nil
	end

	return copyDetachedPage(page)
end

function PluginService:CanPlayerUseDetachedPage(player, page)
	if type(page) ~= "table" then
		return false
	end
	if page.Permission == nil then
		return true
	end

	local permissionService = self.Services.PermissionService
	if not permissionService or type(permissionService.HasPermission) ~= "function" or not player then
		return false
	end

	local success, result = pcall(function()
		return permissionService:HasPermission(player.UserId, page.Permission)
	end)
	return success and result == true
end

function PluginService:CanPlayerUsePluginPage(player, page)
	if type(page) ~= "table" then
		return false
	end
	if page.Permission == nil then
		return true
	end

	local permissionService = self.Services.PermissionService
	if not permissionService or type(permissionService.HasPermission) ~= "function" or not player then
		return false
	end

	local success, result = pcall(function()
		return permissionService:HasPermission(player.UserId, page.Permission)
	end)
	return success and result == true
end

function PluginService:PlayerHasDeveloperPermission(player, permission: string): boolean
	local permissionService = self.Services.PermissionService
	if not permissionService or not player then
		return false
	end

	local success, result = pcall(function()
		if type(permissionService.HasDeveloperPermission) == "function" then
			return permissionService:HasDeveloperPermission(player.UserId, permission)
		end
		if type(permissionService.HasPermission) == "function" then
			return permissionService:HasPermission(player.UserId, permission)
		end
		return false
	end)

	return success and result == true
end

function PluginService:FilterPluginPageForPlayer(player, page)
	if not self:PlayerHasDeveloperPermission(player, "developer.plugins") then
		page.Owner = nil
	end

	return page
end

function PluginService:FilterDetachedPageForPlayer(player, page)
	if page.Id == "Nexus.Changelog" then
		local includeInternal = self:PlayerHasDeveloperPermission(player, "developer.changelog")
		page.Data = sanitizeChangelogData(buildChangelogData(includeInternal))
	end

	if not self:PlayerHasDeveloperPermission(player, "developer.plugins") then
		page.Owner = nil
	end

	return page
end

function PluginService:GetDetachedPagesForPlayer(player)
	local pages = {}
	for _, page in ipairs(self:GetDetachedPages()) do
		if self:CanPlayerUseDetachedPage(player, page) then
			table.insert(pages, self:FilterDetachedPageForPlayer(player, page))
		end
	end

	return pages
end

function PluginService:GetDetachedPageForPlayer(player, id: string)
	local page = self:GetDetachedPage(id)
	if not page or not self:CanPlayerUseDetachedPage(player, page) then
		return nil
	end

	return self:FilterDetachedPageForPlayer(player, page)
end

function PluginService:GetPluginPages()
	local pages = {}
	if not self.Registry then
		return pages
	end

	for _, page in pairs(self.Registry:GetAll("PluginPages")) do
		table.insert(pages, CopyPluginPage(page))
	end

	table.sort(pages, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return a.Id < b.Id
		end
		return a.LayoutOrder < b.LayoutOrder
	end)

	return pages
end

function PluginService:GetPluginPagesForPlayer(player)
	local pages = {}
	for _, page in ipairs(self:GetPluginPages()) do
		if self:CanPlayerUsePluginPage(player, page) then
			table.insert(pages, self:FilterPluginPageForPlayer(player, page))
		end
	end

	return pages
end

function PluginService:GetPluginPageCountsForPlayer(player)
	local counts = {}

	for _, page in ipairs(self:GetPluginPages()) do
		if type(page.Owner) == "string" and self:CanPlayerUsePluginPage(player, page) then
			counts[page.Owner] = (counts[page.Owner] or 0) + 1
		end
	end

	for _, page in ipairs(self:GetDetachedPages()) do
		if type(page.Owner) == "string" and self:CanPlayerUseDetachedPage(player, page) then
			counts[page.Owner] = (counts[page.Owner] or 0) + 1
		end
	end

	return counts
end

function PluginService:CleanupOwner(owner: string)
	local hadCommands = false
	if self.Registry and type(self.Registry.GetOwnedEntries) == "function" then
		local ownedEntries = self.Registry:GetOwnedEntries(owner)
		hadCommands = type(ownedEntries.Commands) == "table" and #ownedEntries.Commands > 0
	end

	local ThemeService = self.Services.ThemeService
	if ThemeService and type(ThemeService.UnregisterOwner) == "function" then
		local success, err = pcall(function()
			ThemeService:UnregisterOwner(owner)
		end)
		if not success then
			self:RecordError(owner, ("Theme cleanup failed: %s"):format(tostring(err)))
		end
	end

	local NetworkService = self.Services.NetworkService
	if NetworkService and type(NetworkService.UnregisterOwner) == "function" then
		local success, err = pcall(function()
			NetworkService:UnregisterOwner(owner)
		end)
		if not success then
			self:RecordError(owner, ("Network handler cleanup failed: %s"):format(tostring(err)))
		end
	end

	local MessagingService = self.Services.MessagingService
	if MessagingService and type(MessagingService.UnsubscribeOwner) == "function" then
		local success, err = pcall(function()
			MessagingService:UnsubscribeOwner(owner)
		end)
		if not success then
			self:RecordError(owner, ("Messaging cleanup failed: %s"):format(tostring(err)))
		end
	end

	local SettingsService = self.Services.SettingsService
	if SettingsService and type(SettingsService.UnregisterOwner) == "function" then
		local success, err = pcall(function()
			SettingsService:UnregisterOwner(owner)
		end)
		if not success then
			self:RecordError(owner, ("Settings cleanup failed: %s"):format(tostring(err)))
		end
	end

	if self.Registry then
		self.Registry:UnregisterOwner(owner)
	end
	if self.HookBus then
		self.HookBus:DisconnectOwner(owner)
	end

	if hadCommands then
		FireCommandMetadataInvalidated(self.Services.NetworkService, "PluginUnloaded", owner)
	end
end

function PluginService:LoadPlugins()
	if not self.PluginsFolder then
		print("Plugin discovery skipped: Plugins folder is missing")
		return 0
	end

	local pluginInstances = {}
	for _, child in ipairs(self.PluginsFolder:GetChildren()) do
		if child:IsA("Folder") or child:IsA("ModuleScript") then
			print(("Discovered plugin instance %s (%s)"):format(GetInstancePath(child), child.ClassName))
			table.insert(pluginInstances, child)
		else
			print(("Skipping plugin instance %s (%s): expected Folder or ModuleScript"):format(GetInstancePath(child), child.ClassName))
		end
	end

	table.sort(pluginInstances, SortByName)

	local loadedCount = 0
	for _, pluginInstance in ipairs(pluginInstances) do
		local success = self:LoadPlugin(pluginInstance)
		if success then
			loadedCount += 1
		end
	end

	return loadedCount
end

function PluginService:LoadPlugin(pluginInstance)
	if not pluginInstance or not (pluginInstance:IsA("Folder") or pluginInstance:IsA("ModuleScript")) then
		self:RecordError("Unknown", "LoadPlugin expected a plugin Folder or ModuleScript")
		return false, "LoadPlugin expected a plugin Folder or ModuleScript"
	end

	local sourceModule = GetPluginSource(pluginInstance)
	if not sourceModule then
		local message = "Missing init ModuleScript"
		self:RecordError(pluginInstance.Name, message)
		return false, message
	end

	print(("Loading plugin instance %s from %s"):format(GetInstancePath(pluginInstance), GetInstancePath(sourceModule)))

	local required, pluginOrError = pcall(require, sourceModule)
	if not required then
		local message = ("Require failed: %s"):format(tostring(pluginOrError))
		self:RecordError(pluginInstance.Name, message)
		return false, message
	end

	local plugin, validationError = self:ValidatePlugin(pluginOrError)
	if not plugin then
		self:RecordError(pluginInstance.Name, validationError)
		return false, validationError
	end

	local pluginName = plugin.Name
	local api = self:CreateApi(pluginName)

	if plugin.Init then
		local initialized, initError = pcall(function()
			plugin.Init(api)
		end)
		if not initialized then
			local message = ("Init failed: %s"):format(tostring(initError))
			self:CleanupOwner(pluginName)
			self:RecordError(pluginName, message)
			return false, message
		end
	end

	if plugin.Start then
		local started, startError = pcall(function()
			plugin.Start(api)
		end)
		if not started then
			local message = ("Start failed: %s"):format(tostring(startError))
			if plugin.Stop then
				local stopped, stopError = pcall(function()
					plugin.Stop(api)
				end)
				if not stopped then
					self:RecordError(pluginName, ("Stop after failed Start failed: %s"):format(tostring(stopError)))
				end
			end
			self:CleanupOwner(pluginName)
			self:RecordError(pluginName, message)
			return false, message
		end
	end

	self.LoadedPlugins[pluginName] = {
		Name = pluginName,
		Version = plugin.Version,
		Author = plugin.Author,
		Folder = pluginInstance:IsA("Folder") and pluginInstance or nil,
		Source = pluginInstance,
		ModuleScript = sourceModule,
		Module = plugin,
		Api = api,
	}
	table.insert(self.LoadedOrder, pluginName)

	print(("Loaded plugin %s from %s"):format(pluginName, GetInstancePath(pluginInstance)))

	return true
end

function PluginService:GetLoadedPlugins()
	local plugins = {}
	for _, pluginName in ipairs(self.LoadedOrder) do
		local plugin = self.LoadedPlugins[pluginName]
		if plugin then
			table.insert(plugins, {
				Name = plugin.Name,
				Version = plugin.Version,
				Author = plugin.Author,
				Folder = plugin.Folder,
			})
		end
	end
	return plugins
end

function PluginService:GetDiagnostics()
	local diagnostics = {
		LoadedPlugins = {},
		Errors = self:GetErrors(),
	}

	for _, pluginName in ipairs(self.LoadedOrder) do
		local plugin = self.LoadedPlugins[pluginName]
		if plugin then
			local ownedEntries = {}
			if self.Registry and type(self.Registry.GetOwnedEntries) == "function" then
				ownedEntries = self.Registry:GetOwnedEntries(pluginName)
			end

			local commands = {}
			local seenCommands = {}
			for _, entry in ipairs(ownedEntries.Commands or {}) do
				InsertUnique(commands, seenCommands, entry.Name or tostring(entry.Key))
			end

			local permissions = {}
			local seenPermissions = {}
			for _, entry in ipairs(ownedEntries.Permissions or {}) do
				InsertUnique(permissions, seenPermissions, tostring(entry.Key))
			end

			local themes = {}
			local seenThemes = {}
			for _, entry in ipairs(ownedEntries.Themes or {}) do
				InsertUnique(themes, seenThemes, tostring(entry.Key))
			end

			local pages = {}
			local seenPages = {}
			for _, entry in ipairs(ownedEntries.PluginPages or {}) do
				InsertUnique(pages, seenPages, tostring(entry.Key))
			end

			local detachedPages = {}
			local seenDetachedPages = {}
			for _, entry in ipairs(ownedEntries.DetachedPages or {}) do
				InsertUnique(detachedPages, seenDetachedPages, tostring(entry.Key))
			end

			local settings = {}
			local seenSettings = {}
			for _, entry in ipairs(ownedEntries.Settings or {}) do
				InsertUnique(settings, seenSettings, tostring(entry.Key))
			end

			local diagnosticSections = {}
			local seenDiagnosticSections = {}
			for _, entry in ipairs(ownedEntries.PluginDiagnosticsSections or {}) do
				InsertUnique(diagnosticSections, seenDiagnosticSections, tostring(entry.Key))
			end

			local networkHandlers = {}
			local seenNetworkHandlers = {}
			local NetworkService = self.Services.NetworkService
			if NetworkService and type(NetworkService.GetOwnedHandlers) == "function" then
				for _, handlerInfo in ipairs(NetworkService:GetOwnedHandlers(pluginName)) do
					InsertUnique(networkHandlers, seenNetworkHandlers, handlerInfo.Action)
				end
			end

			local hooks = {}
			local seenHooks = {}
			local hookBus = self.HookBus
			if hookBus and type(hookBus.GetOwnerConnections) == "function" then
				for _, hookInfo in ipairs(hookBus:GetOwnerConnections(pluginName)) do
					InsertUnique(hooks, seenHooks, hookInfo.Hook)
				end
			end

			SortStrings(commands)
			SortStrings(permissions)
			SortStrings(themes)
			SortStrings(pages)
			SortStrings(detachedPages)
			SortStrings(settings)
			SortStrings(diagnosticSections)
			SortStrings(networkHandlers)
			SortStrings(hooks)

			table.insert(diagnostics.LoadedPlugins, {
				Name = plugin.Name,
				Version = plugin.Version,
				Author = plugin.Author,
				Folder = plugin.Source and plugin.Source.Name or plugin.Name,
				Commands = commands,
				Permissions = permissions,
				Themes = themes,
				Pages = pages,
				DetachedPages = detachedPages,
				Settings = settings,
				DiagnosticSections = diagnosticSections,
				NetworkHandlers = networkHandlers,
				Hooks = hooks,
			})
		end
	end

	diagnostics.PluginSections = self:GetDiagnosticsSections()

	return diagnostics
end

function PluginService:GetPlugin(name: string)
	local plugin = self.LoadedPlugins[name]
	if not plugin then
		return nil
	end

	return {
		Name = plugin.Name,
		Version = plugin.Version,
		Author = plugin.Author,
		Folder = plugin.Folder,
	}
end

function PluginService:GetErrors()
	local errors = {}
	for index, errorEntry in ipairs(self.Errors) do
		errors[index] = {
			Plugin = errorEntry.Plugin,
			Message = errorEntry.Message,
		}
	end
	return errors
end

function PluginService:UnloadPlugin(name: string): (boolean, string)
	local plugin = self.LoadedPlugins[name]
	if not plugin then
		return false, ("Plugin %s is not loaded"):format(tostring(name))
	end

	local stopSucceeded = true
	local stopMessage = nil
	if plugin.Module.Stop then
		stopSucceeded, stopMessage = pcall(function()
			plugin.Module.Stop(plugin.Api)
		end)
	end

	self:CleanupOwner(name)
	self.LoadedPlugins[name] = nil

	for index, pluginName in ipairs(self.LoadedOrder) do
		if pluginName == name then
			table.remove(self.LoadedOrder, index)
			break
		end
	end

	if not stopSucceeded then
		local message = ("Plugin unloaded, but Stop failed: %s"):format(tostring(stopMessage))
		self:RecordError(name, message)
		return false, message
	end

	return true, ("Plugin %s unloaded"):format(name)
end

function PluginService:UnloadAll()
	local names = {}
	for index = #self.LoadedOrder, 1, -1 do
		table.insert(names, self.LoadedOrder[index])
	end

	local allSucceeded = true
	local messages = {}
	for _, pluginName in ipairs(names) do
		local success, message = self:UnloadPlugin(pluginName)
		if not success then
			allSucceeded = false
		end
		table.insert(messages, message)
	end

	return allSucceeded, messages
end

return PluginService
