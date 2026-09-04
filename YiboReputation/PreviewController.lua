local Addon = _G.YiboReputation
local Core = _G.YiboCore
local Theme = Core.UITheme
function Addon:CreatePreviewViews(parent)
 parent:SetClipsChildren(true)
 parent.previewModeButton=Core.UITheme:CreateButton(parent,132,"","secondary")
 -- Keep the instance for safely reused page frames, but no hover mode switch
 -- is exposed: reputation hover is always the monitored account comparison.
 parent.previewModeButton:Hide()
 self:CreateCurrentPreview(parent);self:CreateMonitoredPreview(parent)
end
function Addon:RefreshPreview(parent,context)
 -- Defensive visibility reset: a page instance may have just been used by
 -- the normal account window. A hover may only ever show its selected preview.
 parent.matrixToolbar:Hide();parent.matrixHeader:Hide();parent.matrixScroll:Hide();if parent.matrixScroll.ScrollBar then parent.matrixScroll.ScrollBar:Hide() end;if parent.currentCharacterOutline then parent.currentCharacterOutline:Hide() end
 parent.previewModeButton:Hide();parent.currentPreviewHeading:Hide();parent.currentPreviewNameHeader:Hide();parent.currentPreviewValueHeader:Hide();parent.currentPreviewScroll:Hide();if parent.currentPreviewScroll.ScrollBar then parent.currentPreviewScroll.ScrollBar:Hide() end;for _,row in ipairs(parent.monitoredRows or {}) do row:Show() end;for _,header in ipairs(parent.monitoredHeaders or {}) do header:Show() end;parent.monitoredDetail:Hide()
 self:RefreshMonitoredPreview(parent,context)
end
function Addon:GetPreviewMetrics(context)
 local n=#(context.characters or {})
 local rows=#self:GetSettings().monitoredFactionIDs
 return {minWidth=420,preferredWidth=math.min(1080,150+n*(n>10 and 48 or 86)),minHeight=132,preferredHeight=171+rows*Theme.Table.previewRowHeight,horizontalOverflow="matrix",verticalOverflow="none"}
 --[[ Legacy current-character metric path, retained for migration reference.
 local current = _G.YiboCore.Characters:GetCurrent()
 local snapshot = current and _G.YiboCore.DataDomains:Get(current.id, "reputation")
 local selected = self:GetSettings().currentPreviewExpanded or self:GetSettings().defaultExpansion
 if selected == "auto" or not selected then selected = "mop" end
 local rows = 0
 local function Count(node) rows=rows+1;for _,child in ipairs(node.children or {}) do Count(child) end end
 for _, expansion in ipairs(self:GetTreeNodes(snapshot)) do rows=rows+1;if expansion.key==selected then for _, child in ipairs(expansion.children or {}) do Count(child) end end end
 local rowHeight = rows > 36 and 18 or (rows > 28 and 20 or 24)
 -- Match the actual current-character layout: frame title, mode control,
 -- section heading and precisely the currently visible tree rows.
 local preferred = math.max(132, 131 + rows * rowHeight)
 return {minWidth=400,preferredWidth=480,minHeight=132,preferredHeight=preferred,horizontalOverflow="content",verticalOverflow="none"}
 ]]
end

-- The legacy metrics above describe a whole hover window.  New account pages
-- report their own drawable surface only; AccountView owns every shell edge.
function Addon:GetPreviewSurfaceMetrics(context)
 local rows, characters = 0, (context and context.characters) or {}
 rows = #self:GetSettings().monitoredFactionIDs
 local inset = Theme:GetMatrixInsets(true)
 local cellWidth = #characters > 10 and 56 or 90
 local headerHeight = Theme:GetCharacterHeaderHeight(context)
 return {
  minContentWidth = 150 + cellWidth + inset.left + inset.right,
  naturalContentWidth = 150 + #characters * cellWidth + inset.left + inset.right,
  minContentHeight = inset.top + headerHeight + Theme.Table.previewRowHeight + inset.bottom,
  naturalContentHeight = inset.top + headerHeight + math.max(1, rows) * Theme.Table.previewRowHeight + inset.bottom,
  fixedLeftWidth = 150,
  fixedTopHeight = headerHeight,
 horizontalOverflow = "paginate",
 verticalOverflow = "none",
 }
 --[[ Legacy current-character surface metrics, retained for migration reference.
 local current = Core.Characters:GetCurrent()
 local snapshot = current and Core.DataDomains:Get(current.id, "reputation")
 local selected = self:GetSettings().currentPreviewExpanded or self:GetSettings().defaultExpansion
 if selected == "auto" or not selected then selected = "mop" end
 local function Count(node)
  rows = rows + 1
  for _, child in ipairs(node.children or {}) do Count(child) end
 end
 for _, expansion in ipairs(self:GetTreeNodes(snapshot)) do
  rows = rows + 1
  if expansion.key == selected then for _, child in ipairs(expansion.children or {}) do Count(child) end end
 end
 local rowHeight = rows > 36 and 18 or (rows > 28 and 20 or 24)
 return {
  minContentWidth = 450 + Theme.Space.lg * 2,
  naturalContentWidth = 450 + Theme.Space.lg * 2,
  minContentHeight = Theme.Space.xs + Theme.Size.standard + Theme.Space.xs + Theme.Size.compact + Theme.Space.md,
  naturalContentHeight = Theme.Space.xs + Theme.Size.standard + Theme.Space.xs + Theme.Size.compact + rows * rowHeight + Theme.Space.md,
  fixedLeftWidth = 0,
  fixedTopHeight = Theme.Size.standard + Theme.Size.compact,
 horizontalOverflow = "content",
 verticalOverflow = "content",
 }
 ]]
end
