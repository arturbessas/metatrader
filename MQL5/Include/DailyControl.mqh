//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
///*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
//*/

input group "#---# Daily Control #---#"
input using_daily_control; //Usar Daily Control
input elim_time; //Horário de eliminação

class DailyControl: public Node
{		
	void on_trade(void);
	
	DailyControl(void);
	DailyControl(Context *cont);
	~DailyControl(){};
};

DailyControl::DailyControl(void){}

DailyControl::DailyControl(Context *cont)
{
	context = cont;
}

void DailyControl::on_trade(void)
{	
	if(!using_daily_control)
		return
}