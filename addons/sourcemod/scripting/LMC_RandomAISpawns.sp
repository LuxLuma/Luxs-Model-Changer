#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <L4D2ModelChanger>
#pragma newdecls required

#define PLUGIN_VERSION "cakeChocoA"

#define HUMAN_MODEL_PATH_SIZE 11
#define SPECIAL_MODEL_PATH_SIZE 8
#define UNCOMMON_MODEL_PATH_SIZE 6
#define COMMON_MODEL_PATH_SIZE 34

native int LMC_GetClientOverlayModel(int iClient);
native int LMC_SetClientOverlayModel(int iClient, char sModel[PLATFORM_MAX_PATH]);
native int LMC_GetEntityOverlayModel(int iEntity);
native int LMC_SetEntityOverlayModel(int iEntity, char sModel[PLATFORM_MAX_PATH]);


enum LMCModelSectionType
{
	LMCModelSectionType_Human = 0,
	LMCModelSectionType_Special,
	LMCModelSectionType_UnCommon,
	LMCModelSectionType_Common
};

static const char sHumanPaths[HUMAN_MODEL_PATH_SIZE][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_teenangst_light.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_biker_light.mdl",
	"models/survivors/survivor_manager.mdl",
	"models/npcs/rescue_pilot_01.mdl"
};

enum LMCHumanModelType
{
	LMCHumanModelType_Nick = 0,
	LMCHumanModelType_Rochelle,
	LMCHumanModelType_Coach,
	LMCHumanModelType_Ellis,
	LMCHumanModelType_Bill,
	LMCHumanModelType_Zoey,
	LMCHumanModelType_ZoeyLight,
	LMCHumanModelType_Francis,
	LMCHumanModelType_FrancisLight,
	LMCHumanModelType_Louis,
	LMCHumanModelType_Pilot
};

static char sSpecialPaths[SPECIAL_MODEL_PATH_SIZE][] =
{
	"models/infected/witch.mdl",
	"models/infected/witch_bride.mdl",
	"models/infected/hulk.mdl",
	"models/infected/hulk_dlc3.mdl",
	"models/infected/boomer.mdl",
	"models/infected/boomette.mdl",
	"models/infected/hunter.mdl",
	"models/infected/smoker.mdl"
};

enum LMCSpecialModelType
{
	LMCSpecialModelType_Witch = 0,
	LMCSpecialModelType_WitchBride,
	LMCSpecialModelType_Tank,
	LMCSpecialModelType_TankDLC3,
	LMCSpecialModelType_Boomer,
	LMCSpecialModelType_Boomette,
	LMCSpecialModelType_Hunter,
	LMCSpecialModelType_Smoker
};

static const char sUnCommonPaths[UNCOMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_riot.mdl",
	"models/infected/common_male_mud.mdl",
	"models/infected/common_male_ceda.mdl",
	"models/infected/common_male_clown.mdl",
	"models/infected/common_male_jimmy.mdl",
	"models/infected/common_male_fallen_survivor.mdl"
};

enum LMCUnCommonModelType
{
	LMCUnCommonModelType_RiotCop = 0,
	LMCUnCommonModelType_MudMan,
	LMCUnCommonModelType_Ceda,
	LMCUnCommonModelType_Clown,
	LMCUnCommonModelType_Jimmy,
	LMCUnCommonModelType_Fallen
};

static const char sCommonPaths[COMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_tshirt_cargos.mdl",
	"models/infected/common_male_tankTop_jeans.mdl",
	"models/infected/common_male_dressShirt_jeans.mdl",
	"models/infected/common_female_tankTop_jeans.mdl",
	"models/infected/common_female_tshirt_skirt.mdl",
	"models/infected/common_male_roadcrew.mdl",
	"models/infected/common_male_tankTop_overalls.mdl",
	"models/infected/common_male_tankTop_jeans_rain.mdl",
	"models/infected/common_female_tankTop_jeans_rain.mdl",
	"models/infected/common_male_roadcrew_rain.mdl",
	"models/infected/common_male_tshirt_cargos_swamp.mdl",
	"models/infected/common_male_tankTop_overalls_swamp.mdl",
	"models/infected/common_female_tshirt_skirt_swamp.mdl",
	"models/infected/common_male_formal.mdl",
	"models/infected/common_female_formal.mdl",
	"models/infected/common_military_male01.mdl",
	"models/infected/common_police_male01.mdl",
	"models/infected/common_male_baggagehandler_01.mdl",
	"models/infected/common_tsaagent_male01.mdl",
	"models/infected/common_shadertest.mdl",
	"models/infected/common_female_nurse01.mdl",
	"models/infected/common_surgeon_male01.mdl",
	"models/infected/common_worker_male01.mdl",
	"models/infected/common_morph_test.mdl",
	"models/infected/common_male_biker.mdl",
	"models/infected/common_female01.mdl",
	"models/infected/common_male01.mdl",
	"models/infected/common_male_suit.mdl",
	"models/infected/common_patient_male01_l4d2.mdl",
	"models/infected/common_male_polo_jeans.mdl",
	"models/infected/common_female_rural01.mdl",
	"models/infected/common_male_rural01.mdl",
	"models/infected/common_male_pilot.mdl",
	"models/infected/common_test.mdl"
};


