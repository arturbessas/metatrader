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


class DailyStopLoss: public Node
{	
	public:
	double Value;
		
	void on_trade(void);
	
	DailyStopLoss(void);
	DailyStopLoss(double value);
	~DailyStopLoss(){};
};

DailyStopLoss::DailyStopLoss(void){}

DailyStopLoss::DailyStopLoss(double value)
{
	Value = value;
}

void DailyStopLoss::on_trade(void)
{	
	double daily_profit = context.get_daily_profit();
	
	if(daily_profit <= -Value)
	{
		context.daily_locked = true;
		if(context.pos_info.Select(Symbol()))
		{
			context.trade.PositionClose(Symbol());
			PrintFormat("Stop Loss diário atingido. Loss: %.2f", daily_profit);
		}
	}	
}