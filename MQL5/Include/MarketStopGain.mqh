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
	stop_reference_enum ReferenceType;
		
	void on_trade(void);
	
	MarketStopGain(void);
	MarketStopGain(double distance, stop_type_enum type, stop_reference_enum reference_type);
	~MarketStopGain(){};		
};

MarketStopGain::MarketStopGain(void){}

MarketStopGain::MarketStopGain(double distance, stop_type_enum type, stop_reference_enum reference_type)
{
	Distance = distance;
	Type = type;
	ReferenceType = reference_type;
}

void MarketStopGain::on_trade(void)
{
	if(!context.is_positioned())
		return;
		
	double signal = 1;
	
	if(context.is_sold())
		signal = -1;
	
	double ref_price = ReferenceType == stop_reference_entry ? context.entry_price() : context.average_price();
	double current_price = context.current_price();
	
	double distance = Type == stop_type_absolute ? Distance : (ref_price * Distance/100);
	
	if((current_price - ref_price) * signal > distance)
	{
		context.ClosePositions(StringFormat("Stop gain. Preço: %.4f; Dist: %.4f", current_price, distance));
	}
	
}