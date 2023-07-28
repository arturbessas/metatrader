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
	Context *context;
	double distance_list[];
	int quantity_list[];
	string Type;
	int step;
	string StoredStepName;
	
		
	void on_trade(void);
	int getStep(void);
	void storeStep(void);
	
	PositionIncreaserMarket(void);
	PositionIncreaserMarket(Context *cont, double &dList[], int &qLlist, string type);
	~PositionIncreaserMarket(){};		
};

PositionIncreaserMarket::PositionIncreaserMarket(void){}

PositionIncreaserMarket::PositionIncreaserMarket(Context *cont, double &dList[], int &qLlist, string type = "absolute")
{
	context = cont;
	distance_list = dList;
	quantity_list = qLlist;
	Type = type;
	StoredStepName = context.stock_code + "_increaserStep";
	step = getStep();
}

void PositionIncreaserMarket::on_trade(void)
{
	if(!context.pos_info.Select(context.stock_code))
	{
		step = 0;
		storeStep();
		return;
	}
	if(step >= ArraySize(distance_list))
		return;
		
	double signal = 1;
	
	if(context.pos_info.PositionType() == POSITION_TYPE_SELL)
		signal = -1;
	
	double entry_price = context.entry_price;
	double current_price = context.current_price();
	
	double distance = Type == "absolute" ? distance_list[step] : (entry_price * distance_list[step]/100));
	
	if((entry_price - current_price) * signal > distance)
	{
		bool result;
		if(signal > 0)
			result = context.Buy(quantity_list[step], StringFormat("Increase %d", step));
		else
			result = context.Sell(quantity_list[step], StringFormat("Increase %d", step));
		
		if(result)
		{
			step++;
			storeStep();
		}
	}	
}

int PositionIncreaserMarket::getStep(void)
{
	if(GlobalVariableCheck(StoredStepName) && context.pos_info.Select(context.stock_code))
		return GlobalVariableGet(StoredStepName);
	else
	{
		GlobalVariableSet(StoredStepName, 0);
		return 0;
	}
}

void PositionIncreaserMarket::storeStep(void)
{
	GlobalVariableSet(StoredStepName, step);
}