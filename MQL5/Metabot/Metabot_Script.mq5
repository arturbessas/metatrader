//+------------------------------------------------------------------+
//|                                                 SmarttbotAPI.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property script_show_inputs

#include "SmarttChecker.mqh"
#include "SmarttOrder.mqh"
#include "Enums.mqh"
#include <Generic\HashSet.mqh>

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input string strategy_id = ""; //ID da estratégia
input ulong magic_number = 0; //Magic number do EA emissor de sinais (se houver)
input enum_bool using_multi_stocks; //Operar múltiplos ativos

SmarttChecker smartt_checker;

void OnStart()
{	
		
	if(!smartt_checker.check_initialization())
		return;
		
	while(!IsStopped())
	{
		smartt_checker.check_orders();
		Sleep(50);
	}
	
	return;
}