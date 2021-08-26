//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
/*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class TradesLimit
{	
	public:
	int Value;
	bool Enabled;
		
	void on_order(void);
	
	TradesLimit(void);
	TradesLimit(bool enabled, int value);
	~TradesLimit(){};
};

TradesLimit::TradesLimit(void){}

TradesLimit::TradesLimit(bool enabled, int value)
{
	Enabled = enabled;
	Value = value;
}

void TradesLimit::on_order(void)
{
	if(!Enabled)
		return;
	
	HistorySelect(TimeCurrent() - 12*60*60, TimeCurrent());
	int trades = HistoryDealsTotal() / 2;
	
	if(trades >= Value)
		context.daily_locked = true;
}