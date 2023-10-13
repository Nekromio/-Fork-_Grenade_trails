#pragma semicolon 1
#pragma newdecls required

#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include <sdktools_stringtables>
#include <sdkhooks>
#include <smartdm>

ConVar
	cvEnable[3],
	cvModels[3],
	cvColors[3];

ArrayList
	hGrenadeArray[3];
	
int
	iOwnerEntity[MAXPLAYERS+1][3];

char
	sModels[3][512];

static const char sListGrenade[][] =
{
	"flashbang_projectile",
	"hegrenade_projectile",
	"smokegrenade_projectile",
	"env_particlesmokegrenade"
};

public Plugin myinfo = 
{
	name = "[Fork] Grenade trails/Хвост Гранат",
	author = "NoTiCE, Nek.'a 2x2",
	description = "Хвост за гранатами",
	version = "1.2.4",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	cvEnable[0] = CreateConVar("sm_fg_enable", "1", "Включить следы от слеповой гранаты?", _, true, 0.0, true, 1.0);
	cvEnable[1] = CreateConVar("sm_hg_enable", "1", "Включить следы от взрывной гранаты?", _, true, 0.0, true, 1.0);
	cvEnable[2] = CreateConVar("sm_sg_enable", "1", "Включить следы от дымовой гранаты?", _, true, 0.0, true, 1.0);
	
	cvModels[0] = CreateConVar("sm_model_fl", "effects/combinemuzzle2.vmt", "Путь к материалу, что будет хвостом флешки");
	cvModels[1] = CreateConVar("sm_model_he", "particle/fire.vmt", "Путь к материалу, что будет хвостом флешки");
	cvModels[2] = CreateConVar("sm_model_smoke", "particle/particle_smokegrenade.vmt", "Путь к материалу, что будет хвостом флешки");
	
	cvColors[0] = CreateConVar("sm_color_fl", "255 255 255", "Цвет хвоста флешки");
	cvColors[1] = CreateConVar("sm_color_he", "255 0 0", "Цвет хвоста  ХЕшки");
	cvColors[2] = CreateConVar("sm_color_smoke", "0 0 0", "Цвет хвоста дыма");
	
	AutoExecConfig(true, "grenade_trails");
	
	HookConVarChange(FindConVar("mp_restartgame"), ClearAdtArray);
	
	for(int i; i < 3; i++) hGrenadeArray[i] = CreateArray();
	
	HookEvent("flashbang_detonate", Event_FlashbangDetonate);
	HookEvent("hegrenade_detonate", Event_HEGrenadeDetonate);
	HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
	char sBuffer[512];
	
	for(int i; i < 3; i++)
	{
		cvModels[i].GetString(sBuffer, sizeof(sBuffer));
		
		if(sBuffer[0])
		{
			sModels[i] = sBuffer;
			PrecacheModel(sBuffer, true);
		}
		
		if(!(StrEqual(sModels[i], "effects/combinemuzzle2.vmt", false) || StrEqual(sModels[i], "particle/fire.vmt", false) || StrEqual(sModels[i], "particle/particle_smokegrenade.vmt", false)))
		{
			Format(sBuffer, sizeof(sBuffer), "materials/%s", sBuffer);
			Downloader_AddFileToDownloadsTable(sBuffer);
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i; i < 3;i++) FullyClearArray(hGrenadeArray[i]);
}

void Event_FlashbangDetonate(Event event, const char[] name, bool dontBroadcast)
{
	if(cvEnable[0].BoolValue)
		DetonateGrenade(0, event);
}

void Event_HEGrenadeDetonate(Event event, const char[] name, bool dontBroadcast)
{
	if(cvEnable[1].BoolValue )
		DetonateGrenade(1, event);
}

void Hook_OnSpawnSmokeParticles(int entity)
{
	if(cvEnable[2].BoolValue)
		DetonateGrenade(2, view_as<Handle>(entity));
}

void DetonateGrenade(int index, Handle event)
{
	float fOrigin[3], fOriginNade[3];
	if(index < 2)
	{
		fOrigin[0] = GetEventFloat(event, "x");
		fOrigin[1] = GetEventFloat(event, "y");
		fOrigin[2] = GetEventFloat(event, "z");
	}
	else
		GetEntPropVector(view_as<int>(event), Prop_Send, "m_vecOrigin", fOrigin);

	int iSize = GetArraySize(hGrenadeArray[index]);
	
	if(iSize < 1)
		return;
	
	Handle hGrenade;
	int iGrenade;
	char classname[64];
	for(int i = 0; i < iSize; i++)
	{
		hGrenade = GetArrayCell(hGrenadeArray[index], i);
		iGrenade = GetArrayCell(hGrenade, 0);
		if(IsValidEdict(iGrenade))
		{
			GetEdictClassname(iGrenade, classname, sizeof(classname));
			
			char sBuffer[256];
			switch(index)
			{
				case 0: sBuffer = "flashbang_projectile";
				case 1: sBuffer = "hegrenade_projectile";
				case 2: sBuffer = "smokegrenade_projectile";
			}
			if(StrEqual(classname, sBuffer, false))
			{
				GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", fOriginNade);
				
				if(fOrigin[0] == fOriginNade[0] && fOrigin[1] == fOriginNade[1] && fOrigin[2] == fOriginNade[2] && (GetArraySize(hGrenade) > 1))
				{
					SDKUnhook(iGrenade, SDKHook_Spawn, Hook_OnSpawnFlashProjectile);
					int particle = GetArrayCell(hGrenade, 1);
					if(IsValidEdict(particle))
					{
						AcceptEntityInput(particle, "TurnOff");
						AcceptEntityInput(particle, "Kill");
					}
					
					CloseHandle(hGrenade);
					RemoveFromArray(hGrenadeArray[index], i);
					break;
				}
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{	
	DataPack hPack = new DataPack();
	hPack.WriteCell(entity);
	hPack.WriteString(classname);
	RequestFrame(EntityCreated, hPack);

	for(int i; i < sizeof(sListGrenade); i++)
	{
		int j;
		if(i != 3) j = i;
		else j = 2;
		if(StrEqual(classname, sListGrenade[i], false) && cvEnable[j].BoolValue)
		{
			switch(i)
			{
				case 0:	SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnFlashProjectile);
				case 1: SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnHEProjectile);
				case 2: SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnSmokeProjectile);
				case 3: SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnSmokeParticles);
			}
			
		}
	}
}

void OwnerEntity(int entity, int index)
{
	if(!IsValidEntity(entity))
		return;

	char sName[23];
	GetEntityClassname(entity, sName, sizeof(entity));

	if(!strcmp(sName, sListGrenade[index]))
		return;
	
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!IsValidClient(client))
		return;
	//PrintCenterTextAll("[%s] [%d]", sListGrenade[index], !strcmp(sName, sListGrenade[index]));
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	iOwnerEntity[client][index] = entity;
}

