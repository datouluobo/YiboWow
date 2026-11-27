local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core and Core.UITheme
local PAGE_ID = "reputation"
local ICON = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon"

function Addon:GetMatrixFields()
    local fields = {
        { id = "reaction", title = self:T("MATRIX.FIELD_REACTION"), defaultVisible = true },
        { id = "value", title = self:T("MATRIX.FIELD_PROGRESS"), defaultVisible = true },
        { id = "state", title = self:T("MATRIX.FIELD_STATE"), defaultVisible = true },
    }
    for _, field in ipairs(self.MatrixExtraFields or {}) do
        fields[#fields + 1] = { id = field.id, title = self:T(field.label), defaultVisible = field.defaultVisible }
    end
    return fields
end

local function SurfaceMetrics(context)
    local characters = context.characters or {}
    local inset = Theme:GetMatrixInsets(context.preview)
    local display, _, nameWidth, characterWidth = Addon:GetMatrixLayout(context)
    local rowHeight = Addon:GetMatrixRowHeight()
    local rows = math.max(1, #display)
    local fixedHeight = inset.top + Theme:GetCharacterHeaderHeight(context) + inset.bottom
    if not context.preview then fixedHeight = fixedHeight + Theme.Size.compact + Theme.Space.xs end
    local horizontalInsets = inset.left + inset.right
    local minimumWidth = nameWidth + characterWidth + horizontalInsets
    local naturalWidth = nameWidth + math.max(1, #characters) * (characterWidth + Theme.Space.xs) + horizontalInsets
    if context.preview and context.surfaceAvailableWidth then
        naturalWidth = math.min(naturalWidth, math.max(minimumWidth, context.surfaceAvailableWidth * 0.72))
    end
    fixedHeight = fixedHeight + Addon:GetMatrixPreviewFooterHeight(
        context, naturalWidth - horizontalInsets, nameWidth, characterWidth)
    return {
        minContentWidth = minimumWidth,
        naturalContentWidth = naturalWidth,
        scrollContentHeight = rows * rowHeight,
        scrollFixedHeight = fixedHeight,
        minContentHeight = fixedHeight + rowHeight,
        naturalContentHeight = fixedHeight + (context.preview and rows or math.min(rows, 20)) * rowHeight,
        fixedLeftWidth = nameWidth,
        fixedTopHeight = fixedHeight,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end

function Addon:RegisterMatrixPage(options)
    if not self.matrixPageRegistered then
        options.id, options.icon, options.order = PAGE_ID, ICON, 40
        options.title = self:T("PAGE.TITLE")
        options.columnPager, options.previewEnabled, options.defaultEnabled = true, true, true
        options.scope, options.header = { mode = "realms" }, { characterNameMode = "short" }
        options.fields = self:GetMatrixFields()
        options.GetPreviewFields = function()
            local saved = self:GetSettings().previewColumns or {}
            local visible = {}
            for _, field in ipairs(options.fields) do
                if saved[field.id] ~= nil then
                    visible[field.id] = saved[field.id]
                else
                    visible[field.id] = field.id == "reaction" or field.id == "value" or field.id == "state" or field.id == "session"
                end
            end
            return visible
        end
        options.SetPreviewFieldVisible = function(fieldID, visible)
            local settings = self:GetSettings()
            settings.previewColumns = settings.previewColumns or { reaction = true, value = true, state = true }
            settings.previewColumns[fieldID] = visible
            self:NotifyChanged()
        end
        options.HasCharacterSnapshot = function(character) return self:HasMatrixSnapshot(character) end
        options.GetEligibleCharacters = function(characters)
            local eligible = {}
            for _, character in ipairs(characters) do
                if self:HasMatrixSnapshot(character) then eligible[#eligible + 1] = character end
            end
            return eligible
        end
        options.Create = function(parent) self:CreateMatrixView(parent) end
        options.Refresh = function(parent, context) self:RefreshMatrixView(parent, context) end
        options.GetSurfaceMetrics = SurfaceMetrics
        local page, err = Core.AccountView:RegisterPage(self.NAME, options)
        if not page then return nil, self:T("ERROR.PAGE_REGISTER", tostring(err)) end
        self.matrixPageRegistered = true
    end
    local entry, err = Core.Entry:RegisterBusinessEntry(self.NAME, {
        id = "yrp", brokerName = self.NAME, pageID = PAGE_ID, text = self:T("PAGE.ENTRY"), icon = ICON,
        defaultChannels = { minimap = false, broker = false, builtinBar = false },
    })
    if not entry then return nil, self:T("ERROR.ENTRY_REGISTER", tostring(err)) end
    return true
end
