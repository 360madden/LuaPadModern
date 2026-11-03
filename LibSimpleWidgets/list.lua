function Library.LibSimpleWidgets.List(name, parent)
  local view = UI.CreateFrame("Frame", name, parent)
  view:SetBackgroundColor(0, 0, 0, 1)

  view.items = {}
  view.itemFrames = {}

  function view:SetBorder(width, r, g, b, a)
    Library.LibSimpleWidgets.SetBorder(view, width, r, g, b, a)
  end

  function view:GetItems()
    return self.items
  end

  local function ItemClick(self)
    local item = self:GetText()
    view:SetSelectedItem(item)
    if view.ItemSelectedHandler then
      view.ItemSelectedHandler(view, item)
    end
  end

  local function ItemMouseIn(self)
    if not self.selected then
      self:SetBackgroundColor(0.3, 0.3, 0.3, 1)
    end
  end

  local function ItemMouseOut(self)
    if not self.selected then
      self:SetBackgroundColor(0, 0, 0, 0)
    end
  end

  function view:SetItems(items)
    self.items = items

    -- reset the selected item if it doesn't exist in the new items
    local oldSelectedItem = self:GetSelectedItem()
    self:SetSelectedItem(nil)

    local height = 0
    for i, v in ipairs(items) do
      local itemFrame
      if not self.itemFrames[i] then
        itemFrame = UI.CreateFrame("Text", self:GetName().."Item"..i, self)
        itemFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, height)
        itemFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, height)
        itemFrame.Event.LeftClick = ItemClick
        itemFrame.Event.MouseIn = ItemMouseIn
        itemFrame.Event.MouseOut = ItemMouseOut
        itemFrame.selected = false
        self.itemFrames[i] = itemFrame
      else
        itemFrame = self.itemFrames[i]
      end
      itemFrame:SetText(v)
      itemFrame:SetHeight(itemFrame:GetFullHeight())
      itemFrame:SetVisible(true)
      height = height + itemFrame:GetHeight()
    end

    if #items < #self.itemFrames then
      for i = #items+1, #self.itemFrames do
        self.itemFrames[i]:SetVisible(false)
      end
    end

    self:SetHeight(height)

    self:SetSelectedItem(oldSelectedItem)
  end

  function view:SetSelectedItem(item)
    for i, itemFrame in ipairs(self.itemFrames) do
      if itemFrame:GetText() == item then
        itemFrame.selected = true
        itemFrame:SetBackgroundColor(0, 0, 0.5, 1)
      else
        itemFrame.selected = false
        itemFrame:SetBackgroundColor(0, 0, 0, 0)
      end
    end

    if item and self.ItemSelectedHandler then
      self.ItemSelectedHandler(self, item)
    end
  end

  function view:GetSelectedItem()
    for i, itemFrame in ipairs(self.itemFrames) do
      if itemFrame.selected then
        return itemFrame:GetText()
      end
    end

    return nil
  end

  function view:RegisterItemSelectedHandler(handler)
    self.ItemSelectedHandler = handler
  end

  return view
end
