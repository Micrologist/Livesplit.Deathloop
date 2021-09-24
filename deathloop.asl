state("Deathloop") {}

startup
{
    settings.Add("speedometer", false, "Show Speedometer");
    
    vars.SetTextComponent = (Action<string, string>)((id, text) =>
	{
        var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
        var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
        if (textSetting == null)
        {
            var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
            var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
            textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
            textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
        }
        if (textSetting != null)
            textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
	});

    vars.UpdateSpeedometer = (Action<float, float, bool>)((x, y, round) =>
    {
        double hvel = (Math.Sqrt(x*x + y*y));
        if(round)
            vars.SetTextComponent("Speed", Math.Floor(hvel).ToString("") + " m/s");
        else
            vars.SetTextComponent("Speed", (hvel).ToString("0.00") + " m/s"); 
    });

    if (timer.CurrentTimingMethod == TimingMethod.RealTime)
    {
        var timingMessage = MessageBox.Show(
            "This game uses RTA w/o Loads as the main timing method.\n"
            + "LiveSplit is currently set to show Real Time (RTA).\n"
            + "Would you like to set the timing method to RTA w/o Loads?",
            "Deathloop | LiveSplit",
            MessageBoxButtons.YesNo, MessageBoxIcon.Question
        );
        if (timingMessage == DialogResult.Yes)
        {
            timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
    }

    vars.splitOnLoad = false;
    vars.loopZeroDone = false;
}

init
{
    vars.watchers = new MemoryWatcherList();
    var scanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);
    IntPtr ptr = IntPtr.Zero;

    // someLoadFlag - map
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 0D ????????", // mov rcx,[Deathloop.exe+30CCD00]  <----
        "4C 89 74 24 48"));  // mov [rsp+48],r14
    if (ptr == IntPtr.Zero) throw new Exception("Could not find address - load flags!");
    vars.watchers.Add(new MemoryWatcher<byte>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) + 0x3CE0)) { Name = "someLoadFlag" });
    vars.watchers.Add(new StringWatcher(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) + 0x3E08), 255) { Name = "map" });
    vars.watchers.Add(new MemoryWatcher<byte>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) + 0x9696C4)) { Name = "menuConnected" });
 
    // someOtherLoadFlag
    ptr = scanner.Scan(new SigScanTarget(3,
        "48 8B 1D ????????", // mov rbx,[Deathloop.exe+2D60E00]   <----
        "48 8B F9",          // mov rdi,rcx
        "48 85 DB",          // test rbx,rbx
        "74 41"));           // je Deathloop.exe+B9E13A
    if (ptr == IntPtr.Zero) throw new Exception("Could not find address - someOtherLoadFlag");
    vars.watchers.Add(new MemoryWatcher<long>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr))) { Name = "someOtherLoadFlag" });

    vars.watchers.Add(new MemoryWatcher<float>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) - 0x1778, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB0)) { Name = "xVel" });
    vars.watchers.Add(new MemoryWatcher<float>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) - 0x1778, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB4)) { Name = "yVel" });
    // vars.watchers.Add(new MemoryWatcher<float>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) - 0x1778, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0x80)) { Name = "xPos" }); // commented out because it's never used in the script
    vars.watchers.Add(new MemoryWatcher<float>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) - 0x1778, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0x84)) { Name = "yPos" });
    vars.watchers.Add(new MemoryWatcher<float>(new DeepPointer(ptr + 4 + memory.ReadValue<int>(ptr) - 0x1778, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0x88)) { Name = "zPos" });

    current.level = "";
    current.loading = false;
	timer.Run.Offset = TimeSpan.FromSeconds(-51.5d);
}

update
{
	vars.watchers.UpdateAll(game);
	
	if(settings["speedometer"]) vars.UpdateSpeedometer(vars.watchers["xVel"].Current, vars.watchers["yVel"].Current, false);

    if(!String.IsNullOrEmpty(vars.watchers["map"].Current) && vars.watchers["map"].Current.Contains("campaign"))
    {
        current.level = vars.watchers["map"].Current.Substring(vars.watchers["map"].Current.LastIndexOf("/")+1).Replace(".map","");
    }

    current.loading = vars.watchers["someLoadFlag"].Current != 0x6 || vars.watchers["someOtherLoadFlag"].Current != 0x0 || (current.level == "menu" && vars.watchers["menuConnected"].Current != 0x1);
}

isLoading
{
    return current.loading;
}

split
{
    if(current.level != old.level && old.level != "menu" && current.level != "tutorial_01_p" && old.level != "tutorial_01_p" && old.level != "")
    {
        vars.splitOnLoad = true;
    }

    if(!vars.loopZeroDone && current.level == "menu" && old.level == "tutorial_01_p")
    {
        vars.loopZeroDone = true;
        vars.splitOnLoad = true;
    }

    if(!current.loading && current.level == "upper_antenna_p" && vars.watchers["yPos"].Current > -66.0f && vars.watchers["zPos"].Current <= 185.7f && vars.watchers["zPos"].Old > 185.7f)
        return true;

    if(vars.splitOnLoad && current.loading)
    {
        vars.splitOnLoad = false;
        return true;
    }
}

start
{
    vars.loopZeroDone = false;
    return current.level == "tutorial_01_p" && !current.loading && old.loading;
}
