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
		
	while(true)
	{		
		smartt_checker.check_authorization();
		datetime ini = GetMicrosecondCount();
		smartt_checker.smartt_order.send_cancel_all_and_close();
		PrintFormat("Delay total = %dms", (GetMicrosecondCount() - ini)/1000);
		Sleep(60000);
	}
	
	return;
}