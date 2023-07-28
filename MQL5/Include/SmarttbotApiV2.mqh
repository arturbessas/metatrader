//+------------------------------------------------------------------+
//|                                               SmarttbotApiV2.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

void set_new_stock_code(string stock_code)
{
	int result_code = 0;
	
	while(result_code != 200)
	{
		string authKey = get_auth_key();
		string baseUrl = StringFormat("https://app.smarttbot.com/api/v2/strategies/instances/%s/", robot_id);
		string headers = StringFormat("auth-key:%s\r\nContent-Type:application/json; charset=utf-8", authKey);
		string params = StringFormat("{\"params\":{\"marketName\":\"%s\",\"stockCode\":\"%s\"}}", getMarketName(stock_code), stock_code);
		char json[], result[];
		string result_headers;	
	
		StringToCharArray(params,json,0,StringLen(params), CP_UTF8);		
	
		result_code = WebRequest("PUT", baseUrl, headers, 100, json, result, result_headers);	
		if(result_code != 200)
			MessageBox(StringFormat("Erro ao alterar stock code. Atualize sua auth key imediatamente!\r\nkey: %s \r\n json: %s", authKey, CharArrayToString(json)));
		else
		{
			PrintFormat("Stock code successfully changed to %s for robot %s", stock_code, robot_id);
			restart_robot(baseUrl, headers);
		}
	}
}

void restart_robot(string url, string headers)
{
	char json[], result[];
	string result_headers;
	
	int resultCode = WebRequest("POST", url+"stop/", headers, 100, json, result, result_headers);
	if(resultCode == 200)
		Print("Robot Stopped!");
	else
		MessageBox("Error stopping robot! " + CharArrayToString(result));
	
	resultCode = WebRequest("POST", url+"start/", headers, 100, json, result, result_headers);
	if(resultCode == 200)
		Print("Robot Restarted!");
	else
		MessageBox("Error restarting robot! " + CharArrayToString(result));	
	Print("Sleep for 20 sec");
	Sleep(15000);
}

string get_auth_key()
{
	int file_handle=FileOpen("auth_key.txt",FILE_READ|FILE_BIN|FILE_ANSI);
	string str = FileReadString(file_handle, 200);
	StringSetLength(str, StringLen(str)-1);
	FileClose(file_handle);
	return str;
}

string getMarketName(string stockCode)
{
	if(StringFind(stockCode, "WIN") >= 0)
		return "BMF";
	if(StringFind(stockCode, "IND") >= 0)
		return "BMF";
	if(StringFind(stockCode, "WDO") >= 0)
		return "BMF";
	if(StringFind(stockCode, "DOL") >= 0)
		return "BMF";
	
	return "BOVESPA";
}