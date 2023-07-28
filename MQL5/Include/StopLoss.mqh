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


class StopLoss: public Node
{	
	public:
	Context *context;
	double Distance;
	string Type;
		
	void on_trade(void);
	
	StopLoss(void);
	StopLoss(Context *cont, double distance, string type);
	~StopLoss(){};		
};

StopLoss::StopLoss(void){}

StopLoss::StopLoss(Context *cont, double distance, string type = "absolute")
{
	context = cont;
	Distance = distance;
	Type = type;
}

void StopLoss::on_trade(void)
{
	if(!context.pos_info.Select(context.stock_code))
		return;
		
	double signal = 1;
	
	if(context.pos_info.PositionType() == POSITION_TYPE_SELL)
		signal = -1;
	
	double entry_price = context.entry_price;
	double current_price = context.current_price();
	
	double distance = Type == "absolute" ? Distance : (entry_price * Distance/100);
	
	if((entry_price - current_price) * signal > distance)
	{
		context.trade.PositionClose(context.stock_code);
	}
	
}