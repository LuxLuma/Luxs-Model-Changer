/*
*	
*	LMC_L4D2_SetTransmit() module "LMCL4D2SetTransmit" required to use native, Library is called "LMCL4D2SetTransmit"
*	
*	https://github.com/LuxLuma/-L4D2-Left-4-Dead-2-Model-Changer/
*/

#if defined _LMCL4D2SetTransmit_included
#endinput
#endif
#define _LMCL4D2SetTransmit_included

#define LMCL4D2SetTransmit_version "1.0"

/**
*	Unhook/hook LMC's SetTransmit in LMCL4D2SetTransmit module
*	
*	@param iClient		Client index owner of the iEntity 
*	@param iEntity		Entity to hook/unhook
*	@param Unhook/hook	True to HookEntity, false to Unhook entity
*	@return 			return true if was hooked/unhooked, false entity has no overlay model
*/
native bool LMC_L4D2_SetTransmit(int iClient, int iEntity, bool HookAction=true);

public SharedPlugin __pl_LMCL4D2SetTransmit = 
{
	name = "LMCL4D2SetTransmit",
	file = "LMCL4D2SetTransmit.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_LMCL4D2SetTransmit_SetNTVOptional()
{
	MarkNativeAsOptional("LMC_L4D2_SetTransmit");
}
#endif