// Originally created by Mysterion_06_.
// Additional credits: Ero, EvanMad, TheSast, Shoen, YellowSwerve
// Website: https://github.com/Mysterion06/Ultrakill

state("ULTRAKILL") {}

startup
{
	vars.Dbg = (Action<dynamic>) ((output) => print("[ULTRAKILL ASL] " + output));

	settings.Add("cpSplits", false, "Split whenever hitting a checkpoint");

	vars.TimerStart = (EventHandler) ((s, e) => vars.TotalGameTime = 0);
	timer.OnStart += vars.TimerStart;
}

init
{
	string[] CLASSES = { "StatsManager" };

	vars.CancelSource = new CancellationTokenSource();
	vars.MonoThread = new Thread(() =>
	{
		vars.Dbg("Starting mono thread.");

		IntPtr class_cache = IntPtr.Zero;
		int class_count = 0;

		var token = vars.CancelSource.Token;

		// Check if mono-2.0-bdwgc.dll is initialized. If not, wait 2.0 seconds and retry.
		while (!token.IsCancellationRequested)
		{
			if (game.ModulesWow64Safe().FirstOrDefault(m => m.ModuleName == "mono-2.0-bdwgc.dll") != null)
				break;

			vars.Dbg("Mono module not initialized yet.");
			Thread.Sleep(2000);
		}

		// Find Assembly-CSharp in get_loaded_images_by_name_hash. If unsuccessful, wait 2.0 seconds and retry.
		while (!token.IsCancellationRequested)
		{
			var size = new DeepPointer("mono-2.0-bdwgc.dll", 0x4990C8, 0x18).Deref<int>(game);
			var bucket = new DeepPointer("mono-2.0-bdwgc.dll", 0x4990C8, 0x10, 0x8 * (int)(0xFA381AED % size)).Deref<IntPtr>(game);

			for (; bucket != IntPtr.Zero; bucket = game.ReadPointer(bucket + 0x10))
			{
				if (new DeepPointer(bucket, 0x0).DerefString(game, 32) != "Assembly-CSharp")
					continue;

				class_count = new DeepPointer(bucket + 0x8, 0x4D8).Deref<int>(game);
				class_cache = new DeepPointer(bucket + 0x8, 0x4E0).Deref<IntPtr>(game);
				break;
			}

			if (class_cache != IntPtr.Zero)
				break;

			vars.Dbg("Could not find Assembly-CSharp image.");
			Thread.Sleep(2000);
		}

		var mono = new Dictionary<string, IntPtr>();

		// Iterate over classes in class_cache to find matches in CLASSES array.
		// Get class' parent and its static `instance` field. If any found class is null, wait 5.0 seconds and retry.
		while (!token.IsCancellationRequested)
		{
			bool allFound = false;

			for (int i = 0; i < class_count; ++i)
			{
				var klass = game.ReadPointer(class_cache + 0x8 * i);

				for (; klass != IntPtr.Zero; klass = game.ReadPointer(klass + 0x108))
				{
					string class_name = new DeepPointer(klass + 0x48, 0x0).DerefString(game, 64);
					if (!CLASSES.Contains(class_name))
						continue;

					var instance = new DeepPointer(klass + 0x30, 0xD0, 0x8, 0x68).Deref<IntPtr>(game);
					mono[class_name] = instance;

					if (allFound = mono.Count == CLASSES.Length && mono.Values.All(ptr => ptr != IntPtr.Zero))
						break;
				}

				if (allFound)
					break;
			}

			if (allFound)
			{
				vars.Mono = mono;

				vars.Dbg("Found all variables.");
				break;
			}

			vars.Dbg("Not all pointers found.");
			Thread.Sleep(5000);
		}

		vars.Dbg("Exiting mono thread.");
	});

	vars.MonoThread.Start();

	vars.TotalGameTime = 0d;
}

update
{
	if (vars.MonoThread.IsAlive) return false;

	IntPtr sman = game.ReadPointer((IntPtr)(vars.Mono["StatsManager"]));

	current.Checkpoint = game.ReadPointer(sman + 0x30);
	current.Level = game.ReadValue<int>(sman + 0xBC);
	current.Seconds = game.ReadValue<float>(sman + 0xD0);
	current.TimerEnabled = game.ReadValue<bool>(sman + 0xD4);
	current.StartedLevel = game.ReadValue<bool>(sman + 0xD5);
}

start
{
	return !old.StartedLevel && current.StartedLevel;
}

split
{
	if (!current.StartedLevel) return;

	return old.TimerEnabled && !current.TimerEnabled ||
	       old.Checkpoint != current.Checkpoint && current.Checkpoint != IntPtr.Zero && settings["cpSplits"];
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
	vars.CancelSource.Cancel();
}

shutdown
{
	timer.OnStart -= vars.TimerStart;
	vars.CancelSource.Cancel();
}
