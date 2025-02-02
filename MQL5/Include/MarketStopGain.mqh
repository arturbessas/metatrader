//+------------------------------------------------------------------+
//|                                                     MarketStopGain.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
 /*
#include <Enums.mqh>
#include <Context.mqh>
Context *context;
*/


class MarketStopGain: public Node
{	
	public:
	double Distance;
	stop_type_enum Type;
		
	void on_trade(void);
	
	MarketStopGain(void);
	MarketStopGain(double distance, stop_type_enum type);
	~MarketStopGain(){};		
};

MarketStopGain::MarketStopGain(void){}

MarketStopGain::MarketStopGain(double distance, stop_type_enum type)
{
	Distance = distance;
	Type = type;
}

void MarketStopGain::on_trade(void)
{
	if(!context.is_positioned())
		return;
		
	double signal = 1;
	
	if(context.is_sold())
		signal = -1;
	
	double avg_price = context.position.average_price;
	double current_price = context.current_price();
	
	double distance = Type == stop_type_absolute ? Distance : (avg_price * Distance/100);
	
	if((current_price - avg_price) * signal > distance)
	{
		context.ClosePositions(StringFormat("Stop gain. Preço: %.4f; Dist: %.4f", current_price, distance));
	}
	
}