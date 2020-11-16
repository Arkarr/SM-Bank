#include <sourcemod>
#include <sdktools>
#include <bank>

#pragma newdecls required

//Plugin Info
#define PLUGIN_TAG			"[Bank]"
#define PLUGIN_NAME			"[ANY] Bank"
#define PLUGIN_AUTHOR 		"Arkarr"
#define PLUGIN_VERSION 		"4.0"
#define PLUGIN_DESCRIPTION 	"A simple bank system where you can store money."
//Database
#define QUERY_INIT_DB_TCLIENTS		"CREATE TABLE IF NOT EXISTS `clients` (`clientID` int NOT NULL AUTO_INCREMENT, `steamid` varchar(45) NOT NULL, `credits` int NOT NULL, `bankID` int NOT NULL, PRIMARY KEY (`clientID`))"
#define QUERY_INIT_DB_TBANKS		"CREATE TABLE IF NOT EXISTS `banks` (`bankID` int NOT NULL AUTO_INCREMENT,  `name` varchar(50) NOT NULL, PRIMARY KEY (`bankID`))"
#define QUERY_CREATE_BANK			"INSERT INTO `banks` (name) VALUES ('%s')"
#define QUERY_SELECT_BANKS			"SELECT * FROM `banks`"
#define QUERY_SELECT_CLIENT_BANK	"SELECT * FROM `clients` WHERE steamid='%s' AND bankID=%i"
#define QUERY_ADD_CLIENT_TO_BANK	"INSERT INTO `clients` (steamid, credits, bankID) VALUES ('%s', '0', %i)"
#define QUERY_UPDATE_CLIENT_CREDITS	"UPDATE `clients` SET credits='%i' WHERE steamid='%s' AND bankID=%i"
//Trie
#define STEAMID "steamid"
#define CREDITS	"credits"
#define BANKID	"bankID"
//optype
#define EDIT	1
#define SET		2

bool connected;

Handle DATABASE_Banks;
Handle FORWARD_DatabaseReady;
Handle FORWARD_BankCreated
Handle DATABASE_IDS;
Handle TRIE_Banks_ClientsInfo;

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
	connected = false;
	DATABASE_IDS = CreateTrie();
	TRIE_Banks_ClientsInfo = CreateTrie();
	
	FORWARD_DatabaseReady = CreateGlobalForward("Bank_DatabaseReady", ET_Event)
	FORWARD_BankCreated = CreateGlobalForward("Bank_Created", ET_Event, Param_String)
}

