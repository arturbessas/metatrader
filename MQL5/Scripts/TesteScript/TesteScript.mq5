//+------------------------------------------------------------------+

//|                                                 SmarttbotAPI.mq5 |

//|                        Artur Bessas (artur.bessas@smarttbot.com) |

//|                                        https://www.smarttbot.com |

//+------------------------------------------------------------------+

#define version 0.1
#include <Generic\HashMap.mqh>
#include <SmarttbotApiV2.mqh>

string robot_id = "2441147";

void OnStart()

{		
/*
	//StringReplace(stock_code, "$", "%");

	string authKey = get_auth_key();
	string baseUrl = "https://app.smarttbot.com/api/v2/auth/login_return_auth_key";
	string headers = ("Content-Type:application/json; charset=utf-8");
	//string params = "{\"params\":{\"marketName\":\"BOVESPA\",\"stockCode\":\"BBSA3\"}}";
	char json[];
	char result[];
	string result_headers;
	string params = "{\"login\":\"arturbessas\",\"password\":\"tfP6@BL4BVxUTQv\"}";	

	StringToCharArray(params,json,0,StringLen(params), CP_UTF8);	

	int result_code = WebRequest("POST", baseUrl, headers, 100, json, result, result_headers);	

	if(result_code != 200)
		MessageBox("Erro ao enviar sinal. Procure o time de suporte. Erro: " + CharArrayToString(result));	

	Print(CharArrayToString(json));
	Print(CharArrayToString(result));
	Print(headers);
	Print(result_code);
*/

	//set_new_stock_code("WIN%");
	CHashMap<string, int> teste;
	teste.Add("chave", 1);
	int a;
	teste.TryGetValue("chave", a);
	Print(a);
	teste.TrySetValue("chave", 10);
	teste.TryGetValue("chave", a);
	Print(a);
}

