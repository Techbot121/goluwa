local gui = ... or _G.gui
local META = prototype.CreateTemplate("text_edit")

META:GetSet("CaretColor")
META:GetSet("SelectionColor")
META:GetSet("Editable", true)
META:GetSet("CaretPosition", Vec2(0, 0))
META:GetSet("CaretSubPosition", 0)
META:GetSet("Multiline", true)

META:GetSetDelegate("Text", "", "label")
META:GetSetDelegate("ParseTags", false, "label")
META:GetSetDelegate("Font", nil, "label")
META:GetSetDelegate("TextColor", nil, "label")
META:GetSetDelegate("TextWrap", false, "label")

META:Delegate("label", "CenterText", "Center")
META:Delegate("label", "CenterTextY", "CenterY")
META:Delegate("label", "CenterTextX", "CenterX")
META:Delegate("label", "GetTextSize", "GetSize")

function META:Initialize()
	self:SetStyle("text_edit")
	self:SetFocusOnClick(true)
	self.BaseClass.Initialize(self)

	local label = self:CreatePanel("text", "label")
	label.OnStyleChanged = nil
	label.markup:SetEditable(self.Editable)

	label:SetClipping(true)
	label:SetIgnoreMouse(true)

	self:SetEditable(true)

	label.OnTextChanged = function(_, ...) self:OnTextChanged(...) end
	label.OnEnter = function(_, ...) self:OnEnter(...) if not self.Multiline then return false end end

	self:SetCursor("ibeam")
	self:SizeToText()
end

function META:SetMultiline(b)
	self.Multiline = b
	if b then
		self.label:SetupLayout()
	else
		self.label:SetupLayout("center_y_simple")
	end
end

function META:GetMarkup()
	return self.label.markup
end

function META:OnStyleChanged(skin)
	self:SetCaretColor(skin.text_edit_color:Copy())
	self:SetSelectionColor(skin.text_edit_color:Copy():SetAlpha(0.5))
	self:SetTextColor(skin.text_edit_color:Copy())
	self.label:SetTextColor(skin.text_edit_color:Copy())
	self:SetFont(skin.default_font)

	if self.label and self.label.markup then
		self.label.markup:SetCaretColor(self.CaretColor)
		self.label.markup:SetSelectionColor(self.SelectionColor)
	end
end

function META:SetCaretPosition(pos)
	self.label.markup:SetCaretPosition(pos.x, pos.y)
end

function META:GetCaretPosition()
	return Vec2(self.label.markup:GetCaretPosition())
end

function META:SetCaretSubPosition(pos)
	self.label.markup:SetCaretSubPosition(pos)
end

function META:GetCaretSubPosition()
	return self.label.markup:GetCaretSubPosition()
end

function META:SelectAll()
	self.label.markup:SelectAll()
end

function META:SetEditable(b)
	self.Editable = b
	self.label.markup:SetEditable(b)
end

function META:SizeToText()
	local marg = self:GetMargin()

	self.label:SetPosition(marg:GetPosition())
	self:SetSize(self.label:GetSize() + marg:GetSize() * 2)
end

function META:OnFocus()
	input.DisableFocus = true -- TODO
	if self.Editable then
		self.label.markup:SetEditable(true)
	end
end

function META:OnUnfocus()
	input.DisableFocus = false -- TODO
	self.label.markup:SetEditable(false)
end

function META:OnKeyInput(...)
	return self.label:OnKeyInput(...)
end

function META:OnCharInput(...)
	return self.label:OnCharInput(...)
end

function META:OnMouseInput(button, press, ...)
	self.label:OnMouseInput(button, press, ...)
end

function META:OnMouseMove(...)
	self.label:OnMouseMove(...)
end

function META:OnEnter() end
function META:OnTextChanged() end

gui.RegisterPanel(META)
