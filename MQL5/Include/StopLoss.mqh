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


class StopLoss
{	
	public:
	double Distance;
		
	void on_trade(void);
	
	StopLoss(void);
	StopLoss(double distance);
	~StopLoss(){};		
};

StopLoss::StopLoss(void){}

StopLoss::StopLoss(double distance)
{
	Distance = distance;
}

void StopLoss::on_trade(void)
{
	if(!context.pos_info.Select(Symbol()))
		return;
		
	double signal = 1;
	
	if(context.pos_info.PositionType() == POSITION_TYPE_SELL)
		signal = -1;
	
	double entry_price = context.pos_info.PriceOpen();
	double current_price = context.current_price();
	
	if((entry_price - current_price) * signal > Distance)
	{
		context.trade.PositionClose(Symbol());
	}
	
}