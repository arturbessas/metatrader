//+------------------------------------------------------------------+
//|                                                 DelayChecker.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property service
//+------------------------------------------------------------------+
//| Service program start function                                   |
//+------------------------------------------------------------------+

#include <Generic\HashSet.mqh>
#include <SmarttChecker.mqh>

string login = "arturteste"; //Login da conta emissora de sinais
string password = "Novasenha0102"; //Senha da conta emissora de sinais
string strategy_id = "24"; //ID da estratégia
int magic_number = 0; //Magic number do EA emissor de sinais (se houver)

SmarttChecker smartt_checker;

void OnStart()
{			
	if(!smartt_checker.check_initialization())
		return;	
		
	string cookie=NULL,headers;
   char   post[],result[];
   string url="https://google.com";
   
   
   
	
	
	while(true)
	{			
		smartt_checker.check_authorization();
		datetime ini = GetMicrosecondCount();
		smartt_checker.smartt_order.send_cancel_all_and_close();
		datetime fin = GetMicrosecondCount();
		PrintFormat("Delay Smarttbot = %dms", (fin - ini)/1000);
		WebRequest("POST",url,cookie,NULL,500,post,0,result,headers);
		PrintFormat("Delay Google = %dms", (GetMicrosecondCount() - fin)/1000);
		Sleep(60000);
	}
	
	
	return;
}