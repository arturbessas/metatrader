//+------------------------------------------------------------------+
//|                                                     BBRule.mqh |
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
//#include <Enums.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class BBRule: public Rule
{	
	public:
	int Periods;
	double Deviations;
	ENUM_APPLIED_PRICE PriceType;
	bool InvertSignal;
	bool IsFilter;
	int bbHandle;
	double aux[1];
	double bbUp;
	double bbDown;
	string last_position;
	string Signal;
		
	void on_trade(void);
	
	void getBB(void);
	string get_position(void);
	
	
	BBRule(void);
	BBRule(int periods, double deviations, price_type_enum price_type, bool invert, bool is_filter);
	~BBRule(){};		
};

BBRule::BBRule(void){}

BBRule::BBRule(int periods, double deviations, price_type_enum price_type, bool invert, bool is_filter)
{
	Periods = periods;
	Deviations = deviations;
	PriceType = context.get_price_type(price_type);
	InvertSignal = invert;
	IsFilter = is_filter;
	
	Signal = "";
	last_position = "";
	
	bbHandle = iBands(_Symbol, context.periodicity, Periods, 0, Deviations, PriceType);
}

void BBRule::on_trade(void)
{
	getBB();
	string current_position = get_position();
	if(last_position == "")
		last_position = current_position;
		
	Signal = "";
	
	if(current_position == "above" && IsFilter)
		Signal = InvertSignal ? "buy" : "sell";
	
	else if(current_position == "below" && IsFilter)
		Signal = InvertSignal ? "sell" : "buy";
		
	else if(current_position == "between" && !IsFilter)
	{
		if(last_position == "below")
			Signal = InvertSignal ? "sell" : "buy";
		else if(last_position == "above")
			Signal = InvertSignal ? "buy" : "sell";
	}
	
	last_position = current_position;	
}

void BBRule::getBB()
{
	CopyBuffer(bbHandle,1,1,1,aux);
	bbUp = aux[0];
	CopyBuffer(bbHandle,2,1,1,aux);
	bbDown = aux[0];
}

void BBRule::get_position()
{
	double price = context.current_price();
	
	if(price > bbUp)
		return "above";
	else if(price < bbDown)
		return "below";
	else
		return "between";
}