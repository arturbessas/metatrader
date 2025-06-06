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
#include <Enums.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
 */


class StopLoss: public Node
{	
	public:
	double Distance;
	stop_type_enum Type;
		
	void on_trade(void);
	
	StopLoss(void);
	StopLoss(double distance, stop_type_enum type);
	~StopLoss(){};		
};

StopLoss::StopLoss(void){}

StopLoss::StopLoss(double distance, stop_type_enum type)
{
	Distance = distance;
	Type = type;
}

void StopLoss::on_trade(void)
{
	if(!context.is_positioned())
		return;
		
	double signal = 1;
	
	if(context.is_sold())
		signal = -1;
	
	double entry_price = context.position.entry_price;
	double current_price = context.current_price();
	
	double distance = Type == stop_type_absolute ? Distance : (entry_price * Distance/100);
	
	if((entry_price - current_price) * signal > distance)
	{
		context.ClosePositions(StringFormat("Saída por stop loss. Preço: %.4f", current_price));
	}
	
}