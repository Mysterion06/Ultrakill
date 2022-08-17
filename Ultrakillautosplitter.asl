// Originally created by Mysterion_06_.
// Additional credits: Ero, EvanMad, TheSast, Shoen, YellowSwerve
// Website: https://github.com/Mysterion06/Ultrakill

state("ULTRAKILL") {}

startup
{
	vars.Log = (Action<object>)(output => print("[ULTRAKILL] " + output));

	var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
	var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
	vars.Helper = Activator.CreateInstance(type, timer, this);

	settings.Add("cpSplits", false, "Split whenever hitting a checkpoint");
}

onStart
{
	vars.TotalGameTime = 0d;
}

init
{
	vars.TotalGameTime = 0d;

	vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono =>
	{
		var sm = mono.GetClass("StatsManager", 1);
		vars.Helper["Checkpoint"] = sm.Make<IntPtr>("instance", "currentCheckPoint");
		vars.Helper["Level"] = sm.Make<int>("instance", "levelNumber");
		vars.Helper["Seconds"] = sm.Make<float>("instance", "seconds");
		vars.Helper["TimerEnabled"] = sm.Make<bool>("instance", "timer");
		vars.Helper["StartedLevel"] = sm.Make<bool>("instance", "timerOnOnce");

		return true;
	});

	vars.Helper.Load();
}

update
{
	if (!vars.Helper.Update())
		return false;

	vars.Helper.MapWatchersToCurrent(current);
}

start
{
	return !old.StartedLevel && current.StartedLevel;
}

split
{
	if (!current.StartedLevel) return;

	return old.TimerEnabled && !current.TimerEnabled ||
	       settings["cpSplits"] && old.Checkpoint != current.Checkpoint && current.Checkpoint != IntPtr.Zero;
}

reset
{
	return old.StartedLevel && !current.StartedLevel && timer.CurrentSplitIndex == 0;
}

gameTime
{
	if (old.TimerEnabled && !current.TimerEnabled)
		vars.TotalGameTime += old.Seconds;

	if (current.TimerEnabled)
		return TimeSpan.FromSeconds(vars.TotalGameTime + current.Seconds);
}

isLoading
{
	return true;
}

exit
{
	vars.Helper.Dispose();
}

shutdown
{
	vars.Helper.Dispose();
}
