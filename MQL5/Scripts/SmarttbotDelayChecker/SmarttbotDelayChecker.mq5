//+------------------------------------------------------------------+
//|                                                 SmarttbotAPI.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property script_show_inputs

#include <Generic\HashSet.mqh>
#include <SmarttChecker.mqh>

input string login = "arturteste"; //Login da conta emissora de sinais
input string password = "Novasenha0102"; //Senha da conta emissora de sinais
input string strategy_id = "24"; //ID da estratégia
input int magic_number = 0; //Magic number do EA emissor de sinais (se houver)

SmarttChecker smartt_checker;
datetime last_time = 0;

void OnStart()
{	
		
	if(!smartt_checker.check_initialization())
		return;	
		
	while(true)
	{		
		smartt_checker.smartt_order.send_cancel_all_and_close();
		Sleep(60000);
	}
	
	return;
}