static Handle hCvar_AllowTank = INVALID_HANDLE;
static Handle hCvar_AllowHunter = INVALID_HANDLE;
static Handle hCvar_AllowSmoker = INVALID_HANDLE;
static Handle hCvar_AllowBoomer = INVALID_HANDLE;
static Handle hCvar_AllowSurvivors = INVALID_HANDLE;
static Handle hCvar_AiChanceSurvivor = INVALID_HANDLE;
static Handle hCvar_AiChanceInfected = INVALID_HANDLE;
static Handle hCvar_TankModel = INVALID_HANDLE;

static bool g_bAllowTank = false;
static bool g_bAllowHunter = false;
static bool g_bAllowSmoker = false;
static bool g_bAllowBoomer = false;
static bool g_bAllowSurvivors = false;
static bool g_bTankModel = false;

static int g_iAiChanceSurvivor = 50;
static int g_iAiChanceInfected = 50;

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("L4D2ModelChanger"))
		SetFailState("[LMC]LMC_Core notloaded, load LMC_Core and reload plugin.");
}


public OnPluginStart()
{
	RegConsoleCmd("sm_lmc", ShowMenu, "Brings up a menu to select a client's model");
	
	CreateConVar("l4d2modelchanger_version", PLUGIN_VERSION, "Left 4 Dead Model Changer", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_AdminOnlyModel = CreateConVar("lmc_adminonly", "0", "Allow admins to only change models? (1 = true) NOTE: this will disable announcement to player who join.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AllowTank = CreateConVar("lmc_allowtank", "0", "Allow Tanks to have custom model? (1 = true)",FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AllowHunter = CreateConVar("lmc_allowhunter", "1", "Allow Hunters to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AllowSmoker = CreateConVar("lmc_allowsmoker", "1", "Allow Smoker to have custom model? (1 = true)",FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AllowBoomer = CreateConVar("lmc_allowboomer", "1", "Allow Boomer to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AllowSurvivors = CreateConVar("lmc_allowSurvivors", "1", "Allow Survivors to have custom model? (1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_AnnounceDelay = CreateConVar("lmc_announcedelay", "15.0", "Delay On which a message is displayed for !lmc command", FCVAR_NOTIFY, true, 1.0, true, 360.0);
	hCvar_AnnounceMode = CreateConVar("lmc_announcemode", "1", "Display Mode for !lmc command (0 = off, 1 = Print to chat, 2 = Center text, 3 = Director Hint)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	hCvar_AiChanceSurvivor = CreateConVar("lmc_ai_model_survivor", "10", "(0 = disable custom models)chance on which the AI will get a custom model", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	hCvar_AiChanceInfected = CreateConVar("lmc_ai_model_infected", "15", "(0 = disable custom models)chance on which the AI will get a custom model", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	hCvar_TankModel = CreateConVar("lmc_allow_tank_model_use", "0", "The tank model is big and don't look good on other models so i made it optional(1 = true)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	
	HookConVarChange(hCvar_AllowTank, eConvarChanged);
	HookConVarChange(hCvar_AllowHunter, eConvarChanged);
	HookConVarChange(hCvar_AllowSmoker, eConvarChanged);
	HookConVarChange(hCvar_AllowBoomer, eConvarChanged);
	HookConVarChange(hCvar_AllowSurvivors, eConvarChanged);
	HookConVarChange(hCvar_AiChanceSurvivor, eConvarChanged);
	HookConVarChange(hCvar_AiChanceInfected, eConvarChanged);
	HookConVarChange(hCvar_TankModel, eConvarChanged);
	CvarsChanged();
	
	
	HookEvent("player_spawn", ePlayerSpawn);
	AutoExecConfig(true, "LMC_ModelManager");
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_iHideDeathModel = GetConVarInt(hCvar_HideDeathModel);
}
