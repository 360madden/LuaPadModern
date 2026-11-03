function Library.LibSimpleWidgets.SetBorder(frame, width, r, g, b, a)
  width = width or 1 -- default width to 1

  local border

  -- Re-use the existing border or create a new one
  if frame.border then
    border = frame.border
  else
    border = UI.CreateFrame("Frame", frame:GetName().."Border", frame:GetParent())
    frame.border = border

    -- Hook SetVisible so we can do the same on the border
    frame.OldSetVisible = frame.SetVisible
    function frame:SetVisible(visible)
      self.border:SetVisible(visible)
      self:OldSetVisible(visible)
    end
  end

  border:SetBackgroundColor(r or 0, g or 0, b or 0, a or 0) -- default color to transparent
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -width, -width)
  border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", width, -width)
  border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -width, width)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", width, width)
  border:SetLayer(frame:GetLayer()-1)

  -- Make the border match the frames current visibility
  border:SetVisible(frame:GetVisible())
  
  return border
end
