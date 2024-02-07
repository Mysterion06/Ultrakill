// Originally created by Mysterion_06_.
// Additional credits: 10_days_till_xmas, Ero, EvanMad, TheSast, Shoen, YellowSwerve
// Website: https://github.com/Mysterion06/Ultrakill

state("ULTRAKILL") {}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "ULTRAKILL";

    settings.Add("cpSplits", false, "Split whenever hitting a checkpoint");
    settings.Add("ilMode", false, "IL runs: split on specified amount of kills, reset on level restart");
    settings.SetToolTip(
        "ilMode",
        "Kill splits are defined by the segment name:" + "\n" +
        "  Use [##] anywhere in the segment name to define the kill count." + "\n" +
        "  Example: 'Level Name [10]' will split upon the 10th kill, only when on the split with that name.");

    vars.LevelKills = new Dictionary<int, int>();

    vars.Helper.AlertGameTime();
}

onStart
{
    vars.TotalGameTime = 0d;
    vars.SplitForLevelEnd = false;

    vars.LevelKills.Clear();
    for (int i = 0; i < timer.Run.Count; i++)
    {
        var segment = timer.Run[i];

        int start = segment.Name.IndexOf('[');
        if (start == -1) continue;

        int end = segment.Name.IndexOf(']', start);
        if (end == -1) continue;

        int kills;
        if (int.TryParse(segment.Name.Substring(start + 1, end - start - 1), out kills))
            vars.LevelKills[i] = kills;
    }
}

onSplit
{
    vars.SplitForLevelEnd = false;
}

init
{
    vars.TotalGameTime = 0d;

    vars.SplitForLevelEnd = false;
    vars.WaitForGameTime = false;

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var sm = mono.GetClass("StatsManager", 1);

        vars.Helper["Checkpoint"] = sm.Make<IntPtr>("instance", "currentCheckPoint");
        vars.Helper["Level"] = sm.Make<int>("instance", "levelNumber");
        vars.Helper["Kills"] = sm.Make<int>("instance", "kills");
        vars.Helper["Seconds"] = sm.Make<float>("instance", "seconds");
        vars.Helper["TimerRunning"] = sm.Make<bool>("instance", "timer");
        vars.Helper["LevelInProgress"] = sm.Make<bool>("instance", "timerOnOnce");

        return true;
    });
}

update
{
    if (old.TimerRunning && !current.TimerRunning)
    {
        current.TimerRunning = !vars.WaitForGameTime;
        vars.WaitForGameTime = !vars.WaitForGameTime;
    }
}

start
{
    return !old.LevelInProgress && current.LevelInProgress;
}

split
{
    if (!current.LevelInProgress)
        return;

    if (settings["ilMode"])
    {
        int kills;
        if (vars.LevelKills.TryGetValue(timer.CurrentSplitIndex, out kills)
            && current.Kills >= kills)
        {
            return true;
        }
    }

    return vars.SplitForLevelEnd
        || settings["cpSplits"] && old.Checkpoint != current.Checkpoint && current.Checkpoint != IntPtr.Zero;
}

reset
{
    return old.LevelInProgress && !current.LevelInProgress
        && (settings["ilMode"] || timer.CurrentSplitIndex == 0);
}

gameTime
{
    if (old.TimerRunning && !current.TimerRunning)
    {
        vars.TotalGameTime += current.Seconds;
        vars.SplitForLevelEnd = true;
    }

    if (current.TimerRunning)
        return TimeSpan.FromSeconds(vars.TotalGameTime + current.Seconds);
}

isLoading
{
    return true;
}
