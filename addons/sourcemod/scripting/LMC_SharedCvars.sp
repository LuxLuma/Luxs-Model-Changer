#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

#define PLUGIN_VERSION "cakeBigA"

public Plugin myinfo =
{
	name = "LMC_SharedCvars",
	author = "Lux",
	description = "Modules that sharecvars are put in here",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};

public void OnPluginStart()
{
	CreateConVar("lmc_sharedcvars_version", PLUGIN_VERSION, "LMC_SharedCvars_Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	CreateConVar("lmc_adminonly", "0", "Allow admins to only change models? (1 = true) NOTE: this will disable announcement to player who join.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_allowtank", "0", "Allow Tanks to have custom model? (1 = true)",FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_allowhunter", "1", "Allow Hunters to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_allowsmoker", "1", "Allow Smoker to have custom model? (1 = true)",FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_allowboomer", "1", "Allow Boomer to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_allowSurvivors", "1", "Allow Survivors to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("lmc_announcedelay", "15.0", "Delay On which a message is displayed for !lmc command", FCVAR_NOTIFY, true, 1.0, true, 360.0);
	CreateConVar("lmc_announcemode", "1", "Display Mode for !lmc command (0 = off, 1 = Print to chat, 2 = Center text, 3 = Director Hint)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	CreateConVar("lmc_ai_model_survivor", "10", "(0 = disable custom models)chance on which the AI will get a custom model", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	CreateConVar("lmc_ai_model_infected", "15", "(0 = disable custom models)chance on which the AI will get a custom model", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	CreateConVar("lmc_allow_tank_model_use", "0", "The tank model is big and don't look good on other models so i made it optional(1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "LMC_SharedCvars");
}