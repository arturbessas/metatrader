//+------------------------------------------------------------------+
//|                                                 SmarttbotAPI.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property script_show_inputs

#include <Generic\HashSet.mqh>
#include <SmarttCheckerMultistock.mqh>

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input string strategy_id = ""; //ID da estratégia
input int magic_number = 0; //Magic number do EA emissor de sinais (se houver)
input string robot_id = ""; //ID do robô na Smarttbot
input bool usingMultistockEa = false; //Usando EA multiativos?

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