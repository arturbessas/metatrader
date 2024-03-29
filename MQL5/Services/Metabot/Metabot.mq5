//+------------------------------------------------------------------+
//|                                                      Metabot.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property service

#include <SmarttChecker.mqh>

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input string strategy_id = ""; //ID da estratégia
input int magic_number = 0; //Magic number do EA emissor de sinais (se houver)
input bool using_multi_stocks = false; //Operar múltiplos ativos

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