//+------------------------------------------------------------------+
//|                                                     PositionIncreaserMarket.mqh |
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


class PositionIncreaserMarket: public Node
{	
	public:
	double distance_list[];
	double quantity_list[];
	stop_type_enum type;
	bool trendwise;
	int step;	
		
	void on_trade(void);
	
	PositionIncreaserMarket(void);
	PositionIncreaserMarket(stop_type_enum Type, bool Trendwise, double d1, double q1, double d2=0, double q2=0, double d3=0, double q3=0, double d4=0, double q4=0, double d5=0, double q5=0);
	~PositionIncreaserMarket(){};		
};

PositionIncreaserMarket::PositionIncreaserMarket(void){}

PositionIncreaserMarket::PositionIncreaserMarket(stop_type_enum Type, bool Trendwise, double d1, double q1, double d2=0, double q2=0, double d3=0, double q3=0, double d4=0, double q4=0, double d5=0, double q5=0)
	{
	   type = Type;
	   trendwise = Trendwise;
		step = MathMax(context.positions_quantity() - 1, 0);
		
		logger.info(StringFormat("Position Increaser initial step: %d", step));
		
		//build lists
		if(d1 > 0 && q1 > 0)
		{
			append(distance_list, d1);
			append(quantity_list, q1);
			
			if(d2 > d1 && q2 > 0)
			{
				append(distance_list, d2);
				append(quantity_list, q2);
				
				if(d3 > d2 && q3 > 0)
				{
					append(distance_list, d3);
					append(quantity_list, q3);
					
					if(d4 > d3 && q4 > 0)
   				{
   					append(distance_list, d4);
   					append(quantity_list, q4);
   					
   					if(d5 > d4 && q5 > 0)
      				{
      					append(distance_list, d5);
      					append(quantity_list, q5);
      				}
   				}
				}
			}
		}
	}

void PositionIncreaserMarket::on_trade(void)
{
	if(!context.is_positioned())
	{
		step = 0;
		//storeStep();
		return;
	}
	
	if(step >= ArraySize(distance_list))
		return;
			
	double entry_price = context.position.entry_price;
	double current_price = context.current_price();
	
	double increase_distance = type == stop_type_absolute ? distance_list[step] : (entry_price * distance_list[step]/100);
	// current distance: positive if profitable, otherwise negative
	double current_distance = context.is_bought() ? current_price - entry_price : entry_price - current_price;
	
	//check increase trigger
	if((current_distance > increase_distance && trendwise) || (current_distance < -increase_distance && !trendwise))
   {
   	bool result = false;
   	if(context.is_bought()) 
   		result = context.Buy(quantity_list[step], StringFormat("Aumento %d. Preço: %.4f", step, current_price));
   	else if(context.is_sold())
   		result = context.Sell(quantity_list[step], StringFormat("Aumento %d. Preço: %.4f", step, current_price));
   	
   	if(result)
   	{
   		step++;
   	}
	}
}
