//+------------------------------------------------------------------+
//|                                                 SmarttbotAPI.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property script_show_inputs

#include <CBRT\SmarttChecker.mqh>
#include <CBRT\SmarttOrder.mqh>
#include <Generic\HashSet.mqh>
#include <CBRT\Enums.mqh>

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input CBRT_strategy_enum strategy_id; //ID da estratégia
input int magic_number = 0; //Magic number do EA emissor de sinais (!=0)
enum_bool using_multi_stocks = 0; //Operar múltiplos ativos

SmarttChecker smartt_checker;

void OnStart()
{	
		
	if(!smartt_checker.check_initialization())
		return;
		
	while(true)
	{
		smartt_checker.check_orders();
		Sleep(50);
	}
	
	return;
}