void EntityCreated(DataPack hPack)
{
	hPack.Reset();
	int entity = hPack.ReadCell();
	char classname[24];
	hPack.ReadString(classname, sizeof(classname));

	for(int i; i < sizeof(sListGrenade); i++)
	{
		if(StrEqual(classname, sListGrenade[i], false) && cvEnable[i].BoolValue)
		{
			OwnerEntity(entity, i);
			break;
		}
	}

	delete hPack;
}

void Hook_OnSpawnFlashProjectile(int entity)
{
	if(!cvEnable[0].BoolValue)
		return;
		
	DataPack hPack = new DataPack();
	hPack.WriteCell(entity);
	hPack.WriteCell(0);
	hPack.WriteString(sModels[0]);

	CreateTimer(0.1, TimerSpawnProj, hPack);
}

void Hook_OnSpawnHEProjectile(int entity)
{
	if(!cvEnable[1].BoolValue)
		return;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(entity);
	hPack.WriteCell(1);
	hPack.WriteString(sModels[1]);

	CreateTimer(0.1, TimerSpawnProj, hPack);
}

void Hook_OnSpawnSmokeProjectile(int entity)
{
	if(!cvEnable[2].BoolValue)
		return;

	DataPack hPack = new DataPack();
	hPack.WriteCell(entity);
	hPack.WriteCell(2);
	hPack.WriteString(sModels[2]);

	CreateTimer(0.1, TimerSpawnProj, hPack);
}

