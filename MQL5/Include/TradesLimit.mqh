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


class TradesLimit: public Node
{	
	public:
	int Value;
		
	void on_order(MqlTradeTransaction &trans);
	
	TradesLimit(void);
	TradesLimit(int value);
	~TradesLimit(){};
};

TradesLimit::TradesLimit(void){}

TradesLimit::TradesLimit(int value)
{
	Value = value;
}

void TradesLimit::on_order(MqlTradeTransaction &trans)
{	
	HistorySelect(TimeCurrent() - 12*60*60, TimeCurrent());
	int trades = HistoryDealsTotal() / 2;
	
	if(trades >= Value)
		context.daily_locked = true;
}