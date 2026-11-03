local function contains(tbl, val)
  for k, v in pairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

function Library.LibSimpleWidgets.Select(name, parent)
  local view = UI.CreateFrame("Frame", name, parent)
  view:SetWidth(150)

  view.current = UI.CreateFrame("Text", view:GetName().."Current", view)
  view.current:SetAllPoints(view)
  view.current:SetBackgroundColor(0, 0, 0, 1)
  view.current:SetText("Select...")
  function view.current.Event:LeftClick()
    view.dropdown:SetVisible(not view.dropdown:GetVisible())
  end

  view:SetHeight(view.current:GetFullHeight())

  -- TODO: Down arrow button

  view.dropdown = UI.CreateFrame("Frame", view:GetName().."Dropdown", view)
  view.dropdown:SetBackgroundColor(0, 0, 0, 1)
  view.dropdown:SetPoint("TOPLEFT", view.current, "BOTTOMLEFT", 0, 5)
  view.dropdown:SetPoint("TOPRIGHT", view.current, "BOTTOMRIGHT", 0, 5)
  view.dropdown:SetVisible(false)

  view.items = {}
  view.itemFrames = {}

  function view:SetBorder(width, r, g, b, a)
    Library.LibSimpleWidgets.SetBorder(view.current, width, r, g, b, a)
    Library.LibSimpleWidgets.SetBorder(view.dropdown, width, r, g, b, a)
  end

  function view:GetItems()
    return self.items
  end

  local function DropdownItemClick(self)
    local item = self:GetText()
    view.current:SetText(item)
    view.dropdown:SetVisible(false)
    if view.ItemSelectedHandler then
      view.ItemSelectedHandler(view, item)
    end
  end

  local function DropdownItemMouseIn(self)
    self:SetBackgroundColor(0.3, 0.3, 0.3, 1)
  end

  local function DropdownItemMouseOut(self)
    self:SetBackgroundColor(0, 0, 0, 0)
  end

  function view:SetItems(items)
    self.items = items

    -- reset the selected item if it doesn't exist in the new items
    if not contains(self.items, self:GetSelectedItem()) then
      self.current:SetText("Select...")
    end

    local dropdownHeight = 0
    for i, v in ipairs(items) do
      local itemFrame
      if not self.itemFrames[i] then
        itemFrame = UI.CreateFrame("Text", self.dropdown:GetName().."Item"..i, self.dropdown)
        itemFrame:SetPoint("TOPLEFT", self.dropdown, "TOPLEFT", 0, dropdownHeight)
        itemFrame:SetPoint("TOPRIGHT", self.dropdown, "TOPRIGHT", 0, dropdownHeight)
        itemFrame.Event.LeftClick = DropdownItemClick
        itemFrame.Event.MouseIn = DropdownItemMouseIn
        itemFrame.Event.MouseOut = DropdownItemMouseOut
        self.itemFrames[i] = itemFrame
      else
        itemFrame = self.itemFrames[i]
      end
      itemFrame:SetText(v)
      itemFrame:SetHeight(itemFrame:GetFullHeight())
      itemFrame:SetVisible(true)
      dropdownHeight = dropdownHeight + itemFrame:GetFullHeight()
    end

    if #items < #self.itemFrames then
      for i = #items+1, #self.itemFrames do
        self.itemFrames[i]:SetVisible(false)
      end
    end

    self.dropdown:SetHeight(dropdownHeight)
  end

  function view:SetSelectedItem(item)
    if not contains(self.items, item) then
      return
    end

    self.current:SetText(item)

    if self.ItemSelectedHandler then
      self.ItemSelectedHandler(self, item)
    end
  end

  function view:GetSelectedItem()
    local item = self.current:GetText()
    if item == "" then item = nil end
    return item
  end

  function view:RegisterItemSelectedHandler(handler)
    self.ItemSelectedHandler = handler
  end

  return view
end
