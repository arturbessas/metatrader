//+------------------------------------------------------------------+
//|                                                     DailyBreakEven.mqh |
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


class DailyBreakEven: public Node
{	
	public:
	double Begin;
	double Distance;
	double Profit;
	bool Enabled;
		
	void on_trade(void);
	
	DailyBreakEven(void);
	DailyBreakEven(double begin, double distance);
	~DailyBreakEven(){};		
};

DailyBreakEven::DailyBreakEven(void){}

DailyBreakEven::DailyBreakEven(double begin, double distance)
{
	Begin = begin;
	Distance = distance;
	Enabled = false;
	Profit = 0;
}

void DailyBreakEven::on_trade(void)
{
	if(context.is_new_day())
		Enabled = false;
		
	double current_profit = context.get_daily_profit();
	
	if(!Enabled && current_profit >= Begin)
	{
		Enabled = true;
		Profit = current_profit;
	}
	
	if(Enabled && current_profit > Profit)
		Profit = current_profit;
	
	if(Enabled && Profit - current_profit >= Distance)
	{
		context.daily_locked = true;
		if(context.pos_info.Select(Symbol()))
		{
			context.trade.PositionClose(Symbol());			
			Print("Saída por break even financeiro diário.");
		}
	}
}