Action TimerSpawnProj(Handle hTimer, Handle hDataPack)
{
	DataPack hPack = view_as<DataPack>(hDataPack);
	hPack.Reset();
	int entity = hPack.ReadCell();
	int index = hPack.ReadCell();
	char sProj[512];
	hPack.ReadString(sProj, sizeof(sProj));
	
	if(IsValidEntity(entity))
		Hook_OnSpawnNadeProjectile(index, entity, sProj);
	
	delete hPack;
	return Plugin_Stop;
}

void Hook_OnSpawnNadeProjectile(int index, int entity, char[] vmt)
{
	int particle = CreateEntityByName("env_smokestack");

	if(!IsValidEdict(particle))
	{
		LogError("Failed to create env_smokestack!");
		return;
	}
	
	if(!IsValidEntity(entity))
		return;
	
	char sBuffer[256];
	cvColors[index].GetString(sBuffer, sizeof(sBuffer));
	
	int client = -1;
	for(int i = 1; i <= MaxClients; i++) if(iOwnerEntity[i][index] == entity)
	{
		client = i;
		break;
	}
	
	if(!IsValidClient(client))
		return;
	
	char Name[32]; float fPos[3];
	Format(Name, sizeof(Name), "SmokeParticle_%i", entity);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fPos);
	DispatchKeyValueVector(particle, "Origin", fPos);
	DispatchKeyValueVector(particle, "Angles", view_as<float>({0.0, 0.0, 0.0}));
	DispatchKeyValueFloat(particle, "BaseSpread", 3.0);
	DispatchKeyValueFloat(particle, "StartSize", 3.5);
	DispatchKeyValueFloat(particle, "EndSize", 4.0);
	DispatchKeyValueFloat(particle, "Twist", 0.0);
	DispatchKeyValue(particle, "Name", Name);
	DispatchKeyValue(particle, "SmokeMaterial", vmt);
	DispatchKeyValue(particle, "RenderColor", sBuffer);
	DispatchKeyValue(particle, "SpreadSpeed", "10");
	DispatchKeyValue(particle, "RenderAmt", "200");
	DispatchKeyValue(particle, "JetLength", "13");
	DispatchKeyValue(particle, "RenderMode", "0");
	DispatchKeyValue(particle, "Initial", "0");
	DispatchKeyValue(particle, "Speed", "10");
	DispatchKeyValue(particle, "Rate", "173");
	if(IsValidEntity(particle) && IsValidClient(client))
	{
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", client);

		DispatchSpawn(particle);
		SetEdictFlags(particle, GetEdictFlags(particle) & ~(FL_EDICT_ALWAYS|FL_EDICT_DONTSEND|FL_EDICT_PVSCHECK));
		SDKHook(particle, SDKHook_SetTransmit, OnTransmit);
		
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", entity, particle, 0);
		AcceptEntityInput(particle, "TurnOn");
	}
	
	Handle hGrenade = CreateArray();
	PushArrayCell(hGrenade, entity);
	PushArrayCell(hGrenade, particle);
	PushArrayCell(hGrenadeArray[index], hGrenade);
}

Action OnTransmit(int iEntity, int client)
{
	if(!IsValidClient(client) || !IsValidClient(GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity")))
		return Plugin_Handled;
		
	SetEdictFlags(iEntity, GetEdictFlags(iEntity) & ~(FL_EDICT_ALWAYS|FL_EDICT_DONTSEND|FL_EDICT_PVSCHECK));
	
	if(GetClientTeam(GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity")) == GetClientTeam(client) || GetClientTeam(client) < 2)
		return Plugin_Continue;
	else
		return Plugin_Handled;
}

void ClearAdtArray(Handle convar, const char[] oldValue, const char[] newValue)
{
	for(int i; i < 3;i++) FullyClearArray(hGrenadeArray[i]);
}

void FullyClearArray(Handle hArray)
{
	if(!GetArraySize(hArray))
		return;
		
	for(int i = 0; i < GetArraySize(hArray); i++)
		CloseHandle(GetArrayCell(hArray, i));
	ClearArray(hArray);
}

bool IsValidClient(int client)
{
	return 0 <client <= MaxClients && IsClientInGame(client);
}