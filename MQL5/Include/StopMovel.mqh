//+------------------------------------------------------------------+
//|                                                     StopMovel.mqh |
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


class StopMovel: public Node
{	
	public:
	double Begin;
	double Distance;
	double Profit;
	bool Enabled;
		
	void on_trade(void);
	
	StopMovel(void);
	StopMovel(double begin, double distance);
	~StopMovel(){};		
};

StopMovel::StopMovel(void){}

StopMovel::StopMovel(double begin, double distance)
{
	Begin = begin;
	Distance = distance;
	Enabled = false;
	Profit = 0;
}

void StopMovel::on_trade(void)
{
	if(!context.pos_info.Select(Symbol()))
	{
		Enabled = false;
		return;
	}
		
	double signal = 1;
	
	if(context.pos_info.PositionType() == POSITION_TYPE_SELL)
		signal = -1;
	
	double entry_price = context.pos_info.PriceOpen();
	double current_price = context.current_price();
	double current_profit = (current_price - entry_price) * signal;
	
	if(!Enabled && current_profit >= Begin)
	{
		Enabled = true;
		Profit = current_profit;
	}
	
	if(Enabled && current_profit > Profit)
		Profit = current_profit;
	
	if(Enabled && Profit - current_profit >= Distance)
		context.trade.PositionClose(Symbol());
	
}