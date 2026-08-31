--// Settings //--
print("Loading settings module...")

local SelfDestructGroupBox = _Tabs.Settings:AddLeftGroupbox("Self Destruct")

SelfDestructGroupBox:AddLabel("Self Destruct the UI")
SelfDestructGroupBox:AddButton("Self Destruct", function()
    _linoriaScreenGUI:Destroy()
end)