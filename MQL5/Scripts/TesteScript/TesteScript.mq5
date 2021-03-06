//+------------------------------------------------------------------+
//|                                                 SmarttbotAPI.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property script_show_inputs

#define version 0.1

#include <Generic\HashSet.mqh>

#import "shell32.dll"

int ShellExecuteA(int hwnd,string Operation,string File,string Parameters,string Directory,int ShowCmd);

#import

void OnStart()
{		
	//StringReplace(stock_code, "$", "%");
	string authKey = get_auth_key();
	string baseUrl = "https://app.smarttbot.com/api/v2/strategies/instances/2441147/";
	string headers = StringFormat("auth-key:%s\r\nContent-Type:application/json; charset=utf-8", authKey);
	string params = "{\"params\":{\"marketName\":\"BOVESPA\",\"stockCode\":\"VALE3\"}}";
	//string cookie = "_ga=GA1.2.489707697.1613999444; _ga=GA1.3.489707697.1613999444; _clck=103vuio; __zlcmid=12mjpXGspMza1gf; _hjid=a985f05e-b792-404f-b9bb-dd8d2f953fab; _BEAMER_USER_ID_hyBdprMt22323=ef2c2853-efbb-4dc5-9eb2-3d7aaddd3ff4; _BEAMER_USER_ID_hyBdprMt22323=ef2c2853-efbb-4dc5-9eb2-3d7aaddd3ff4; _BEAMER_FIRST_VISIT_hyBdprMt22323=2021-02-22T13:13:10.554Z; _fbp=fb.1.1617109550766.2049843569; _BEAMER_DATE_hyBdprMt22323=2021-05-07T11:57:02.000Z; _BEAMER_LAST_UPDATE_hyBdprMt22323=1622495635059; _BEAMER_LAST_PUSH_PROMPT_INTERACTION_hyBdprMt22323=1623275056924; _BEAMER_DATE_hyBdprMt22323=2021-08-17T18:56:20.000Z; _BEAMER_NPS_LAST_SHOWN_hyBdprMt22323=1630088715743; _hjDonePolls=724234; _gcl_au=1.1.1819949600.1630422275; amplitude_idundefinedsmarttbot.com=eyJvcHRPdXQiOmZhbHNlLCJzZXNzaW9uSWQiOm51bGwsImxhc3RFdmVudFRpbWUiOm51bGwsImV2ZW50SWQiOjAsImlkZW50aWZ5SWQiOjAsInNlcXVlbmNlTnVtYmVyIjowfQ==; _BEAMER_LAST_POST_SHOWN_hyBdprMt22323=18689016; i18next=pt; ajs_user_id=%22arturbessas%22; ajs_anonymous_id=%226286b097-21ff-4191-a9dc-e1ebacc69e82%22; _gid=GA1.2.19376597.1633955628; _gid=GA1.3.19376597.1633955628; _clck=v0hs4l|1|evh|0; ubvt=187.127.121.651618567449485172; _clsk=1b1np7r|1633976082635|4|1|b.clarity.ms/collect; _BEAMER_BOOSTED_ANNOUNCEMENT_DATE_hyBdprMt22323=2021-10-11T20:40:30.748Z; _hjIncludedInPageviewSample=1; _hjIncludedInSessionSample=1; ss_auth=s%3A2ad08bfe-cc71-4d48-ad6c-c0bcebd49dbd.iHa9l%2F%2F2Hyin29WE9DgvVg8HCvMOJ0HIeKHncAcRLRw; _hjAbsoluteSessionInProgress=0; amplitude_id_70c75c6f5426ac3ba67a03dfb2b773d8smarttbot.com=eyJkZXZpY2VJZCI6IjVmZWQ2Mzk4LTYxMzMtNDAwNS1iNWIzLWQ1YTkxYzk2M2Y1MVIiLCJ1c2VySWQiOiJhcnR1cmJlc3NhcyIsIm9wdE91dCI6ZmFsc2UsInNlc3Npb25JZCI6MTYzNDAwNjkyNjMzMiwibGFzdEV2ZW50VGltZSI6MTYzNDAxMjU2ODk1MCwiZXZlbnRJZCI6NjQ0NCwiaWRlbnRpZnlJZCI6OTk1OSwic2VxdWVuY2VOdW1iZXIiOjE2NDAzfQ==; _BEAMER_FILTER_BY_URL_hyBdprMt22323=true; mp_ad9f6cf9a52fb96989df36da0b372752_mixpanel=%7B%22distinct_id%22%3A%20%22177c9de10934b6-00be99a8ede6cf-3b7c0d51-1fa400-177c9de1094e8d%22%2C%22%24initial_referrer%22%3A%20%22https%3A%2F%2Fsmarttbot.com%2F%22%2C%22%24initial_referring_domain%22%3A%20%22smarttbot.com%22%7D; _BEAMER_LAST_UPDATE_hyBdprMt22323=1634014177329";
	string referer = "https://app.smarttbot.com/private/robos/2441147/parametros";
	


	char json[];
	char result[];
	string result_headers;
	//string text = "{\"login\":\"arturbessas\",\"password\":\"tfP6@BL4BVxUTQv\"}";
	
	StringToCharArray(params,json,0,StringLen(params), CP_UTF8);
	
	//int result_code = WebRequest("PUT", baseUrl, cookie, referer, 60, json, ArraySize(json), result, headers);	
	
	int result_code = WebRequest("PUT", baseUrl, headers, 100, json, result, result_headers);	
	if(result_code != 200)
		MessageBox("Erro ao enviar sinal. Procure o time de suporte. Erro: " + CharArrayToString(result));	
	Print(CharArrayToString(json));
	Print(CharArrayToString(result));
	Print(headers);
	//Print(result_headers);
	Print(result_code);	
	
}

string get_auth_key()
{
	int file_handle=FileOpen("data"+"//"+"auth_key.txt",FILE_READ|FILE_BIN|FILE_ANSI);
	string str = FileReadString(file_handle, 200);
	StringSetLength(str, StringLen(str));
	return str;
}

void readFile()
{
	ResetLastError();
   int file_handle=FileOpen("data"+"//"+"auth_key.txt",FILE_READ|FILE_BIN|FILE_ANSI);
   if(file_handle!=INVALID_HANDLE)
     {
      PrintFormat("%s arquivo está disponível para leitura","auth_key.txt");
      PrintFormat("Caminho do arquivo: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      //--- variáveis ​​adicionais
      string str;
      //--- ler dados de um arquivo
      //while(!FileIsEnding(file_handle))
        {
         //--- descobrir quantos símbolos são usados ​​para escrever o tempo
         //str_size=FileReadInteger(file_handle,INT_VALUE);
         //--- ler a string
         str=FileReadString(file_handle, 200);
         StringSetLength(str, StringLen(str)-1);
         //--- imprimir a string
         Print(str);
        }
      //--- fechar o arquivo
      FileClose(file_handle);
      PrintFormat("Dados são lidos, %s arquivo está fechado","auth_key.txt");
     }
   else
      PrintFormat("Falha para abrir %s arquivo, Código de erro = %d","auth_key.txt",GetLastError());
}