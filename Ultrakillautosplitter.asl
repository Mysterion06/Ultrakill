//Credits Mysterion_06_
//TheSast, Shoen and YellowSwerve testing

state("ULTRAKILL"){
    string256 level: "tier0_s64.dll", 0x000589D0, 0x18;
    float IGT: "UnityPlayer.dll", 0x017CA358, 0xA0, 0x78, 0x28, 0x130, 0x38, 0xC8;
}

init{
    vars.totalGameTime = 0;
}

startup{
    settings.Add("EAA%", false, "Early Access Any%");
    settings.Add("AR", false, "Act Runs");
    settings.Add("LR", false, "Layer Runs");
}

start{
    if((current.level == "1: INTO THE FIRE" && settings["EAA%"] && (old.level == "play" || old.level == "" || current.IGT == 0f))
    ||
    ((current.level == "1: HEART OF THE SUNRISE" || current.level == "1: INTO THE FIRE" || current.level == "1: BRIDGEBURNER" || current.level == "1: BELLY OF THE BEAST")&& settings["LR"] && (old.level == "play" || old.level == "" || current.IGT == 0f))
    ||
    (current.level == "1: HEART OF THE SUNRISE" && settings["AR"] && (old.level == "play" || old.level == "" || current.IGT == 0f))){
        vars.totalGameTime = 0;
        return true;
    }
}

split{
    if(current.level != old.level && current.level != "1: INTO THE FIRE"){
        return true;
    }
}

reset
{
    if(current.level == "play" && old.level != "2: IN THE FLESH"){
        return true;
    }
}

gameTime{
    if(current.IGT < old.IGT && current.IGT == 0f){
        vars.totalGameTime = vars.totalGameTime + old.IGT;
    }
    return TimeSpan.FromSeconds(vars.totalGameTime + current.IGT);
}