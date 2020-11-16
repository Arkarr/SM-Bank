#include <sourcemod>
#include <sdktools>
#include <bank>

//Plugin Info
#define PLUGIN_TAG			"[Bank]"
#define PLUGIN_NAME			"Bank - test plugin"
#define PLUGIN_AUTHOR 		"Arkarr"
#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_DESCRIPTION 	"A simple plugin to test the bank plugin."

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_balance", CMD_ShowBalance, "Display your current ammount of credits in a specific bank");
	
	RegAdminCmd("sm_addcredit", CMD_AddCredits, ADMFLAG_CHEATS, "Add a specific ammount of credits to an accounts");
	RegAdminCmd("sm_subcredit", CMD_SubCredits, ADMFLAG_CHEATS, "Substract a specific ammount of credits to an accounts");
	RegAdminCmd("sm_setcredit", CMD_SetCredits, ADMFLAG_CHEATS, "Set a specific ammount of credits to an accounts");
	RegAdminCmd("sm_createbank", CMD_CreateBank, ADMFLAG_CHEATS, "Create a new bank");
	
	Bank_Create("TestBank");
}

public void OnClientPostAdminCheck(int client)
{
	Bank_EditBalance("TestBank", client, 10);
}

//Command Callback

public Action CMD_CreateBank(int client, int args)
{
	if(args < 1)
	{
		if(client != 0)
			PrintToChat(client, "Usage : sm_balance [BANK NAME]");
		else
			PrintToServer("Usage : sm_balance [BANK NAME]");
		
		return Plugin_Handled;
	}
	
	char bank[40];
	GetCmdArg(1, bank, sizeof(bank));
	
	Bank_Create(bank);
	
	return Plugin_Handled;
}

public Action CMD_ShowBalance(int client, int args)
{
	if(args < 1)
	{
		PrintToChat(client, "Usage : sm_balance [BANK NAME]");
		return Plugin_Handled;
	}
	
	char bank[40];
	GetCmdArg(1, bank, sizeof(bank));
	
	int credits = Bank_GetBalance(bank, client);
	
	if(credits == -1)
		PrintToChat(client, "You are not registred in the bank %s", bank);
	else
		PrintToChat(client, "You have %i credits in bank %s", credits, bank);
	
	return Plugin_Handled;
}

public Action CMD_AddCredits(int client, int args)
{
	if(args < 3)
	{
		if(client != 0)
			PrintToChat(client, "Usage : sm_balance [BANK NAME] [TARGET] [AMMOUNT]");
		else
			PrintToServer("Usage : sm_balance [BANK NAME] [TARGET] [AMMOUNT]");
		return Plugin_Handled;
	}
	
	char bank[40];
	char strTarget[40];
	char strAmmount[40];
	GetCmdArg(1, bank, sizeof(bank));
	GetCmdArg(2, strTarget, sizeof(strTarget));
	GetCmdArg(3, strAmmount, sizeof(strAmmount));
	
	int target = FindTarget(client, strTarget);
	int ammount = StringToInt(strAmmount);
	
	if(ammount < 1)
	{
		if(client != 0)
			PrintToChat(client, "You need to put at least more than 1 unit !");
		else
			PrintToServer("You need to put at least more than 1 unit !");
			
		return Plugin_Handled;	
	}
	
	if(target != -1)
	{
		Bank_EditBalance(bank, target, ammount);
	}
	else
	{
		if(client != 0)
			PrintToChat(client, "Target not found.");
		else
			PrintToServer("Target not found.");
	}	
	

	return Plugin_Handled;
}

public Action CMD_SubCredits(int client, int args)
{
	if(args < 3)
	{
		if(client != 0)
			PrintToChat(client, "Usage : sm_balance [BANK NAME] [TARGET] [AMMOUNT]");
		else
			PrintToServer("Usage : sm_balance [BANK NAME] [TARGET] [AMMOUNT]");
			
		return Plugin_Handled;
	}
	
	char bank[40];
	char strTarget[40];
	char strAmmount[40];
	GetCmdArg(1, bank, sizeof(bank));
	GetCmdArg(2, strTarget, sizeof(strTarget));
	GetCmdArg(3, strAmmount, sizeof(strAmmount));
	
	int target = FindTarget(client, strTarget);
	int ammount = StringToInt(strAmmount);
	
	if(ammount > 0)
	{
		if(client != 0)
			PrintToChat(client, "You need to put at least less than 0 unit !");
		else
			PrintToServer("You need to put at least less than 0 unit !");
			
		return Plugin_Handled;	
	}
	
	if(target != -1)
	{
		Bank_EditBalance(bank, target, ammount);
	}
	else
	{
		if(client != 0)
			PrintToChat(client, "Target not found.");
		else
			PrintToServer("Target not found.");
	}
	
	return Plugin_Handled;
}

public Action CMD_SetCredits(int client, int args)
{
	if(args < 3)
	{
		if(client != 0)
			PrintToChat(client, "Usage : sm_setcredit [BANK NAME] [TARGET] [AMMOUNT]");
		else
			PrintToServer("Usage : sm_setcredit [BANK NAME] [TARGET] [AMMOUNT]");
			
		return Plugin_Handled;
	}
	
	char bank[40];
	char strTarget[40];
	char strAmmount[40];
	GetCmdArg(1, bank, sizeof(bank));
	GetCmdArg(2, strTarget, sizeof(strTarget));
	GetCmdArg(3, strAmmount, sizeof(strAmmount));
	
	int target = FindTarget(client, strTarget);
	int ammount = StringToInt(strAmmount);
	
	
	if(target != -1)
	{
		Bank_SetBalance(bank, target, ammount);
	}
	else
	{
		if(client != 0)
			PrintToChat(client, "Target not found.");
		else
			PrintToServer("Target not found.");
	}
	
	return Plugin_Handled;
}