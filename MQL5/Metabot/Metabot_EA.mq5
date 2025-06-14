//+------------------------------------------------------------------+
//|                                                      TesteEA.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+


#include "SmarttChecker.mqh"
#include "SmarttOrder.mqh"
#include "Enums.mqh"
#include <Generic\HashSet.mqh>

#define LOOP_WAIT 100

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input string strategy_id = ""; //ID da estratégia
input ulong magic_number = 0; //Magic number do EA emissor de sinais (se houver)

SmarttChecker smartt_checker;
string button_name = "emergency_button";

ulong chart = ChartID();

int OnInit()
{		
	if(!smartt_checker.check_initialization())
		ExpertRemove();
		
	// create timer
   EventSetMillisecondTimer(LOOP_WAIT);
		
	create_emergency_button();
	
	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
	ObjectDelete(ChartID(), button_name);
}

void OnTimer()
{
	smartt_checker.check_deals();
}

//+------------------------------------------------------------------+

void create_emergency_button(void)
{
	ObjectCreate(chart, button_name, OBJ_BUTTON, 0, 0, 0);
	ObjectSetInteger(chart, button_name, OBJPROP_XDISTANCE, 0);
	ObjectSetInteger(chart, button_name, OBJPROP_YDISTANCE, 100);
	ObjectSetInteger(chart, button_name, OBJPROP_BGCOLOR, clrBrown);
	ObjectSetInteger(chart, button_name, OBJPROP_COLOR, clrWhite);
	ObjectSetInteger(chart, button_name, OBJPROP_XSIZE, 300);
	ObjectSetInteger(chart, button_name, OBJPROP_YSIZE, 30);
	ObjectSetString(chart, button_name, OBJPROP_TEXT, "ENVIAR SINAL DE ZERAGEM");	
	
}

void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
{
	if(sparam == button_name && id == CHARTEVENT_OBJECT_CLICK)
	{
		ObjectSetInteger(chart, button_name, OBJPROP_STATE, 0);

		CKeyValuePair<string,SmarttOrder*> *smartt_order_items[];
		int count = smartt_checker.smartt_order_map.CopyTo(smartt_order_items);
		for(int i = 0; i < count; i++)
		{
			smartt_order_items[i].Value().send_cancel_all_and_close();
		}
	}
}
