state("Deathloop", "2021-09-12")
{
    float xVel : 0x02D5F688, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB0;
    float yVel : 0x02D5F688, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB4;
    string255 map : 0x30D0A88;
    byte someLoadFlag : 0x30D0960;
    long someOtherLoadFlag : 0x2D60E00;
    byte menuConnected : 0x3A36344;
}

state("Deathloop", "2021-09-16")
{
    float xVel : 0x02D5F688, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB0;
    float yVel : 0x02D5F688, 0x8, 0x8, 0x98, 0xA0, 0x1F0, 0xB4;
    string255 map : 0x30D0B08;
    byte someLoadFlag : 0x30D09E0;
    long someOtherLoadFlag : 0x2D60E00;
    byte menuConnected : 0x3A363C4;
}

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

    vars.setGameTime = false;
    vars.timeToRemove = 0.0f;
    vars.menuPause = false;
    vars.splitOnLoad = false;
    vars.loopZeroDone = false;
}

init
{
    current.level = "";
    current.loading = false;
    int moduleSize = modules.First().ModuleMemorySize;
	print("Main Module Size: "+moduleSize.ToString());
    switch(moduleSize)
    {
        case 601436160:
            version = "2021-09-12";
            break;
        case 583708672:
            version = "2021-09-16";
            break;
    }
}

update
{
	if(settings["speedometer"]) vars.UpdateSpeedometer(current.xVel, current.yVel, false);

    if(!String.IsNullOrEmpty(current.map) && current.map.Contains("campaign"))
    {
        current.level = current.map.Substring(current.map.LastIndexOf("/")+1).Replace(".map","");
    }

    current.loading = current.someLoadFlag != 0x6 || current.someOtherLoadFlag != 0x0 || (current.level == "menu" && current.menuConnected != 0x1);
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

    if(vars.splitOnLoad && current.loading)
    {
        vars.splitOnLoad = false;
        return true;
    }
}

start
{
    vars.loopZeroDone = false;

    if(current.level == "tutorial_01_p" && !current.loading && old.loading)
    {
        vars.setGameTime = true;
        vars.timeToRemove = 51.5f;
        return true;
    }
}

gameTime
{
	if(vars.setGameTime)
	{
		vars.setGameTime = false;
		return TimeSpan.FromSeconds(-vars.timeToRemove);
	}
}