public void OnConfigsExecuted()
{
	SQL_TConnect(DBConResult, "Bank");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{   
   	CreateNative("Bank_Create", Native_BankCreate);
	CreateNative("Bank_GetBalance", Native_BankGetBalance);
	CreateNative("Bank_SetBalance", Native_BankSetBalance);
	CreateNative("Bank_EditBalance", Native_BankEditBalance);
	
	RegPluginLibrary("Bank");
   
	return APLRes_Success;
}

//Database init
public void DBConResult(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	else
	{
		DATABASE_Banks = hndl;
		
		char buffer[300];
		if (!SQL_FastQuery(DATABASE_Banks, QUERY_INIT_DB_TCLIENTS) || !SQL_FastQuery(DATABASE_Banks, QUERY_INIT_DB_TBANKS))
		{
			SQL_GetError(DATABASE_Banks, buffer, sizeof(buffer));
			SetFailState(buffer);
		}
		else
		{
			connected = true;
			
			LoadBanksID();
			
			Call_StartForward(FORWARD_DatabaseReady);
			Call_Finish();
	  	}
	}
}

public void CheckConnection()
{
	if(connected)
		return;
		
	SetFailState("Tried to work with banks but database is not connected yet ! Wait for 'Bank_DatabaseReady' to fire !");
}

//Natives
public int Native_BankCreate(Handle plugin, int numParams)
{
	CheckConnection();
	
	char buffer[300];
	char strBankName[128];
	
	GetNativeString(1, strBankName, sizeof(strBankName));
		
	if(BankExist(strBankName))
	{
		Format(buffer, sizeof(buffer), "Bank %s already exist !", strBankName);
		PrintWarningMessage(buffer);
		
		return false;
	}
	
	Format(buffer, sizeof(buffer), QUERY_CREATE_BANK, strBankName);

	Handle TRIE_SqlInfo = CreateTrie();
	SetTrieString(TRIE_SqlInfo, "bankname", strBankName);
	SQL_TQuery(DATABASE_Banks, TQuery_CreateBank, buffer, TRIE_SqlInfo);
	
	return true;
}

public int Native_BankEditBalance(Handle plugin, int numParams)
{
	CheckConnection();
	
	char strBankName[128];
	
	GetNativeString(1, strBankName, sizeof(strBankName));
	int client = GetNativeCell(2);
	int amount = GetNativeCell(3);
	
	ManageClientBalance(client, strBankName, EDIT, amount)
}

public int Native_BankSetBalance(Handle plugin, int numParams)
{
	CheckConnection();
	
	char strBankName[128];
	
	GetNativeString(1, strBankName, sizeof(strBankName));
	int client = GetNativeCell(2);
	int amount = GetNativeCell(3);
	
	ManageClientBalance(client, strBankName, SET, amount)
}

public void ManageClientBalance(int client, const char[] strBankName, int mode, int amount)
{	
	char steamID[50];
	char buffer[200];
	
	int bankID = GetBankID(strBankName);
	if(bankID == -1)
	{
		Format(buffer, sizeof(buffer), "Bank %s doesn't exist !", strBankName);
		PrintErrorMessage(buffer);
		
		return;
	}
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	bool clientFound = ProcessClientBalance(client, strBankName, bankID, mode, amount);
	
	if(!clientFound)
	{
		char dbquery[200];
		Format(dbquery, sizeof(dbquery), QUERY_SELECT_CLIENT_BANK, steamID, bankID);
		
		Handle sqlDataTrie = CreateTrie();
		SetTrieValue(sqlDataTrie, "optype", EDIT);
		SetTrieString(sqlDataTrie, "steamid", steamID);
		SetTrieValue(sqlDataTrie, "bankid", bankID);
		SetTrieValue(sqlDataTrie, "amount", amount);
		SetTrieString(sqlDataTrie, "bankname", strBankName);
		
		SQL_TQuery(DATABASE_Banks, TQuery_InsertAndReadUser, dbquery, sqlDataTrie);
	}
}

public int Native_BankGetBalance(Handle plugin, int numParams)
{
	CheckConnection();
	
	char steamID[50];
	char bankName[128];
	
	GetNativeString(1, bankName, sizeof(bankName));
	int client = GetNativeCell(2);
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Handle TRIE_Clients = CreateTrie();
	Handle TRIE_ClientInfo = CreateTrie();

	if(!GetTrieValue(TRIE_Banks_ClientsInfo, bankName, TRIE_Clients))
		return -1;
	
	int credits = 0;
	if(!GetTrieValue(TRIE_Clients, steamID, TRIE_ClientInfo))
	{
		char dbquery[200];
		int bankID = GetBankID(bankName);
		Format(dbquery, sizeof(dbquery), QUERY_SELECT_CLIENT_BANK, steamID, bankID);
		
		Handle query = SQL_Query(DATABASE_Banks, dbquery);
		if (query == null)
		{
			char error[255];
			SQL_GetError(DATABASE_Banks, error, sizeof(error));
			SetFailState(error);
			
			return -1;
		} 
		else 
		{
			Handle TRIE_Client = CreateTrie();
			while (SQL_FetchRow(query))
			{
				SetTrieString(TRIE_Client, "steamid", steamID);
				SetTrieValue(TRIE_Client, "credits", SQL_FetchInt(query, 2), true);
				SetTrieValue(TRIE_Client, "bankID", SQL_FetchInt(query, 3));
			
				SetTrieValue(TRIE_Clients, steamID, TRIE_Client);
				
				return SQL_FetchInt(query, 2);
			}
			
			delete query;
		}
	
		return 0;
	}
	else
	{
		GetTrieValue(TRIE_ClientInfo, CREDITS, credits);	
		return credits;
	}
}

//Helper function
stock bool ProcessClientBalance(int client, const char[] bankName, int bankID, int operationType, int amount)
{
	char steamID[50];
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Handle TRIE_Clients = CreateTrie();	
	Handle TRIE_ClientInfo = CreateTrie();
	
	if(!GetTrieValue(TRIE_Banks_ClientsInfo, bankName, TRIE_Clients))
	{
		PrintToServer("Clients info for bank %s not found, cretting array...", bankName);		
		return false;
	}
	
	if(GetTrieValue(TRIE_Clients, steamID, TRIE_ClientInfo))
	{
		int credits;
		GetTrieValue(TRIE_ClientInfo, CREDITS, credits);
		
		if(operationType == SET)
			credits = amount;
		else
			credits += amount;
		
		char buffer[200];
		Format(buffer, sizeof(buffer), QUERY_UPDATE_CLIENT_CREDITS, credits, steamID, bankID);
		if (!SQL_FastQuery(DATABASE_Banks, buffer))
		{
			SQL_GetError(DATABASE_Banks, buffer, sizeof(buffer));
			PrintErrorMessage(buffer);
		}
		SetTrieValue(TRIE_ClientInfo, CREDITS, credits);
	
		return true;
	}
	
	return false;
}

stock void LoadBanksID()
{
	SQL_TQuery(DATABASE_Banks, TQuery_GetAllBanks, QUERY_SELECT_BANKS);
}

stock int GetBankID(const char[] strBankName)
{
	int bankID = -1;
	
	if(!GetTrieValue(DATABASE_IDS, strBankName, bankID))
	{
		char msg[50];
		Format(msg, sizeof(msg), "Bank with name '%s' not found !", strBankName);
		PrintErrorMessage(msg)
	}
	
	return bankID;
}

public void TQuery_CreateBank(Handle owner, Handle db, const char[] error, any sqlInfo)
{
	if (db == INVALID_HANDLE)
	{
		char msg[50];
		char bankname[50];
		GetTrieString(sqlInfo, "bankname", bankname, sizeof(bankname))
		Format(msg, sizeof(msg), "Error while creating new bank '%s' !", bankname);
		PrintErrorMessage(msg);
		
		char err[255];
		SQL_GetError(DATABASE_Banks, err, sizeof(err));
		SetFailState(err);
		
		return;
	}
	
	LoadBanksID();
	
	Call_StartForward(FORWARD_BankCreated);
	Call_Finish();
}

public void TQuery_InsertAndReadUser(Handle owner, Handle db, const char[] error, any sqlInfo)
{
	if (db == INVALID_HANDLE)
	{
		PrintErrorMessage("Error while fetching/saving for user data !");
		
		char err[255];
		SQL_GetError(DATABASE_Banks, err, sizeof(err));
		SetFailState(err);
		
		return;
	}
	
	int opType = -1;
	int bankID = -1;
	int amount = -1;
	char steamID[50];
	char buffer[200];
	char strBankName[128];
	
	GetTrieValue(sqlInfo, "optype", opType);
	GetTrieValue(sqlInfo, "bankid", bankID);
	GetTrieValue(sqlInfo, "amount", amount);
	GetTrieString(sqlInfo, "steamid", steamID, sizeof(steamID));
	GetTrieString(sqlInfo, "bankname", strBankName, sizeof(strBankName));
	
	Handle TRIE_Client = CreateTrie();
		
	bool clientFound = SQL_GetRowCount(db) > 0;
	
	while (clientFound && SQL_FetchRow(db))
	{
		clientFound = true;
		SetTrieString(TRIE_Client, STEAMID, steamID);
		SetTrieValue(TRIE_Client, CREDITS, SQL_FetchInt(db, 2), true);
		SetTrieValue(TRIE_Client, BANKID, SQL_FetchInt(db, 3));
	}
	
	if(!clientFound)
	{
		SetTrieString(TRIE_Client, STEAMID, steamID);
		SetTrieValue(TRIE_Client, CREDITS, 0, true);
		SetTrieValue(TRIE_Client, BANKID, bankID);
	
		Format(buffer, sizeof(buffer), QUERY_ADD_CLIENT_TO_BANK, steamID, bankID);
		if (!SQL_FastQuery(DATABASE_Banks, buffer))
		{
			SQL_GetError(DATABASE_Banks, buffer, sizeof(buffer));
			PrintErrorMessage(buffer);
		}
	}
	
	
	int credits;
	if(opType == EDIT)
	{
		GetTrieValue(TRIE_Client, CREDITS, credits);
		SetTrieValue(TRIE_Client, CREDITS, credits+amount);
		credits += amount;
	}
	else
	{
		SetTrieValue(TRIE_Client, CREDITS, amount);
		credits = amount;
	}
	
	Format(buffer, sizeof(buffer), QUERY_UPDATE_CLIENT_CREDITS, credits, steamID, bankID);
	SQL_TQuery(DATABASE_Banks, TQuery_SaveCredits, buffer);
	
	Handle TRIE_ClientsInfo = CreateTrie();
	SetTrieValue(TRIE_Banks_ClientsInfo, strBankName, TRIE_ClientsInfo);
	SetTrieValue(TRIE_ClientsInfo, steamID, TRIE_Client);
}

public void TQuery_SaveCredits(Handle owner, Handle db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		PrintErrorMessage("Error while saving credits in database !");
		
		char err[255];
		SQL_GetError(DATABASE_Banks, err, sizeof(err));
		SetFailState(err);
		
		return;
	}
}
	
public void TQuery_GetAllBanks(Handle owner, Handle db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		PrintErrorMessage("Error while fetching database for bank IDs !");
		
		char err[255];
		SQL_GetError(DATABASE_Banks, err, sizeof(err));
		SetFailState(err);
		
		return;
	}
	
	char bankName[45];
	while (SQL_FetchRow(db))
	{
		SQL_FetchString(db, 1, bankName, sizeof(bankName));
		SetTrieValue(DATABASE_IDS, bankName, SQL_FetchInt(db, 0), false);
		SetTrieValue(TRIE_Banks_ClientsInfo, bankName, CreateTrie());
	}
}

stock bool BankExist(const char[] strBankName)
{
	return GetBankID(strBankName) > 0 ? true : false;
}

stock void PrintWarningMessage(const char[] msg)
{
	PrintToServer("%s - WARNING - %s", PLUGIN_TAG, msg);
}

stock void PrintErrorMessage(const char[] msg)
{
	PrintToServer("%s - ***ERROR*** - %s", PLUGIN_TAG, msg);
}