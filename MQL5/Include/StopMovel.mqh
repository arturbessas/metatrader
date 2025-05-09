//+------------------------------------------------------------------+
//|                                                     StopMovel.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


/*
#include <Context.mqh>

Context context;
*/


class StopMovel: public Node
{	
	public:
	double Begin;
	double Distance;
	stop_type_enum Type;
	bool Enabled;
	double Reference;
		
	void on_trade(void);
	
	StopMovel(void);
	StopMovel(stop_type_enum type, double begin, double distance);
	~StopMovel(){};		
};

StopMovel::StopMovel(void){}

StopMovel::StopMovel(stop_type_enum type, double begin, double distance)
{
   Type = type;
	Begin = begin;
	Distance = distance;
	Enabled = false;
	Reference = 0;
}

void StopMovel::on_trade(void)
{
	if(!context.is_positioned())
	{
		Enabled = false;
		return;
	}
		
	double signal = context.is_bought() ? 1 : -1;
	
	double entry_price = context.entry_price();
	double current_price = context.current_price();
	
	if(!Enabled)
	{
	   double begin_delta = Type == stop_type_absolute ? Begin : (entry_price * Begin/100);
	
   	if((current_price - entry_price) * signal > begin_delta)
   	{
   	   Enabled = true;
   	   Reference = current_price;
   	}
   	
   	return;
	}
	
	// Update reference price
	if((context.is_bought() && current_price > Reference) || (context.is_sold() && current_price < Reference))
	   Reference = current_price;
	   
	// Check stop
	double stop_delta = Type == stop_type_absolute ? Distance : (Reference * Distance/100);
	if((Reference - current_price) * signal > stop_delta)
	{
		context.ClosePositions(StringFormat("Stop movel. Max: %.1f%%; D: %.1f%%",100*MathAbs(Reference/entry_price - 1), 100*MathAbs(Reference/current_price - 1)));
	}
}