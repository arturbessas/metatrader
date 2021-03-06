//+------------------------------------------------------------------+
//|                                                      TesteEA.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property icon "image.ico"


#include <SmarttChecker.mqh>
#include <SmarttOrder.mqh>
#include <Generic\HashSet.mqh>

input string login = ""; //Login da conta emissora de sinais
input string password = ""; //Senha da conta emissora de sinais
input string strategy_id = ""; //ID da estratégia
input int magic_number = 0; //Magic number do EA emissor de sinais (se houver)

SmarttChecker smartt_checker;

ulong chart = ChartID();

int OnInit()
{
		
	if(!smartt_checker.check_initialization())
		ExpertRemove();
		
	create_emergency_button();
	
	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
	ObjectDelete(ChartID(), "emergency_button");
}

void OnTick()
{
	smartt_checker.check_orders();
}

//+------------------------------------------------------------------+


string button_name = "emergency_button";

void create_emergency_button(void)
{
	ObjectCreate(chart, button_name, OBJ_BUTTON, 0, 0, 0);
	ObjectSetInteger(chart, button_name, OBJPROP_XDISTANCE, 0);
	ObjectSetInteger(chart, button_name, OBJPROP_YDISTANCE, 100);
	//ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
	ObjectSetInteger(chart, button_name, OBJPROP_BGCOLOR, clrBrown);
	ObjectSetInteger(chart, button_name, OBJPROP_COLOR, clrWhite);
	ObjectSetInteger(chart, button_name, OBJPROP_XSIZE, 300);
	ObjectSetInteger(chart, button_name, OBJPROP_YSIZE, 30);
	ObjectSetString(chart, button_name, OBJPROP_TEXT, "ENVIAR SINAL DE ZERAGEM");	
	
}

void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
{
	if(sparam == "emergency_button" && id == CHARTEVENT_OBJECT_CLICK)
	{
		ObjectSetInteger(chart, button_name, OBJPROP_STATE, 0);
		smartt_checker.smartt_order.send_cancel_all_and_close();		
	}
}
